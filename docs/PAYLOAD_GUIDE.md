# TeeKum — V3 Payload and Encoding Guide

**Last reviewed: 11 November 2026 · Source-observed layouts, not verified interoperability**

> The V3 payload layout follows `f4c6393`. The [session migration note](features/session-migration.md) lists the shared XCTest cases and device checks still needed.

Use [PROTOCOL_SPECIFICATION.md](PROTOCOL_SPECIFICATION.md) for authentication/nonce invariants, [NETWORKING.md](NETWORKING.md) for transport/wiring and [agent.md](agent.md) for migration evidence.

## 1. Current Source Baseline

Configuration in `Core/Configuration/TeeKumConfiguration.swift`, exposed through `Core/Packets/PacketConstants.swift`, currently declares:

| Item | Source value |
| :--- | :--- |
| Protocol version | 0x01 in the current app; 0x03 in the frozen prototype |
| Wire frame | 56 bytes |
| Cleartext envelope | 10 bytes |
| Plaintext/ciphertext payload | 30 bytes |
| Authentication tag | 16 bytes |
| Nonce | 12 bytes |
| Nonce domain tag | Four ASCII bytes, TKM3 |

All source paths are relative to `Teekum/Teekum/`. `RawWirePacket` assembles and parses the frame. `CleartextEnvelope` owns its ten-byte header.

```text
Wire offsets (zero-based, inclusive):
0........9  10........................39  40...............55
Envelope    30-byte encrypted payload    16-byte auth tag
10 bytes    30 bytes                     16 bytes
```

Payload tables below use **plaintext payload-relative offsets**, not ciphertext inspection results. Add 10 to get the corresponding wire positions after decryption. Payload bytes on the wire are encrypted; do not paste plaintext plus an invented MAC and call it a valid encrypted fixture.

The previous 54-byte/8-byte-envelope, packed-hop and 29-byte-payload proposals do not describe the current serializer. No compatibility mode is established for them.

## 2. Cleartext Envelope

See `Core/Packets/CleartextEnvelope.swift` and `Core/Packets/RawWirePacket.swift`.

| Wire bytes | Size | Field / current encoding |
| :--- | :--- | :--- |
| 0 | 1 | High nibble protocol version; low nibble PacketType. |
| 1 | 1 | hopLimit, separate UInt8. |
| 2 | 1 | hopCount, separate UInt8. |
| 3..5 | 3 | 24-bit sessionId (`0x000001...0xFFFFFF`) in three bytes, big-endian (`UInt32` masked to `0x00FFFFFF`). |
| 6..9 | 4 | sequenceNumber, big-endian UInt32. |
| 10..39 | 30 | Ciphertext. |
| 40..55 | 16 | Poly1305 authentication tag. |

The decoder reads all three bytes (`3..5`) as a 24-bit `UInt32` SID, and `CleartextEnvelope` masks `sessionId` to `0x00FFFFFF`.

The decoder checks for a positive hop limit and a hop count within that limit. The initializer then clamps the limit to 1...PacketConstants.maxHopLimit (15) and clamps the count to that limit.

| PacketType | Code | Version/type byte | Located payload |
| :--- | :--- | :--- | :--- |
| locationPing | 0x01 | 0x11 | LocationPingPayload |
| sos | 0x02 | 0x12 | SOSPayload |
| meetingUpdate | 0x03 | 0x13 | MeetingUpdatePayload |
| routeReq | 0x04 | 0x14 | RouteReqPayload |
| routeResp | 0x05 | 0x15 | RouteRespPayload |
| ack | 0x06 | 0x16 | ACKPayload |
| chatMessage | 0x07 | 0x17 | ChatMessagePayload |
| uwbTokenExchange | 0x08 | 0x18 | Enum case exists; no dedicated payload implementation/complete UWB flow located. |
| sosResolved | 0x09 | 0x19 | SOSResolvedPayload |

## 3. Field Encoding

- Multi-byte numeric fields use big-endian encoding. The three-byte SID field holds a canonical 24-bit `sessionId` (`0x000001...0xFFFFFF`), formatted as `%06X` for invite links, Keychain accounts, Bonjour TXT `sid`, and routing keys.
- Coordinate integers are rounded signed Int32 values of degrees × 1,000,000. This is about 0.11 m latitude quantization, **not GPS accuracy**; longitude spacing depends on latitude. Validate finite/range-safe inputs before conversion.
- Timestamp fields are UInt32 Unix seconds. Do not refresh an old measurement timestamp when a packet is received. Existing direct conversions require range review; clock-skew/expiry rules are not uniformly enforced by serialization.
- Accuracy is a one-byte meter value. Battery is capped at 100 by several constructors/serializers. Do not invent an unknown-value encoding without reviewing both sides.
- Heading helpers map degrees into a one-byte representation. Quantization/dequantization is not a live compass provider.
- InitialsCodec encodes 1–3 uppercase letters with base 27: a × 729 + b × 27 + c, A=1...Z=26, missing positions=0. Two bytes hold the result. Initials are display data; they do not prove unique membership or non-colliding sender slots.
- The one-byte `MemberColor` field uses `0x00` for automatic color and `0x01...0x09` for explicit choices. Cream uses `0x04` and yellow uses `0x09`. Location and SOS carry this field. Chat displays the local session or the latest roster color, with an initials-based fallback until a profile color is received. Older builds use their automatic color for an unrecognized code. Saved `0x04` profiles restore as cream because earlier builds stored both choices under that code.

## 4. Current 30-Byte Payloads

Sources are in `Core/Packets/Payloads/`.

### 4.1 LocationPingPayload — 0x01

| Payload bytes | Field |
| :--- | :--- |
| 0..3 | latitudeRaw: Int32 |
| 4..7 | longitudeRaw: Int32 |
| 8..11 | Original measurement timestamp: UInt32 |
| 12 | accuracy: UInt8 |
| 13..14 | senderInitials: base-27 two bytes |
| 15 | batteryLevel: UInt8 |
| 16 | heading: UInt8 |
| 17 | colorCode: UInt8 |
| 18..29 | 12 zero reserved bytes |

**No statusCode or targetRefId is serialized.** LocationPublisher's executable construction follows this sensor-only layout despite older comments describing status piggybacking. SessionStore still has localStatus/localTargetRefId and Status remains a domain enum; agree their transport behavior separately. Chat presets are separate messages, not an implicit field in this payload.

### 4.2 SOSPayload — 0x02

| Payload bytes | Field |
| :--- | :--- |
| 0..3 | latitudeRaw: Int32 |
| 4..7 | longitudeRaw: Int32 |
| 8..11 | Coordinate measurement timestamp: UInt32 |
| 12 | accuracy: UInt8 |
| 13 | Fixed urgent marker 0x01 |
| 14..17 | sosEventId: UInt32 |
| 18..19 | senderInitials: two bytes |
| 20 | emergencyType: SOSType UInt8 |
| 21 | batteryLevel: UInt8 |
| 22 | colorCode: UInt8 |
| 23..29 | 7 zero reserved bytes |

SOSType currently declares general=0, medical=1, separated=2, security=3 and inactivity=4. A declared inactivity code is not an enabled/validated automatic safety feature. UI hold currently uses 1.5 s; configuration contains 3 s. Those values do not change byte layout and still need product reconciliation.

#### SOSResolvedPayload — 0x09

| Payload bytes | Field |
| :--- | :--- |
| 0..3 | Original SOS event ID, nonzero UInt32, big-endian |
| 4..5 | Original sender initials, encoded with `InitialsCodec` |
| 6..29 | Reserved, written as zero |

Only the sender's explicit confirmation queues this frame. The recipient can dismiss the alert and stop its sound while the Orbit name bubble stays red. The packet uses the existing bounded carry window and has no delivery ACK of its own.

### 4.3 MeetingUpdatePayload — 0x03

| Payload bytes | Field |
| :--- | :--- |
| 0..3 | Meeting latitudeRaw: Int32 |
| 4..7 | Meeting longitudeRaw: Int32 |
| 8..11 | meetupTime: UInt32 |
| 12..15 | createdAt: UInt32 |
| 16 | MeetingAction: propose=1, accept=2, decline=3, cancel=4 |
| 17 | AttendanceStatus: attending=1, cantMakeIt=2, atMeetingPoint=9 |
| 18..21 | meetingPointId: UInt32 |
| 22..23 | senderInitials: two bytes |
| 24 | arrivalRadiusMeters: UInt8; initializer clamps 5...100, default 25 |
| 25 | flags: bit 0 isRightNow; bit 1 anchorToProposerGPS |
| 26..29 | 4 zero reserved bytes |

There is **no landmarkId wire field** in this imported layout. MeetingAttendance in the UI/domain is distinct from this AttendanceStatus wire enum. MeetingPointService maps the wire enum to UI attendance; reconnect and simultaneous proposals still need device checks. The enum source filename is currently `Core/Packets/Payloads/AttendanceStatus.swift`.

### 4.4 RouteReqPayload / RouteRespPayload — 0x04 / 0x05

Both serializers use this layout:

| Payload bytes | Field |
| :--- | :--- |
| 0..1 | originatorInitials: two bytes |
| 2..3 | targetInitials: two bytes |
| 4..7 | discoveryNonce: UInt32 |
| 8 | routeCost: UInt8 |
| 9..29 | 21 zero reserved bytes |

These are initials fields, not the old four-byte originator/target ID proposal. Imported routing helpers and sender identity must be reviewed together.

### 4.5 ACKPayload — 0x06

| Payload bytes | Field |
| :--- | :--- |
| 0..3 | ackedSeqNumber: UInt32 |
| 4..5 | ackedSenderInitials: two bytes |
| 6..9 | ackTimestamp: UInt32 |
| 10 | ACKStatus: deliveredToFriend=1, relayedByMeshHop=2 |
| 11 | receivedRssi: Int8 |
| 12..15 | originalEventId: UInt32 |
| 16..17 | responderInitials: two bytes |
| 18..29 | 12 zero reserved bytes |

Relay receipt is not recipient-confirmed delivery. Current transport reception supplies nil RSSI; agree how “unavailable” is represented in this non-optional payload field. Never fabricate a measured signal value.

### 4.6 ChatMessagePayload — 0x07

| Payload bytes | Field |
| :--- | :--- |
| 0..1 | senderInitials: two bytes |
| 2..5 | timestamp: UInt32 |
| 6 | UTF-8 byte length, 0...20 at the payload codec boundary |
| 7..26 | Up to 20 UTF-8 bytes, padded with zeros |
| 27..29 | 3 zero reserved bytes |

The limit is **bytes, not characters**. serialize() rejects overlong text; serializeUnchecked() truncates raw UTF-8 bytes and can split a multi-byte character. clampTo20Bytes() preserves character boundaries; do not route normal user input through the unchecked encoder without an agreed validation path. The engine may impose a nonempty-text rule separately from the codec.

The strict chat decoder additionally requires exactly 30 bytes and zero reserved/unused text padding. The ordinary decoder checks minimum size, length and UTF-8 but does not establish all strict padding rules. Most other payload decoders accept at least 30 bytes and use defaults for some unknown enums/initials; they are not uniformly strict parsers.

## 5. Shared XCTest Envelope Vector

`ParityContractTests` compares both builds against this frozen prototype envelope and nonce. The current app uses `0x11` in place of `0x31` in the envelope, nonce, and AAD.

```text
version=3, type=locationPing, hopLimit=8, hopCount=2
sessionId=0x1234, memberSlot=7, counter=42
sequenceNumber=(7 << 24) | 42 = 0x0700002A

10-byte serialized envelope:
31 08 02 00 12 34 07 00 00 2A

12-byte nonce constructed from that envelope:
00 12 34 07 00 00 2A 31 54 4B 4D 33
```

Both builds round-trip the SID `0x1234` using their respective protocol versions. `Teekum` encodes and decodes the full 24-bit SID (`0x000001...0xFFFFFF`). AAD masks hop count without changing the other canonical bytes.

A valid encrypted fixture must declare test-only key/input data and use the actual CryptoKit implementation to produce ciphertext/tag. No fabricated authentication tags or copied historical pass counts belong in acceptance evidence.

## 6. Before Changing the Layout

1. Compare with the frozen legacy revision; record unknown/missing payload helpers and behaviors. The current source inventory cannot prove full migration.
2. Resolve SID width, unique identity/counter/key lifecycle and all consumers together. Do not silently enable the old 54-byte proposal or reuse reserved bytes without compatibility review.
3. Validate untrusted bounds, timestamps, enum/initials decoding, padding and UTF-8 at the agreed boundary before mutating state. Serialization helpers are not a complete security pipeline.
4. Verify actual roundtrips across both existing codec/envelope paths, SID boundary values, boundary coordinates, wrong sizes, all packet types and authenticated tampering. UWB is currently an enum without a complete payload flow; do not claim eight working feature payloads.
5. Record tests actually run at the current revision. Use the focused XCTest and optional parity targets. UI testing remains developer-managed.
