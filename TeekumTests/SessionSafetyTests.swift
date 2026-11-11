//
//  SessionSafetyTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CryptoKit
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
        identity.append(contentsOf: [0x12, 0x34, session.memberSlot])
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

    @MainActor
    func testRecoveryUsesKeychainAndLeaveClearsMetadataAndKey() async throws {
        let suite = "session-test-\(UUID())"
        let service = "session-key-test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite); removeKeychainItems(service: service) }
        let session = GroupSession(sessionId: 0x1234, sessionName: "Crew", symmetricKeyData: Data(repeating: 0x42, count: 32), localInitials: "ALX")
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

    func testOrbitProjectionUsesCompassHeadingAndClampsDistantMembers() {
        let north = OrbitProjection(distance: 30, bearing: 0, heading: 0, radius: 100)
        XCTAssertEqual(north.x, 0, accuracy: 0.001)
        XCTAssertLessThan(north.y, 0)
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
