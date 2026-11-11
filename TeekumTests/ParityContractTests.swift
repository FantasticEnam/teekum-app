//
//  ParityContractTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CoreLocation
import CryptoKit
import XCTest
#if PROTOTYPE_REFERENCE
@testable import PrototypeReference
#else
@testable import Teekum
#endif

/// The same fixtures and assertions run against the frozen read-only prototype and the migrated app.
@MainActor
final class ParityContractTests: XCTestCase {
    func testEnvelopeAndNonceMatchPrototypeV3Vector() throws {
        let envelope = CleartextEnvelope(type: .locationPing, hopLimit: 8, hopCount: 2,
            sessionId: 0x1234, sequenceNumber: 0x0700_002a)
        XCTAssertEqual(envelope.serialize(), Data([0x31, 8, 2, 0, 0x12, 0x34, 7, 0, 0, 42]))
        XCTAssertEqual(envelope.constructNonce(), Data([0, 0x12, 0x34, 7, 0, 0, 42, 0x31, 0x54, 0x4b, 0x4d, 0x33]))
        XCTAssertEqual(envelope.authenticatedAssociatedData(), Data([0x31, 8, 0, 0, 0x12, 0x34, 7, 0, 0, 42]))
        XCTAssertEqual(try CleartextEnvelope.deserialize(from: envelope.serialize()), envelope)
        let packet = RawWirePacket(envelope: envelope, ciphertext: Data(repeating: 0x42, count: 30),
            authTag: Data(repeating: 0x24, count: 16))
        let wire = try packet.toWireData()
        XCTAssertEqual(wire.count, 56)
        XCTAssertEqual(wire.prefix(10), envelope.serialize())
        XCTAssertEqual(try RawWirePacket.fromWireData(wire), packet)
    }

    func testLocationPayloadPreservesMeasurementTimeAndTelemetry() throws {
        let measured = Date(timeIntervalSince1970: 1_800_000_000)
        let payload = LocationPingPayload(coordinate: .init(latitude: -6.1988, longitude: 106.8225),
            timestamp: measured, accuracy: 17, senderInitials: "ALX", batteryLevel: 84,
            heading: 127, colorCode: 3)
        let data = payload.serialize()
        XCTAssertEqual(data.count, 30)
        XCTAssertEqual(data.suffix(12), Data(repeating: 0, count: 12))
        let decoded = try LocationPingPayload.deserialize(from: data)
        XCTAssertEqual(decoded.timestamp, measured)
        XCTAssertEqual(decoded.coordinate.latitude, payload.coordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(decoded.coordinate.longitude, payload.coordinate.longitude, accuracy: 0.000001)
        XCTAssertEqual(decoded.senderInitials, "ALX")
        XCTAssertEqual(decoded.batteryLevel, 84)
        XCTAssertEqual(decoded.heading, 127)
        XCTAssertEqual(decoded.colorCode, 3)
    }

    func testUTF8LimitIsTwentyBytesAndKeepsCharacterBoundary() throws {
        let text = String(repeating: "🙂", count: 6)
        let clamped = ChatMessagePayload.clampTo20Bytes(text)
        XCTAssertEqual(clamped, String(repeating: "🙂", count: 5))
        XCTAssertThrowsError(try ChatMessagePayload(senderInitials: "ALX", text: text).serialize())
        let payload = ChatMessagePayload(senderInitials: "ALX", timestamp: .init(timeIntervalSince1970: 1_800_000_000), text: clamped)
        XCTAssertEqual(try ChatMessagePayload.deserialize(from: payload.serialize()).text, clamped)
    }

    func testBLEFragmentationAndCarryCustodyMatchPrototype() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let packet = RawWirePacket(envelope: .init(type: .chatMessage, sessionId: 0x1234, sequenceNumber: 1),
            ciphertext: Data(repeating: 0x42, count: 30), authTag: Data(repeating: 0x24, count: 16))
        let wire = try packet.toWireData()
        var codec = BLEFrameCodec()
        var received: Data?
        for fragment in BLEFrameCodec.fragments(wire, maximumValueLength: 20) { received = codec.receive(fragment) }
        XCTAssertEqual(received, wire)
        var custody = CarryMessageStore()
        custody.remember(wire, isForeign: true, excludingPeerId: "source", now: now)
        XCTAssertNil(custody.nextTransmission(to: ["source"], now: now))
        XCTAssertEqual(custody.nextTransmission(to: ["next"], now: now)?.data, wire)
        custody.markAttempt(wire, to: "next", now: now)
        XCTAssertNil(custody.nextTransmission(to: ["next"], now: now.addingTimeInterval(1)))
        XCTAssertNotNil(custody.nextTransmission(to: ["next"], now: now.addingTimeInterval(2)))
        XCTAssertNil(custody.nextTransmission(to: ["next"], now: now.addingTimeInterval(600)))
    }

    func testForeignSOSAndACKPreemptChatAndTelemetry() throws {
        let queue = PriorityOutboxQueue()
        for (index, type) in [PacketType.locationPing, .chatMessage, .sos, .ack].enumerated() {
            let data = try RawWirePacket(envelope: .init(type: type, sessionId: 0x1234, sequenceNumber: UInt32(index)),
                ciphertext: Data(repeating: 0, count: 30), authTag: Data(repeating: 0, count: 16)).toWireData()
            try queue.enqueue(data: data, isRelay: true)
        }
        XCTAssertEqual(queue.dequeue()?.packetType, .sos)
        XCTAssertEqual(queue.dequeue()?.packetType, .ack)
        XCTAssertEqual(queue.dequeue()?.packetType, .chatMessage)
        XCTAssertEqual(queue.dequeue()?.packetType, .locationPing)
    }

    @MainActor
    func testInactivityDefaultsOffAndMotionOrInteractionCancelsWarning() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let guardService = InactivityGuardService(dateProvider: { now })
        XCTAssertFalse(guardService.isEnabled)
        XCTAssertEqual(guardService.state, .disabled)
        guardService.isEnabled = true
        defer { guardService.isEnabled = false }
        guardService.simulateStillness(seconds: 180)
        XCTAssertTrue(guardService.isWarningActive)
        XCTAssertEqual(guardService.state, .warning(remainingSeconds: 30))
        guardService.recordPhysicalMotion()
        XCTAssertFalse(guardService.isWarningActive)
        guardService.simulateStillness(seconds: 180)
        XCTAssertTrue(guardService.isWarningActive)
        guardService.recordUserInteraction()
        XCTAssertFalse(guardService.isWarningActive)
        XCTAssertEqual(guardService.countdownRemaining, 0)
    }

    @MainActor
    func testSOSRetryPreservesEventAndUsesLatestHardwareMeasurement() async throws {
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: Data(repeating: 0x42, count: 32), localInitials: "ALX")
        let location = LocationService()
        let firstTime = Date.now.addingTimeInterval(-1)
        let secondTime = firstTime.addingTimeInterval(1)
        let firstCoordinate = CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        let secondCoordinate = CLLocationCoordinate2D(latitude: -6.2001, longitude: 106.8001)
        location.simulateLocation(coordinate: firstCoordinate, timestamp: firstTime)
        let crypto = CryptoService()
        let transport = ParityTransport()
        #if PROTOTYPE_REFERENCE
        let sender = SOSViewModel(locationService: location, sessionProvider: { session }, cryptoService: crypto, transport: transport)
        await sender.executeSOSDispatch(eventId: 77, emergencyType: .general)
        location.simulateLocation(coordinate: secondCoordinate, timestamp: secondTime)
        await sender.executeRetryAttempt(eventId: 77, emergencyType: .general, session: session)
        sender.reset()
        #else
        let sender = SOSForwardingEngine(transport: transport, cryptoService: crypto, sessionProvider: { session })
        await sender.setMeasurementProvider { (location.getLatestLocationForSOS(), location.currentBatteryLevel) }
        _ = try await sender.dispatchSOS(location: firstCoordinate, accuracy: 5, timestamp: firstTime, batteryPct: 100)
        await sender.cancelRetries()
        location.simulateLocation(coordinate: secondCoordinate, timestamp: secondTime)
        await sender.triggerRetryNow()
        await sender.reset()
        #endif
        let packets = await transport.broadcasts
        XCTAssertEqual(packets.count, 2)
        var payloads: [SOSPayload] = []
        for data in packets {
            let raw = try RawWirePacket.fromWireData(data)
            let opened = try await crypto.open(ciphertext: raw.ciphertext, envelope: raw.envelope,
                authTag: raw.authTag, using: SymmetricKey(data: session.symmetricKeyData))
            payloads.append(try SOSPayload.deserialize(from: opened))
        }
        let first = try XCTUnwrap(payloads.first)
        let retry = try XCTUnwrap(payloads.dropFirst().first)
        XCTAssertEqual(first.timestamp.timeIntervalSince1970, floor(firstTime.timeIntervalSince1970), accuracy: 1)
        XCTAssertEqual(retry.timestamp.timeIntervalSince1970, floor(secondTime.timeIntervalSince1970), accuracy: 1)
        XCTAssertEqual(retry.coordinate.latitude, secondCoordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(retry.sosEventId, first.sosEventId)
    }

    func testAuthenticatedChatAtFinalHopReacksWithoutDuplicateHistory() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let key = SymmetricKey(data: Data(repeating: 0x42, count: 32))
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: key.withUnsafeBytes { Data($0) }, localInitials: "BOB")
        let crypto = CryptoService()
        let transport = ParityTransport()
        let engine = ChatMessageEngine(transport: transport, cryptoService: crypto,
            clock: TestMeshClock(initialDate: now), sessionProvider: { session })
        let envelope = CleartextEnvelope(type: .chatMessage, hopLimit: 8, hopCount: 8,
            sessionId: session.sessionId, sequenceNumber: 0x0100_0001)
        let payload = try ChatMessagePayload(senderInitials: "ALX", timestamp: now, text: "Where are you?").serialize()
        let sealed = try await crypto.seal(payload: payload, envelope: envelope, using: key)
        let packet = RawWirePacket(envelope: envelope, ciphertext: sealed.ciphertext, authTag: sealed.authTag)
        var forged = packet
        forged.authTag[0] ^= 1
        let rejected = try await engine.handleInboundPacket(.init(rawPacket: forged, sourcePeerId: "relay"))
        XCTAssertEqual(rejected, .droppedSecurityFailed)
        let accepted = try await engine.handleInboundPacket(.init(rawPacket: packet, sourcePeerId: "relay"))
        XCTAssertTrue(accepted.isDeliveredLocally)
        let duplicate = try await engine.handleInboundPacket(.init(rawPacket: packet, sourcePeerId: "relay"))
        XCTAssertEqual(duplicate, .droppedDuplicate(sequenceNumber: envelope.sequenceNumber))
        let history = await engine.activeMessages()
        let broadcasts = await transport.broadcasts
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(broadcasts.count, 2)
        await engine.clearHistory()
    }

    @MainActor
    func testSOSWithoutGPSAlertsOnceAndAcknowledgesAgain() async throws {
        let key = SymmetricKey(data: Data(repeating: 0x42, count: 32))
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: key.withUnsafeBytes { Data($0) }, localInitials: "BOB")
        let crypto = CryptoService()
        let transport = ParityTransport()
        let audio = ParityAudio()
        let envelope = CleartextEnvelope(type: .sos, sessionId: session.sessionId, sequenceNumber: 0x0100_0001)
        let payload = SOSPayload(coordinate: .init(latitude: 0, longitude: 0), timestamp: .init(timeIntervalSince1970: 0),
            accuracy: 255, sosEventId: 77, senderInitials: "ALX", emergencyType: .general, batteryLevel: 80)
        let sealed = try await crypto.seal(payload: payload.serialize(), envelope: envelope, using: key)
        let packet = RawWirePacket(envelope: envelope, ciphertext: sealed.ciphertext, authTag: sealed.authTag)
        // Adapt only the public receiver API; both receive identical packets and share all assertions.
        #if PROTOTYPE_REFERENCE
        let receiver = SOSViewModel(sessionProvider: { session }, cryptoService: crypto, transport: transport, audioAlerter: audio)
        await receiver.processInboundPacket(.init(rawPacket: packet, sourcePeerId: "ALX"))
        await receiver.processInboundPacket(.init(rawPacket: packet, sourcePeerId: "ALX"))
        let alert = receiver.activeIncomingAlert
        receiver.dismissIncomingAlert()
        #else
        let receiver = SOSForwardingEngine(transport: transport, cryptoService: crypto, sessionProvider: { session }, audioAlerter: audio)
        try await receiver.handleInboundSOSPacket(rawPacket: packet, fromPeerId: "ALX")
        try await receiver.handleInboundSOSPacket(rawPacket: packet, fromPeerId: "ALX")
        let alert = await receiver.activeIncomingAlert
        await receiver.dismissIncomingAlert()
        #endif
        XCTAssertEqual(alert?.id, 77)
        XCTAssertEqual(alert?.timestamp, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(audio.triggerCount, 1)
        XCTAssertEqual(audio.stopCount, 1)
        let broadcasts = await transport.broadcasts
        XCTAssertEqual(broadcasts.count, 2)
    }
}

private actor ParityTransport: PeerTransport, MeshTransport {
    nonisolated let inboundPackets = AsyncStream<InboundPacket> { _ in }
    nonisolated let inboundFrames = AsyncStream<InboundFrame> { _ in }
    nonisolated let peerUpdates = AsyncStream<[PeerInfo]> { _ in }
    nonisolated let stateUpdates = AsyncStream<TransportState> { _ in }
    nonisolated let transportErrors = AsyncStream<TransportError> { _ in }
    nonisolated let sendOutcomes = AsyncStream<SendOutcome> { _ in }
    nonisolated let neighborEvents = AsyncStream<NeighborEvent> { _ in }
    private(set) var broadcasts: [Data] = []
    func start(serviceType: String, session: GroupSession) async throws {}
    func stop() async {}
    func broadcastPacket(_ data: Data) async throws { broadcasts.append(data) }
    func broadcastFrame(_ data: Data) async throws { broadcasts.append(data) }
    func sendPacket(_ data: Data, to peerId: String) async throws { broadcasts.append(data) }
    func sendFrame(_ data: Data, to peerId: String) async throws -> SendOutcome { broadcasts.append(data); return .init(destinationPeerId: peerId, packetType: .ack, isSuccess: true) }
    func forwardFrame(_ data: Data, to nextHopPeerId: String) async throws -> SendOutcome { .init(destinationPeerId: nextHopPeerId, packetType: .ack, isSuccess: true) }
    func activeDirectPeerCount() async -> Int { 0 }
    func activeNeighbors() async -> [NeighborInfo] { [] }
    func queueDepth() async -> QueueDepth { QueueDepth() }
    func setRelayParticipation(enabled: Bool) async {}
    func isRelayPermitted() async -> Bool { false }
    func retainReceivedForCarry(_ packet: RawWirePacket, excludingPeerId: String?) async {}
    func getDiagnostics() async -> TransportDiagnostics {
        .init(localPeerId: "test", serviceType: "_teekum._tcp", sessionName: "Test", sessionId: 0x1234,
            state: .stopped, activeDirectPeers: [], packetsSent: 0, packetsReceived: 0, obsoletePingsCoalesced: 0,
            sendErrors: 0, lastError: nil, recentEvents: [])
    }
}

private final class ParityAudio: SOSAudioAlerting, @unchecked Sendable {
    private let lock = NSLock()
    private var triggers = 0
    private var stops = 0
    var triggerCount: Int { lock.withLock { triggers } }
    var stopCount: Int { lock.withLock { stops } }
    func triggerEmergencyAlertFeedback() { lock.withLock { triggers += 1 } }
    func stopEmergencyAlertFeedback() { lock.withLock { stops += 1 } }
}
