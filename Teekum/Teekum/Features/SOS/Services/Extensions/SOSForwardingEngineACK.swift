//
//  SOSForwardingEngineACK.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CryptoKit

// MARK: - Multi-Hop Return ACK Transmission & Ingestion

extension SOSForwardingEngine {
    
    // MARK: - Multi-Hop Return ACK Transmission
    
    /// Conformance to `SOSForwardingManaging`: Generates and transmits an authenticated ACK.
    /// Routes unicast along known reverse route if present; otherwise uses bounded flooding fallback.
    public func sendDeliveryACK(
        for originalPacket: RawWirePacket,
        status: ACKStatus
    ) async throws {
        guard let session = sessionProvider?() else {
            throw TransportError.sessionInvalid
        }
        
        let key = SymmetricKey(data: session.symmetricKeyData)
        
        // Decrypt original payload to extract event ID and sender initials
        let decrypted = try await cryptoService.open(
            ciphertext: originalPacket.ciphertext,
            envelope: originalPacket.envelope,
            authTag: originalPacket.authTag,
            using: key
        )
        
        guard let sosPayload = try? SOSPayload.deserialize(from: decrypted) else {
            throw TransportError.malformedPacket
        }
        
        let ackPayload = ACKPayload(
            ackedSeqNumber: originalPacket.envelope.sequenceNumber,
            ackedSenderInitials: sosPayload.senderInitials,
            ackTimestamp: clock.now(),
            ackStatus: status,
            receivedRssi: 0,
            originalEventId: sosPayload.sosEventId,
            responderInitials: session.localInitials
        )
        let payloadData = ackPayload.serialize()
        
        let seq = CleartextEnvelope.makeSequenceNumber(memberSlot: session.memberSlot, counter: monotonicCounter)
        monotonicCounter &+= 1
        
        let ackEnvelope = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .ack,
            hopLimit: PacketConstants.sosHopLimit,
            hopCount: 0,
            sessionId: session.sessionId,
            sequenceNumber: seq
        )
        
        let sealed = try await cryptoService.seal(payload: payloadData, envelope: ackEnvelope, using: key)
        let wirePacket = RawWirePacket(envelope: ackEnvelope, ciphertext: sealed.ciphertext, authTag: sealed.authTag)
        let wireData = try wirePacket.toWireData()
        
        // Return ACK Route Resolution: Prefer known usable route towards the distressed sender
        if let routingTable = routingTable,
           let route = await routingTable.findRoute(to: sosPayload.senderInitials),
           route.isFresh {
            // Send unicast along known multi-hop route
            _ = try await transport.sendFrame(wireData, to: route.nextHopPeerId)
        } else {
            // Bounded Flooding Fallback across all active mesh links
            try await transport.broadcastFrame(wireData)
        }
        
        totalAcksSentCount += 1
    }
    
    // MARK: - Inbound ACK Processing Pipeline
    
    /// Conformance to `SOSForwardingManaging`: Ingests and processes an incoming delivery ACK.
    public func handleInboundACK(
        rawPacket: RawWirePacket,
        fromPeerId: String
    ) async {
        guard let session = sessionProvider?() else { return }
        
        let envelope = rawPacket.envelope
        guard envelope.sessionId == session.sessionId else { return }
        
        let key = SymmetricKey(data: session.symmetricKeyData)
        guard let decrypted = try? await cryptoService.open(
            ciphertext: rawPacket.ciphertext,
            envelope: envelope,
            authTag: rawPacket.authTag,
            using: key
        ) else {
            // Unauthenticated ACK dropped
            return
        }
        
        guard let payload = try? ACKPayload.deserialize(from: decrypted) else { return }
        
        // Verify this ACK confirms our local member and matches active SOS event
        guard payload.ackedSenderInitials == session.localInitials else { return }
        if let activeId = activeSOSEventId, payload.originalEventId != activeId {
            return
        }
        
        totalAcksReceivedCount += 1
        
        switch payload.ackStatus {
        case .deliveredToFriend:
            cancelRetries()
            lastDeliveredFriendId = payload.responderInitials
            lastDeliveredTimestamp = clock.now()
            lastDeliveredHopCount = envelope.hopCount
            updateDeliveryState(.deliveredToFriend(friendId: payload.responderInitials, timestamp: clock.now()))
            
        case .relayedByMeshHop:
            lastRelayHopCount = envelope.hopCount
            lastRelayResponderId = payload.responderInitials
            if !currentDeliveryState.isDelivered {
                updateDeliveryState(.relayedAck(relayHopCount: envelope.hopCount, responderId: payload.responderInitials))
            }
        }
    }
}
