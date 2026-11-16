//
//  PeerTransportService+Diagnostics.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import Network
import WiFiAware

// MARK: - Link Metrics & Diagnostic Telemetry

extension PeerTransportService {
    
    /// Forward using live links so a newly ready peer is immediately available to the router.
    public func activeNeighbors() async -> [NeighborInfo] {
        connections.values.filter(\.isReady).map {
            NeighborInfo(id: $0.peerId, displayName: $0.displayName, state: .connected,
                rssi: nil, lastSeen: $0.lastSeen, roundTripTimeMs: nil,
                isGroupMember: $0.isGroupMember, capabilities: .standardMesh)
        }
    }

    /// Returns the number of direct peer connections currently established and operational.
    public func activeDirectPeerCount() async -> Int {
        connections.values.count(where: \.isReady)
    }
    
    /// Captures a live diagnostic snapshot of radio telemetry.
    public func getDiagnostics() async -> TransportDiagnostics {
        let links = connections.values.filter(\.isReady).map { ($0.peerId, $0.token, $0.connection.currentPath) }
        var signalStrengthByPeer: [String: Double] = [:]
        for (peerID, token, path) in links {
            guard let strength = try? await path?.wifiAware?.performance.signalStrength,
                  connections[peerID]?.token == token, (0...1).contains(strength) else { continue }
            signalStrengthByPeer[peerID] = strength
        }
        let activePeers = connections.values.filter(\.isReady).map { peer in
            PeerInfo(
                id: peer.peerId,
                displayName: peer.displayName,
                rssi: nil,
                isDirectLink: peer.isReady,
                isGroupMember: peer.isGroupMember,
                lastSeen: peer.lastSeen
            )
        }
        
        return TransportDiagnostics(
            localPeerId: activeSession?.localInitials ?? "",
            serviceType: serviceType,
            sessionName: activeSession?.sessionName ?? "None",
            sessionId: activeSession?.sessionId ?? 0,
            state: currentState,
            activeDirectPeers: activePeers,
            signalStrengthByPeer: signalStrengthByPeer,
            pairedDeviceCount: pairedDeviceIDs.count,
            packetsSent: packetsSentCount,
            packetsReceived: packetsReceivedCount,
            obsoletePingsCoalesced: outbox.obsoletePingsCoalesced,
            sendErrors: sendErrorsCount,
            lastError: lastErrorMessage,
            recentEvents: diagnosticEvents,
            recentPackets: packetEvents
        )
    }

    func recordPacket(_ envelope: CleartextEnvelope, direction: TransportDiagnostics.PacketEvent.Direction, peerId: String) {
        guard let session = activeSession else { return }
        packetEvents.append(.init(envelope: envelope, direction: direction, peerId: peerId,
            isOutsideGroup: envelope.sessionId != session.sessionId))
        if packetEvents.count > 100 {
            packetEvents.removeFirst()
        }
    }
}
