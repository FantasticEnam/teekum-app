//
//  ChatSOSMigrationTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import XCTest
import CryptoKit
import CoreLocation
@testable import Teekum

final class ChatSOSMigrationTests: XCTestCase {
    private let keyData = Data(repeating: 0x42, count: 32)

    // Same behavioral cases as f4c6393 ChatMessagingEngineTests: auth, dedup ACK and final-hop receipt.
    func testAuthenticatedChatDuplicatesReackWithoutDuplicatingHistory() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: keyData, localInitials: "BOB")
        let crypto = CryptoService()
        let transport = MessagingTestTransport()
        let engine = ChatMessageEngine(transport: transport, cryptoService: crypto,
            clock: TestMeshClock(initialDate: now), sessionProvider: { session })
        let packet = try await chatPacket(crypto: crypto, date: now, hopCount: 8)
        var tampered = packet
        tampered.authTag[0] ^= 0xFF

        let rejected = try await engine.handleInboundPacket(InboundPacket(rawPacket: tampered, sourcePeerId: "ALX"), relay: false)
        XCTAssertEqual(rejected, .droppedSecurityFailed)
        let first = try await engine.handleInboundPacket(InboundPacket(rawPacket: packet, sourcePeerId: "ALX"), relay: false)
        XCTAssertTrue(first.isDeliveredLocally)
        let duplicate = try await engine.handleInboundPacket(InboundPacket(rawPacket: packet, sourcePeerId: "ALX"), relay: false)
        XCTAssertEqual(duplicate, .droppedDuplicate(sequenceNumber: packet.envelope.sequenceNumber))
        let history = await engine.activeMessages()
        let broadcasts = await transport.broadcasts
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(broadcasts.count, 2, "A lost first ACK must be recoverable by an authenticated duplicate.")
        for data in broadcasts {
            XCTAssertEqual(try RawWirePacket.fromWireData(data).envelope.type, .ack)
        }
        await engine.clearHistory()
    }

    func testRouterOwnedChatDoesNotAlsoForwardInsideEngine() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: keyData, localInitials: "BOB")
        let crypto = CryptoService()
        let transport = MessagingTestTransport()
        let engine = ChatMessageEngine(transport: transport, cryptoService: crypto,
            clock: TestMeshClock(initialDate: now), sessionProvider: { session })
        let packet = try await chatPacket(crypto: crypto, date: now)
        let result = try await engine.handleInboundPacket(InboundPacket(rawPacket: packet, sourcePeerId: "ALX"), relay: false)
        XCTAssertTrue(result.isDeliveredLocally)
        let broadcasts = await transport.broadcasts
        XCTAssertEqual(broadcasts.count, 1)
        XCTAssertEqual(try RawWirePacket.fromWireData(XCTUnwrap(broadcasts.first)).envelope.type, .ack)
        await engine.clearHistory()
    }

    func testChatRelayACKNeverCountsAsRecipientDelivery() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: keyData, localInitials: "ALX")
        let crypto = CryptoService()
        let transport = MessagingTestTransport()
        let engine = ChatMessageEngine(transport: transport, cryptoService: crypto,
            clock: TestMeshClock(initialDate: now), sessionProvider: { session })
        let message = try await engine.sendMessage(text: "Where are you?", targetRecipients: ["BOB"])
        let ack = ACKPayload(ackedSeqNumber: message.sequenceNumber, ackedSenderInitials: "ALX", ackTimestamp: now,
            ackStatus: .relayedByMeshHop, receivedRssi: -70, originalEventId: message.sequenceNumber, responderInitials: "REL")
        let raw = try await sealed(crypto: crypto, payload: ack.serialize(), type: .ack, sequence: 0x02000001)
        let processed = await engine.processDeliveryACK(rawPacket: raw, fromPeerId: "REL")
        XCTAssertTrue(processed)
        let updated = await engine.message(withSequenceNumber: message.sequenceNumber)
        XCTAssertTrue(updated?.deliveryState.isRelayed == true)
        XCTAssertEqual(updated?.confirmedRecipientCount, 0)
        await engine.clearHistory()
    }

    // f4 runtime SOSViewModel uses measurement time, including epoch for unavailable GPS.
    func testSOSWithoutGPSAlertsOnceAndReacksDuplicate() async throws {
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: keyData, localInitials: "BOB")
        let crypto = CryptoService()
        let transport = MessagingTestTransport()
        let audio = MessagingTestAudio()
        let engine = SOSForwardingEngine(transport: transport, cryptoService: crypto,
            sessionProvider: { session }, audioAlerter: audio)
        let payload = SOSPayload(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            timestamp: Date(timeIntervalSince1970: 0), accuracy: 255, sosEventId: 77,
            senderInitials: "ALX", emergencyType: .general, batteryLevel: 85)
        let packet = try await sealed(crypto: crypto, payload: payload.serialize(), type: .sos, sequence: 0x01000001)
        try await engine.handleInboundSOSPacket(rawPacket: packet, fromPeerId: "ALX")
        try await engine.handleInboundSOSPacket(rawPacket: packet, fromPeerId: "ALX")
        let alert = await engine.activeIncomingAlert
        XCTAssertEqual(alert?.id, 77)
        XCTAssertEqual(alert?.timestamp, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(audio.triggerCount, 1)
        let broadcasts = await transport.broadcasts
        XCTAssertEqual(broadcasts.count, 2)
        await engine.cancelOutgoingSOS()
        let incomingAfterOutgoingDismissal = await engine.activeIncomingAlert
        XCTAssertEqual(incomingAfterOutgoingDismissal?.id, 77)
        XCTAssertEqual(audio.stopCount, 0)
        await engine.reset()
        let cleared = await engine.activeIncomingAlert
        let seen = await engine.seenSOSEventIds
        XCTAssertNil(cleared)
        XCTAssertTrue(seen.isEmpty)
        XCTAssertEqual(audio.stopCount, 1)
    }

    func testSOSACKWithoutActiveEventDoesNotClaimDelivery() async throws {
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: keyData, localInitials: "ALX")
        let crypto = CryptoService()
        let engine = SOSForwardingEngine(transport: MessagingTestTransport(), cryptoService: crypto, sessionProvider: { session })
        let ack = ACKPayload(ackedSeqNumber: 0x01000001, ackedSenderInitials: "ALX", ackTimestamp: .now,
            ackStatus: .deliveredToFriend, receivedRssi: -70, originalEventId: 77, responderInitials: "BOB")
        let packet = try await sealed(crypto: crypto, payload: ack.serialize(), type: .ack, sequence: 0x02000001)
        await engine.handleInboundACK(rawPacket: packet, fromPeerId: "BOB")
        let state = await engine.currentDeliveryState
        XCTAssertEqual(state, .idle)
    }

    @MainActor
    func testChatDraftPreservesUTF8BoundaryAndPowerGate() {
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: keyData, localInitials: "ALX")
        let engine = ChatMessageEngine(transport: MessagingTestTransport(), cryptoService: CryptoService())
        let model = ChatViewModel(service: engine, sessionProvider: { session })
        model.updateDraft(String(repeating: "🙂", count: 6))
        XCTAssertEqual(model.draftText, String(repeating: "🙂", count: 5))
        XCTAssertEqual(model.byteCount, 20)
        XCTAssertTrue(model.canSend)
        model.updateBattery(level: 0.19, isLowPower: false)
        XCTAssertFalse(model.canSend)
    }

    private func chatPacket(crypto: CryptoService, date: Date, hopCount: UInt8 = 0) async throws -> RawWirePacket {
        let payload = ChatMessagePayload(senderInitials: "ALX", timestamp: date, text: "At Main Stage")
        return try await sealed(crypto: crypto, payload: payload.serialize(), type: .chatMessage,
            sequence: 0x01000001, hopCount: hopCount)
    }

    private func sealed(crypto: CryptoService, payload: Data, type: PacketType,
                        sequence: UInt32, hopCount: UInt8 = 0) async throws -> RawWirePacket {
        let envelope = CleartextEnvelope(type: type, hopLimit: 8, hopCount: hopCount,
            sessionId: 0x1234, sequenceNumber: sequence)
        let result = try await crypto.seal(payload: payload, envelope: envelope, using: SymmetricKey(data: keyData))
        return RawWirePacket(envelope: envelope, ciphertext: result.ciphertext, authTag: result.authTag)
    }
}

private actor MessagingTestTransport: MeshTransport {
    nonisolated let inboundFrames = AsyncStream<InboundFrame> { _ in }
    nonisolated let sendOutcomes = AsyncStream<SendOutcome> { _ in }
    nonisolated let neighborEvents = AsyncStream<NeighborEvent> { _ in }
    nonisolated let transportErrors = AsyncStream<TransportError> { _ in }
    private(set) var broadcasts: [Data] = []
    func start(serviceType: String, session: GroupSession) async throws {}
    func stop() async {}
    func sendFrame(_ data: Data, to peerId: String) async throws -> SendOutcome {
        broadcasts.append(data)
        return SendOutcome(destinationPeerId: peerId, packetType: .chatMessage, isSuccess: true)
    }
    func broadcastFrame(_ data: Data) async throws { broadcasts.append(data) }
    func forwardFrame(_ data: Data, to nextHopPeerId: String) async throws -> SendOutcome {
        try await sendFrame(data, to: nextHopPeerId)
    }
    func activeNeighbors() async -> [NeighborInfo] { [] }
    func queueDepth() async -> QueueDepth { QueueDepth() }
    func setRelayParticipation(enabled: Bool) async {}
    func isRelayPermitted() async -> Bool { true }
}

private final class MessagingTestAudio: SOSAudioAlerting, @unchecked Sendable {
    private let lock = NSLock()
    private var triggers = 0
    private var stops = 0
    var triggerCount: Int { lock.withLock { triggers } }
    var stopCount: Int { lock.withLock { stops } }
    func triggerEmergencyAlertFeedback() { lock.withLock { triggers += 1 } }
    func stopEmergencyAlertFeedback() { lock.withLock { stops += 1 } }
}
