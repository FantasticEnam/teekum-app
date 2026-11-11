//
//  SOSForwardingEngineInbound.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CryptoKit

// MARK: - Inbound SOS Processing & Authentication Pipeline

extension SOSForwardingEngine {
    
    /// Conformance to `SOSForwardingManaging`: Ingests and processes an incoming SOS packet.
    /// Strict Cryptographic Authentication: Only verified group members can trigger emergency alerts.
    public func handleInboundSOSPacket(
        rawPacket: RawWirePacket,
        fromPeerId: String
    ) async throws {
        guard let session = sessionProvider?() else {
            throw TransportError.sessionInvalid
        }
        
        let envelope = rawPacket.envelope
        let generation = sessionGeneration
        guard envelope.type == .sos else { throw TransportError.malformedPacket }
        
        // 1. Session Isolation
        guard envelope.sessionId == session.sessionId else {
            throw TransportError.sessionMismatch
        }
        
        // 2. Cryptographic Tag Verification (ChaCha20-Poly1305)
        let key = SymmetricKey(data: session.symmetricKeyData)
        let decrypted: Data
        do {
            decrypted = try await cryptoService.open(
                ciphertext: rawPacket.ciphertext,
                envelope: envelope,
                authTag: rawPacket.authTag,
                using: key
            )
        } catch {
            // Tampered, forged, or unauthenticated packet: Reject with ZERO state changes!
            throw TransportError.securityVerificationFailed
        }
        
        guard generation == sessionGeneration else { return }

        // 3. Deserialize Emergency Payload
        guard let payload = try? SOSPayload.deserialize(from: decrypted) else {
            throw TransportError.malformedPacket
        }
        
        // 4. Do not sound alert for our own packets
        guard payload.senderInitials != session.localInitials else { return }
        
        // GPS measurement age is not the time of the emergency; preserve legacy no-fix SOS reception.
        let eventId = payload.sosEventId
        
        // 6. Duplicate Suppression Check
        if seenSOSEventIds.contains(eventId) {
            totalDuplicatesSuppressedCount += 1
            // Duplicate arrived (e.g. over an alternate multi-hop path):
            // Re-emit delivery ACK so sender's retry timer resolves,
            // but STRICTLY SUPPRESS repeated sirens and alert banners!
            try await sendDeliveryACK(for: rawPacket, status: .deliveredToFriend)
            return
        }
        
        // 7. First-Time Trusted Reception
        seenSOSEventIds.insert(eventId)
        totalReceivedCount += 1
        
        // Sound Siren & Haptics
        isSirenActive = true
        audioAlerter?.triggerEmergencyAlertFeedback()
        
        let alert = IncomingSOSAlert(
            id: eventId,
            senderInitials: payload.senderInitials,
            senderName: payload.senderInitials,
            emergencyType: payload.emergencyType,
            coordinate: payload.coordinate,
            accuracy: payload.accuracy,
            timestamp: payload.timestamp,
            batteryLevel: payload.batteryLevel,
            receivedAt: clock.now()
        )
        self.activeIncomingAlert = alert
        onIncomingAlertTriggered?(alert)
        
        // 8. Multi-Hop Return ACK Routing
        try await sendDeliveryACK(for: rawPacket, status: .deliveredToFriend)
    }
}
