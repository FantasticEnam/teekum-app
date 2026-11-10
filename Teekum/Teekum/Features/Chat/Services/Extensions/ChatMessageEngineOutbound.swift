//
//  ChatMessageEngineOutbound.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation
import CryptoKit

// MARK: - Outbound Chat Dispatch Pipeline

extension ChatMessageEngine {
    
    /// Accepts, validates, encodes, encrypts, and transmits a chat message across the mesh.
    ///
    /// - Parameters:
    ///   - text: User text content (must be between 1 and 20 UTF-8 bytes).
    ///   - targetRecipients: Optional explicit recipient initials list. If nil, defaults to active group roster.
    /// - Returns: Created `ChatMessage` in `.forwardedToNextHop` state.
    /// - Throws: `ChatEngineError` on validation, battery cutoff, cooldown, or cryptographic failure.
    @discardableResult
    public func sendMessage(
        text: String,
        targetRecipients: [String]? = nil
    ) async throws -> ChatMessage {
        // 1. Session verification
        guard let session = sessionProvider?() else {
            throw ChatEngineError.noActiveSession
        }
        
        // 2. Battery & Survival Mode verification (Requirement 10)
        guard currentBatteryLevel >= 0.20 && !isLowPowerMode && !isSurvivalMode else {
            throw ChatEngineError.batteryThrottled(batteryLevel: currentBatteryLevel)
        }
        
        // 3. 3-Second Cooldown verification (Requirement 5)
        let now = clock.now()
        let elapsedSinceLast = now.timeIntervalSince(lastSentTimestamp)
        if elapsedSinceLast < timingConfig.chatUserCooldown {
            let remaining = timingConfig.chatUserCooldown - elapsedSinceLast
            throw ChatEngineError.cooldownActive(remainingSeconds: remaining)
        }
        
        // 4. Text validation (1..20 UTF-8 bytes)
        let rawUtf8 = Array(text.utf8)
        guard !rawUtf8.isEmpty && rawUtf8.count <= ChatMessagePayload.maxTextBytes else {
            throw ChatEngineError.invalidTextLength(rawUtf8.count)
        }
        
        // 5. Intended Recipients Resolution (Requirement 6)
        let resolvedRecipients: [String]
        if let explicit = targetRecipients {
            resolvedRecipients = explicit.map { InitialsCodec.sanitize($0) }.filter { $0 != session.localInitials }
        } else if let provider = recipientsProvider {
            let recipients = await provider()
            resolvedRecipients = recipients.map { InitialsCodec.sanitize($0) }.filter { $0 != session.localInitials }
        } else {
            resolvedRecipients = []
        }
        
        // 6. Sequence Number Generation
        let seq = (UInt32(session.memberSlot) << 24) | (monotonicCounter & 0x00FFFFFF)
        monotonicCounter &+= 1
        
        // 7. Payload Serialization
        let payload = ChatMessagePayload(
            senderInitials: session.localInitials,
            timestamp: now,
            text: text
        )
        guard let payloadData = try? payload.serialize() else {
            throw ChatEngineError.serializationFailed
        }
        
        // 8. Envelope Construction & Cryptographic Sealing (Requirement 1)
        let envelope = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .chatMessage,
            hopLimit: PacketConstants.chatHopLimit,
            hopCount: 0,
            sessionId: session.sessionId,
            sequenceNumber: seq
        )
        
        let symmetricKey = SymmetricKey(data: session.symmetricKeyData)
        let (ciphertext, authTag): (Data, Data)
        do {
            (ciphertext, authTag) = try await cryptoService.seal(
                payload: payloadData,
                envelope: envelope,
                using: symmetricKey
            )
        } catch {
            throw ChatEngineError.encryptionFailed(error.localizedDescription)
        }
        
        let rawWirePacket = RawWirePacket(
            envelope: envelope,
            ciphertext: ciphertext,
            authTag: authTag
        )
        
        let wireData: Data
        do {
            wireData = try rawWirePacket.toWireData()
        } catch {
            throw ChatEngineError.serializationFailed
        }
        
        // 9. Initial In-Memory Message Model (Requirement 8 & 9)
        var initialRecipientStates: [String: RecipientDeliveryState] = [:]
        for recipient in resolvedRecipients {
            initialRecipientStates[recipient] = .locallyAccepted
        }
        
        var message = ChatMessage(
            id: UUID(),
            sequenceNumber: seq,
            senderInitials: session.localInitials,
            text: text,
            timestamp: now,
            confirmedResponders: [],
            recipientStates: initialRecipientStates,
            deliveryState: .locallyAccepted,
            isLocalSender: true
        )
        
        // Record in in-memory message history (strictly in-memory, no persistence)
        appendMessage(message)
        lastSentTimestamp = now
        
        // 10. Radio Transmission & Transition to Forwarded
        message.deliveryState = .forwardedToNextHop
        for recipient in resolvedRecipients {
            initialRecipientStates[recipient] = .forwardedToNextHop
        }
        message.recipientStates = initialRecipientStates
        updateMessage(message)
        
        // Submit to transport outbox (FIFO Tier 3, ahead of stranger relays)
        try await transport.broadcastFrame(wireData)
        
        // 11. Register in-flight message for ACK tracking & retries (Requirement 5 & 6)
        let inFlight = InFlightMessage(
            message: message,
            rawWirePacket: rawWirePacket,
            wireData: wireData,
            attemptCount: 1,
            maxRetries: timingConfig.chatMaxRetries,
            lastSentAt: now
        )
        inFlightMessages[seq] = inFlight
        
        return message
    }
}
