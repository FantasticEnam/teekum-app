//
//  PeerTransportServiceDiagnostics.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import Network

// MARK: - Link Metrics & Diagnostic Telemetry

extension PeerTransportService {
    
    /// Current view of directly reachable neighbors from NeighborTable.
    public func activeNeighbors() async -> [NeighborInfo] {
        await neighborTable.activeNeighbors()
    }
    
    /// Returns the number of direct peer connections currently established and operational.
    public func activeDirectPeerCount() async -> Int {
        connections.values.filter { $0.isReady }.count
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
            activeDirectPeers: activePeers,
            packetsSent: packetsSentCount,
            packetsReceived: packetsReceivedCount,
            obsoletePingsCoalesced: outbox.obsoletePingsCoalesced,
            sendErrors: sendErrorsCount,
            lastError: lastErrorMessage,
            recentEvents: diagnosticEvents
        )
    }
    
    // MARK: - Diagnostic Testing Mechanism
    
    /// Interactive diagnostic probe for physical two-device testing.
    /// Sends a diagnostic test message to verify bidirectional link latency and ACK reception.
    ///
    /// - Parameter peerId: Target peer ID, or nil to ping all direct peers.
    /// - Returns: Count of peers to which the test probe was dispatched.
    @discardableResult
    public func sendDiagnosticPing(to peerId: String? = nil) async throws -> Int {
        guard let session = activeSession else {
            throw TransportError.notStarted
        }
        
        let envelope = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .ack,
            hopLimit: 1,
            hopCount: 0,
            sessionId: session.sessionId,
            sequenceNumber: UInt32.random(in: 1...UInt32.max)
        )
        
        // 30 bytes dummy payload for ping
        let dummyPayload = Data(repeating: 0xEE, count: PacketConstants.encryptedPayloadSize)
        // 16 bytes auth tag
        let dummyTag = Data(repeating: 0xFF, count: PacketConstants.authTagSize)
        
        let wirePacket = RawWirePacket(envelope: envelope, ciphertext: dummyPayload, authTag: dummyTag)
        let wireData = try wirePacket.toWireData()
        
        if let peerId = peerId {
            try await sendPacket(wireData, to: peerId)
            return 1
        } else {
            let count = await activeDirectPeerCount()
            try await broadcastPacket(wireData)
            return count
        }
    }
}
