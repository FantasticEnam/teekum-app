//
//  SessionSafetyTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CryptoKit
import Observation
import Security
import XCTest
@testable import Teekum

final class SessionSafetyTests: XCTestCase {
    func testSharedSequenceIsUniqueAcrossConcurrentEmittersAndAllocatorRestart() async throws {
        let service = "sequence-test-\(UUID())"
        defer { removeKeychainItems(service: service) }
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: Data(repeating: 0x42, count: 32), localInitials: "ALX")
        let allocator = PacketSequenceAllocator(serviceName: service)
        let values = try await withThrowingTaskGroup(of: UInt32.self, returning: [UInt32].self) { tasks in
            for _ in 0..<32 { tasks.addTask { try await allocator.next(for: session) } }
            var result: [UInt32] = []
            for try await value in tasks { result.append(value) }
            return result
        }
        XCTAssertEqual(Set(values).count, 32)
        XCTAssertEqual(values.map { $0 & 0x00ff_ffff }.sorted(), Array(1...32))
        XCTAssertTrue(values.allSatisfy { UInt8($0 >> 24) == session.memberSlot })
        let restarted = PacketSequenceAllocator(serviceName: service)
        let next = try await restarted.next(for: session)
        XCTAssertEqual(next & 0x00ff_ffff, 33)
    }

    func testExhaustedSequenceFailsWithoutWrappingNonce() async throws {
        let service = "sequence-test-\(UUID())"
        defer { removeKeychainItems(service: service) }
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: Data(repeating: 0x42, count: 32), localInitials: "ALX")
        var identity = session.symmetricKeyData
        identity.append(contentsOf: [0x00, 0x12, 0x34, session.memberSlot])
        let account = SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account,
            kSecValueData: Data([0, 255, 255, 255])
        ] as CFDictionary, nil)
        XCTAssertEqual(status, errSecSuccess)
        do {
            _ = try await PacketSequenceAllocator(serviceName: service).next(for: session)
            XCTFail("Exhausted nonce space must not restart at zero.")
        } catch PacketSequenceError.exhausted { }
    }

    func testSharedSequenceSupports24BitSessionIdsAndIsolatesUpperByte() async throws {
        let service = "sequence-test-\(UUID())"
        defer { removeKeychainItems(service: service) }
        let key = Data(repeating: 0x42, count: 32)
        let sessionA = GroupSession(sessionId: 0xAB1234, symmetricKeyData: key, localInitials: "ALX")
        let sessionB = GroupSession(sessionId: 0xCD1234, symmetricKeyData: key, localInitials: "ALX")
        let defaultMesh = GroupSession(localInitials: "ALX")
        XCTAssertEqual(defaultMesh.sessionId, 0x7E3AF5)

        let allocator = PacketSequenceAllocator(serviceName: service)
        let seqA1 = try await allocator.next(for: sessionA)
        let seqA2 = try await allocator.next(for: sessionA)
        let seqB1 = try await allocator.next(for: sessionB)
        let seqDefault = try await allocator.next(for: defaultMesh)

        XCTAssertEqual(CleartextEnvelope.counter(from: seqA1), 1)
        XCTAssertEqual(CleartextEnvelope.counter(from: seqA2), 2)
        XCTAssertEqual(CleartextEnvelope.counter(from: seqB1), 1)
        XCTAssertEqual(CleartextEnvelope.counter(from: seqDefault), 1)
    }

    @MainActor
    func testRecoveryUsesKeychainAndLeaveClearsMetadataAndKey() async throws {
        let suite = "session-test-\(UUID())"
        let service = "session-key-test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite); removeKeychainItems(service: service) }
        let session = GroupSession(sessionId: 0xABCDEF, sessionName: "Crew", symmetricKeyData: Data(repeating: 0x42, count: 32), localInitials: "ALX")
        let saved = SessionPersistence(defaults: defaults, keys: KeychainStore(serviceName: service))
        try await saved.save(session)
        let metadata = try XCTUnwrap(defaults.data(forKey: "com.teekum.sessionMetadata"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: metadata) as? [String: Any])
        XCTAssertNil(object["symmetricKeyData"])
        XCTAssertNil(object["members"])
        let restored = SessionPersistence(defaults: defaults, keys: KeychainStore(serviceName: service))
        let loaded = try await restored.load()
        XCTAssertEqual(loaded, session)
        try await restored.clear()
        let empty = try await saved.load()
        let key = try await KeychainStore(serviceName: service).loadKeyFromKeychain(forSessionId: session.sessionId)
        XCTAssertNil(empty)
        XCTAssertNil(key)
    }

    @MainActor
    func testDelayedLocationDoesNotReplaceNewerHardwareMeasurementAndLeaveClearsState() {
        let store = SessionStore(activeSession: GroupSession(localInitials: "ALX"))
        let newer = Date(timeIntervalSince1970: 1_800_000_000)
        let older = newer.addingTimeInterval(-30)
        let lastReceipt = newer.addingTimeInterval(10)
        let pingPacket = RawWirePacket(envelope: .init(type: .locationPing, sessionId: 0x1234, sequenceNumber: 1),
            ciphertext: Data(), authTag: Data())
        let sosPacket = RawWirePacket(envelope: .init(type: .sos, hopCount: 1, sessionId: 0x1234, sequenceNumber: 2),
            ciphertext: Data(), authTag: Data())

        store.applyLocationPing(LocationPingPayload(coordinate: .init(latitude: 1, longitude: 2),
            timestamp: newer, accuracy: 5, senderInitials: "BOB", batteryLevel: 84, heading: 127),
            inbound: InboundPacket(rawPacket: pingPacket, sourcePeerId: "BOB", receivedAt: newer))
        store.applyLocationPing(LocationPingPayload(coordinate: .init(latitude: 3, longitude: 4),
            timestamp: older, accuracy: 50, senderInitials: "BOB", batteryLevel: 84, heading: 0),
            inbound: InboundPacket(rawPacket: pingPacket, sourcePeerId: "BOB", receivedAt: newer.addingTimeInterval(5)))
        store.applySOSLocation(SOSPayload(coordinate: .init(latitude: 0, longitude: 0),
            timestamp: .init(timeIntervalSince1970: 0), accuracy: 255, sosEventId: 1,
            senderInitials: "BOB", batteryLevel: 83),
            inbound: InboundPacket(rawPacket: sosPacket, sourcePeerId: "ALX", receivedAt: lastReceipt))

        XCTAssertEqual(store.members.first?.coordinate?.latitude, 1)
        XCTAssertEqual(store.members.first?.measurementTimestamp, newer)
        XCTAssertEqual(store.members.first?.horizontalAccuracy, 5)
        XCTAssertEqual(store.members.first?.lastSeen, lastReceipt)
        XCTAssertEqual(store.members.first?.isDirectPeer, false)
        store.resetSessionState()
        XCTAssertNil(store.activeSession)
        XCTAssertTrue(store.members.isEmpty)
        XCTAssertNil(store.activeMeetingPoint)
    }

    @MainActor
    func testContactLossHidesMarkerAndLogsOnceUntilMemberReturns() {
        let lastContact = Date(timeIntervalSince1970: 1_800_000_000)
        let timing = MeshTimingConfiguration.default
        let recoveryWindow = timing.stalePeerThreshold + timing.staleRecoveryTimeout
        let recoveryEnds = lastContact.addingTimeInterval(recoveryWindow)
        let peers = [
            PeerInfo(id: "ANI", displayName: "Ani"),
            PeerInfo(id: "BOB", displayName: "Outside group", isGroupMember: false)
        ]
        let store = SessionStore(members: [
            Member(id: "BOB", lastSeen: lastContact, coordinate: .init(latitude: 1, longitude: 2), isDirectPeer: true),
            Member(id: "ANI", lastSeen: lastContact),
            Member(id: "CAL", lastSeen: lastContact, isEmergency: true)
        ])
        store.applyPeerSnapshot(peers, connected: ["ANI", "BOB"])

        XCTAssertTrue(store.refreshMemberVisibility(now: recoveryEnds, peers: peers).isEmpty)
        XCTAssertEqual(store.visibleMembers.map(\.id), ["BOB", "ANI", "CAL"])

        let nextReceipt = recoveryEnds.addingTimeInterval(1)
        let losses = store.refreshMemberVisibility(now: nextReceipt, peers: peers)
        XCTAssertEqual(losses.map(\.initials), ["BOB", "CAL"])
        XCTAssertEqual(losses.first?.timestamp, nextReceipt)
        XCTAssertEqual(store.visibleMembers.map(\.id), ["ANI", "CAL"])
        XCTAssertEqual(store.members.map(\.id), ["BOB", "ANI", "CAL"])
        XCTAssertTrue(store.refreshMemberVisibility(now: nextReceipt.addingTimeInterval(1), peers: peers).isEmpty)
        XCTAssertEqual(store.memberContactLog, losses)

        let packet = RawWirePacket(envelope: .init(type: .locationPing, hopCount: 1, sessionId: 0x1234, sequenceNumber: 1),
            ciphertext: Data(), authTag: Data())
        store.applyLocationPing(LocationPingPayload(coordinate: .init(latitude: 1, longitude: 2),
            timestamp: lastContact, accuracy: 5, senderInitials: "BOB", batteryLevel: 84),
            inbound: InboundPacket(rawPacket: packet, sourcePeerId: "ANI", receivedAt: nextReceipt))
        XCTAssertTrue(store.refreshMemberVisibility(now: nextReceipt, peers: peers).isEmpty)
        XCTAssertEqual(store.visibleMembers.map(\.id), ["BOB", "ANI", "CAL"])

        let laterLosses = store.refreshMemberVisibility(now: nextReceipt.addingTimeInterval(recoveryWindow + 1), peers: peers)
        XCTAssertEqual(laterLosses.map(\.initials), ["BOB"])
        XCTAssertEqual(store.memberContactLog, losses + laterLosses)
        store.resetSessionState()
        XCTAssertTrue(store.memberContactLog.isEmpty)
    }

    @MainActor
    func testFriendListUpdatesWhenAReconnectHasNotReachedReady() {
        let lastContact = Date(timeIntervalSince1970: 1_800_000_000)
        let timing = MeshTimingConfiguration.default
        let now = lastContact.addingTimeInterval(timing.stalePeerThreshold + timing.staleRecoveryTimeout + 1)
        let store = SessionStore(members: [Member(id: "BOB", lastSeen: lastContact, isDirectPeer: true)])
        let friends = FriendListViewModel(sessionStore: store)
        let pending = PeerInfo(id: "BOB", displayName: "Bob", isDirectLink: false, lastSeen: now)
        store.applyPeerSnapshot([pending], connected: [])
        XCTAssertEqual(store.members.first?.lastSeen, lastContact)

        let refresh = XCTestExpectation(description: "Friend list observes the shared roster")
        withObservationTracking {
            XCTAssertEqual(friends.filteredMembers.map(\.id), ["BOB"])
        } onChange: {
            refresh.fulfill()
        }

        XCTAssertEqual(store.refreshMemberVisibility(now: now, peers: [pending]).map(\.initials), ["BOB"])
        XCTAssertEqual(XCTWaiter.wait(for: [refresh], timeout: 0), .completed)
        XCTAssertTrue(friends.filteredMembers.isEmpty)

        let ready = PeerInfo(id: "BOB", displayName: "Bob", lastSeen: now)
        store.applyPeerSnapshot([ready], connected: ["BOB"])
        XCTAssertTrue(store.refreshMemberVisibility(now: now, peers: [ready]).isEmpty)
        XCTAssertEqual(friends.filteredMembers.map(\.id), ["BOB"])
    }

    @MainActor
    func testOrbitUsesTheSelectedLocalProfileColor() {
        let session = GroupSession(localInitials: "DAF", localColorCode: PairingProfileColor.yellow.wireColorCode)
        let store = SessionStore(activeSession: session)
        let orbit = OrbitMapViewModel(sessionStore: store)
        XCTAssertEqual(orbit.localProfileColor, .yellow)

        store.activeSession?.localColorCode = PairingProfileColor.blue.wireColorCode
        XCTAssertEqual(orbit.localProfileColor, .darkSkyBlue)
    }

    func testOrbitProjectionUsesCompassHeadingAndClampsDistantMembers() {
        let north = OrbitProjection(distance: 30, bearing: 0, heading: 0, radius: 100)
        XCTAssertEqual(north.x, 0, accuracy: 0.001)
        XCTAssertLessThan(north.y, 0)
        XCTAssertFalse(north.isClamped)
        let eastWhenFacingEast = OrbitProjection(distance: 600, bearing: 90, heading: 90, radius: 100)
        XCTAssertEqual(eastWhenFacingEast.x, 0, accuracy: 0.001)
        XCTAssertEqual(eastWhenFacingEast.y, -100, accuracy: 0.001)
        XCTAssertTrue(eastWhenFacingEast.isClamped)
    }

    func testOrbitProjectsMeetingPointBearingAndKeepsActualDistanceWhenClamped() {
        let location = LocationPin(coordinate: .init(latitude: 0, longitude: 0), horizontalAccuracy: 5)
        let point = MeetingPoint(name: "Meet here", coordinate: .init(latitude: 0, longitude: 0.001),
            proposerInitials: "ALX")
        let facingNorth = OrbitProjection(from: location, to: point.coordinate, heading: 0, radius: 100)
        let facingEast = OrbitProjection(from: location, to: point.coordinate, heading: 90, radius: 100)

        XCTAssertEqual(facingNorth.x, 100, accuracy: 0.001)
        XCTAssertEqual(facingEast.y, -100, accuracy: 0.001)
        XCTAssertTrue(facingEast.isClamped)
        XCTAssertEqual(facingEast.distance, 111.3, accuracy: 0.5)
    }

    private func removeKeychainItems(service: String) {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary)
    }
}
