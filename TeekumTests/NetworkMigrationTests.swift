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
    @MainActor
    func testDelayedPublisherDoesNotBroadcastAnOldQueuedCoordinate() async throws {
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: Data(repeating: 0x42, count: 32),
            localInitials: "ALX")
        let crypto = CryptoService()
        let transport = NetworkTestTransport()
        let location = LocationService()
        let firstTime = Date(timeIntervalSince1970: 1_800_000_000)
        let newestTime = firstTime.addingTimeInterval(4)
        location.simulateLocation(coordinate: .init(latitude: 0, longitude: 0), timestamp: firstTime)
        location.publishCurrentState()
        location.simulateLocation(coordinate: .init(latitude: 0, longitude: 0.0002), timestamp: newestTime)
        let sent = expectation(description: "Initial fix and buffered tick have been transmitted")
        sent.expectedFulfillmentCount = 2
        await transport.setOnBroadcast { _ in sent.fulfill() }
        let publisher = LocationPublisher(locationService: location, sessionProvider: { session },
            cryptoService: crypto, transport: transport)
        publisher.start()
        defer { publisher.stop() }
        await fulfillment(of: [sent], timeout: 2)

        let packets = await transport.broadcastPackets
        XCTAssertEqual(packets.count, 2)
        for data in packets {
            let raw = try RawWirePacket.fromWireData(data)
            let opened = try await crypto.open(ciphertext: raw.ciphertext, envelope: raw.envelope,
                authTag: raw.authTag, using: SymmetricKey(data: session.symmetricKeyData))
            let ping = try LocationPingPayload.deserialize(from: opened)
            XCTAssertEqual(ping.timestamp, newestTime)
            XCTAssertEqual(ping.coordinate.longitude, 0.0002, accuracy: 0.000001)
        }
    }

    @MainActor
    func testSchedulerStreamsFreshCoordinatesThroughTheRunningPublisher() async throws {
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: Data(repeating: 0x42, count: 32),
            localInitials: "ALX")
        let crypto = CryptoService()
        let transport = NetworkTestTransport()
        let location = LocationService(cadenceConfig: .init(movingInterval: 0.02, stationaryInterval: 0.1))
        let publisher = LocationPublisher(locationService: location, sessionProvider: { session },
            cryptoService: crypto, transport: transport)
        let nextTime = Date(timeIntervalSince1970: 1_800_000_004)
        let transmitted = expectation(description: "Scheduled ping carries the latest measurement")
        let receiveFresh: @Sendable (Data) async -> Void = { data in
            guard let raw = try? RawWirePacket.fromWireData(data),
                  let opened = try? await crypto.open(ciphertext: raw.ciphertext, envelope: raw.envelope,
                    authTag: raw.authTag, using: SymmetricKey(data: session.symmetricKeyData)),
                  let ping = try? LocationPingPayload.deserialize(from: opened),
                  ping.timestamp == nextTime else { return }
            XCTAssertEqual(ping.coordinate.longitude, 0.0002, accuracy: 0.000001)
            transmitted.fulfill()
        }
        location.simulateLocation(coordinate: .init(latitude: 0, longitude: 0),
            timestamp: nextTime.addingTimeInterval(-4))
        location.setStationaryState(true)
        location.isTracking = true
        let initial = expectation(description: "Publisher has sent its initial coordinate")
        await transport.setOnBroadcast { _ in initial.fulfill() }
        publisher.start()
        defer {
            publisher.stop()
            location.stopTracking()
        }
        await fulfillment(of: [initial], timeout: 2)
        await transport.setOnBroadcast(receiveFresh)
        location.startPublishingScheduler()

        location.simulateLocation(coordinate: .init(latitude: 0, longitude: 0.0002), timestamp: nextTime)

        await fulfillment(of: [transmitted], timeout: 2)
        XCTAssertGreaterThan(publisher.publishedPingsCount, 0)
    }

    @MainActor
    func testPublishedLocationUpdatesMoveTheOrbitMember() async throws {
        let crypto = CryptoService()
        let transport = NetworkTestTransport()
        let keyData = Data(repeating: 0x42, count: 32)
        let sender = GroupSession(sessionId: 0x1234, symmetricKeyData: keyData, localInitials: "ALX")
        let receiver = GroupSession(sessionId: 0x1234, symmetricKeyData: keyData, localInitials: "BOB")
        let store = SessionStore(activeSession: receiver)
        let location = LocationService()
        let publisher = LocationPublisher(locationService: location, sessionProvider: { sender },
            cryptoService: crypto, transport: transport)
        let routing = RoutingTable()
        let discovery = RouteDiscoveryService(routingTable: routing, neighborTable: NeighborTable(),
            transport: transport, cryptoService: crypto)
        let policy = RelayPolicyManager(storageKeyPrefix: "orbit-location-\(UUID())",
            transport: transport, defaultMode: .disabled)
        let router = PacketRouter(cryptoService: crypto, peerTransport: transport,
            relayPolicyManager: policy, routeDiscoveryService: discovery, seenPacketCache: SeenPacketCache(),
            onLocationPing: { store.applyLocationPing($0, inbound: $1) }, onSOS: { _, _ in },
            onACK: { _ in }, onMeetingUpdate: { _ in }, onChat: { _ in })
        let origin = LocationPin(coordinate: .init(latitude: 0, longitude: 0), horizontalAccuracy: 5)
        let firstTime = Date(timeIntervalSince1970: 1_800_000_000)
        var projections: [OrbitProjection] = []

        for (index, longitude) in [0.0001, 0.0003].enumerated() {
            let timestamp = firstTime.addingTimeInterval(Double(index * 5))
            location.simulateLocation(coordinate: .init(latitude: 0, longitude: longitude), timestamp: timestamp)
            try await publisher.handleLocationPingReady(location: XCTUnwrap(location.currentLocation))
            let packets = await transport.broadcastPackets
            let raw = try RawWirePacket.fromWireData(XCTUnwrap(packets.last))
            await router.routeInboundPacket(.init(rawPacket: raw, sourcePeerId: "ALX"), for: receiver)
            let member = try XCTUnwrap(store.visibleMembers.first)
            let coordinate = try XCTUnwrap(member.coordinate)
            XCTAssertEqual(coordinate.longitude, longitude, accuracy: 0.000001)
            XCTAssertEqual(member.measurementTimestamp, timestamp)
            projections.append(OrbitProjection(from: origin, to: coordinate,
                heading: 0, radius: 100))
        }

        XCTAssertGreaterThan(projections[1].distance, projections[0].distance)
        XCTAssertGreaterThan(projections[1].x, projections[0].x)
    }

    func testPacketLogDistinguishesOutsideReceiptFromCompletedRelay() async throws {
        let transport = PeerTransportService()
        let generation = await transport.beginPacketLogTestSession()
        let groupSOS = try wire(type: .sos, sequence: 1)
        var foreignChat = try RawWirePacket.fromWireData(wire(type: .chatMessage, sequence: 2))
        foreignChat.envelope.sessionId = 0x4321
        foreignChat.envelope.hopCount = 1

        await transport.receiveBLE(groupSOS, from: "ble-p:sender", generation: generation)
        await transport.receiveBLE(try foreignChat.toWireData(), from: "ble-p:relay-source", generation: generation)
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
        let sentBeforeLateCompletion = await transport.getDiagnostics().packetsSent
        await transport.recordSendSuccess(foreignChat.envelope, to: "next-hop", generation: generation)
        let nextSession = await transport.getDiagnostics()
        XCTAssertTrue(nextSession.recentPackets.isEmpty)
        XCTAssertEqual(nextSession.packetsSent, sentBeforeLateCompletion)
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

    func testBLEFragmentsPreserveFrameAndRejectOutOfOrderData() {
        let frame = Data((0..<56).map(UInt8.init))
        for mtu in [2, 20, 57] {
            let fragments = BLEFrameCodec.fragments(frame, maximumValueLength: mtu)
            var codec = BLEFrameCodec()
            var result: Data?
            for fragment in fragments {
                XCTAssertLessThanOrEqual(fragment.count, mtu)
                result = codec.receive(fragment)
            }
            XCTAssertEqual(result, frame)
        }
        var codec = BLEFrameCodec()
        let fragments = BLEFrameCodec.fragments(frame, maximumValueLength: 20)
        XCTAssertNil(codec.receive(fragments[1]))
        XCTAssertNil(codec.receive(fragments[0]))
        XCTAssertNil(codec.receive(fragments[2]))
        XCTAssertTrue(BLEFrameCodec.fragments(frame, maximumValueLength: 1).isEmpty)
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

    func testLocationBroadcastCoalescesOnlyPingsFromTheSameSender() throws {
        let queue = PriorityOutboxQueue()
        let local = try wire(type: .locationPing, sequence: 0x0100_0001)
        let olderRelay = try wire(type: .locationPing, sequence: 0x0200_0001, hopCount: 1)
        let latestRelay = try wire(type: .locationPing, sequence: 0x0200_0002, hopCount: 1)

        try queue.enqueue(data: local)
        try queue.enqueue(data: olderRelay)
        try queue.enqueue(data: latestRelay)
        try queue.enqueue(data: olderRelay)
        try queue.enqueue(data: latestRelay, destinationPeerId: "relay")

        XCTAssertEqual(queue.obsoletePingsCoalesced, 2)
        XCTAssertEqual(queue.queueDepth.normalCount, 3)
        var broadcasts: Set<Data> = []
        var targeted: Data?
        while let item = queue.dequeue() {
            if item.destinationPeerId == nil {
                broadcasts.insert(item.packetData)
            } else {
                XCTAssertEqual(item.destinationPeerId, "relay")
                targeted = item.packetData
            }
        }
        XCTAssertEqual(broadcasts, [local, latestRelay])
        XCTAssertEqual(targeted, latestRelay)
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

    @MainActor
    func testRouterDeliversOnlyFreshAddressedFollowIntentsWithoutConfirmingDelivery() async throws {
        let transport = NetworkTestTransport()
        let crypto = CryptoService()
        let discovery = RouteDiscoveryService(routingTable: RoutingTable(), neighborTable: NeighborTable(),
            transport: transport, cryptoService: crypto)
        let policy = RelayPolicyManager(storageKeyPrefix: "network-follow-\(UUID())", transport: transport, defaultMode: .disabled)
        let key = SymmetricKey(size: .bits256)
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: key.withUnsafeBytes { Data($0) },
            localInitials: "BOB")
        let senderSlot = MemberID.fromInitials("ALX").memberSlot
        var acknowledgements = 0
        var follows: [FollowIntentPayload] = []
        let router = PacketRouter(cryptoService: crypto, peerTransport: transport,
            relayPolicyManager: policy, routeDiscoveryService: discovery, seenPacketCache: SeenPacketCache(),
            onLocationPing: { _, _ in }, onSOS: { _, _ in }, onACK: { _ in acknowledgements += 1 },
            onMeetingUpdate: { _ in }, onChat: { _ in }, onFollow: { follows.append($0) })

        func packet(_ payload: Data, counter: UInt32, slot: UInt8) async throws -> RawWirePacket {
            let envelope = CleartextEnvelope(type: .ack, sessionId: session.sessionId,
                sequenceNumber: CleartextEnvelope.makeSequenceNumber(memberSlot: slot, counter: counter))
            let wire = try await crypto.sealToWireBytes(payload: payload, envelope: envelope, using: key)
            return try RawWirePacket.fromWireData(wire)
        }

        let helper = FollowIntentPayload(senderInitials: "ALX", recipientInitials: "BOB", sosEventId: 77).serialize()
        let legacy = try ACKPayload.deserialize(from: helper)
        XCTAssertEqual(legacy.ackedSeqNumber, 0)
        XCTAssertEqual(legacy.originalEventId, 0)

        let valid = try await packet(helper, counter: 1, slot: senderSlot)
        var tampered = valid
        tampered.authTag[tampered.authTag.startIndex] ^= 1
        let wrongSlot = try await packet(helper, counter: 2, slot: senderSlot ^ 1)
        let elsewhere = FollowIntentPayload(senderInitials: "ALX", recipientInitials: "NIC", sosEventId: 77).serialize()
        let otherRecipient = try await packet(elsewhere, counter: 3, slot: senderSlot)
        var stale = helper
        var timestamp = UInt32(Date().addingTimeInterval(-90).timeIntervalSince1970).bigEndian
        withUnsafeBytes(of: &timestamp) { stale.replaceSubrange(6..<10, with: $0) }
        let expired = try await packet(stale, counter: 4, slot: senderSlot)
        let regular = FollowIntentPayload(senderInitials: "ALX", recipientInitials: "BOB", sosEventId: nil).serialize()
        let regularFollow = try await packet(regular, counter: 5, slot: senderSlot)
        let delivery = ACKPayload(ackedSeqNumber: 1, ackedSenderInitials: "BOB", ackStatus: .deliveredToFriend,
            receivedRssi: 0, originalEventId: 1, responderInitials: "ALX").serialize()
        let deliveryACK = try await packet(delivery, counter: 6, slot: senderSlot)

        for frame in [tampered, valid, valid, wrongSlot, otherRecipient, expired, regularFollow, deliveryACK] {
            await router.routeInboundPacket(.init(rawPacket: frame, sourcePeerId: "relay"), for: session)
        }
        XCTAssertEqual(follows.map(\.senderInitials), ["ALX", "ALX"])
        XCTAssertEqual(follows.map(\.sosEventId), [77, nil])
        XCTAssertEqual(acknowledgements, 1)
    }

    @MainActor
    func testDismissingHelperNoticeKeepsSOSActiveUntilEnded() async throws {
        let session = GroupSession(sessionId: 0x1234, localInitials: "BOB")
        let engine = SOSForwardingEngine(transport: NetworkTestTransport(), cryptoService: CryptoService(),
            sessionProvider: { session })
        let model = SOSViewModel(engine: engine, locationService: LocationService(isLiveSharingEnabled: false),
            sessionProvider: { session })
        await model.start()
        model.triggerSOS()
        for _ in 0..<100 where model.isSending { try await Task.sleep(for: .milliseconds(10)) }
        let eventId = try XCTUnwrap(model.outgoingEventId)
        model.receiveHelper("ALX", eventId: eventId ^ 1)
        XCTAssertNil(model.helperOnTheWay)

        model.receiveHelper("ALX", eventId: eventId)
        model.receiveHelper("ALX", eventId: eventId)
        model.receiveHelper("NIC", eventId: eventId)
        XCTAssertEqual(model.helperOnTheWay, "ALX")
        model.dismissHelperOnTheWay()
        XCTAssertEqual(model.helperOnTheWay, "NIC")
        model.dismissHelperOnTheWay()
        XCTAssertNil(model.helperOnTheWay)
        XCTAssertEqual(model.outgoingEventId, eventId)
        XCTAssertTrue(model.showsEdgeGlow)

        model.endSOS()
        for _ in 0..<100 where model.isResolving { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNil(model.outgoingEventId)
        XCTAssertFalse(model.showsEdgeGlow)
        model.receiveHelper("HSN", eventId: eventId)
        XCTAssertNil(model.helperOnTheWay)
        await model.stop()
    }

    @MainActor
    func testNearbySetupAuthenticatesDirectGroupTrafficWithoutRelayingOrChangingGPS() async throws {
        let transport = NetworkTestTransport()
        let crypto = CryptoService()
        let discovery = RouteDiscoveryService(routingTable: RoutingTable(), neighborTable: NeighborTable(),
            transport: transport, cryptoService: crypto)
        let policy = RelayPolicyManager(storageKeyPrefix: "network-nearby-\(UUID())", transport: transport, defaultMode: .disabled)
        let key = SymmetricKey(size: .bits256)
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: key.withUnsafeBytes { Data($0) }, localInitials: "BOB")
        let store = SessionStore(activeSession: session)
        var advertisementLinks: [String] = []
        var assembly = NearbyTokenFragment.Assembly()
        var receivedToken: Data?
        let router = PacketRouter(cryptoService: crypto, peerTransport: transport,
            relayPolicyManager: policy, routeDiscoveryService: discovery, seenPacketCache: SeenPacketCache(),
            onLocationPing: { _, _ in }, onSOS: { _, _ in }, onACK: { _ in },
            onMeetingUpdate: { _ in }, onChat: { _ in }, onNearbyToken: { fragment, inbound in
                if let color = fragment.advertisedColor {
                    advertisementLinks.append(inbound.sourcePeerId)
                    _ = store.applyNearbyPresence(from: fragment.sender, color: color, at: inbound.receivedAt)
                } else if let token = assembly.receive(fragment) {
                    receivedToken = token
                }
            })
        let advertisement = try XCTUnwrap(NearbyTokenFragment.advertisement(from: "ALX", color: MemberColor.yellow.rawValue))
        let slot = MemberID.fromInitials("ALX").memberSlot
        let envelope = CleartextEnvelope(type: .nearbyToken, hopLimit: 1, sessionId: session.sessionId,
            sequenceNumber: CleartextEnvelope.makeSequenceNumber(memberSlot: slot, counter: 1))
        let sealed = try await crypto.sealToWireBytes(payload: advertisement, envelope: envelope, using: key)
        let valid = try RawWirePacket.fromWireData(sealed)
        var relayed = valid
        relayed.envelope.hopCount = 1
        var foreign = valid
        foreign.envelope.sessionId = 0x4321
        var tampered = valid
        tampered.authTag[tampered.authTag.startIndex] ^= 1
        for raw in [relayed, foreign, tampered, valid, valid] {
            await router.routeInboundPacket(.init(rawPacket: raw, sourcePeerId: "direct-link"), for: session)
        }
        await router.routeInboundPacket(.init(rawPacket: valid, sourcePeerId: "ble-p:alternate"), for: session)
        XCTAssertEqual(advertisementLinks, ["direct-link", "ble-p:alternate"])

        let token = Data((0..<(NearbyTokenFragment.chunkSize * NearbyTokenFragment.maxFragments)).map { UInt8(truncatingIfNeeded: $0) })
        let payloads = NearbyTokenFragment.payloads(for: token, from: "ALX", to: "BOB", transfer: 1)
        XCTAssertEqual(payloads.count, NearbyTokenFragment.maxFragments)
        for (index, payload) in payloads.reversed().enumerated() {
            let header = CleartextEnvelope(type: .nearbyToken, hopLimit: 1, sessionId: session.sessionId,
                sequenceNumber: CleartextEnvelope.makeSequenceNumber(memberSlot: slot, counter: UInt32(index + 2)))
            let data = try await crypto.sealToWireBytes(payload: payload, envelope: header, using: key)
            let raw = try RawWirePacket.fromWireData(data)
            await router.routeInboundPacket(.init(rawPacket: raw, sourcePeerId: "ble-p:alternate"), for: session)
        }
        XCTAssertEqual(receivedToken, token)
        let member = try XCTUnwrap(store.visibleMembers.first)
        XCTAssertEqual(member.id, "ALX")
        XCTAssertEqual(member.color, .yellow)
        XCTAssertNil(member.coordinate)
        XCTAssertNil(member.measurementTimestamp)
        let broadcasts = await transport.broadcastCount
        let carries = await transport.carriedCount
        XCTAssertEqual(broadcasts, 0)
        XCTAssertEqual(carries, 0)
    }

    func testNearbyTransferReassemblesAndQueuesBehindLocationChatAndSOS() throws {
        let data = Data(0..<124)
        let payloads = NearbyTokenFragment.payloads(for: data, from: "ALX", to: "BOB", transfer: 1)
        var assembly = NearbyTokenFragment.Assembly()
        let fragments = try payloads.reversed().map { try XCTUnwrap(NearbyTokenFragment(payload: $0)) }
        for fragment in fragments.dropLast() {
            XCTAssertNil(assembly.receive(fragment))
        }
        XCTAssertEqual(assembly.receive(try XCTUnwrap(fragments.last)), data)
        let queue = PriorityOutboxQueue()
        let control = try wire(type: .nearbyToken, sequence: 1)
        queue.enqueueNearbyFrames([control, control], to: "direct-link")
        XCTAssertFalse(queue.isEmpty)
        queue.clearRelayQueue()
        XCTAssertEqual(queue.totalQueuedCount, 2)
        XCTAssertThrowsError(try queue.enqueue(data: control))
        try queue.enqueue(data: wire(type: .locationPing, sequence: 2))
        try queue.enqueue(data: wire(type: .chatMessage, sequence: 3))
        try queue.enqueue(data: wire(type: .sos, sequence: 4))
        XCTAssertEqual(queue.dequeue()?.packetType, .sos)
        XCTAssertEqual(queue.dequeue()?.packetType, .chatMessage)
        XCTAssertEqual(queue.dequeue()?.packetType, .locationPing)
        XCTAssertEqual(queue.dequeue()?.destinationPeerId, "direct-link")
        XCTAssertEqual(queue.dequeue()?.packetType, .nearbyToken)
        XCTAssertTrue(queue.isEmpty)
        queue.enqueueNearbyFrames([control], to: "direct-link")
        queue.clear()
        XCTAssertTrue(queue.isEmpty)
    }

    private func wire(type: PacketType, sequence: UInt32, hopCount: UInt8 = 0) throws -> Data {
        try RawWirePacket(envelope: CleartextEnvelope(type: type, hopCount: hopCount, sessionId: 0x1234, sequenceNumber: sequence),
            ciphertext: Data(repeating: 0, count: 30), authTag: Data(repeating: 0, count: 16)).toWireData()
    }
}

private extension PeerTransportService {
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
    private(set) var broadcastPackets: [Data] = []
    private var onBroadcast: (@Sendable (Data) async -> Void)?

    func setOnBroadcast(_ handler: @escaping @Sendable (Data) async -> Void) {
        onBroadcast = handler
    }

    func start(serviceType: String, session: GroupSession) async throws {}
    func stop() async {}
    func broadcastPacket(_ data: Data) async throws {
        broadcastCount += 1
        broadcastPackets.append(data)
        await onBroadcast?(data)
    }
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
        TransportDiagnostics(localPeerId: "test", serviceType: "_teekum._tcp", sessionName: "Test",
            sessionId: 0x1234, state: .stopped, activeDirectPeers: [], packetsSent: 0, packetsReceived: 0,
            obsoletePingsCoalesced: 0, sendErrors: 0, lastError: nil, recentEvents: [])
    }
}
