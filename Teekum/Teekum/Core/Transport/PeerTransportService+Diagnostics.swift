//
//  PeerTransportService+Diagnostics.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

// MARK: - Link Metrics & Diagnostic Telemetry

extension PeerTransportService {
    
    /// Current view of directly reachable neighbors from NeighborTable.
    public func activeNeighbors() async -> [NeighborInfo] {
        // Forward using live links, not the asynchronously updated telemetry registry.
        // BLE and newly ready Wi-Fi links must be available to the router immediately.
        let wifi = connections.values.filter { $0.isReady }.map {
            NeighborInfo(id: $0.peerId, displayName: $0.displayName, state: .connected,
                rssi: nil, lastSeen: $0.lastSeen, roundTripTimeMs: nil,
                isGroupMember: $0.isGroupMember, capabilities: $0.capabilities)
        }
        return wifi + blePeers.map {
            NeighborInfo(id: $0, displayName: "Bluetooth peer", state: .connected,
                rssi: nil, lastSeen: Date(), roundTripTimeMs: nil,
                isGroupMember: false, capabilities: .standardMesh)
        }
    }
    
    /// Returns the number of direct peer connections currently established and operational.
    public func activeDirectPeerCount() async -> Int {
        connections.values.filter { $0.isReady }.count + blePeers.count
    }
    
    /// Captures a live diagnostic snapshot of radio telemetry.
    public func getDiagnostics() async -> TransportDiagnostics {
        let activePeers = connections.values.map { peer in
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
            localPeerId: localPeerId,
            serviceType: serviceType,
            sessionName: activeSession?.sessionName ?? "None",
            sessionId: activeSession?.sessionId ?? 0,
            state: currentState,
            activeDirectPeers: activePeers + blePeers.map { PeerInfo(id: $0, displayName: "Bluetooth peer", isGroupMember: false) },
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
