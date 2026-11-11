//
//  PacketCodecTest.swift
//  TeekumTests
//
//  Created by Nicho on 05/11/26.
//

import Testing
import Foundation
import CoreLocation
import CryptoKit
@testable import Teekum

@Suite("Protocol V3 Packet Codec Test Suite (56-Byte)")
struct PacketCodecTests {

    // MARK: - Test 1: CleartextEnvelope Serialization & Deserialization

    @Test("CleartextEnvelope 10-byte serialization and deserialization roundtrip")
    func envelopeSerializationRoundtrip() throws {
        let original = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .locationPing,
            hopLimit: 8,
            hopCount: 2,
            sessionId: 0xBEEF,
            sequenceNumber: 1337
        )

        let data = original.serialize()
        #expect(data.count == 10)

        let decoded = try CleartextEnvelope.deserialize(from: data)
        #expect(decoded == original)

        for sid: UInt32 in [0x000001, 0x7E3AF5, 0xFFFFFF] {
            let sidEnv = CleartextEnvelope(type: .chatMessage, hopLimit: 8, hopCount: 1, sessionId: sid, sequenceNumber: 99)
            #expect(try CleartextEnvelope.deserialize(from: sidEnv.serialize()) == sidEnv)
        }

        var overwide = CleartextEnvelope(type: .locationPing, sessionId: 0x12345678, sequenceNumber: 1)
        #expect(overwide.sessionId == 0x345678)
        overwide.sessionId = 0xAABBCCDD
        #expect(overwide.sessionId == 0xBBCCDD)
        #expect(try CleartextEnvelope.deserialize(from: overwide.serialize()) == overwide)
    }

    // MARK: - Test 2: Envelope Validation & Error Handling

    @Test("CleartextEnvelope validation and error handling")
    func envelopeValidationAndErrors() {
        // 1. Buffer underflow (<10 bytes)
        let shortData = Data([0x21, 0x08, 0x00, 0x00, 0x12, 0x34])
        #expect(throws: PacketCodecError.bufferUnderflow) {
            try CleartextEnvelope.deserialize(from: shortData)
        }

        // 2. Unsupported protocol version (e.g. 0x01 when 0x03 is required)
        let invalidVersionData = Data([0x11, 0x08, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01])
        #expect {
            try CleartextEnvelope.deserialize(from: invalidVersionData)
        } throws: { error in
            guard case PacketCodecError.unsupportedVersion(let v) = error else { return false }
            return v == 1
        }

        // 3. Unknown packet type (e.g. 0x0F)
        let invalidTypeData = Data([0x3F, 0x08, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01])
        #expect {
            try CleartextEnvelope.deserialize(from: invalidTypeData)
        } throws: { error in
            guard case PacketCodecError.unknownPacketType(let t) = error else { return false }
            return t == 0x0F
        }

        // 4. Invalid hop limit (0)
        let zeroHopLimitData = Data([0x31, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01])
        #expect {
            try CleartextEnvelope.deserialize(from: zeroHopLimitData)
        } throws: { error in
            guard case PacketCodecError.invalidHopLimit(let limit) = error else { return false }
            return limit == 0
        }

        // 5. Hop count exceeding hop limit (count=5, limit=3)
        let hopCountExceededData = Data([0x31, 0x03, 0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01])
        #expect {
            try CleartextEnvelope.deserialize(from: hopCountExceededData)
        } throws: { error in
            guard case PacketCodecError.hopCountExceededLimit(let count, let limit) = error else { return false }
            return count == 5 && limit == 3
        }
    }

    // MARK: - Test 3: Sequence Number Partitioning

    @Test("Sequence number partitioning (memberSlot + monotonic counter)")
    func sequenceNumberPartitioning() {
        // Case A: Member slot 3, counter 100
        let seqA = CleartextEnvelope.makeSequenceNumber(memberSlot: 3, counter: 100)
        #expect(CleartextEnvelope.memberSlot(from: seqA) == 3)
        #expect(CleartextEnvelope.counter(from: seqA) == 100)

        // Case B: Boundary values - slot 255 (0xFF), max 24-bit counter 16,777,215 (0x00FFFFFF)
        let maxCounter: UInt32 = 0x00FFFFFF
        let seqB = CleartextEnvelope.makeSequenceNumber(memberSlot: 255, counter: maxCounter)
        #expect(CleartextEnvelope.memberSlot(from: seqB) == 255)
        #expect(CleartextEnvelope.counter(from: seqB) == maxCounter)
        #expect(seqB == 0xFFFFFFFF)

        // Case C: Disjointness guarantee
        let seqMember0 = CleartextEnvelope.makeSequenceNumber(memberSlot: 0, counter: 1)
        let seqMember1 = CleartextEnvelope.makeSequenceNumber(memberSlot: 1, counter: 1)
        #expect(seqMember0 != seqMember1)
    }

    // MARK: - Test 4: Raw 56-Byte Wire Packet Layout & Size Enforcement

    @Test("RawWirePacket 56-byte layout and size validation")
    func wirePacketLayoutAndSizeValidation() throws {
        let envelope = CleartextEnvelope(
            type: .sos,
            sessionId: 0x1234,
            sequenceNumber: 42
        )
        let dummyCiphertext = Data(repeating: 0xAA, count: 30)
        let dummyAuthTag = Data(repeating: 0xBB, count: 16)

        let packet = RawWirePacket(envelope: envelope, ciphertext: dummyCiphertext, authTag: dummyAuthTag)

        let wireData = try packet.toWireData()
        #expect(wireData.count == 56)

        let parsed = try RawWirePacket.fromWireData(wireData)
        #expect(parsed == packet)

        // Reject short packet (55 bytes)
        let shortWire = wireData.prefix(55)
        #expect {
            try RawWirePacket.fromWireData(shortWire)
        } throws: { error in
            guard case PacketCodecError.invalidPacketSize(let exp, let act) = error else { return false }
            return exp == 56 && act == 55
        }

        // Reject long packet (57 bytes)
        var longWire = wireData
        longWire.append(0x00)
        #expect {
            try RawWirePacket.fromWireData(longWire)
        } throws: { error in
            guard case PacketCodecError.invalidPacketSize(let exp, let act) = error else { return false }
            return exp == 56 && act == 57
        }
    }

    // MARK: - Test 5: Location Ping Quantization & Precision (~11cm)

    @Test("LocationPingPayload Int32 quantization precision (<11cm)")
    func locationPingQuantization() throws {
        let coordinate = CLLocationCoordinate2D(latitude: 33.680312, longitude: -116.237409)
        let timestamp = Date(timeIntervalSince1970: 1729000000)

        let payload = LocationPingPayload(
            coordinate: coordinate,
            timestamp: timestamp,
            accuracy: 8,
            senderInitials: "DNA",
            batteryLevel: 85,
            heading: 180,
            colorCode: 0
        )

        let data = payload.serialize()
        #expect(data.count == 30)

        let decoded = try LocationPingPayload.deserialize(from: data)
        let latDiff = abs(decoded.coordinate.latitude - coordinate.latitude)
        let lonDiff = abs(decoded.coordinate.longitude - coordinate.longitude)

        #expect(latDiff < 0.000002)
        #expect(lonDiff < 0.000002)
        #expect(decoded.accuracy == 8)
        #expect(decoded.senderInitials == "DNA")
        #expect(decoded.batteryLevel == 85)
        #expect(decoded.heading == 180)
    }

    // MARK: - Test 6: Coordinate Boundary Values

    @Test(
        "Coordinate boundary values preservation",
        arguments: [
            CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
            CLLocationCoordinate2D(latitude: -90.0, longitude: -180.0),
            CLLocationCoordinate2D(latitude: 90.0, longitude: 180.0),
            CLLocationCoordinate2D(latitude: -90.0, longitude: 180.0),
            CLLocationCoordinate2D(latitude: 90.0, longitude: -180.0)
        ]
    )
    func coordinateBoundaryValues(coord: CLLocationCoordinate2D) throws {
        let payload = LocationPingPayload(
            coordinate: coord,
            accuracy: 5,
            senderInitials: "ALE",
            batteryLevel: 50
        )
        let data = payload.serialize()
        #expect(data.count == 30)

        let decoded = try LocationPingPayload.deserialize(from: data)
        let latDiff = abs(decoded.coordinate.latitude - coord.latitude)
        let lonDiff = abs(decoded.coordinate.longitude - coord.longitude)

        #expect(latDiff < 0.000002)
        #expect(lonDiff < 0.000002)
    }

    // MARK: - Test 7: SOS Payload Roundtrip

    @Test("SOSPayload roundtrip serialization")
    func sosPayloadRoundtrip() throws {
        let coord = CLLocationCoordinate2D(latitude: 33.681122, longitude: -116.236544)
        let payload = SOSPayload(
            coordinate: coord,
            timestamp: Date(timeIntervalSince1970: 1729000500),
            accuracy: 4,
            sosEventId: 0x98765432,
            senderInitials: "BOB",
            emergencyType: .medical,
            batteryLevel: 42
        )

        let data = payload.serialize()
        #expect(data.count == 30)

        let decoded = try SOSPayload.deserialize(from: data)
        #expect(decoded.sosEventId == 0x98765432)
        #expect(decoded.senderInitials == "BOB")
        #expect(decoded.emergencyType == .medical)
        #expect(decoded.batteryLevel == 42)
    }

    // MARK: - Test 8: Meeting Update Payload Roundtrip

    @Test("MeetingUpdatePayload roundtrip serialization")
    func meetingUpdatePayloadRoundtrip() throws {
        let coord = CLLocationCoordinate2D(latitude: 33.682200, longitude: -116.235500)
        let payload = MeetingUpdatePayload(
            coordinate: coord,
            meetupTime: Date(timeIntervalSince1970: 1729003600),
            createdAt: Date(timeIntervalSince1970: 1729000000),
            action: .accept,
            attendanceStatus: .attending,
            meetingPointId: 0x55556666,
            senderInitials: "SAM",
            arrivalRadiusMeters: 25,
            isRightNow: false,
            anchorToProposerGPS: true
        )

        let data = payload.serialize()
        #expect(data.count == 30)

        let decoded = try MeetingUpdatePayload.deserialize(from: data)
        #expect(decoded.meetingPointId == 0x55556666)
        #expect(decoded.senderInitials == "SAM")
        #expect(decoded.action == .accept)
        #expect(decoded.attendanceStatus == .attending)
        #expect(decoded.arrivalRadiusMeters == 25)
        #expect(decoded.anchorToProposerGPS == true)
        #expect(decoded.isRightNow == false)
    }

    // MARK: - Test 9: ACK Payload Roundtrip

    @Test("ACKPayload roundtrip serialization")
    func ackPayloadRoundtrip() throws {
        let payload = ACKPayload(
            ackedSeqNumber: 0x00000005,
            ackedSenderInitials: "SAM",
            ackTimestamp: Date(timeIntervalSince1970: 1729000100),
            ackStatus: .deliveredToFriend,
            receivedRssi: -65,
            originalEventId: 0x99998888,
            responderInitials: "DNA"
        )

        let data = payload.serialize()
        #expect(data.count == 30)

        let decoded = try ACKPayload.deserialize(from: data)
        #expect(decoded.ackedSeqNumber == 0x00000005)
        #expect(decoded.ackedSenderInitials == "SAM")
        #expect(decoded.ackStatus == .deliveredToFriend)
        #expect(decoded.receivedRssi == -65)
        #expect(decoded.originalEventId == 0x99998888)
        #expect(decoded.responderInitials == "DNA")
    }

    // MARK: - Tests 10 & 11: Route Discovery Payloads

    @Test("RouteReqPayload roundtrip serialization")
    func routeReqPayloadRoundtrip() throws {
        let payload = RouteReqPayload(
            originatorInitials: "DNA",
            targetInitials: "BOB",
            discoveryNonce: 0x12345678,
            routeCost: 3
        )
        let data = payload.serialize()
        #expect(data.count == 30)

        let decoded = try RouteReqPayload.deserialize(from: data)
        #expect(decoded.originatorInitials == "DNA")
        #expect(decoded.targetInitials == "BOB")
        #expect(decoded.discoveryNonce == 0x12345678)
        #expect(decoded.routeCost == 3)
    }

    @Test("RouteRespPayload roundtrip serialization")
    func routeRespPayloadRoundtrip() throws {
        let payload = RouteRespPayload(
            originatorInitials: "DNA",
            targetInitials: "BOB",
            discoveryNonce: 0x12345678,
            routeCost: 3
        )
        let data = payload.serialize()
        #expect(data.count == 30)

        let decoded = try RouteRespPayload.deserialize(from: data)
        #expect(decoded.originatorInitials == "DNA")
        #expect(decoded.targetInitials == "BOB")
        #expect(decoded.discoveryNonce == 0x12345678)
        #expect(decoded.routeCost == 3)
    }

    // MARK: - Test 12: Deterministic Test Vector

    @Test("Deterministic test vector serialization")
    func deterministicTestVector() {
        let envelope = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .locationPing,
            hopLimit: 8,
            hopCount: 0,
            sessionId: 0x0102,
            sequenceNumber: 0x0A0B0C0D
        )
        let envBytes = envelope.serialize()
        let expectedEnvHex = "3108000001020a0b0c0d"
        let actualEnvHex = envBytes.map { String(format: "%02x", $0) }.joined()
        #expect(actualEnvHex == expectedEnvHex)

        let aadBytes = envelope.authenticatedAssociatedData()
        let actualAadHex = aadBytes.map { String(format: "%02x", $0) }.joined()
        #expect(actualAadHex == expectedEnvHex)

        let nonceBytes = envelope.constructNonce()
        let expectedNonceHex = "0001020a0b0c0d31544b4d33"
        let actualNonceHex = nonceBytes.map { String(format: "%02x", $0) }.joined()
        #expect(actualNonceHex == expectedNonceHex)
    }

    // MARK: - Test 13: 1 to 3-Letter Initials Codec

    @Test("InitialsCodec 1-to-3 letter encoding, decoding, and boundaries")
    func initialsCodecBase26() throws {
        // 1. Single letter: "A"
        let aBytes = try #require(InitialsCodec.encode("A"))
        #expect(aBytes.count == 2)
        #expect(InitialsCodec.decode(aBytes) == "A")

        // Single letter: "Z"
        let zBytes = try #require(InitialsCodec.encode("Z"))
        #expect(InitialsCodec.decode(zBytes) == "Z")

        // 2. Two letters: "AB"
        let abBytes = try #require(InitialsCodec.encode("AB"))
        #expect(abBytes.count == 2)
        #expect(InitialsCodec.decode(abBytes) == "AB")

        // Two letters: "ZZ"
        let zzBytes = try #require(InitialsCodec.encode("ZZ"))
        #expect(InitialsCodec.decode(zzBytes) == "ZZ")

        // 3. Three letters: "DNA"
        let dnaBytes = try #require(InitialsCodec.encode("DNA"))
        #expect(dnaBytes.count == 2)
        #expect(InitialsCodec.decode(dnaBytes) == "DNA")

        // Boundary AAA & ZZZ
        let aaaBytes = try #require(InitialsCodec.encode("AAA"))
        #expect(InitialsCodec.decode(aaaBytes) == "AAA")

        let zzzBytes = try #require(InitialsCodec.encode("ZZZ"))
        #expect(InitialsCodec.decode(zzzBytes) == "ZZZ")

        // 4. Invalid inputs
        #expect(InitialsCodec.encode("") == nil)
        #expect(InitialsCodec.encode("ABCD") == nil)
        #expect(InitialsCodec.encode("123") == nil)
        #expect(InitialsCodec.decode([0, 0]) == nil)
        #expect(InitialsCodec.decode([0xFF, 0xFF]) == nil)

        // 5. Sanitization
        #expect(InitialsCodec.sanitize("d") == "D")
        #expect(InitialsCodec.sanitize("ab") == "AB")
        #expect(InitialsCodec.sanitize("Alex") == "ALE")
        #expect(InitialsCodec.sanitize(" d-n.a! ") == "DNA")
    }

    // MARK: - Test 14: MemberColor Payload Serialization & Deterministic Initials Fallback

    @Test("MemberColor 1-byte wire serialization and deterministic hash fallback")
    func memberColorPayloadRoundtripAndInitialsHashFallback() throws {
        let coord = CLLocationCoordinate2D(latitude: 37.774929, longitude: -122.419416)

        // 1. LocationPingPayload roundtrip with explicit MemberColor
        let ping = LocationPingPayload(
            coordinate: coord,
            timestamp: Date(timeIntervalSince1970: 1730000000),
            accuracy: 8,
            senderInitials: "NIC",
            batteryLevel: 88,
            heading: 120,
            colorCode: MemberColor.reddish.rawValue
        )
        let pingData = ping.serialize()
        #expect(pingData.count == 30)
        #expect(pingData[17] == MemberColor.reddish.rawValue)

        let decodedPing = try LocationPingPayload.deserialize(from: pingData)
        #expect(decodedPing.colorCode == MemberColor.reddish.rawValue)
        let resolvedColor = MemberColor.resolve(code: decodedPing.colorCode, initials: decodedPing.senderInitials)
        #expect(resolvedColor == .reddish)

        // 2. SOSPayload roundtrip with explicit MemberColor
        let sos = SOSPayload(
            coordinate: coord,
            timestamp: Date(timeIntervalSince1970: 1730000010),
            accuracy: 5,
            sosEventId: 0xCAFEBABE,
            senderInitials: "ALX",
            emergencyType: .medical,
            batteryLevel: 65,
            colorCode: MemberColor.orangeSalmon.rawValue
        )
        let sosData = sos.serialize()
        #expect(sosData.count == 30)
        #expect(sosData[22] == MemberColor.orangeSalmon.rawValue)

        let decodedSOS = try SOSPayload.deserialize(from: sosData)
        #expect(decodedSOS.colorCode == MemberColor.orangeSalmon.rawValue)
        let resolvedSOSColor = MemberColor.resolve(code: decodedSOS.colorCode, initials: decodedSOS.senderInitials)
        #expect(resolvedSOSColor == .orangeSalmon)

        // 3. Backward Compatibility: Legacy zero-padded packet (colorCode == 0x00)
        let legacyPing = LocationPingPayload(
            coordinate: coord,
            timestamp: Date(timeIntervalSince1970: 1730000000),
            accuracy: 8,
            senderInitials: "DNA",
            batteryLevel: 90,
            heading: 0,
            colorCode: 0
        )
        let legacyData = legacyPing.serialize()
        #expect(legacyData[17] == 0x00)

        let decodedLegacy = try LocationPingPayload.deserialize(from: legacyData)
        #expect(decodedLegacy.colorCode == 0)
        let resolvedLegacy = MemberColor.resolve(code: decodedLegacy.colorCode, initials: decodedLegacy.senderInitials)
        let expectedDNAColor = MemberColor.deterministicColor(for: "DNA")
        #expect(resolvedLegacy == expectedDNAColor)
        #expect(resolvedLegacy != .unset)

        // 4. Deterministic Hashing Invariance & Stability
        let color1 = MemberColor.deterministicColor(for: "NIC")
        let color2 = MemberColor.deterministicColor(for: "NIC")
        #expect(color1 == color2)

        // 5. Selectable Palette Integrity
        let selectable = MemberColor.selectableColors
        #expect(selectable.count == 9)
        #expect(!selectable.contains(.unset))
    }

    // MARK: - Test 15: ChatMessagePayload Serialization & Deserialization Roundtrip

    struct ChatTestCase: CustomTestStringConvertible {
        let initials: String
        let text: String
        var testDescription: String { "Initials: \(initials) | Text: \"\(text)\"" }
    }

    @Test(
        "ChatMessagePayload 30-byte serialization roundtrip",
        arguments: [
            ChatTestCase(initials: "NIC", text: ""),
            ChatTestCase(initials: "A", text: "H"),
            ChatTestCase(initials: "AB", text: "Stage 2"),
            ChatTestCase(initials: "DNA", text: "Beer? Stage 2 - OMW"),
            ChatTestCase(initials: "ALX", text: "12345678901234567890"),
            ChatTestCase(initials: "SAM", text: ChatMessagePayload.presetRestroom),
            ChatTestCase(initials: "BOB", text: ChatMessagePayload.presetAtMainStage),
            ChatTestCase(initials: "CHA", text: ChatMessagePayload.presetRestroom),
            ChatTestCase(initials: "DAN", text: ChatMessagePayload.presetWhereAreYou),
            ChatTestCase(initials: "EVE", text: ChatMessagePayload.presetOnMyWay),
            ChatTestCase(initials: "FRANK", text: ChatMessagePayload.presetLost)
        ]
    )
    func chatMessagePayloadSerializationRoundtrip(testCase: ChatTestCase) throws {
        let timestamp = Date(timeIntervalSince1970: 1730005000)
        let payload = ChatMessagePayload(
            senderInitials: testCase.initials,
            timestamp: timestamp,
            text: testCase.text
        )

        let data = try payload.serialize()
        #expect(data.count == PacketConstants.encryptedPayloadSize)

        let expectedLen = UInt8(testCase.text.utf8.count)
        #expect(data[6] == expectedLen)

        // Reserved padding check
        #expect(data[27] == 0)
        #expect(data[28] == 0)
        #expect(data[29] == 0)

        // Unused text bytes check
        for i in (7 + Int(expectedLen))..<27 {
            #expect(data[i] == 0)
        }

        let decoded = try ChatMessagePayload.deserialize(from: data)
        let expectedInitials = InitialsCodec.sanitize(testCase.initials)
        #expect(decoded.senderInitials == expectedInitials)
        #expect(abs(decoded.timestamp.timeIntervalSince1970 - timestamp.timeIntervalSince1970) < 1.0)
        #expect(decoded.text == testCase.text)
    }

    // MARK: - Test 16: ChatMessagePayload UTF-8 Multi-Byte Encoding & Emoji Clamping

    @Test("ChatMessagePayload UTF-8 multi-byte encoding and byte-boundary clamping")
    func chatMessagePayloadUTF8EncodingAndMultiByte() throws {
        let ts = Date(timeIntervalSince1970: 1730006000)

        // 1. Accented characters (2-byte UTF-8)
        let cafePayload = ChatMessagePayload(senderInitials: "ALX", timestamp: ts, text: "Café 10")
        let cafeData = try cafePayload.serialize()
        #expect(cafeData[6] == 8)
        let decodedCafe = try ChatMessagePayload.deserialize(from: cafeData)
        #expect(decodedCafe.text == "Café 10")

        // 2. Standard 4-byte emoji
        let emojiPayload = ChatMessagePayload(senderInitials: "NIC", timestamp: ts, text: "Beer 🍺")
        let emojiData = try emojiPayload.serialize()
        #expect(emojiData[6] == 9)
        let decodedEmoji = try ChatMessagePayload.deserialize(from: emojiData)
        #expect(decodedEmoji.text == "Beer 🍺")

        // 3. Exactly 5 emojis (20 bytes)
        let maxEmojiPayload = ChatMessagePayload(senderInitials: "BOB", timestamp: ts, text: "🍺🎉🎸🍕🎪")
        #expect(maxEmojiPayload.text.utf8.count == 20)
        let maxEmojiData = try maxEmojiPayload.serialize()
        #expect(maxEmojiData[6] == 20)
        let decodedMaxEmoji = try ChatMessagePayload.deserialize(from: maxEmojiData)
        #expect(decodedMaxEmoji.text == "🍺🎉🎸🍕🎪")

        // 4. Clamping helper
        let longMixed = "123456789012345678🍺"
        let clamped = ChatMessagePayload.clampTo20Bytes(longMixed)
        #expect(clamped.utf8.count <= 20)
        #expect(clamped == "123456789012345678")

        let sixEmojis = "🍺🎉🎸🍕🎪🔥"
        let clampedEmojis = ChatMessagePayload.clampTo20Bytes(sixEmojis)
        #expect(clampedEmojis.utf8.count == 20)
        #expect(clampedEmojis == "🍺🎉🎸🍕🎪")
    }

    // MARK: - Test 17: ChatMessagePayload Malformed Inputs & Bounds Validation

    @Test("ChatMessagePayload malformed inputs and error handling")
    func chatMessagePayloadMalformedInputsAndValidation() {
        let validPayload = ChatMessagePayload(senderInitials: "DNA", text: "Hello")
        let validData = validPayload.serializeUnchecked()

        // 1. Buffer underflow (<30 bytes)
        let shortData = validData.prefix(29)
        #expect(throws: PacketCodecError.bufferUnderflow) {
            try ChatMessagePayload.deserialize(from: shortData)
        }

        // 2. Length field exceeding 20 bytes
        var invalidLenData = validData
        invalidLenData[6] = 21
        #expect {
            try ChatMessagePayload.deserialize(from: invalidLenData)
        } throws: { error in
            guard case PacketCodecError.invalidTextLength(let len) = error else { return false }
            return len == 21
        }

        invalidLenData[6] = 255
        #expect {
            try ChatMessagePayload.deserialize(from: invalidLenData)
        } throws: { error in
            guard case PacketCodecError.invalidTextLength(let len) = error else { return false }
            return len == 255
        }

        // 3. Malformed UTF-8 text bytes
        var malformedUtf8Data = validData
        malformedUtf8Data[6] = 2
        malformedUtf8Data[7] = 0xFF
        malformedUtf8Data[8] = 0x00
        #expect(throws: PacketCodecError.invalidTextEncoding) {
            try ChatMessagePayload.deserialize(from: malformedUtf8Data)
        }

        // 4. Serialization with text exceeding 20 bytes throws invalidTextLength
        let longText = "This text is definitely way longer than twenty bytes!"
        let oversizedPayload = ChatMessagePayload(senderInitials: "NIC", text: longText)
        #expect {
            try oversizedPayload.serialize()
        } throws: { error in
            guard case PacketCodecError.invalidTextLength(let count) = error else { return false }
            return count == longText.utf8.count
        }

        // 5. serializeUnchecked clamps oversized text
        let clampedSerialized = oversizedPayload.serializeUnchecked()
        #expect(clampedSerialized.count == 30)
        #expect(clampedSerialized[6] == 20)

        // 6. Strict deserialization rejects corrupted reserved padding
        var corruptedReservedData = validData
        corruptedReservedData[27] = 0xAA
        #expect(!ChatMessagePayload.hasValidReservedPadding(in: corruptedReservedData))
        #expect(throws: PacketCodecError.payloadDeserializationFailed) {
            try ChatMessagePayload.deserializeStrict(from: corruptedReservedData)
        }

        // 7. Strict deserialization rejects non-zero unused text padding
        var corruptedUnusedPadding = validData
        corruptedUnusedPadding[15] = 0x01
        #expect(!ChatMessagePayload.hasValidReservedPadding(in: corruptedUnusedPadding))
    }

    // MARK: - Test 18: Chat Wire Packet Layout & ChaCha20-Poly1305 AEAD Cryptography

    @Test("Chat wire packet 56-byte layout and ChaCha20-Poly1305 AEAD sealing")
    func chatMessageWirePacketRoundtripAndCryptoAEAD() throws {
        let key = SymmetricKey(size: .bits256)
        let sessionId: UInt32 = 0xCAFEEE
        let sequenceNumber: UInt32 = CleartextEnvelope.makeSequenceNumber(memberSlot: 5, counter: 101)

        let envelope = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .chatMessage,
            hopLimit: 8,
            hopCount: 0,
            sessionId: sessionId,
            sequenceNumber: sequenceNumber
        )

        // 1. Envelope serialization
        let envData = envelope.serialize()
        #expect(envData.count == 10)
        #expect(envData[0] == 0x37)

        // 2. Nonce test
        let nonce = envelope.constructNonce()
        #expect(nonce.count == 12)
        #expect(nonce[7] == 0x37)

        // 3. Seal payload
        let chat = ChatMessagePayload(senderInitials: "SAM", text: "Beer line")
        let plainPayload = try chat.serialize()
        let aad = envelope.authenticatedAssociatedData()
        #expect(aad.count == 10)
        #expect(aad[0] == 0x37)
        #expect(aad[2] == 0x00)

        let chachaNonce = try ChaChaPoly.Nonce(data: nonce)
        let sealed = try ChaChaPoly.seal(plainPayload, using: key, nonce: chachaNonce, authenticating: aad)
        #expect(sealed.ciphertext.count == 30)
        #expect(sealed.tag.count == 16)

        // 4. Form RawWirePacket
        let rawPacket = RawWirePacket(envelope: envelope, ciphertext: sealed.ciphertext, authTag: sealed.tag)
        let wireBytes = try rawPacket.toWireData()
        #expect(wireBytes.count == 56)

        // 5. Parse back
        let parsedRaw = try RawWirePacket.fromWireData(wireBytes)
        #expect(parsedRaw.envelope.type == .chatMessage)
        #expect(parsedRaw.envelope.sessionId == sessionId)

        // 6. Simulate mesh relay hop
        var relayedEnvelope = parsedRaw.envelope
        relayedEnvelope.hopCount = 1

        let relayedAAD = relayedEnvelope.authenticatedAssociatedData()
        let openedBox = try ChaChaPoly.SealedBox(nonce: chachaNonce, ciphertext: parsedRaw.ciphertext, tag: parsedRaw.authTag)
        let decryptedData = try ChaChaPoly.open(openedBox, using: key, authenticating: relayedAAD)
        #expect(decryptedData == plainPayload)

        let decodedChat = try ChatMessagePayload.deserialize(from: decryptedData)
        #expect(decodedChat.senderInitials == "SAM")
        #expect(decodedChat.text == "Beer line")

        // 7. Tampering verification
        var tamperedEnvelope = relayedEnvelope
        tamperedEnvelope.hopLimit = 15
        let tamperedAAD = tamperedEnvelope.authenticatedAssociatedData()
        #expect(throws: (any Error).self) {
            try ChaChaPoly.open(openedBox, using: key, authenticating: tamperedAAD)
        }
    }

    // MARK: - Test 19: LocationPing Option B Contiguous Packing & Reserved Padding

    @Test("LocationPing Option B contiguous packing and 12-byte reserved padding")
    func locationPingOptionBContiguousPackingAndRegression() throws {
        let coord = CLLocationCoordinate2D(latitude: 37.774929, longitude: -122.419416)
        let ts = Date(timeIntervalSince1970: 1730007000)

        let ping = LocationPingPayload(
            coordinate: coord,
            timestamp: ts,
            accuracy: 6,
            senderInitials: "DNA",
            batteryLevel: 92,
            heading: 240,
            colorCode: MemberColor.sandrift.rawValue
        )

        let data = ping.serialize()
        #expect(data.count == 30)
        #expect(data[12] == 6)

        let initialBytes = [data[13], data[14]]
        #expect(InitialsCodec.decode(initialBytes) == "DNA")
        #expect(data[15] == 92)
        #expect(data[16] == 240)
        #expect(data[17] == MemberColor.sandrift.rawValue)

        let reservedSlice = data.subdata(in: 18..<30)
        #expect(reservedSlice.count == 12)
        #expect(reservedSlice.allSatisfy { $0 == 0 })

        let decoded = try LocationPingPayload.deserialize(from: data)
        let latDiff = abs(decoded.coordinate.latitude - coord.latitude)
        let lonDiff = abs(decoded.coordinate.longitude - coord.longitude)
        #expect(latDiff < 0.000002)
        #expect(lonDiff < 0.000002)
        #expect(decoded.accuracy == 6)
        #expect(decoded.senderInitials == "DNA")
        #expect(decoded.batteryLevel == 92)
        #expect(decoded.heading == 240)
        #expect(decoded.colorCode == MemberColor.sandrift.rawValue)

        let truncated = data.prefix(29)
        #expect(throws: PacketCodecError.bufferUnderflow) {
            try LocationPingPayload.deserialize(from: truncated)
        }
    }

    // MARK: - Test 20: Regression Test for All 8 Packet Types

    struct PacketTypeMapping: CustomTestStringConvertible {
        let type: PacketType
        let rawByte: UInt8
        let byte0: UInt8
        var testDescription: String { "\(type) (Raw: 0x\(String(format: "%02X", rawByte)), Byte0: 0x\(String(format: "%02X", byte0)))" }
    }

    @Test(
        "Regression test across all 8 PacketTypes",
        arguments: [
            PacketTypeMapping(type: .locationPing, rawByte: 0x01, byte0: 0x31),
            PacketTypeMapping(type: .sos, rawByte: 0x02, byte0: 0x32),
            PacketTypeMapping(type: .meetingUpdate, rawByte: 0x03, byte0: 0x33),
            PacketTypeMapping(type: .routeReq, rawByte: 0x04, byte0: 0x34),
            PacketTypeMapping(type: .routeResp, rawByte: 0x05, byte0: 0x35),
            PacketTypeMapping(type: .ack, rawByte: 0x06, byte0: 0x36),
            PacketTypeMapping(type: .chatMessage, rawByte: 0x07, byte0: 0x37),
            PacketTypeMapping(type: .uwbTokenExchange, rawByte: 0x08, byte0: 0x38)
        ]
    )
    func packetTypesRegression(mapping: PacketTypeMapping) throws {
        #expect(PacketType.allCases.count == 8)
        #expect(mapping.type.rawValue == mapping.rawByte)

        let env = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: mapping.type,
            sessionId: 0x1234,
            sequenceNumber: 1
        )
        let envData = env.serialize()
        #expect(envData[0] == mapping.byte0)

        let parsedEnv = try CleartextEnvelope.deserialize(from: envData)
        #expect(parsedEnv.type == mapping.type)
    }
}
