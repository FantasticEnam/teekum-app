//
//  ChatMessageEngine+Delivery.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation
import CryptoKit

// MARK: - Delivery ACK Processing, Retries & Ephemeral History

extension ChatMessageEngine {
    
    // MARK: - Delivery ACK Dispatching & Ingestion
    
    /// Generates and transmits an authenticated ACK back to the message sender across the mesh.
    public func sendDeliveryACK(
        for originalPacket: RawWirePacket,
        senderInitials: String,
        receivedRssi: Int8
    ) async throws {
        let generation = sessionGeneration
        guard let session = sessionProvider?() else { return }
        let now = clock.now()
        
        let chatPayload = ChatACKPayload(
            ackedSeqNumber: originalPacket.envelope.sequenceNumber,
            ackedSenderInitials: senderInitials,
            ackStatus: .deliveredToFriend,
            receivedRssi: receivedRssi
        )
        let ackPayload = ACKPayload.chat(
            chatPayload,
            timestamp: now,
            responderInitials: session.localInitials
        )
        let payloadData = ackPayload.serialize()
        
        let ackSeq = try await nextSequenceNumber(for: session)
        guard generation == sessionGeneration else { throw ChatEngineError.noActiveSession }
        
        let envelope = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .ack,
            hopLimit: PacketConstants.chatHopLimit,
            hopCount: 0,
            sessionId: session.sessionId,
            sequenceNumber: ackSeq
        )
        
        let key = SymmetricKey(data: session.symmetricKeyData)
        let (ciphertext, authTag) = try await cryptoService.seal(
            payload: payloadData,
            envelope: envelope,
            using: key
        )
        guard generation == sessionGeneration else { throw ChatEngineError.noActiveSession }
        let rawAck = RawWirePacket(
            envelope: envelope,
            ciphertext: ciphertext,
            authTag: authTag
        )
        let wireData = try rawAck.toWireData()
        
        // Broadcast ACK across direct neighbors to find route back to originator
        try await transport.broadcastFrame(wireData)
    }
    
    /// Generates an intermediary relay ACK when forwarding for a multi-hop friend.
    public func sendRelayACK(
        for originalPacket: RawWirePacket,
        senderInitials: String,
        receivedRssi: Int8
    ) async throws {
        let generation = sessionGeneration
        guard let session = sessionProvider?() else { return }
        let now = clock.now()
        
        let chatPayload = ChatACKPayload(
            ackedSeqNumber: originalPacket.envelope.sequenceNumber,
            ackedSenderInitials: senderInitials,
            ackStatus: .relayedByMeshHop,
            receivedRssi: receivedRssi
        )
        let ackPayload = ACKPayload.chat(
            chatPayload,
            timestamp: now,
            responderInitials: session.localInitials
        )
        let payloadData = ackPayload.serialize()
        
        let ackSeq = try await nextSequenceNumber(for: session)
        guard generation == sessionGeneration else { throw ChatEngineError.noActiveSession }
        
        let envelope = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .ack,
            hopLimit: PacketConstants.chatHopLimit,
            hopCount: 0,
            sessionId: session.sessionId,
            sequenceNumber: ackSeq
        )
        
        let key = SymmetricKey(data: session.symmetricKeyData)
        let (ciphertext, authTag) = try await cryptoService.seal(
            payload: payloadData,
            envelope: envelope,
            using: key
        )
        guard generation == sessionGeneration else { throw ChatEngineError.noActiveSession }
        let rawAck = RawWirePacket(
            envelope: envelope,
            ciphertext: ciphertext,
            authTag: authTag
        )
        let wireData = try rawAck.toWireData()
        try await transport.broadcastFrame(wireData)
    }
    
    /// Processes an incoming delivery ACK from wire data.
    public func processDeliveryACK(rawPacket: RawWirePacket, fromPeerId: String) async -> Bool {
        let generation = sessionGeneration
        guard rawPacket.envelope.type == .ack else { return false }
        guard let session = sessionProvider?(), rawPacket.envelope.sessionId == session.sessionId else {
            return false
        }
        
        let decrypted: Data
        do {
            decrypted = try await decryptPayload(rawPacket: rawPacket)
        } catch {
            return false
        }
        
        guard generation == sessionGeneration else { return false }
        guard let ack = try? ACKPayload.deserialize(from: decrypted) else {
            return false
        }
        
        guard case .chat(let chatPayload, let timestamp, let responder) = ack else {
            return false
        }
        
        return await processChatACK(
            payload: chatPayload,
            responder: responder,
            timestamp: timestamp,
            hopCount: rawPacket.envelope.hopCount,
            fromPeerId: fromPeerId
        )
    }

    /// Processes a typed Chat ACK directly without redundant decryption.
    ///
    /// Implements Requirement 6 & 7:
    /// - Tracks ACK and delivery state separately for each intended recipient.
    /// - Never treats a relay ACK (`0x02`) as final recipient delivery (`0x01`).
    public func processChatACK(
        payload: ChatACKPayload,
        responder: String,
        timestamp: Date,
        hopCount: UInt8,
        fromPeerId: String
    ) async -> Bool {
        let generation = sessionGeneration
        guard let session = sessionProvider?() else { return false }
        guard generation == sessionGeneration else { return false }
        
        // Verify this ACK was intended for our local device
        guard payload.ackedSenderInitials == session.localInitials else {
            return false
        }
        
        let seq = payload.ackedSeqNumber
        guard let idx = inMemoryMessages.firstIndex(where: { $0.sequenceNumber == seq && $0.isLocalSender }) else {
            return false
        }
        
        var message = inMemoryMessages[idx]
        
        if payload.ackStatus == .relayedByMeshHop {
            // Intermediate Mesh Relay Hop Confirmed!
            // Requirement 7: Never treat a relay ACK as final recipient delivery!
            if message.deliveryState == .locallyAccepted || message.deliveryState == .forwardedToNextHop {
                message.deliveryState = .relayedByMesh(hopCount: hopCount)
            }
            
            // Mark individual recipient state as relayed by mesh without marking delivered
            if let current = message.recipientStates[responder], !current.isDelivered {
                message.recipientStates[responder] = .relayedByMesh(hops: hopCount, relayPeerId: fromPeerId)
            } else if message.recipientStates[responder] == nil {
                for (rec, state) in message.recipientStates where !state.isDelivered {
                    message.recipientStates[rec] = .relayedByMesh(hops: hopCount, relayPeerId: fromPeerId)
                }
            }
            
            inMemoryMessages[idx] = message
            if var inFlight = inFlightMessages[seq] {
                inFlight.message = message
                inFlightMessages[seq] = inFlight
            }
            notifyMessageUpdated(message)
            return true
            
        } else if payload.ackStatus == .deliveredToFriend {
            // Final Intended Recipient Confirmed Delivery!
            message.confirmedResponders.insert(responder)
            message.recipientStates[responder] = .deliveredToRecipient(
                timestamp: timestamp,
                rssi: payload.receivedRssi
            )
            
            let total = message.totalRecipientCount
            let confirmed = message.confirmedRecipientCount
            message.deliveryState = .delivered(confirmedCount: confirmed, totalRecipients: total)
            
            inMemoryMessages[idx] = message
            if confirmed >= total {
                // All recipients have confirmed delivery
                inFlightMessages.removeValue(forKey: seq)
            } else if var inFlight = inFlightMessages[seq] {
                inFlight.message = message
                inFlightMessages[seq] = inFlight
            }
            notifyMessageUpdated(message)
            return true
        }
        
        return false
    }
    
    // MARK: - Retries & Timeout Evaluation (Deterministic Test Support)
    
    /// Evaluates in-flight messages against retry delays and ACK timeouts.
    /// Supports deterministic testing when invoked after advancing a `MeshClock`.
    public func evaluateTimeoutsAndRetries() async {
        let now = clock.now()
        
        for (seq, var inFlight) in inFlightMessages {
            // 1. Check if all intended recipients have already confirmed
            let unconfirmedRecipients = inFlight.message.recipientStates.filter { !$0.value.isDelivered }
            if inFlight.message.recipientStates.isEmpty && inFlight.message.deliveryState.isDelivered {
                inFlightMessages.removeValue(forKey: seq)
                continue
            }
            
            // 2. Check 15-Second Delivery Timeout Window (Requirement 8)
            if now.timeIntervalSince(inFlight.message.timestamp) >= timingConfig.chatAckTimeout {
                var message = inFlight.message
                for (rec, state) in message.recipientStates where !state.isDelivered {
                    message.recipientStates[rec] = .deliveryTimedOut
                }
                
                if message.confirmedRecipientCount == 0 {
                    message.deliveryState = .deliveryTimedOut
                } else if message.confirmedRecipientCount < message.totalRecipientCount {
                    message.deliveryState = .deliveryTimedOut
                }
                
                updateMessage(message)
                inFlightMessages.removeValue(forKey: seq)
                continue
            }
            
            // 3. Check Transmission Retries (Max 2 retries, 3 total attempts, 0.5s backoff)
            if unconfirmedRecipients.count > 0 || inFlight.message.recipientStates.isEmpty {
                if inFlight.attemptCount < inFlight.maxRetries + 1 {
                    if now.timeIntervalSince(inFlight.lastSentAt) >= timingConfig.chatRetryBackoff {
                        inFlight.attemptCount += 1
                        inFlight.lastSentAt = now
                        inFlightMessages[seq] = inFlight
                        
                        // Retransmit frame across radio
                        try? await transport.broadcastFrame(inFlight.wireData)
                    }
                }
            }
        }
    }
    
    // MARK: - Ephemeral History & Querying (Requirement 9)
    
    /// Returns the active in-memory message history (up to 50 latest messages).
    public func activeMessages() -> [ChatMessage] {
        inMemoryMessages
    }
    
    /// Finds a message by sequence counter.
    public func message(withSequenceNumber seq: UInt32) -> ChatMessage? {
        inMemoryMessages.first(where: { $0.sequenceNumber == seq })
    }
    
    /// Clears all in-memory chat history and in-flight tracking on group session teardown.
    public func clearHistory() async {
        sessionGeneration = UUID()
        onMessageUpdated = nil
        lastSentTimestamp = .distantPast
        retrySupervisorTask?.cancel()
        retrySupervisorTask = nil
        inMemoryMessages.removeAll()
        inFlightMessages.removeAll()
        seenChatSequences.removeAll()
        await seenPacketCache.removeAll()
    }
}
