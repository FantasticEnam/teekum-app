//
//  ChatMessageEngineInbound.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation
import CryptoKit

// MARK: - Inbound Packet Ingestion Pipeline

extension ChatMessageEngine {
    
    /// Ingests, validates, and processes an inbound wire packet.
    /// Supports direct peer reception and blind stranger relay forwarding.
    public func handleInboundWirePacket(
        _ wireData: Data,
        fromPeerId: String,
        receivedRssi: Int8? = nil
    ) async throws -> InboundChatOutcome {
        // 1. Strict size check
        guard wireData.count == PacketConstants.wirePacketSize else {
            return .droppedMalformed
        }
        
        let rawPacket: RawWirePacket
        do {
            rawPacket = try RawWirePacket.fromWireData(wireData)
        } catch {
            return .droppedMalformed
        }
        
        return try await handleInboundPacket(
            rawPacket: rawPacket,
            wireData: wireData,
            fromPeerId: fromPeerId,
            receivedRssi: receivedRssi
        )
    }
    
    /// Ingests an inbound `InboundPacket` struct.
    public func handleInboundPacket(_ inbound: InboundPacket, relay: Bool = true) async throws -> InboundChatOutcome {
        let wireData = try inbound.rawPacket.toWireData()
        return try await handleInboundPacket(
            rawPacket: inbound.rawPacket,
            wireData: wireData,
            fromPeerId: inbound.sourcePeerId,
            receivedRssi: inbound.receivedRssi,
            relay: relay
        )
    }
    
    func handleInboundPacket(
        rawPacket: RawWirePacket,
        wireData: Data,
        fromPeerId: String,
        receivedRssi: Int8? = nil,
        relay: Bool = true
    ) async throws -> InboundChatOutcome {
        let envelope = rawPacket.envelope
        let generation = sessionGeneration
        
        // Verify protocol version
        guard envelope.version == PacketConstants.protocolVersion else {
            return .droppedMalformed
        }
        
        // Hop count enforcement (Requirement 2: Max 8 hops)
        guard envelope.hopCount <= envelope.hopLimit else {
            return .droppedHopLimitExceeded
        }
        
        let activeSession = sessionProvider?()
        
        // 2. Stranger Packet Relaying (Requirement 3: Zero-Knowledge Blind Relaying)
        if let session = activeSession, envelope.sessionId != session.sessionId {
            guard envelope.hopCount < envelope.hopLimit else { return .droppedHopLimitExceeded }
            // Stranger packet! Verify relay policy and battery cutoff (<20%)
            guard currentBatteryLevel >= 0.20 && !isLowPowerMode && !isSurvivalMode else {
                return .droppedPolicyDisabled
            }
            
            // Rate limiter check for ordinary relay traffic
            if let limiter = rateLimiter {
                let permitted = await limiter.consumeOrdinaryToken()
                guard permitted else {
                    return .droppedPolicyDisabled
                }
            }
            
            guard generation == sessionGeneration else { return .droppedSecurityFailed }

            // Deduplication suppression (Requirement 4)
            let packetKey = PacketKey(wirePacket: rawPacket)
            let isDuplicate = await seenPacketCache.isDuplicateAndRecord(packetKey, now: clock.now())
            guard generation == sessionGeneration else { return .droppedSecurityFailed }
            if isDuplicate {
                return .droppedDuplicate(sequenceNumber: envelope.sequenceNumber)
            }
            
            // Mutate hopCount (+1) preserving Poly1305 MAC tag via AAD masking
            var mutatedData = wireData
            mutatedData[mutatedData.startIndex + 2] = envelope.hopCount + 1
            
            // Blind forward across mesh (never decrypt or display)
            try await forwardOpaquePacket(mutatedData, exceptPeerId: fromPeerId)
            return .relayedStranger(sessionId: UInt32(envelope.sessionId), hopCount: envelope.hopCount + 1)
        }
        
        // 3. Local Group Session Ingestion
        guard let session = activeSession, envelope.sessionId == session.sessionId else {
            return .droppedSecurityFailed
        }
        
        if envelope.type == .ack {
            // Process delivery acknowledgement
            let processed = await processDeliveryACK(rawPacket: rawPacket, fromPeerId: fromPeerId)
            if processed {
                let decrypted = try? await decryptPayload(rawPacket: rawPacket)
                let ackPayload = decrypted.flatMap { try? ACKPayload.deserialize(from: $0) }
                let responder = ackPayload?.responderInitials ?? fromPeerId
                return .ackProcessed(sequenceNumber: envelope.sequenceNumber, responderInitials: responder, isDelivered: true)
            }
            if relay && envelope.hopCount < envelope.hopLimit {
                var mutatedData = wireData
                mutatedData[mutatedData.startIndex + 2] = envelope.hopCount + 1
                try await forwardOpaquePacket(mutatedData, exceptPeerId: fromPeerId)
            }
            return .droppedMalformed
        }
        
        guard envelope.type == .chatMessage else {
            return .droppedMalformed
        }
        
        // 4. Cryptographic Authentication & Decryption (Requirement 1)
        let symmetricKey = SymmetricKey(data: session.symmetricKeyData)
        let decrypted: Data
        do {
            decrypted = try await cryptoService.open(
                ciphertext: rawPacket.ciphertext,
                envelope: envelope,
                authTag: rawPacket.authTag,
                using: symmetricKey
            )
        } catch {
            return .droppedSecurityFailed
        }
        
        guard generation == sessionGeneration else { return .droppedSecurityFailed }

        // Deserialization & validation
        guard let payload = try? ChatMessagePayload.deserialize(from: decrypted) else {
            return .droppedMalformed
        }
        
        guard payload.senderInitials != session.localInitials else {
            return .droppedSelfEcho
        }
        
        guard abs(clock.now().timeIntervalSince(payload.timestamp)) <= CarryMessageStore.retention else {
            return .droppedMalformed
        }

        // Duplicate suppression (Requirement 4)
        let packetKey = PacketKey(wirePacket: rawPacket)
        let isDuplicate = await seenPacketCache.isDuplicateAndRecord(packetKey, now: clock.now())
        guard generation == sessionGeneration else { return .droppedSecurityFailed }
        if isDuplicate || seenChatSequences.contains(envelope.sequenceNumber) {
            // The first ACK may have been lost. Confirm authenticated receipt again,
            // without adding another message or forwarding the chat again.
            try await sendDeliveryACK(for: rawPacket, senderInitials: payload.senderInitials,
                receivedRssi: receivedRssi ?? -70)
            return .droppedDuplicate(sequenceNumber: envelope.sequenceNumber)
        }
        seenChatSequences.insert(envelope.sequenceNumber)
        if seenChatSequences.count > 1000 {
            seenChatSequences.removeAll()
        }

        // 5. In-Memory Message Display (Requirement 9: In-Memory Only, Zero Persistence)
        let message = ChatMessage(
            sequenceNumber: envelope.sequenceNumber,
            senderInitials: payload.senderInitials,
            text: payload.text,
            timestamp: payload.timestamp,
            confirmedResponders: [session.localInitials],
            recipientStates: [:],
            deliveryState: .delivered(confirmedCount: 1, totalRecipients: 1),
            isLocalSender: false
        )
        appendMessage(message)
        
        // 6. Return Delivery ACK Dispatch (Requirement 6 & 7)
        try await sendDeliveryACK(
            for: rawPacket,
            senderInitials: payload.senderInitials,
            receivedRssi: receivedRssi ?? -70
        )
        
        // 7. Multi-Hop Forwarding if hops remain (Requirement 2)
        if relay && envelope.hopCount < envelope.hopLimit {
            var mutatedData = wireData
            mutatedData[mutatedData.startIndex + 2] = envelope.hopCount + 1
            try await forwardOpaquePacket(mutatedData, exceptPeerId: fromPeerId)
            return .deliveredLocallyAndRelayed(message: message, nextHopCount: envelope.hopCount + 1)
        }
        
        return .deliveredLocally(message: message)
    }
}
