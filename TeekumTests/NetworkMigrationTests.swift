//
//  NetworkMigrationTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import XCTest
import CryptoKit
import CoreLocation
@testable import Teekum

final class NetworkMigrationTests: XCTestCase {
    func testPacketLogDistinguishesOutsideReceiptFromCompletedRelay() async throws {
        let transport = PeerTransportService()
        let generation = await transport.beginPacketLogTestSession()
        let groupSOS = try wire(type: .sos, sequence: 1)
        var foreignChat = try RawWirePacket.fromWireData(wire(type: .chatMessage, sequence: 2))
        foreignChat.envelope.sessionId = 0x4321
        foreignChat.envelope.hopCount = 1

        await transport.acceptFrame(groupSOS, from: "sender", generation: generation)
        await transport.acceptFrame(try foreignChat.toWireData(), from: "aware-42", generation: generation)
        let received = await transport.getDiagnostics().recentPackets
        XCTAssertEqual(received.map(\.direction), [.received, .received])
        XCTAssertEqual(received.map(\.isOutsideGroup), [false, true])
        XCTAssertEqual(received.map(\.envelope.type), [.sos, .chatMessage])

        foreignChat.envelope.hopCount += 1
        await transport.recordSendSuccess(foreignChat.envelope, to: "next-hop", generation: generation)
        let diagnostics = await transport.getDiagnostics()
        let dispatched = try XCTUnwrap(diagnostics.recentPackets.last)
        XCTAssertEqual(diagnostics.packetsSent, 1)
        XCTAssertEqual(dispatched.direction, .dispatched)
        XCTAssertTrue(dispatched.isOutsideGroup)
        XCTAssertEqual(dispatched.peerId, "next-hop")
        XCTAssertEqual(dispatched.envelope.hopCount, 2)
        XCTAssertEqual(dispatched.envelope.sequenceNumber, received.last?.envelope.sequenceNumber)

        await transport.stop()
        _ = await transport.beginPacketLogTestSession()
        let beforeLateCompletion = await transport.getDiagnostics()
        await transport.recordSendSuccess(foreignChat.envelope, to: "next-hop", generation: generation)
        await transport.acceptFrame(groupSOS, from: "sender", generation: generation)
        let nextSession = await transport.getDiagnostics()
        XCTAssertTrue(nextSession.recentPackets.isEmpty)
        XCTAssertEqual(nextSession.packetsSent, beforeLateCompletion.packetsSent)
        XCTAssertEqual(nextSession.packetsReceived, beforeLateCompletion.packetsReceived)
    }

    func testPacketLogKeepsOnlyTheNewestHundredEntries() async {
        let transport = PeerTransportService()
        _ = await transport.beginPacketLogTestSession()
        for sequence in 1...110 {
            let envelope = CleartextEnvelope(type: .locationPing, sessionId: 0x1234, sequenceNumber: UInt32(sequence))
            await transport.recordPacket(envelope, direction: .received, peerId: "sender")
        }
        let packets = await transport.getDiagnostics().recentPackets
        XCTAssertEqual(packets.map(\.envelope.sequenceNumber), Array(11...110))
    }

    func testWiFiAwareLinkHelloPreservesRelayPolicyAndChoosesOneDirection() throws {
        let local = WiFiAwareLinkHello(attemptOrder: UUID(), sessionID: 0xABCDEF, initials: "A1Z", relayEnabled: false)
        let sameGroup = WiFiAwareLinkHello(attemptOrder: UUID(), sessionID: local.sessionID, initials: "B2", relayEnabled: true)
        let stranger = WiFiAwareLinkHello(attemptOrder: UUID(), sessionID: 0x123456, initials: "A1Z", relayEnabled: true)

        let encoded = try local.encode()
        XCTAssertEqual(encoded.count, WiFiAwareLinkHello.byteCount)
        let decoded = try WiFiAwareLinkHello.decode(encoded)
        XCTAssertEqual(decoded.attemptOrder, local.attemptOrder)
        XCTAssertEqual(decoded.sessionID, local.sessionID)
        XCTAssertEqual(decoded.initials, local.initials)
        XCTAssertFalse(decoded.relayEnabled)
        XCTAssertTrue(decoded.permitsLink(to: sameGroup))
        XCTAssertFalse(decoded.permitsLink(to: stranger))
        XCTAssertTrue(sameGroup.permitsLink(to: stranger))
        XCTAssertNotEqual(decoded.prefersOutbound(to: sameGroup), sameGroup.prefersOutbound(to: decoded))
        XCTAssertThrowsError(try WiFiAwareLinkHello.decode(encoded.dropLast()))
    }

    func testTCPFramingPreservesSplitAndCombinedMeshPackets() throws {
        let first = try wire(type: .locationPing, sequence: 1)
        let second = try wire(type: .chatMessage, sequence: 2)
        let framer = StreamMessageFramer()
        let split = 20
        XCTAssertTrue(try framer.processIncomingChunk(first.prefix(split)).isEmpty)
        XCTAssertEqual(try framer.processIncomingChunk(first.dropFirst(split) + second), [first, second])
    }

    func testRelaySendRetryWaitsForBackoffAndStopsOnOptOut() async throws {
        let transport = PeerTransportService()
        _ = await transport.beginPacketLogTestSession()
        let item = OutboxItem(packetData: try wire(type: .sos, sequence: 1),
            packetType: .sos, destinationPeerId: "aware-42", isUrgent: true, isRelay: true)

        let scheduled = await transport.scheduleRelayRetryForTest(item)
        XCTAssertTrue(scheduled)

        await transport.setRelayParticipation(enabled: false)
        let awaitingRetry = await transport.outboxRetries.isEmpty
        let depth = await transport.queueDepth()
        XCTAssertTrue(awaitingRetry)
        XCTAssertEqual(depth.urgentCount, 0)
        await transport.stop()
    }

    func testCarryRetriesSlowDownAndDuplicateDoesNotExtendRetention() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let data = try wire(type: .chatMessage, sequence: 1)
        var store = CarryMessageStore()
        store.remember(data, isForeign: true, excludingPeerId: "source", now: now)
        XCTAssertNil(store.nextTransmission(to: ["source"], now: now))
        XCTAssertEqual(store.nextTransmission(to: ["next"], now: now)?.data, data)
        store.markAttempt(data, to: "next", now: now)
        XCTAssertNil(store.nextTransmission(to: ["next"], now: now.addingTimeInterval(1)))
        XCTAssertNotNil(store.nextTransmission(to: ["next"], now: now.addingTimeInterval(2)))
        store.markAttempt(data, to: "next", now: now.addingTimeInterval(2))
        store.markAttempt(data, to: "next", now: now.addingTimeInterval(4))
        XCTAssertNil(store.nextTransmission(to: ["next"], now: now.addingTimeInterval(6)))
        XCTAssertNotNil(store.nextTransmission(to: ["next"], now: now.addingTimeInterval(34)))
        store.disconnected("next")
        XCTAssertNotNil(store.nextTransmission(to: ["next"], now: now.addingTimeInterval(35)))
        store.remember(data, isForeign: true, now: now.addingTimeInterval(590))
        XCTAssertNil(store.nextTransmission(to: ["new"], now: now.addingTimeInterval(600)))
    }

    func testCarryPrioritizesACKAndPurgesForeignCustody() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let chat = try wire(type: .chatMessage, sequence: 1)
        let ack = try wire(type: .ack, sequence: 2)
        let local = try wire(type: .chatMessage, sequence: 3)
        var store = CarryMessageStore(capacity: 2)
        store.remember(chat, isForeign: true, now: now)
        store.remember(ack, isForeign: true, now: now)
        XCTAssertEqual(store.nextTransmission(to: ["next"], now: now)?.data, ack)
        store.remember(local, isForeign: false, now: now)
        store.removeForeign()
        XCTAssertEqual(store.nextTransmission(to: ["next"], now: now)?.data, local)
        store.removeAll()
        XCTAssertNil(store.nextTransmission(to: ["next"], now: now))
    }

    func testForeignReliableTrafficKeepsPriorityAndConsentPurge() throws {
        let queue = PriorityOutboxQueue()
        try queue.enqueue(data: wire(type: .locationPing, sequence: 1), isRelay: true)
        try queue.enqueue(data: wire(type: .chatMessage, sequence: 2), isRelay: true)
        try queue.enqueue(data: wire(type: .sos, sequence: 3), isRelay: true)
        try queue.enqueue(data: wire(type: .ack, sequence: 4), isRelay: true)
        XCTAssertEqual(queue.dequeue()?.packetType, .sos)
        XCTAssertEqual(queue.dequeue()?.packetType, .ack)
        XCTAssertEqual(queue.dequeue()?.packetType, .chatMessage)
        XCTAssertEqual(queue.dequeue()?.packetType, .locationPing)
        try queue.enqueue(data: wire(type: .sos, sequence: 5), isRelay: true)
        try queue.enqueue(data: wire(type: .chatMessage, sequence: 6), isRelay: true)
        try queue.enqueue(data: wire(type: .chatMessage, sequence: 7))
        queue.clearRelayQueue()
        XCTAssertEqual(queue.totalQueuedCount, 1)
        XCTAssertEqual(queue.dequeue()?.isRelay, false)
    }

    func testTelemetryReservesReliableTrafficToken() async {
        let clock = TestMeshClock(initialDate: Date(timeIntervalSince1970: 1_800_000_000))
        let limiter = ForwardingRateLimiter(clock: clock, ordinaryCapacity: 4, ordinaryRefillRate: 8)
        for _ in 0..<3 {
            let consumed = await limiter.consumeTelemetryToken()
            XCTAssertTrue(consumed)
        }
        let telemetryBlocked = await limiter.consumeTelemetryToken()
        let reliableAllowed = await limiter.consumeOrdinaryToken()
        let depleted = await limiter.consumeOrdinaryToken()
        XCTAssertFalse(telemetryBlocked)
        XCTAssertTrue(reliableAllowed)
        XCTAssertFalse(depleted)
        clock.advance(by: 0.25)
        let refilled = await limiter.consumeTelemetryToken()
        XCTAssertTrue(refilled)
    }

    @MainActor
    func testRouterRejectsUnauthenticatedChatWithoutPoisoningCacheOrCarry() async throws {
        let transport = NetworkTestTransport()
        let crypto = CryptoService()
        let cache = SeenPacketCache()
        let routing = RoutingTable()
        let neighbors = NeighborTable()
        let discovery = RouteDiscoveryService(routingTable: routing, neighborTable: neighbors,
            transport: transport, cryptoService: crypto)
        let policy = RelayPolicyManager(storageKeyPrefix: "network-router-\(UUID())", transport: transport, defaultMode: .disabled)
        let key = SymmetricKey(size: .bits256)
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: key.withUnsafeBytes { Data($0) },
            localInitials: "BOB")
        var accepted = 0
        var alerts = 0
        let router = PacketRouter(cryptoService: crypto, peerTransport: transport,
            relayPolicyManager: policy, routeDiscoveryService: discovery, seenPacketCache: cache,
            onLocationPing: { _, _ in }, onSOS: { _, _ in alerts += 1 }, onACK: { _ in }, onMeetingUpdate: { _ in },
            onChat: { _ in accepted += 1 })
        let envelope = CleartextEnvelope(type: .chatMessage, sessionId: session.sessionId,
            sequenceNumber: CleartextEnvelope.makeSequenceNumber(memberSlot: 1, counter: 1))
        let payload = try ChatMessagePayload(senderInitials: "ALX", timestamp: .now, text: "Hello").serialize()
        let sealed = try await crypto.seal(payload: payload, envelope: envelope, using: key)
        let valid = RawWirePacket(envelope: envelope, ciphertext: sealed.ciphertext, authTag: sealed.authTag)
        var invalid = valid
        invalid.authTag[invalid.authTag.startIndex] ^= 1
        await router.routeInboundPacket(InboundPacket(rawPacket: invalid, sourcePeerId: "relay"), for: session)
        let cacheBefore = await cache.count
        let carryBefore = await transport.carriedCount
        XCTAssertEqual(accepted, 0)
        XCTAssertEqual(cacheBefore, 0)
        XCTAssertEqual(carryBefore, 0)
        await router.routeInboundPacket(InboundPacket(rawPacket: valid, sourcePeerId: "relay"), for: session)
        let carryAfter = await transport.carriedCount
        let sentAfter = await transport.broadcastCount
        XCTAssertEqual(accepted, 1)
        XCTAssertEqual(carryAfter, 1)
        XCTAssertEqual(sentAfter, 1)
        let opaqueSOS = try RawWirePacket.fromWireData(wire(type: .sos, sequence: 0x0100_0002))
        await router.routeInboundPacket(.init(rawPacket: opaqueSOS, sourcePeerId: "relay"), for: session)
        await router.routeInboundPacket(.init(rawPacket: opaqueSOS, sourcePeerId: "relay"), for: session)
        let sentWithOpaqueSOS = await transport.broadcastCount
        XCTAssertEqual(alerts, 0)
        XCTAssertEqual(sentWithOpaqueSOS, 2, "Prototype fallback forwards once without delivering an alert.")
        router.stop()
        await router.routeInboundPacket(InboundPacket(rawPacket: valid, sourcePeerId: "relay"), for: session)
        XCTAssertEqual(accepted, 1)
    }

    @MainActor
    func testRouterAuthenticatesResolutionBeforeForwardingOrRetaining() async throws {
        let transport = NetworkTestTransport()
        let crypto = CryptoService()
        let discovery = RouteDiscoveryService(routingTable: RoutingTable(), neighborTable: NeighborTable(),
            transport: transport, cryptoService: crypto)
        let policy = RelayPolicyManager(storageKeyPrefix: "network-router-\(UUID())", transport: transport, defaultMode: .disabled)
        let key = SymmetricKey(size: .bits256)
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: key.withUnsafeBytes { Data($0) },
            localInitials: "BOB")
        let senderSlot = MemberID.fromInitials("ALX").memberSlot
        let resolution = SOSResolvedPayload(senderInitials: "ALX", eventId: 77)
        var accepted: [SOSResolvedPayload] = []
        let router = PacketRouter(cryptoService: crypto, peerTransport: transport,
            relayPolicyManager: policy, routeDiscoveryService: discovery, seenPacketCache: SeenPacketCache(),
            onLocationPing: { _, _ in }, onSOS: { _, _ in }, onACK: { _ in }, onMeetingUpdate: { _ in },
            onChat: { _ in }, onSOSResolved: { accepted.append($0) })
        let sequence = CleartextEnvelope.makeSequenceNumber(memberSlot: senderSlot, counter: 1)
        let envelope = CleartextEnvelope(type: .sosResolved, sessionId: session.sessionId, sequenceNumber: sequence)
        let data = try await crypto.sealToWireBytes(payload: resolution.serialize(), envelope: envelope, using: key)
        var tampered = data
        tampered[tampered.index(before: tampered.endIndex)] ^= 1
        let invalid = try RawWirePacket.fromWireData(tampered)
        await router.routeInboundPacket(.init(rawPacket: invalid, sourcePeerId: "relay"), for: session)
        XCTAssertTrue(accepted.isEmpty)
        let valid = try RawWirePacket.fromWireData(data)
        for _ in 0..<2 {
            await router.routeInboundPacket(.init(rawPacket: valid, sourcePeerId: "relay"), for: session)
        }
        XCTAssertEqual(accepted, [resolution])
        let carried = await transport.carriedCount
        let broadcast = await transport.broadcastCount
        XCTAssertEqual(carried, 1)
        XCTAssertEqual(broadcast, 1)

        var carry = CarryMessageStore()
        carry.remember(data, isForeign: false)
        XCTAssertEqual(carry.nextTransmission(to: ["reconnected-friend"])?.data, data)
    }

    @MainActor
    func test24BitSessionIdsRoundTripEnvelopeIsolateRoutesAndAuthenticateInRouter() async throws {
        for sid: UInt32 in [0x000001, GroupSession.defaultSessionId, 0xAB1234, 0xFFFFFF] {
            var env = CleartextEnvelope(type: .locationPing, hopLimit: 8, hopCount: 2, sessionId: sid, sequenceNumber: 0x0700_002A)
            let serialized = env.serialize()
            XCTAssertEqual(serialized.subdata(in: 3..<6), Data(PacketConstants.encodeSessionId24(sid)))
            XCTAssertEqual(env.constructNonce().prefix(3), Data(PacketConstants.encodeSessionId24(sid)))
            XCTAssertEqual(env.authenticatedAssociatedData().subdata(in: 3..<6), Data(PacketConstants.encodeSessionId24(sid)))
            XCTAssertEqual(try CleartextEnvelope.deserialize(from: serialized), env)
            XCTAssertEqual(PacketKey(wireData: serialized)?.sessionId, sid)

            env.sessionId = 0x1200_0000 | sid
            XCTAssertEqual(env.sessionId, sid)
        }

        let routing = RoutingTable()
        await routing.recordForwardRoute(destinationId: "ALX", nextHop: "P1", hopCount: 1, cost: 1, sequenceNumber: 1, ttl: 30, sessionId: 0xAB1234)
        await routing.recordForwardRoute(destinationId: "ALX", nextHop: "P2", hopCount: 1, cost: 1, sequenceNumber: 1, ttl: 30, sessionId: 0xCD1234)
        await routing.invalidateRoutes(forSessionId: 0xAB1234)
        let evicted = await routing.findRoute(to: "ALX", inSession: 0xAB1234)
        let kept = await routing.findRoute(to: "ALX", inSession: 0xCD1234)
        XCTAssertNil(evicted)
        XCTAssertEqual(kept?.nextHopPeerId, "P2")

        let transport = NetworkTestTransport()
        let crypto = CryptoService()
        let cache = SeenPacketCache()
        let neighbors = NeighborTable()
        let discovery = RouteDiscoveryService(routingTable: routing, neighborTable: neighbors, transport: transport, cryptoService: crypto)
        let policy = RelayPolicyManager(storageKeyPrefix: "network-24bit-\(UUID())", transport: transport, defaultMode: .disabled)
        let key = SymmetricKey(size: .bits256)
        let session = GroupSession(sessionId: 0xAB1234, symmetricKeyData: key.withUnsafeBytes { Data($0) }, localInitials: "BOB")
        var delivered = 0
        let router = PacketRouter(cryptoService: crypto, peerTransport: transport, relayPolicyManager: policy,
            routeDiscoveryService: discovery, seenPacketCache: cache,
            onLocationPing: { _, _ in }, onSOS: { _, _ in }, onACK: { _ in }, onMeetingUpdate: { _ in },
            onChat: { _ in delivered += 1 })
        let envelope = CleartextEnvelope(type: .chatMessage, sessionId: session.sessionId, sequenceNumber: 0x0100_0001)
        let payload = try ChatMessagePayload(senderInitials: "ALX", timestamp: .now, text: "24-bit mesh").serialize()
        let sealed = try await crypto.seal(payload: payload, envelope: envelope, using: key)
        let wire = try RawWirePacket(envelope: envelope, ciphertext: sealed.ciphertext, authTag: sealed.authTag).toWireData()
        let parsed = try RawWirePacket.fromWireData(wire)
        XCTAssertEqual(parsed.envelope.sessionId, session.sessionId)
        await router.routeInboundPacket(InboundPacket(rawPacket: parsed, sourcePeerId: "ALX"), for: session)
        XCTAssertEqual(delivered, 1)
    }

    @MainActor
    func testRouterDeduplicatesInboundMeetingUpdatesAndStillRelaysOnce() async throws {
        let transport = NetworkTestTransport()
        let crypto = CryptoService()
        let cache = SeenPacketCache()
        let routing = RoutingTable()
        let neighbors = NeighborTable()
        let discovery = RouteDiscoveryService(routingTable: routing, neighborTable: neighbors,
            transport: transport, cryptoService: crypto)
        let policy = RelayPolicyManager(storageKeyPrefix: "network-meeting-\(UUID())", transport: transport, defaultMode: .disabled)
        let key = SymmetricKey(size: .bits256)
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: key.withUnsafeBytes { Data($0) },
            localInitials: "BOB")
        var updates: [MeetingUpdatePayload] = []
        let router = PacketRouter(cryptoService: crypto, peerTransport: transport,
            relayPolicyManager: policy, routeDiscoveryService: discovery, seenPacketCache: cache,
            onLocationPing: { _, _ in }, onSOS: { _, _ in }, onACK: { _ in },
            onMeetingUpdate: { updates.append($0) }, onChat: { _ in })

        let envelope = CleartextEnvelope(type: .meetingUpdate, hopLimit: 15, hopCount: 0,
            sessionId: session.sessionId,
            sequenceNumber: CleartextEnvelope.makeSequenceNumber(memberSlot: 1, counter: 1))
        let payload = MeetingUpdatePayload(
            coordinate: .init(latitude: -6.2, longitude: 106.8),
            action: .propose, attendanceStatus: .attending,
            meetingPointId: 77, senderInitials: "ALX"
        ).serialize()
        let sealed = try await crypto.seal(payload: payload, envelope: envelope, using: key)
        let packet = RawWirePacket(envelope: envelope, ciphertext: sealed.ciphertext, authTag: sealed.authTag)

        await router.routeInboundPacket(InboundPacket(rawPacket: packet, sourcePeerId: "ALX"), for: session)
        await router.routeInboundPacket(InboundPacket(rawPacket: packet, sourcePeerId: "relay"), for: session)

        let relayed = await transport.broadcastCount
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(relayed, 1)
    }

    private func wire(type: PacketType, sequence: UInt32) throws -> Data {
        try RawWirePacket(envelope: CleartextEnvelope(type: type, sessionId: 0x1234, sequenceNumber: sequence),
            ciphertext: Data(repeating: 0, count: 30), authTag: Data(repeating: 0, count: 16)).toWireData()
    }
}

private extension PeerTransportService {
    func scheduleRelayRetryForTest(_ item: OutboxItem) -> Bool {
        handleSendError(TransportError.sendFailed("Test failure"), outboxItem: item)
        return outboxRetries[item.id] != nil && outbox.isEmpty
    }

    func beginPacketLogTestSession() -> UUID {
        activeSession = GroupSession(sessionId: 0x1234, localInitials: "TST")
        return radioGeneration
    }
}

private actor NetworkTestTransport: PeerTransport, MeshTransport {
    nonisolated let inboundPackets = AsyncStream<InboundPacket> { _ in }
    nonisolated let inboundFrames = AsyncStream<InboundFrame> { _ in }
    nonisolated let peerUpdates = AsyncStream<[PeerInfo]> { _ in }
    nonisolated let stateUpdates = AsyncStream<TransportState> { _ in }
    nonisolated let transportErrors = AsyncStream<TransportError> { _ in }
    nonisolated let sendOutcomes = AsyncStream<SendOutcome> { _ in }
    nonisolated let neighborEvents = AsyncStream<NeighborEvent> { _ in }
    private(set) var carriedCount = 0
    private(set) var broadcastCount = 0

    func start(serviceType: String, session: GroupSession) async throws {}
    func stop() async {}
    func broadcastPacket(_ data: Data) async throws { broadcastCount += 1 }
    func broadcastFrame(_ data: Data) async throws { broadcastCount += 1 }
    func sendPacket(_ data: Data, to peerId: String) async throws {}
    func sendFrame(_ data: Data, to peerId: String) async throws -> SendOutcome {
        SendOutcome(destinationPeerId: peerId, packetType: .chatMessage, isSuccess: true)
    }
    func forwardFrame(_ data: Data, to nextHopPeerId: String) async throws -> SendOutcome {
        SendOutcome(destinationPeerId: nextHopPeerId, packetType: .chatMessage, isSuccess: true)
    }
    func retainReceivedForCarry(_ packet: RawWirePacket, excludingPeerId: String?) async { carriedCount += 1 }
    func activeDirectPeerCount() async -> Int { 0 }
    func activeNeighbors() async -> [NeighborInfo] { [] }
    func queueDepth() async -> QueueDepth { QueueDepth() }
    func setRelayParticipation(enabled: Bool) async {}
    func isRelayPermitted() async -> Bool { false }
    func getDiagnostics() async -> TransportDiagnostics {
        TransportDiagnostics(localPeerId: "test", serviceType: "_meepo-mesh._tcp", sessionName: "Test",
            sessionId: 0x1234, state: .stopped, activeDirectPeers: [], packetsSent: 0, packetsReceived: 0,
            obsoletePingsCoalesced: 0, sendErrors: 0, lastError: nil, recentEvents: [])
    }
}
