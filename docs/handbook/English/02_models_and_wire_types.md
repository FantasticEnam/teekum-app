# Volume 02: Binary Models, Wire Types & Session Domain Entities (Meepo)

## 1. Executive Summary & 56-Byte Wire Architecture

Volume 02 defines the core binary serialization contracts, bit-level wire formats, cryptographic containers, and session domain entities of the Meepo mesh networking client. In severe off-grid disaster zone environments, wireless radio spectrum is scarce, Bluetooth Low Energy (BLE) and Wi-Fi Direct MTUs are constrained, and devices operate under strict battery envelopes. To overcome these harsh physical realities, Meepo departs from variable-length, cleartext serialization protocols (such as JSON or Protobuf) and instead implements a strictly invariant **56-byte wire frame**.

Every datagram traversing the radio mesh adheres to an immutable three-segment physical layout:
1. **Cleartext Routing Envelope (Bytes 0..9, 10 Bytes):** Carries unencrypted routing metadata—protocol version (`0x03`), packet opcode (`PacketType`), hop count (`0..7`), 24-bit session ID, and bit-partitioned sequence number. This allows intermediate peer radios to inspect and relay packets without holding cryptographic keys or decrypting payloads.
2. **Sealed Ciphertext Payload (Bytes 10..39, 30 Bytes):** Encrypted using the ChaCha20 stream cipher with a 256-bit symmetric session key. All high-level features—location pings, chat messages, rendezvous updates, route discoveries, and emergency SOS alerts—pack their serialized state into this identical 30-byte container.
3. **Poly1305 MAC Authentication Tag (Bytes 40..55, 16 Bytes):** A high-speed, cryptographically secure 128-bit authentication tag computed over both the unencrypted envelope (Authenticated Associated Data, or AAD) and the ciphertext payload. Any physical frame modification or radio bit corruption causes immediate verification failure and silent drop.

```
+---------------------------------------------------------------------------------------+
|                                56-Byte Physical Datagram                              |
+--------------------------+-----------------------------------+------------------------+
| Bytes 0..9 (10 Bytes)    | Bytes 10..39 (30 Bytes)           | Bytes 40..55 (16 Bytes)|
| Cleartext Routing Header | Sealed Ciphertext Payload         | Poly1305 MAC Tag       |
| (Unencrypted AAD)        | (ChaCha20 Encrypted)              | (Authentication Tag)   |
+--------------------------+-----------------------------------+------------------------+
```

---

### ELI5 Wire Analogy: The Sealed Diplomatic Pouch

Imagine a catastrophic disaster zone—such as an earthquake rubble field, flooded river basin, or blacked-out urban grid—where cellular towers and power substations are completely destroyed. A volunteer Community Emergency Response Team (CERT) and search-and-rescue squad is deployed across collapsed blocks to locate survivors, mark hazard zones, and coordinate medical triage. Because direct radio ranges through concrete rubble are severely limited, responders pass encrypted digital dispatches along from device to device across the ad-hoc mesh.

To keep your communication secure and efficient, your group uses identical, standardized metal diplomatic pouches:
1. **The Transparent Cleartext Address Label (Bytes 0..9):** Taped to the outside of the pouch is a small transparent card. It lists:
   - What version of the pouch system you are using (Version 3).
   - What kind of letter is inside (e.g., Chat, Location Ping, or Emergency SOS).
   - A step counter (Hop Count) that starts at 0. Every relay responder who passes the pouch along adds 1 to this counter. If the counter reaches 7, the pouch is retired so it does not loop through the rubble forever.
   - Your rescue squad ID (Session ID) and message number (Sequence Number).
2. **The Heavy Steel Locked Safe (Bytes 10..39):** Inside the pouch is an armored steel lockbox that only opens with your rescue squad's private 256-bit symmetric key. A stranger or intermediary volunteer relaying the pouch through the rubble cannot open the lockbox or inspect casualty details; they only know which session ID it belongs to and where to forward it.
3. **The Tamper-Evident Wax Seal (Bytes 40..55):** Before sending the pouch, you apply an unbreakable wax seal stamped with a unique mathematical code (Poly1305 MAC). When your teammate receives the pouch, they verify the seal against their squad key. If someone tampered with the address label or scratched the metal lockbox, the seal shatters and the recipient immediately discards the corrupted packet.

---

### Critical Cryptographic Wire Invariants

Meepo's wire architecture enforces five non-negotiable systems engineering invariants:

1. **Strict 56-Byte Datagram Invariance:**
   Every transmitted packet across all 8 protocol opcodes is padded or clamped to exactly 56 bytes. This prevents eavesdroppers equipped with RF packet sniffers from classifying traffic based on datagram length (for example, distinguishing between an SOS emergency broadcast, a location beacon, or a text message).
2. **Hop Count AAD Masking Invariant:**
   In intermediate mesh forwarding, relay nodes must increment the `hopCount` byte (Byte 2) to track transmission distance and prevent infinite loops. If Byte 2 were included in the Poly1305 MAC computation, the sender's authentication tag would break at the very first relay hop. To solve this, `CleartextEnvelope.authenticatedAssociatedData()` masks Byte 2 strictly to `0x00` during both encryption and decryption. Relays can increment the hop count on the wire while the Poly1305 MAC tag remains 100% valid.
3. **Sequence Number Bit Partitioning:**
   The 32-bit sequence number (`UInt32`) is bit-partitioned into:
   - Upper 8 bits (`sequenceNumber >> 24`): The sender's `memberSlot` ($0..255$).
   - Lower 24 bits (`sequenceNumber & 0x00FFFFFF`): A monotonic packet sequence counter ($0..16,777,215$).
   This partitioning guarantees that up to 256 group members maintain completely independent sequence counters, eliminating replay-detection collisions between simultaneous senders.
4. **12-Byte AEAD Nonce Composition:**
   The ChaCha20-Poly1305 AEAD cipher requires a 12-byte (96-bit) nonce that must NEVER repeat under the same symmetric key. Meepo deterministically constructs this nonce from wire metadata:
   - Bytes 0..2 (3 bytes): 24-bit `sessionId`.
   - Bytes 3..6 (4 bytes): 32-bit big-endian `sequenceNumber`.
   - Byte 7 (1 byte): `0x30 | opcode` (combining protocol version 3 and packet type).
   - Bytes 8..11 (4 bytes): Static ASCII domain tag `[0x54, 0x4B, 0x4D, 0x33]` (`"TKM3"`).
5. **Fixed-Point Geographic Quantization:**
   To pack floating-point GPS coordinates into compact integer fields, coordinates are multiplied by $10^7$ (`10_000_000.0`) and stored as signed 32-bit big-endian integers (`Int32`). This delivers approximately 1.1 centimeters of geographic resolution worldwide while requiring only 8 bytes total for both latitude and longitude.

---

## Included Source Files

The following table itemizes every source code file assigned to Volume 02. Every file path is linked relative to this document, accompanied by its category, verified line count (`wc -l`), and singular architectural role:

| File Path | Category | Line Count (`wc -l`) | Architectural Purpose & Responsibility |
| :--- | :--- | :---: | :--- |
| [MeepoConfiguration.swift](../../Teekum/Teekum/Core/Configuration/MeepoConfiguration.swift) | Configuration | 199 | Master configuration repository unifying network thresholds, hop limits, retry backoffs, battery cutoffs, and UI timings. |
| [PacketConstants.swift](../../Teekum/Teekum/Core/Packets/PacketConstants.swift) | Wire Protocol | 67 | Network wire invariants defining strictly fixed 56-byte datagram, 10-byte envelope, 24-bit session ID masks, and domain tags. |
| [CleartextEnvelope.swift](../../Teekum/Teekum/Core/Packets/CleartextEnvelope.swift) | Wire Protocol | 178 | 10-byte unencrypted wire header carrying protocol version, packet opcode, hop limits, session ID, and partitioned sequence number. |
| [RawWirePacket.swift](../../Teekum/Teekum/Core/Packets/RawWirePacket.swift) | Wire Protocol | 54 | Canonical 56-byte wire datagram container binding 10-byte CleartextEnvelope, 30-byte ciphertext, and 16-byte Poly1305 authentication tag. |
| [PacketType.swift](../../Teekum/Teekum/Core/Packets/PacketType.swift) | Wire Protocol | 19 | Wire packet opcode enumeration defining the 8 active datagram types (0x01 through 0x08) and opcode serialization. |
| [PacketCodecError.swift](../../Teekum/Teekum/Core/Packets/PacketCodecError.swift) | Wire Protocol | 55 | Serialization and deserialization error domain covering buffer underflow, invalid hop counts, and unknown packet opcodes. |
| [ACKStatus.swift](../../Teekum/Teekum/Core/Packets/ACKStatus.swift) | Binary Payload | 13 | Delivery acknowledgment status enumeration classifying confirmation outcomes (delivered, timedOut, failed). |
| [ACKPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/ACKPayload.swift) | Binary Payload | 93 | 30-byte binary payload confirming message receipt with responder initials, sequence counter, and millisecond timestamp. |
| [AttendanceStatus.swift](../../Teekum/Teekum/Core/Packets/Payloads/AttendanceStatus.swift) | Binary Payload | 22 | Rendezvous attendance status enumeration (attending, declined, pending) for meeting point synchronization. |
| [ChatMessagePayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/ChatMessagePayload.swift) | Binary Payload | 146 | 30-byte binary payload packing sender initials, sequence counter, and up to 20 UTF-8 text bytes with byte-boundary clamping. |
| [LocationPingPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/LocationPingPayload.swift) | Binary Payload | 106 | 30-byte binary payload packing quantized latitude/longitude (Int32), horizontal accuracy, battery status, and sender initials. |
| [MeetingAction.swift](../../Teekum/Teekum/Core/Packets/Payloads/MeetingAction.swift) | Binary Payload | 15 | Rendezvous mutation action enumeration (propose, update, cancel) governing meeting point lifecycle. |
| [MeetingUpdatePayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/MeetingUpdatePayload.swift) | Binary Payload | 147 | 30-byte binary payload encoding rendezvous GPS coordinate, scheduled epoch time, setter slot, and action opcode. |
| [RouteReqPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/RouteReqPayload.swift) | Binary Payload | 59 | 30-byte binary payload for AODV route discovery carrying target initials, originator sequence, and accumulated metric. |
| [RouteRespPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/RouteRespPayload.swift) | Binary Payload | 59 | 30-byte binary payload for AODV route reply establishing return paths with destination sequence and hop count. |
| [SOSPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSPayload.swift) | Binary Payload | 103 | 30-byte binary payload broadcasting emergency distress alert with GPS coordinate, horizontal accuracy, and sender initials. |
| [SOSResolvedPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSResolvedPayload.swift) | Binary Payload | 41 | 30-byte binary payload broadcasting cancellation and resolution of an active SOS emergency. |
| [SOSType.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSType.swift) | Binary Payload | 27 | Emergency alert classification enumeration distinguishing manual user SOS swipes from automated inactivity triggers. |
| [GroupSession.swift](../../Teekum/Teekum/Core/Session/GroupSession.swift) | Session Domain Model | 185 | Core domain model representing an active disaster zone mesh group with 24-bit session ID, symmetric key, and local member profile. |
| [GroupSessionInvite.swift](../../Teekum/Teekum/Core/Session/GroupSessionInvite.swift) | Session Domain Model | 22 | Value type representing invitation credentials and QR code payload containing session ID, key fingerprint, and group name. |
| [MeetingAttendance.swift](../../Teekum/Teekum/Core/Session/MeetingAttendance.swift) | Session Domain Model | 34 | Domain model tracking member RSVP attendance and arrival status for an active group rendezvous. |
| [MeetingPoint.swift](../../Teekum/Teekum/Core/Session/MeetingPoint.swift) | Session Domain Model | 66 | Domain model representing a group rendezvous point with GPS coordinates, scheduled meetup time, and setter lock ownership. |
| [Member.swift](../../Teekum/Teekum/Core/Session/Member.swift) | Session Domain Model | 136 | Domain model representing a disaster zone group peer, including telemetry, latest GPS fix, heading, and link reachability state. |
| [MemberColor.swift](../../Teekum/Teekum/Core/Session/MemberColor.swift) | Session Domain Model | 84 | Domain enum defining the 8 selectable member identity colors with hex serialization and SwiftUI color bridges. |
| [MemberID.swift](../../Teekum/Teekum/Core/Session/MemberID.swift) | Session Domain Model | 41 | Compact member identifier value type binding 1-to-3 character initials with partitioned member slots. |
| [SessionHolder.swift](../../Teekum/Teekum/Core/Session/SessionHolder.swift) | Session Domain Model | 19 | Observable container holding the active GroupSession instance for reactive SwiftUI view observation. |
| [SessionPersistence.swift](../../Teekum/Teekum/Core/Session/SessionPersistence.swift) | Session Domain Model | 43 | Actor managing secure on-disk persistence of active group session credentials and participant metadata. |
| [SessionRecord.swift](../../Teekum/Teekum/Core/Session/SessionRecord.swift) | Session Domain Model | 33 | Codable persistence schema used to serialize and restore active session state across app restarts. |
| [SessionStore.swift](../../Teekum/Teekum/Core/Session/SessionStore.swift) | Session Domain Model | 192 | Central observable state store tracking participant rosters, active meeting points, contact loss events, and presence. |
| **Total Volume 02 Artifacts** | **29 Files** | **2258** | **100% Volume 02 Codebase Accounting** |

---

## ASCII Byte-Layout & Serialization Diagrams

The following ASCII diagrams detail the physical bit and byte layouts for the 56-byte wire datagram, cleartext routing envelope, cryptographic nonce, and all active binary payload types.

### 1. 56-Byte Physical Datagram Frame (`RawWirePacket`)

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 Cleartext Routing Envelope                    |
|                     (Bytes 0..3: 4 Bytes)                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 Cleartext Routing Envelope                    |
|                     (Bytes 4..7: 4 Bytes)                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Envelope (8..9)               |   Sealed Ciphertext Payload   |
| (Bytes 8..9: 2 Bytes)         |    (Bytes 10..11: 2 Bytes)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                   Sealed Ciphertext Payload                   |
|                    (Bytes 12..39: 28 Bytes)                   |
|                   [ChaCha20 Encrypted Stream]                 |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                   Poly1305 Authentication Tag                 |
|                    (Bytes 40..55: 16 Bytes)                   |
|                     [128-Bit Cryptographic MAC]               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 2. 10-Byte Cleartext Routing Envelope (`CleartextEnvelope`)

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Vers  | Opcode|   Hop Count   |           Session ID          |
| (4b)  |  (4b) | (8 bits: 0..7)|           (Bytes 2..3)        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Session ID (4)|  Member Slot  |   Monotonic Sequence Counter  |
|   (Byte 4)    |  (8 bits: 0)  |          (Bytes 6..7)         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Counter (8)   | Reserved / Pad|
|   (Byte 8)    |   (Byte 9)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

Byte 0:     [ Version: 4 bits (0x03) | PacketType Opcode: 4 bits (0x01..0x08) ]
Byte 1:     [ Hop Count: 8 bits (0..7, AAD-masked to 0x00 during auth) ]
Bytes 2..4: [ Session ID: 24 bits big-endian (0x000001..0xFFFFFF) ]
Bytes 5..8: [ Sequence Number: 32 bits (Upper 8b MemberSlot | Lower 24b Sequence Counter) ]
Byte 9:     [ Reserved / Trailing Envelope alignment byte (0x00) ]
```

### 3. 12-Byte AEAD Nonce Construction

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Session ID (24 bits)      | Sequence Num  |
|                       (Bytes 0..2)            |   (Byte 3)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Sequence Number (cont.)    | Vers | Opcode |
|                       (Bytes 4..6)            |   (Byte 7)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|            Domain Tag "TKM3" [0x54, 0x4B, 0x4D, 0x33]         |
|                      (Bytes 8..11: 4 Bytes)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 4. Binary Payload Layouts (30 Bytes Sealed Payload Slot)

#### A. ACK Payload (`PacketType.ack = 0x04`)
```text
+-----------------------+-----------------------+--------------------+------------------------+
| Bytes 0..3 (4 Bytes)  | Bytes 4..5 (2 Bytes)  | Byte 6 (1 Byte)    | Bytes 7..29 (23 Bytes) |
| Target Sequence Number| Target Initials       | Status (ACKStatus) | Reserved Zero-Padding  |
| (Big-Endian UInt32)   | (Base-27 Encoded)     | (0x01 = Delivered) | (Data(repeating: 0))   |
+-----------------------+-----------------------+--------------------+------------------------+
```

#### B. Chat Message Payload (`PacketType.chat = 0x02`)
```text
+-----------------------+-----------------------+-------------------+--------------------+------------------------+
| Bytes 0..1 (2 Bytes)  | Bytes 2..3 (2 Bytes)  | Byte 4 (1 Byte)   | Bytes 5..24 (20 B) | Bytes 25..29 (5 Bytes) |
| Sender Initials       | Target Initials       | UTF-8 Byte Length | Clamped UTF-8 Text | Reserved Zero-Padding  |
| (Base-27 Encoded)     | ("ALL" = Broadcast)   | (0..20 Bytes)     | (Backwards Trimmed)| (Data(repeating: 0))   |
+-----------------------+-----------------------+-------------------+--------------------+------------------------+
```

#### C. Location Ping Payload (`PacketType.locationPing = 0x01`)
```text
+--------------------+--------------------+--------------------+-----------------+-----------------+-----------------+--------------------+-----------------+------------------------+
| Bytes 0..3 (4 B)   | Bytes 4..7 (4 B)   | Bytes 8..11 (4 B)  | Byte 12 (1 B)   | Byte 13 (1 B)   | Byte 14 (1 B)   | Bytes 15..16 (2 B) | Byte 17 (1 B)   | Bytes 18..29 (12 B)    |
| Quantized Latitude | Quantized Longitude| Timestamp (Epoch)  | Accuracy (Meter)| Battery (%)     | Heading (0..255)| Sender Initials    | Color Code      | Reserved Zero-Padding  |
| (Int32 * 10,000,000| (Int32 * 10,000,000| (Big-Endian UInt32)| (UInt8 Clamped) | (0..100)        | (Degrees *256/36| (Base-27 Encoded)  | (MemberColor)   | (Data(repeating: 0))   |
+--------------------+--------------------+--------------------+-----------------+-----------------+-----------------+--------------------+-----------------+------------------------+
```

#### D. Meeting Update Payload (`PacketType.meetingUpdate = 0x07`)
```text
+--------------------+--------------------+--------------------+-----------------+--------------------+-----------------+--------------------+-----------------+------------------+
| Bytes 0..3 (4 B)   | Bytes 4..7 (4 B)   | Bytes 8..11 (4 B)  | Byte 12 (1 B)   | Bytes 13..24 (12 B)| Byte 25 (1 B)   | Bytes 26..27 (2 B) | Byte 28 (1 B)   | Byte 29 (1 B)    |
| Quantized Latitude | Quantized Longitude| Target Time (Epoch)| Name Length (012| UTF-8 Meeting Name | Action (Opcode) | Proposer Initials  | Target Member   | Reserved Padding |
| (Int32 * 10,000,000| (Int32 * 10,000,000| (Big-Endian UInt32)| (UInt8)         | (Zero-Padded 12B)  | (MeetingAction) | (Base-27 Encoded)  | (Member Slot)   | (0x00)           |
+--------------------+--------------------+--------------------+-----------------+--------------------+-----------------+--------------------+-----------------+------------------+
```

#### E. Route Request (`0x05`) & Route Response (`0x06`) Payloads
```text
+-----------------------+-----------------------+-----------------------+-------------------+------------------------+
| Bytes 0..1 (2 Bytes)  | Bytes 2..3 (2 Bytes)  | Bytes 4..7 (4 Bytes)  | Byte 8 (1 Byte)   | Bytes 9..29 (21 Bytes) |
| Originator Initials   | Target Initials       | Discovery Nonce       | Route Cost        | Reserved Zero-Padding  |
| (Base-27 Encoded)     | (Base-27 Encoded)     | (Big-Endian UInt32)   | (Hop Accumulator) | (Data(repeating: 0))   |
+-----------------------+-----------------------+-----------------------+-------------------+------------------------+
```

#### F. Emergency SOS Payload (`PacketType.sos = 0x03`)
```text
+--------------------+--------------------+--------------------+------------------+------------------+--------------------+--------------------+------------------+------------------+------------------+-----------------------+
| Bytes 0..3 (4 B)   | Bytes 4..7 (4 B)   | Bytes 8..11 (4 B)  | Byte 12 (1 B)    | Byte 13 (1 B)    | Bytes 14..17 (4 B) | Bytes 18..19 (2 B) | Byte 20 (1 B)    | Byte 21 (1 B)    | Byte 22 (1 B)    | Bytes 23..29 (7 B)    |
| Quantized Latitude | Quantized Longitude| Timestamp (Epoch)  | Accuracy (Meters)| Urgent Marker    | SOS Event ID       | Sender Initials    | Emergency Type   | Battery Level    | Color Code       | Reserved Zero-Padding |
| (Int32 * 10,000,000| (Int32 * 10,000,000| (Big-Endian UInt32)| (UInt8)          | (0x01 Fixed)     | (Big-Endian UInt32)| (Base-27 Encoded)  | (SOSType Opcode) | (0..100 Clamped) | (MemberColor)    | (Data(repeating: 0))  |
+--------------------+--------------------+--------------------+------------------+------------------+--------------------+--------------------+------------------+------------------+------------------+-----------------------+
```

#### G. SOS Resolved Payload (`PacketType.sosResolved = 0x08`)
```text
+-----------------------+-----------------------+------------------------+
| Bytes 0..3 (4 Bytes)  | Bytes 4..5 (2 Bytes)  | Bytes 6..29 (24 Bytes) |
| SOS Event ID          | Sender Initials       | Reserved Zero-Padding  |
| (Big-Endian UInt32)   | (Base-27 Encoded)     | (Data(repeating: 0))   |
+-----------------------+-----------------------+------------------------+
```

---
## 1. Teekum/Teekum/Core/Configuration/MeepoConfiguration.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [MeepoConfiguration.swift](../../Teekum/Teekum/Core/Configuration/MeepoConfiguration.swift) |
| **Line Count (`wc -l`)** | 199 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type enum (`nonisolated public enum MeepoConfiguration`) |
| **Concurrency Domain** | `nonisolated` namespace enum; completely free of actor isolation and thread-safe across all domains. |
| **Architectural Role** | Master configuration repository unifying network thresholds, hop limits, retry backoffs, battery cutoffs, and UI timings. |

### What This File Does
`MeepoConfiguration.swift` functions as the single source of truth for all architectural constants, wire protocol constraints, cadence intervals, network thresholds, hop limits, retry backoffs, and battery cutoff gates across the entire application. It groups these operational knobs into discrete static namespaces (`Network`, `Timing`, `Chat`, `SOS`, `Rendezvous`, `Battery`, `Navigation`), ensuring that critical system parameters (such as the strictly fixed 56-byte wire datagram or the 20% battery survival threshold) are tuned centrally without code divergence across modules.

### ELI5 Analogy
Think of `MeepoConfiguration.swift` as the master rulebook and control dial dashboard for an off-grid expedition radio network. Instead of letting every radio operator guess how long a transmission can be, how many hops a distress call can travel, or when to switch into emergency power-saving mode, the chief engineer writes all the immutable rules into a single laminated handbook that every device and radio component checks before sending a single byte into the air.

### Technical Terms Defined
- **Uninhabited Enum Namespace:** A Swift enum with zero cases (`enum MeepoConfiguration {}`) used strictly as a namespace for static constants and functions. Because it has no cases, it can never be allocated or instantiated as a runtime object (`MeepoConfiguration()`), preventing memory overhead and state leakage.
- **`nonisolated`:** A Swift Concurrency keyword explicitly detaching an entity from any actor isolation context. Marking configuration constants as `nonisolated` ensures they can be read synchronously and without `await` from background worker threads, UI view bodies, and isolated actors.
- **Wire Datagram Invariant:** A fixed-length protocol constraint requiring every transmitted radio frame to measure exactly 56 bytes. This prevents packet fragmentation over lossy Bluetooth Low Energy (BLE) channels and eliminates memory re-allocation on resource-constrained embedded radios.
- **Authenticated Encryption with Associated Data (AEAD) Nonce:** A 12-byte (96-bit) single-use number used in cryptographic ciphers (ChaCha20-Poly1305) to ensure that identical plaintexts encrypted under the same key yield distinct ciphertexts.
- **Token Bucket Rate Limiting:** A network traffic management algorithm where tokens are accumulated at a steady rate up to a burst capacity. Forwarding a packet consumes a token; if no tokens remain, the packet is throttled or dropped to prevent mesh broadcast storms.
- **AODV (Ad-hoc On-Demand Distance Vector):** A reactive mesh routing protocol where paths between nodes are discovered only when requested by an active traffic flow (via Route Request `RREQ` and Route Reply `RREP` datagrams).

### Code-Block and Line-by-Line Walkthrough
#### Block 1: Header and Network Protocol Parameters (Lines 1–49)
```swift
// Line 1-49
//
//  MeepoConfiguration.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

/// Centralized Master Configuration Repository for Google Antigravity / TeeKum disaster zone Mesh.
///
/// Every configurable knob, cadences, network thresholds, hop limits, battery cutoffs,
/// retry parameters, and UI timings are unified in this single file for rapid testing and field tuning.
nonisolated public enum MeepoConfiguration {
    
    // MARK: - 1. Wire Protocol & Network Topology Parameters
    public enum Network {
        /// Strictly fixed 56-byte wire datagram format (invariant across all packet types).
        public static let wirePacketSize: Int = 56
        
        /// Size of cleartext envelope for routing inspection (10 bytes).
        public static let cleartextEnvelopeSize: Int = 10
        
        /// Size of encrypted ChaCha20 / Poly1305 payload (30 bytes).
        public static let encryptedPayloadSize: Int = 30
        
        /// Size of Poly1305 authentication tag (16 bytes).
        public static let authTagSize: Int = 16
        
        /// Size of cryptographic AEAD nonce (12 bytes).
        public static let nonceSize: Int = 12
        
        /// Protocol version (0x01 for Protocol Version 1).
        public static let protocolVersion: UInt8 = 0x01
        
        /// 4-byte domain separation tag used in AEAD nonce construction: 'T', 'K', 'M', '3'.
        public static let protocolDomainTag: [UInt8] = [0x54, 0x4B, 0x4D, 0x33]

        /// Bitmask for canonical 24-bit Session ID values (`0x000000...0xFFFFFF`).
        public static let sessionIdMask: UInt32 = 0x00FFFFFF

        /// Maximum allowable 24-bit Session ID (`0x00FFFFFF` = 16,777,215).
        public static let maxSessionId: UInt32 = 0x00FFFFFF
        
        /// Hard architectural maximum allowable hop limit across the entire mesh (1...15).
        public static let maxHopLimit: UInt8 = 15
        
        /// Hop limit for standard periodic Location Ping packets (Type 0x01) (default: 8).
        public static let defaultHopLimit: UInt8 = 8
        
        /// Dedicated hop limit budget for Chat Messages (Type 0x07) and Delivery ACKs (Type 0x06).
        /// Tuneable independently to control text propagation radius and conserve disaster zone airtime (default: 8).
        public static let chatHopLimit: UInt8 = 8
        
        /// High-reach hop limit for Group Rendezvous / Meeting Point updates (Type 0x03) (default: 15).
        public static let meetingPointHopLimit: UInt8 = 15
        
        /// Maximum-priority hop limit for Emergency SOS siren alerts (Type 0x02) (default: 15).
        public static let sosHopLimit: UInt8 = 15
    }
```
- **Line 1–11:** Header comments and `import Foundation`. Declares `nonisolated public enum MeepoConfiguration`.
- **Line 15–18:** `wirePacketSize = 56` enforces the hard architectural invariant that every physical wire packet is exactly 56 bytes.
- **Line 20–22:** `cleartextEnvelopeSize = 10` defines the 10-byte unencrypted header (Bytes 0..9) read by intermediate mesh relays.
- **Line 24–26:** `encryptedPayloadSize = 30` defines the 30-byte ChaCha20 ciphertext block (Bytes 10..39).
- **Line 28–30:** `authTagSize = 16` defines the 16-byte Poly1305 MAC tag (Bytes 40..55). Note that $10 + 30 + 16 = 56$ bytes.
- **Line 32–34:** `nonceSize = 12` defines the 12-byte AEAD nonce required by ChaChaPoly.
- **Line 36–37:** `protocolVersion = 0x01` identifies Protocol Version 1 in the upper nibble of Byte 0.
- **Line 39–40:** `protocolDomainTag = [0x54, 0x4B, 0x4D, 0x33]` defines ASCII `'T'`, `'K'`, `'M'`, `'3'` appended to the nonce for domain separation.
- **Line 42–46:** `sessionIdMask = 0x00FFFFFF` and `maxSessionId = 0x00FFFFFF` enforce the 24-bit boundary on group identifiers.
- **Line 48–56:** Hop limits: `maxHopLimit = 15` (4-bit maximum), `defaultHopLimit = 8` (location pings), `chatHopLimit = 8` (chat and ACKs), `meetingPointHopLimit = 15` (wide reach rendezvous), and `sosHopLimit = 15` (maximum reach emergency alerts).

#### Block 2: Mesh Cadences & Timing Parameters (Lines 51–118)
```swift
// Line 51-118
    // MARK: - 2. Broadcast Cadence & Mesh Timing Parameters
    public enum Timing {
        /// Location publishing interval when actively moving with strong nearby peers (default: 4.0s).
        public static let locationMovingInterval: TimeInterval = 4.0
        
        /// Location publishing interval when stationary with nearby peers (default: 20.0s).
        public static let locationStationaryInterval: TimeInterval = 20.0
        
        /// Accelerated publishing interval when links degrade or peers become distant (default: 2.0s).
        public static let distantPeerInterval: TimeInterval = 2.0
        
        /// Throttled publishing interval in disaster zone Survival Mode (<20% battery) (default: 60.0s).
        public static let survivalInterval: TimeInterval = 60.0
        
        /// RSSI threshold (dBm) below which a link is deemed weak/distant (default: -75 dBm).
        public static let distantRSSIThreshold: Int8 = -75
        
        /// GPS distance threshold (meters) beyond which a peer is treated as distant (default: 30.0m).
        public static let distantDistanceThresholdMeters: Double = 30.0
        
        /// Elapsed seconds of inactivity before a member is marked Stale (default: 30.0s).
        public static let stalePeerThreshold: TimeInterval = 30.0
        
        /// Elapsed seconds of inactivity before a member is marked Offline (default: 180.0s).
        public static let offlinePeerThreshold: TimeInterval = 180.0
        
        /// Direct neighbor heartbeat cadence (default: 2.0s).
        public static let neighborHeartbeatInterval: TimeInterval = 2.0
        
        /// Timeout to prune dead direct neighbor connections (default: 6.0s).
        public static let neighborPruneThreshold: TimeInterval = 6.0
        
        /// AODV routing table entry validity time-to-live (default: 30.0s).
        public static let routingTableTTL: TimeInterval = 30.0
        
        /// Minimum interval between route requests (RREQ) to prevent mesh flooding (default: 10.0s).
        public static let rreqRateLimitInterval: TimeInterval = 10.0
        
        /// Timeout waiting for Route Response (RREP) before retrying (default: 1.5s).
        public static let rreqRetryTimeout: TimeInterval = 1.5
        
        /// Maximum route discovery retries (default: 2).
        public static let rreqMaxRetries: Int = 2
        
        /// Maximum ordinary packet relay forwarding rate (packets/second, default: 2.0).
        public static let ordinaryRelayRateLimit: Double = 8.0
        
        /// Burst token bucket capacity for ordinary packet relaying (default: 4.0).
        public static let ordinaryRelayBurstCapacity: Double = 4.0
        
        /// Urgent SOS packet forwarding rate (packets/second, default: 4.0).
        public static let urgentSOSRateLimit: Double = 4.0
        
        /// Maximum entries preserved in the LRU duplicate suppression cache (default: 1024).
        public static let seenPacketCacheCapacity: Int = 1024
        
        /// Priority outbox queue buffer capacity (default: 64 packets).
        public static let outboxQueueCapacity: Int = 64
        
        /// Maximum retry attempts for outbox transmissions (default: 2 retries = 3 total attempts).
        public static let outboxMaxRetries: Int = 2
        
        /// Initial backoff delay for outbox retries (default: 0.25s).
        public static let outboxBackoffInitialDelay: TimeInterval = 0.25
        
        /// Multiplier for exponential backoff between retries (default: 2.0).
        public static let outboxBackoffMultiplier: Double = 2.0
    }
```
- **Line 53–66:** Dynamic location publishing intervals: moving (`4.0s`), stationary (`20.0s`), degraded/distant links (`2.0s`), and survival mode (`60.0s`).
- **Line 68–73:** Peer degradation boundaries: RSSI threshold `<= -75 dBm` or spatial distance `>= 30.0m` triggers accelerated publishing.
- **Line 75–79:** Presence thresholds: inactive after `30.0s` marks a peer stale; inactive after `180.0s` marks a peer offline.
- **Line 81–85:** Neighbor health: direct heartbeats every `2.0s`; peer pruned as dead after `6.0s` without heartbeats.
- **Line 87–98:** Routing and AODV discovery: route entry TTL is `30.0s`; rate limit between RREQ discovery is `10.0s`; RREP response timeout is `1.5s` with `2` retries.
- **Line 100–108:** Token bucket forwarding: ordinary traffic rate is `8.0` packets/sec with burst capacity `4.0`; emergency SOS rate is `4.0` packets/sec; deduplication cache capacity is `1024` entries.
- **Line 110–118:** Priority outbox queue: buffer holds up to `64` packets, retrying up to `2` times with initial backoff `0.25s` and multiplier `2.0x`.

#### Block 3: Chat, SOS, Rendezvous, Battery & Navigation Parameters (Lines 120–199)
```swift
// Line 120-199
    // MARK: - 3. Chat Messaging Parameters
    public enum Chat {
        public static let carryFastRetryInterval: TimeInterval = 2.0
        public static let carryFastAttemptLimit: Int = 3
        public static let carrySlowRetryInterval: TimeInterval = 30.0
        /// Maximum chat messages held strictly in ephemeral RAM (purged on exit) (default: 50).
        public static let maxHistory: Int = 50
        
        /// Anti-spam client-side cooldown interval between outgoing messages (default: 3.0s).
        public static let cooldownDuration: TimeInterval = 3.0
        
        /// ACK confirmation timeout window before marking a recipient as timed out (default: 15.0s).
        public static let deliveryTimeout: TimeInterval = 15.0
        
        /// Maximum automated retries for unacknowledged messages (default: 2 retries = 3 attempts).
        public static let maxRetries: Int = 2
        
        /// Initial backoff delay for chat message retries (default: 0.5s).
        public static let backoffInitialDelay: TimeInterval = 0.5
        
        /// Multiplier for exponential backoff on unacknowledged chat retries (default: 1.5).
        public static let backoffMultiplier: Double = 1.5
        
        /// Maximum UTF-8 byte boundary for chat text (strictly 20 bytes).
        public static let maxPayloadBytes: Int = 20
    }
    
    // MARK: - 4. Emergency SOS Parameters
    public enum SOS {
        /// Inactivity stillness duration before triggering pre-alarm warning countdown (default: 180.0s = 3 minutes).
        public static let inactivityStillnessDuration: TimeInterval = 180.0
        
        /// Pre-alarm silent haptic warning countdown duration before broadcasting auto-SOS (default: 30.0s).
        public static let inactivityWarningCountdown: TimeInterval = 30.0
        
        /// Acceleration variance threshold (in g) above which device is considered in physical motion (default: 0.15g).
        public static let inactivityMotionThreshold: Double = 0.15
    }
    
    // MARK: - 5. Group Rendezvous / Meeting Point Parameters
    public enum Rendezvous {
        /// Proximity radius in meters for automatic arrival detection (default: 25.0m).
        public static let defaultArrivalRadiusMeters: Double = 25.0
        
        /// Duration past scheduled meetup time before rendezvous auto-clears (default: 3600.0s = 1 hour).
        public static let autoExpirationSeconds: TimeInterval = 3600.0
        
        /// 1-tap quick preset offsets in minutes.
        public static let presetMinutes: [Int] = [0, 15, 30, 60]
    }
    
    // MARK: - 6. Battery & Survival Mode Parameters
    public enum Battery {
        /// Battery percentage threshold triggering disaster zone Survival Mode (default: 20%).
        public static let survivalThresholdPercent: UInt8 = 20
        
        /// Default duration for Lock Screen Timed Relay mode (default: 1800s = 30 minutes).
        public static let timedRelayDefaultDuration: TimeInterval = 1800.0
    }
    
    // MARK: - 7. Tactical Radar & Directional Navigation Parameters
    public enum Navigation {
        /// Outer polar boundary radius rendered on Tactical Radar (default: 60.0m).
        public static let tacticalRadarRangeMeters: Double = 60.0
        
        /// Field of view angle for attendee heading vision cones on map (default: 50.0 degrees).
        public static let visionConeFOV: Double = 50.0
    }
}
```
- **Line 122–143:** `Chat` parameters: ephemeral RAM history limited to `50` messages; client cooldown is `3.0s`; delivery timeout is `15.0s`; automated retries are `2` with initial delay `0.5s` and multiplier `1.5x`; text capacity strictly clamped to `20` UTF-8 bytes.
- **Line 146–155:** `SOS` parameters: Inactivity stillness threshold is `180.0s` (3 min); pre-alarm warning countdown is `30.0s`; CoreMotion accelerometer variance threshold is `0.15g`.
- **Line 158–168:** `Rendezvous` parameters: arrival proximity radius is `25.0m`; automatic expiration is `3600.0s` (1 hour past target time); quick time presets are `[0, 15, 30, 60]` minutes.
- **Line 171–178:** `Battery` parameters: disaster zone Survival Mode trips at `<= 20%` battery; lock screen timed relay duration defaults to `1800.0s` (30 min).
- **Line 181–188:** `Navigation` parameters: Tactical Radar maximum polar range is `60.0m`; map heading vision cone field of view is `50.0` degrees.

### Engineering Rationale and Edge Cases
- **Strictly Fixed 56-Byte Datagram:** Variable-length packets over Bluetooth Low Energy incur MTU renegotiation latency, unpredictable fragmentation overhead, and heap memory fragmentation on embedded microcontrollers. Enforcing an invariant 56-byte buffer guarantees deterministic radio scheduling and static memory allocation.
- **The 20% Battery Cutoff Gate:** When rescue workers and survivors drop below 20% battery, their phone is at risk of shutting down before the event ends. Tripping Survival Mode at 20% preserves the device's remaining charge strictly for high-priority emergency SOS beacons, shutting down stranger relay forwarding.

---

---

## 2. Teekum/Teekum/Core/Packets/PacketConstants.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [PacketConstants.swift](../../Teekum/Teekum/Core/Packets/PacketConstants.swift) |
| **Line Count (`wc -l`)** | 67 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type enum (`public enum PacketConstants`) |
| **Concurrency Domain** | Unrestricted value namespace; thread-safe across all actors. |
| **Architectural Role** | Network wire invariants defining strictly fixed 56-byte datagram, 10-byte envelope, 24-bit session ID masks, and domain tags. |

### What This File Does
`PacketConstants.swift` provides a clean protocol-level interface to the underlying configuration constants defined in `MeepoConfiguration`. It exposes computed accessors for packet sizing, protocol version bytes, hop limits, and domain tags. It also encapsulates canonical validation and big-endian wire serialization algorithms for the 24-bit Session Identifier (`sessionId`), ensuring uniform 3-byte wire encoding across all packet handlers.

### ELI5 Analogy
If `MeepoConfiguration` is the master dial control room, `PacketConstants.swift` is the standardized measuring gauge and wire stencil used by the technicians assembling packets. When a technician builds a packet envelope, they use this gauge to make sure the envelope is exactly 10 bytes, the payload is 30 bytes, the security stamp is 16 bytes, and the group identification number is stamped as a clean 3-byte hexadecimal code.

### Technical Terms Defined
- **24-Bit Session ID (`sessionId`):** A 3-byte network identifier identifying the group session on the wire (`0x000001` to `0xFFFFFF`, representing up to 16,777,215 unique disaster zone networks).
- **Big-Endian Encoding:** An architectural byte-ordering convention where the most significant byte (MSB) of a multi-byte word is placed at the lowest memory address (first byte on the wire).
- **Bitwise Masking (`&`):** Applying a bitmask (`sessionId & 0x00FFFFFF`) to zero out unwanted high bits, ensuring that a 32-bit integer variable strictly conforms to a 24-bit domain.
- **Hexadecimal String Formatting:** Converting a raw integer into a formatted ASCII string (`String(format: "%06X", ...)`) yielding exactly 6 uppercase hexadecimal characters (e.g. `0x7E3AF5` -> `"7E3AF5"`).

### Code-Block and Line-by-Line Walkthrough
#### Block 1: Wire Sizing & Protocol Knobs (Lines 1–40)
```swift
// Line 1-40
//
//  PacketConstants.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

nonisolated public enum PacketConstants {
    public static var wirePacketSize: Int { MeepoConfiguration.Network.wirePacketSize }
    public static var cleartextEnvelopeSize: Int { MeepoConfiguration.Network.cleartextEnvelopeSize }
    public static var encryptedPayloadSize: Int { MeepoConfiguration.Network.encryptedPayloadSize }
    public static var authTagSize: Int { MeepoConfiguration.Network.authTagSize }
    public static var nonceSize: Int { MeepoConfiguration.Network.nonceSize }
    
    public static var protocolVersion: UInt8 { MeepoConfiguration.Network.protocolVersion }
    public static var defaultHopLimit: UInt8 {
        get { MeepoConfiguration.Network.defaultHopLimit }
    }
    public static var chatHopLimit: UInt8 {
        get { MeepoConfiguration.Network.chatHopLimit }
    }
    public static var maxHopLimit: UInt8 {
        get { MeepoConfiguration.Network.maxHopLimit }
    }
    public static var meetingPointHopLimit: UInt8 {
        get { MeepoConfiguration.Network.meetingPointHopLimit }
    }
    public static var sosHopLimit: UInt8 {
        get { MeepoConfiguration.Network.sosHopLimit }
    }
    
    /// Validates whether a given data buffer size matches the strictly fixed 56-byte wire format.
    public static func isValidWirePacketSize(_ count: Int) -> Bool {
        count == wirePacketSize
    }
    
    /// 4-byte protocol domain tag used in nonce construction: 'T', 'K', 'M', '3'
    public static var protocolDomainTag: [UInt8] { MeepoConfiguration.Network.protocolDomainTag }
```
- **Line 1–10:** Imports Foundation and declares `nonisolated public enum PacketConstants`.
- **Line 11–15:** Computed properties delegating to `MeepoConfiguration.Network`: `wirePacketSize` (56), `cleartextEnvelopeSize` (10), `encryptedPayloadSize` (30), `authTagSize` (16), and `nonceSize` (12).
- **Line 17–33:** Hop limit accessors: `protocolVersion` (`0x01`), `defaultHopLimit` (8), `chatHopLimit` (8), `maxHopLimit` (15), `meetingPointHopLimit` (15), and `sosHopLimit` (15).
- **Line 35–37:** `isValidWirePacketSize(_ count: Int)` validates whether incoming byte buffers equal exactly 56 bytes.
- **Line 39–40:** Exposes `protocolDomainTag` (`[0x54, 0x4B, 0x4D, 0x33]`).

#### Block 2: 24-Bit Session ID Management & Serialization (Lines 42–67)
```swift
// Line 42-67
    /// Canonical 24-bit Session ID bitmask (`0x00FFFFFF`).
    public static var sessionIdMask: UInt32 { MeepoConfiguration.Network.sessionIdMask }

    /// Maximum valid 24-bit Session ID (`0x00FFFFFF`).
    public static var maxSessionId: UInt32 { MeepoConfiguration.Network.maxSessionId }

    /// Validates whether a Session ID falls within the non-zero 24-bit range (`0x000001...0xFFFFFF`).
    public static func isValidSessionId(_ sessionId: UInt32) -> Bool {
        sessionId >= 1 && sessionId <= maxSessionId
    }

    /// Encodes a 24-bit Session ID into 3 big-endian wire bytes.
    public static func encodeSessionId24(_ sessionId: UInt32) -> [UInt8] {
        let sid = sessionId & sessionIdMask
        return [
            UInt8((sid >> 16) & 0xFF),
            UInt8((sid >> 8) & 0xFF),
            UInt8(sid & 0xFF)
        ]
    }

    /// Formats a 24-bit Session ID canonically as 6 uppercase hexadecimal characters.
    public static func formatSessionId(_ sessionId: UInt32) -> String {
        String(format: "%06X", sessionId & sessionIdMask)
    }
}
```
- **Line 42–46:** Exposes `sessionIdMask` (`0x00FFFFFF`) and `maxSessionId` (16,777,215).
- **Line 48–51:** `isValidSessionId` verifies that a session ID is non-zero and does not exceed $2^{24}-1$.
- **Line 53–61:** `encodeSessionId24` masks the integer, then extracts 3 big-endian bytes:
  - Byte 0: `(sid >> 16) & 0xFF` (bits 16..23)
  - Byte 1: `(sid >> 8) & 0xFF` (bits 8..15)
  - Byte 2: `sid & 0xFF` (bits 0..7)
- **Line 63–66:** `formatSessionId` produces a 6-character uppercase hex string (`"%06X"`).

### Engineering Rationale and Edge Cases
- **Why 24-Bit Session IDs:** Using 3 bytes for session IDs saves 1 byte per frame compared to standard 32-bit integers, while providing over 16.7 million distinct session channels—more than enough to eliminate collision risk across simultaneous disaster zone groups.
- **Bitmasking Before Formatting:** Always applying `sessionId & sessionIdMask` prevents erroneous display of high-order bits if an unmasked 32-bit integer was passed into the formatter.

---

---

## 3. Teekum/Teekum/Core/Packets/CleartextEnvelope.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [CleartextEnvelope.swift](../../Teekum/Teekum/Core/Packets/CleartextEnvelope.swift) |
| **Line Count (`wc -l`)** | 178 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct CleartextEnvelope: Equatable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type; safe for transfer across concurrency domains. |
| **Architectural Role** | 10-byte unencrypted wire header carrying protocol version, packet opcode, hop limits, session ID, and partitioned sequence number. |

### What This File Does
`CleartextEnvelope.swift` models and serializes the strictly fixed 10-byte unencrypted wire header (Bytes 0..9) carried at the front of every 56-byte datagram. It allows intermediate disaster zone mesh relays to inspect packet version, packet type, hop limits, session ID, and sequence numbers without possessing the group's cryptographic key. It partitions the 32-bit sequence number into an 8-bit member slot and 24-bit counter, constructs the 10-byte Associated Authenticated Data (AAD) with masked hop count for ChaCha20-Poly1305 verification, and builds the deterministic 12-byte AEAD nonce.

### ELI5 Analogy
Imagine sending a sealed, armored metal cash box through a chain of disaster zone volunteers. On the outside of the box is a clear plastic sleeve (`CleartextEnvelope`) holding a shipping slip. The slip shows the box's destination group number, its delivery hop countdown, and the sender's member slot. Any volunteer along the way can read the slip and increment the hop count without opening the armored lock. However, if any volunteer tampers with the destination number or sequence code, the armored lock (`Poly1305 AAD`) will permanently jam and refuse to open when it arrives.

### Technical Terms Defined
- **Cleartext Envelope:** The unencrypted leading portion of a wire packet that exposes metadata necessary for intermediate relay routing and duplicate suppression.
- **Associated Authenticated Data (AAD):** Additional data fed into an AEAD cipher (ChaCha20-Poly1305) that is integrity-checked and cryptographically bound to the ciphertext, but transmitted unencrypted.
- **AAD Hop Count Masking:** The technique of substituting `0x00` in place of the live `hopCount` byte when generating the cryptographic AAD. This permits intermediate nodes to increment `hopCount` on the wire without breaking the sender's 16-byte Poly1305 authentication tag.
- **Bit-Partitioning:** Dividing a single machine integer into multiple logical sub-fields. Here, a 32-bit integer (`UInt32`) is divided into an 8-bit `memberSlot` (upper 8 bits) and a 24-bit monotonic sequence counter (lower 24 bits).
- **Buffer Underflow:** An error condition occurring during deserialization when an input data stream contains fewer bytes than the required fixed structure size (here $< 10$ bytes).

### Code-Block and Line-by-Line Walkthrough
#### Block 1: Struct Declaration and Properties (Lines 1–48)
```swift
// Line 1-48
//
//  CleartextEnvelope.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct CleartextEnvelope: Equatable, Sendable {
    public var version: UInt8
    public var type: PacketType
    public var hopLimit: UInt8
    public var hopCount: UInt8
    /// Canonical 24-bit session identifier (`0x000000...0xFFFFFF`).
    public var sessionId: UInt32 {
        didSet { sessionId &= PacketConstants.sessionIdMask }
    }
    public var sequenceNumber: UInt32
    
    public var memberSlot: UInt8 {
        CleartextEnvelope.memberSlot(from: sequenceNumber)
    }
    
    public var counter: UInt32 {
        CleartextEnvelope.counter(from: sequenceNumber)
    }
    
    public init(
        version: UInt8 = PacketConstants.protocolVersion,
        type: PacketType,
        hopLimit: UInt8 = PacketConstants.defaultHopLimit,
        hopCount: UInt8 = 0,
        sessionId: UInt32,
        sequenceNumber: UInt32
    ) {
        self.version = version
        self.type = type
        self.hopLimit = min(max(1, hopLimit), PacketConstants.maxHopLimit)
        self.hopCount = min(hopCount, self.hopLimit)
        self.sessionId = sessionId & PacketConstants.sessionIdMask
        self.sequenceNumber = sequenceNumber
    }
```
- **Line 10:** Declares `public struct CleartextEnvelope: Equatable, Sendable`.
- **Line 11–17:** Stored properties: `version` (UInt8), `type` (PacketType), `hopLimit` (UInt8), `hopCount` (UInt8), `sessionId` (UInt32 masked to 24 bits on `didSet`), and `sequenceNumber` (UInt32).
- **Line 19–25:** Computed properties extracting partitioned fields from `sequenceNumber`: `memberSlot` and `counter`.
- **Line 27–47:** Initializer clamping `hopLimit` between 1 and 15 (`PacketConstants.maxHopLimit`), clamping `hopCount` to `hopLimit`, and masking `sessionId` with `sessionIdMask`.

#### Block 2: Sequence Number Partitioning & Wire Serialization (Lines 50–133)
```swift
// Line 50-133
    // MARK: - Sequence Number Partitioning
    
    public static func makeSequenceNumber(memberSlot: UInt8, counter: UInt32) -> UInt32 {
        (UInt32(memberSlot) << 24) | (counter & 0x00FFFFFF)
    }
    
    public static func memberSlot(from sequenceNumber: UInt32) -> UInt8 {
        UInt8((sequenceNumber >> 24) & 0xFF)
    }
    
    public static func counter(from sequenceNumber: UInt32) -> UInt32 {
        sequenceNumber & 0x00FFFFFF
    }

    private var versionAndTypeByte: UInt8 {
        ((version & 0x0F) << 4) | (type.rawValue & 0x0F)
    }

    private var sessionIdBytes: [UInt8] {
        PacketConstants.encodeSessionId24(sessionId)
    }
    
    // MARK: - Serialization (10 Bytes)
    
    public func serialize() -> Data {
        var data = Data(capacity: PacketConstants.cleartextEnvelopeSize)
        
        // Byte 0: version (high 4 bits) | type (low 4 bits)
        data.append(versionAndTypeByte)
        
        // Byte 1: hopLimit (UInt8)
        data.append(hopLimit)
        
        // Byte 2: hopCount (UInt8)
        data.append(hopCount)
        
        // Bytes 3..5: sessionId (3 bytes, 24-bit big-endian)
        data.append(contentsOf: sessionIdBytes)
        
        // Bytes 6..9: sequenceNumber (32-bit big-endian)
        var seqBE = sequenceNumber.bigEndian
        data.append(Data(bytes: &seqBE, count: 4))
        
        return data
    }
    
    public static func deserialize(from data: Data) throws -> CleartextEnvelope {
        guard data.count >= PacketConstants.cleartextEnvelopeSize else {
            throw PacketCodecError.bufferUnderflow
        }
        
        let byte0 = data[data.startIndex]
        let version = (byte0 >> 4) & 0x0F
        guard version == PacketConstants.protocolVersion else {
            throw PacketCodecError.unsupportedVersion(version)
        }
        
        let typeRaw = byte0 & 0x0F
        guard let type = PacketType(rawValue: typeRaw) else {
            throw PacketCodecError.unknownPacketType(typeRaw)
        }
        
        let hopLimit = data[data.startIndex + 1]
        guard hopLimit >= 1 else {
            throw PacketCodecError.invalidHopLimit(hopLimit)
        }
        
        let hopCount = data[data.startIndex + 2]
        guard hopCount <= hopLimit else {
            throw PacketCodecError.hopCountExceededLimit(count: hopCount, limit: hopLimit)
        }
        
        let b3 = UInt32(data[data.startIndex + 3])
        let b4 = UInt32(data[data.startIndex + 4])
        let b5 = UInt32(data[data.startIndex + 5])
        let sid24 = (b3 << 16) | (b4 << 8) | b5
        
        let seq = data.subdata(in: (data.startIndex + 6)..<(data.startIndex + 10)).withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self).bigEndian
        }
        
        return CleartextEnvelope(
            version: version,
            type: type,
            hopLimit: hopLimit,
            hopCount: hopCount,
            sessionId: sid24,
            sequenceNumber: seq
        )
    }
```
- **Line 52–62:** Sequence partitioning helpers:
  - `makeSequenceNumber`: `(UInt32(memberSlot) << 24) | (counter & 0x00FFFFFF)`.
  - `memberSlot`: `UInt8((sequenceNumber >> 24) & 0xFF)` shifts down 24 bits.
  - `counter`: `sequenceNumber & 0x00FFFFFF` masks off the top 8 bits.
- **Line 64–70:** `versionAndTypeByte` packs the 4-bit version into the high nibble and 4-bit type into the low nibble: `((version & 0x0F) << 4) | (type.rawValue & 0x0F)`.
- **Line 74–94:** `serialize()` constructs exactly 10 bytes:
  - Byte 0: `versionAndTypeByte`
  - Byte 1: `hopLimit`
  - Byte 2: `hopCount`
  - Bytes 3..5: 3-byte big-endian `sessionId`
  - Bytes 6..9: 4-byte big-endian `sequenceNumber`
- **Line 96–133:** `deserialize(from:)` unpacks 10 bytes, verifying minimum size, validating protocol version against `0x01`, validating packet opcode against `PacketType`, enforcing `hopCount <= hopLimit`, reconstructing 24-bit `sessionId`, and loading 32-bit big-endian `sequenceNumber`.

#### Block 3: Cryptographic AAD and Nonce Construction (Lines 135–178)
```swift
// Line 135-178
    // MARK: - Cryptographic Inputs (10 Bytes AAD)
    
    public func authenticatedAssociatedData() -> Data {
        var aad = Data(capacity: PacketConstants.cleartextEnvelopeSize)
        
        // Byte 0: versionAndType
        aad.append(versionAndTypeByte)
        
        // Byte 1: hopLimit
        aad.append(hopLimit)
        
        // Byte 2: hopCount masked to 0x00
        aad.append(0x00)
        
        // Bytes 3..5: sessionId (3 bytes)
        aad.append(contentsOf: sessionIdBytes)
        
        // Bytes 6..9: sequenceNumber (4 bytes)
        var seqBE = sequenceNumber.bigEndian
        aad.append(Data(bytes: &seqBE, count: 4))
        
        return aad
    }
    
    /// Constructs the deterministic 12-byte (96-bit) AEAD Nonce:
    /// - Bytes 0..2: sessionId (3 bytes)
    /// - Bytes 3..6: sequenceNumber (4 bytes)
    /// - Byte 7: versionAndType (1 byte)
    /// - Bytes 8..11: Protocol Domain Tag "TKM3" ([0x54, 0x4B, 0x4D, 0x33])
    public func constructNonce() -> Data {
        var nonceData = Data(capacity: PacketConstants.nonceSize)
        
        nonceData.append(contentsOf: sessionIdBytes)
        
        var seqBE = sequenceNumber.bigEndian
        nonceData.append(Data(bytes: &seqBE, count: 4))
        
        nonceData.append(versionAndTypeByte)
        
        nonceData.append(contentsOf: PacketConstants.protocolDomainTag)
        return nonceData
    }
}
```
- **Line 137–156:** `authenticatedAssociatedData()` outputs the 10-byte AAD: Byte 0 (version/type), Byte 1 (hopLimit), **Byte 2 masked strictly to `0x00`**, Bytes 3..5 (sessionId), and Bytes 6..9 (sequenceNumber).
- **Line 158–177:** `constructNonce()` builds the deterministic 12-byte AEAD Nonce:
  - Bytes 0..2: 3-byte `sessionId`
  - Bytes 3..6: 4-byte `sequenceNumber` (big-endian)
  - Byte 7: 1-byte `versionAndType`
  - Bytes 8..11: 4-byte domain tag `[0x54, 0x4B, 0x4D, 0x33]` ("TKM3").

### Engineering Rationale and Edge Cases
- **Why Mask `hopCount` to `0x00` in AAD:** In multi-hop mesh forwarding, intermediate relay nodes must increment `hopCount` by 1 before broadcasting a packet to the next hop. If `hopCount` were included in the AAD verbatim, incrementing it would invalidate the sender's 16-byte Poly1305 MAC tag, causing recipient nodes to reject the packet as tampered. By masking Byte 2 to `0x00` during both sealing and opening, the hop count remains mutable on the wire while the remaining 9 bytes (version, type, hopLimit, session ID, sequence) remain strictly tamper-proof.
- **Member Slot Sequence Partitioning:** Allocating the upper 8 bits of `sequenceNumber` to `memberSlot` ensures that each group participant maintains an independent 24-bit sequence counter ($0$ to $16,777,215$). Even if two members transmit simultaneously, their full sequence numbers will never collide, guaranteeing unique AEAD nonces.

---

---

## 4. Teekum/Teekum/Core/Packets/RawWirePacket.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [RawWirePacket.swift](../../Teekum/Teekum/Core/Packets/RawWirePacket.swift) |
| **Line Count (`wc -l`)** | 54 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct RawWirePacket: Equatable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type; safe for cross-actor dispatch. |
| **Architectural Role** | Canonical 56-byte wire datagram container binding 10-byte CleartextEnvelope, 30-byte ciphertext, and 16-byte Poly1305 authentication tag. |

### What This File Does
`RawWirePacket.swift` represents the canonical 56-byte wire datagram that traverses the physical radio channel. It binds three contiguous components into a single immutable value type: the 10-byte unencrypted `CleartextEnvelope` (Bytes 0..9), the 30-byte encrypted ciphertext payload (Bytes 10..39), and the 16-byte Poly1305 authentication tag (Bytes 40..55). It provides bidirectional conversion between the structured packet and raw binary `Data`.

### ELI5 Analogy
Think of `RawWirePacket` as a standardized shipping container built for a specialized cargo train. The train will only accept containers that are exactly 56 centimeters long—no more, no less. The front 10 centimeters are the shipping label that anyone can read (`CleartextEnvelope`), the middle 30 centimeters are a locked steel safe holding the private letter (`ciphertext`), and the final 16 centimeters are a tamper-proof wax seal with an engraved crest (`authTag`).

### Technical Terms Defined
- **Wire Datagram:** A self-contained, independent entity of data carrying sufficient information to be routed from the source to the destination computer without reliance on earlier exchanges.
- **Poly1305 MAC Tag:** A 128-bit (16-byte) one-time cryptographic authenticator computed over the ciphertext and AAD using a one-time key derived from ChaCha20.
- **Buffer Slicing (`subdata`):** Extracting contiguous byte slices from a `Data` buffer without copying memory when possible.
- **Fixed-Buffer Invariant:** Enforcing that every valid protocol message maps to an identical byte size, preventing side-channel packet length analysis and buffer overruns.

### Code-Block and Line-by-Line Walkthrough
```swift
// Line 1-54
//
//  RawWirePacket.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct RawWirePacket: Equatable, Sendable {
    public var envelope: CleartextEnvelope
    public var ciphertext: Data // 30 bytes
    public var authTag: Data    // 16 bytes
    
    public init(envelope: CleartextEnvelope, ciphertext: Data, authTag: Data) {
        self.envelope = envelope
        self.ciphertext = ciphertext
        self.authTag = authTag
    }
    
    /// Combines envelope (10B), encrypted payload (30B), and auth tag (16B) into exactly 56 bytes.
    public func toWireData() throws -> Data {
        let envData = envelope.serialize()
        guard envData.count == PacketConstants.cleartextEnvelopeSize else {
            throw PacketCodecError.invalidPacketSize(expected: PacketConstants.cleartextEnvelopeSize, actual: envData.count)
        }
        guard ciphertext.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.invalidPacketSize(expected: PacketConstants.encryptedPayloadSize, actual: ciphertext.count)
        }
        guard authTag.count == PacketConstants.authTagSize else {
            throw PacketCodecError.invalidPacketSize(expected: PacketConstants.authTagSize, actual: authTag.count)
        }
        
        var packet = Data(capacity: PacketConstants.wirePacketSize)
        packet.append(envData)
        packet.append(ciphertext)
        packet.append(authTag)
        return packet
    }
    
    /// Parses a 56-byte binary datagram from the network.
    public static func fromWireData(_ data: Data) throws -> RawWirePacket {
        guard data.count == PacketConstants.wirePacketSize else {
            throw PacketCodecError.invalidPacketSize(expected: PacketConstants.wirePacketSize, actual: data.count)
        }
        
        let envData = data.subdata(in: 0..<10)
        let envelope = try CleartextEnvelope.deserialize(from: envData)
        let ciphertext = data.subdata(in: 10..<40)
        let authTag = data.subdata(in: 40..<56)
        
        return RawWirePacket(envelope: envelope, ciphertext: ciphertext, authTag: authTag)
    }
}
```
- **Line 1–8:** Header and Foundation import.
- **Line 10–13:** Declares `public struct RawWirePacket: Equatable, Sendable` with stored properties: `envelope` (CleartextEnvelope), `ciphertext` (30 bytes Data), and `authTag` (16 bytes Data).
- **Line 15–19:** Standard memberwise initializer.
- **Line 21–38:** `toWireData()`: serializes the envelope, performs strict length checks on each component (`envData.count == 10`, `ciphertext.count == 30`, `authTag.count == 16`), preallocates a 56-byte `Data` buffer, appends the three slices sequentially, and returns the concatenated buffer.
- **Line 40–53:** `fromWireData(_ data:)`: validates that `data.count == 56`. Slices Bytes 0..<10 for `CleartextEnvelope.deserialize`, Bytes 10..<40 for `ciphertext`, and Bytes 40..<56 for `authTag`, returning the assembled `RawWirePacket`.

### Engineering Rationale and Edge Cases
- **Strict Size Guards Against Memory Corruption:** If an encryption routine returned a 28-byte ciphertext or a 15-byte tag, transmitting it would corrupt byte alignment on receiver frames. Guarding all three segments individually in `toWireData()` guarantees that malformed packets fail locally before touching the radio.
- **Offset Boundary Slicing:** In `fromWireData`, offsets `0..<10`, `10..<40`, and `40..<56` are hardcoded to match protocol specification invariants.

---

---

## 5. Teekum/Teekum/Core/Packets/PacketType.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [PacketType.swift](../../Teekum/Teekum/Core/Packets/PacketType.swift) |
| **Line Count (`wc -l`)** | 19 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value enum (`public enum PacketType: UInt8, Sendable, CaseIterable`) |
| **Concurrency Domain** | `Sendable` primitive enum; thread-safe. |
| **Architectural Role** | Wire packet opcode enumeration defining the 8 active datagram types (0x01 through 0x08) and opcode serialization. |

### What This File Does
`PacketType.swift` defines the 8 active datagram opcodes recognized by the Meepo mesh networking stack. Each case is backed by an unsigned 8-bit integer (`UInt8`) occupying the lower 4 bits (low nibble) of Byte 0 in the wire envelope. It enables incoming packet dispatchers to classify traffic into location pings, emergency alerts, rendezvous updates, AODV routing requests, delivery acknowledgments, and chat messages.

### ELI5 Analogy
Think of `PacketType.swift` as the color-coded stamp catalog used by the disaster zone mail room. When an envelope arrives, the mail clerk looks at the bottom half of the first stamp to see what kind of letter it is: red for emergency SOS (`0x02`), blue for location coordinates (`0x01`), yellow for chat notes (`0x07`), or green for meeting points (`0x03`).

### Technical Terms Defined
- **Opcode (Operation Code):** An encoded numerical value that specifies the intended operation or message format in a binary network protocol.
- **Low Nibble:** The lower 4 bits of a single 8-bit byte (`byte & 0x0F`), capable of representing values from `0x0` to `0xF` (0 to 15).
- **`CaseIterable`:** A Swift standard library protocol that automatically synthesizes an `allCases` collection containing every case in the enumeration, facilitating comprehensive unit testing and validation loops.
- **`RawRepresentable`:** A Swift protocol that provides bidirectional conversion between a custom enum case and an underlying primitive value (here `UInt8`).

### Code-Block and Line-by-Line Walkthrough
```swift
// Line 1-19
//
//  PacketType.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum PacketType: UInt8, CaseIterable, Sendable {
    case locationPing  = 0x01
    case sos           = 0x02
    case meetingUpdate = 0x03
    case routeReq      = 0x04
    case routeResp     = 0x05
    case ack           = 0x06
    case chatMessage   = 0x07
    case sosResolved   = 0x08
}
```
- **Line 1–8:** Header comments and Foundation import.
- **Line 10:** Declares `public enum PacketType: UInt8, CaseIterable, Sendable`.
- **Line 11:** `case locationPing = 0x01`: Periodic GPS coordinates, battery level, velocity, and sender initials.
- **Line 12:** `case sos = 0x02`: High-priority distress beacon broadcasting emergency coordinates and siren triggers.
- **Line 13:** `case meetingUpdate = 0x03`: Group rendezvous location, epoch target time, and attendance status.
- **Line 14:** `case routeReq = 0x04`: AODV reactive route request datagram seeking a multi-hop path to a destination.
- **Line 15:** `case routeResp = 0x05`: AODV reactive route reply datagram establishing reverse paths.
- **Line 16:** `case ack = 0x06`: End-to-end delivery confirmation acknowledging received chat or distress frames.
- **Line 17:** `case chatMessage = 0x07`: Ephemeral 20-byte text message payload.
- **Line 18:** `case sosResolved = 0x08`: Emergency cancellation broadcasting that an active distress state has concluded.
- **Line 19:** Closes enumeration.

### Engineering Rationale and Edge Cases
- **4-Bit Nibble Allocation:** Because Byte 0 in `CleartextEnvelope` allocates the upper 4 bits to protocol version and the lower 4 bits to packet type, opcodes are strictly constrained to `0x01` through `0x0F`.
- **Reserved Opcodes:** Opcodes `0x00` and `0x09` through `0x0F` are reserved. Any packet arriving with an opcode outside `0x01...0x08` causes `CleartextEnvelope.deserialize` to throw `PacketCodecError.unknownPacketType`.

---

---

## 6. Teekum/Teekum/Core/Packets/PacketCodecError.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [PacketCodecError.swift](../../Teekum/Teekum/Core/Packets/PacketCodecError.swift) |
| **Line Count (`wc -l`)** | 55 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value enum (`public enum PacketCodecError: Error, Equatable, Sendable`) |
| **Concurrency Domain** | `Sendable` error type; thread-safe error propagation. |
| **Architectural Role** | Serialization and deserialization error domain covering buffer underflow, invalid hop counts, and unknown packet opcodes. |

### What This File Does
`PacketCodecError.swift` defines the unified error domain for all packet serialization, deserialization, buffer underflow, and validation failures in the mesh networking stack. It provides typed, descriptive failure cases covering buffer sizing discrepancies, unsupported protocol versions, unknown opcodes, invalid hop counts, out-of-bounds GPS coordinates, malformed 3-letter initials, and UTF-8 encoding violations.

### ELI5 Analogy
Think of `PacketCodecError.swift` as the quality inspection stamp kit used by a factory inspector. If an assembled radio packet is 1 byte too short, contains an upside-down address, or has an impossible GPS number, the inspector rejects the package and stamps it with an exact rejection reason so the technician knows exactly why it was tossed out.

### Technical Terms Defined
- **`LocalizedError`:** A Foundation protocol allowing custom error types to provide a user-friendly, localized description string via the `errorDescription` property.
- **Buffer Underflow:** An error triggered when an operation attempts to read more bytes from a buffer than are actually available, which would cause an out-of-bounds memory trap in unsafe C-style languages.
- **Equatable Error Domain:** Conforming to `Equatable` allows unit tests to assert exact expected error cases using `#expect(error == PacketCodecError.bufferUnderflow)` without string matching.
- **Associated Values:** Swift language feature allowing specific contextual metadata (e.g. expected vs. actual byte counts) to be bound directly to an enum case.

### Code-Block and Line-by-Line Walkthrough
```swift
// Line 1-55
//
//  PacketCodecError.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum PacketCodecError: Error, LocalizedError, Equatable {
    case invalidPacketSize(expected: Int, actual: Int)
    case unsupportedVersion(UInt8)
    case unknownPacketType(UInt8)
    case invalidHopLimit(UInt8)
    case hopCountExceededLimit(count: UInt8, limit: UInt8)
    case invalidCoordinateRange(latitude: Double, longitude: Double)
    case invalidBatteryLevel(UInt8)
    case payloadSerializationFailed
    case payloadDeserializationFailed
    case bufferUnderflow
    case invalidInitials(String)
    case invalidTextLength(Int)
    case invalidTextEncoding
    
    public var errorDescription: String? {
        switch self {
        case let .invalidPacketSize(expected, actual):
            return "Invalid packet size: expected \(expected) bytes, got \(actual) bytes."
        case let .unsupportedVersion(v):
            return "Unsupported protocol version: \(v)."
        case let .unknownPacketType(t):
            return "Unknown packet type identifier: \(t)."
        case let .invalidHopLimit(limit):
            return "Invalid hop limit \(limit): must be in range 1...15."
        case let .hopCountExceededLimit(count, limit):
            return "Hop count \(count) exceeded maximum hop limit \(limit)."
        case let .invalidCoordinateRange(lat, lon):
            return "Coordinate outside geographic boundaries: lat=\(lat), lon=\(lon)."
        case let .invalidBatteryLevel(b):
            return "Battery level \(b)% exceeds maximum valid range 0...100%."
        case .payloadSerializationFailed:
            return "Failed to serialize payload to exactly 30 bytes."
        case .payloadDeserializationFailed:
            return "Failed to deserialize 30-byte payload."
        case .bufferUnderflow:
            return "Buffer underflow while reading wire bytes."
        case let .invalidInitials(i):
            return "Invalid 3-letter initials: '\(i)'. Must be exactly 3 uppercase letters A-Z."
        case let .invalidTextLength(len):
            return "Invalid text length: \(len) bytes. Must be between 0 and 20 bytes."
        case .invalidTextEncoding:
            return "Invalid text encoding: string content is not valid UTF-8."
        }
    }
}
```
- **Line 10:** Declares `public enum PacketCodecError: Error, LocalizedError, Equatable`.
- **Line 11–23:** Enumerates 13 explicit error cases with associated diagnostic values:
  - `invalidPacketSize`: Sizing mismatch on buffers.
  - `unsupportedVersion`: Protocol version byte is not `0x01`.
  - `unknownPacketType`: Opcode is not in `0x01...0x08`.
  - `invalidHopLimit`: Hop limit `< 1` or `> 15`.
  - `hopCountExceededLimit`: Live hop count exceeds configured limit.
  - `invalidCoordinateRange`: Latitude outside `[-90, 90]` or longitude outside `[-180, 180]`.
  - `invalidBatteryLevel`: Battery level exceeds 100%.
  - `payloadSerializationFailed`: Payload does not pack into 30 bytes.
  - `payloadDeserializationFailed`: Payload bytes corrupted or unparseable.
  - `bufferUnderflow`: Data buffer shorter than required byte boundary.
  - `invalidInitials`: Participant initials not 3 uppercase A-Z characters.
  - `invalidTextLength`: Chat message exceeds 20 bytes.
  - `invalidTextEncoding`: Chat bytes not valid UTF-8.
- **Line 25–54:** `errorDescription` synthesizes plain-English diagnostic strings for every case.

### Engineering Rationale and Edge Cases
- **Exhaustive Deserialization Protection:** Radio data arriving over Bluetooth Low Energy is inherently untrusted. Without strict codec validation, an attacker could inject random byte streams that trigger integer overflow or memory crashes. Providing granular error cases ensures that malformed packets are dropped cleanly with diagnostic telemetry.

---

---

## 7. Teekum/Teekum/Core/Packets/ACKStatus.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [ACKStatus.swift](../../Teekum/Teekum/Core/Packets/ACKStatus.swift) |
| **Line Count (`wc -l`)** | 13 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value enum (`public enum ACKStatus: UInt8, Sendable`) |
| **Concurrency Domain** | `Sendable` primitive enum. |
| **Architectural Role** | Delivery acknowledgment status enumeration classifying confirmation outcomes (delivered, timedOut, failed). |

### What This File Does
`ACKStatus.swift` defines the operational delivery confirmation stages carried inside 30-byte `ACKPayload` structures. It distinguishes between an intermediate relay acknowledgment (confirming that an intermediate mesh hop forwarded the packet) and an end-to-end peer delivery acknowledgment (confirming that the destination friend's device received, decrypted, and displayed the message).

### ELI5 Analogy
Think of `ACKStatus` as the two checkmarks on a messaging app. One checkmark means your radio packet was picked up by a friendly volunteer relay station along the road (`relayedByMeshHop`). Two checkmarks mean the packet was physically delivered directly into your friend's hands (`deliveredToFriend`).

### Technical Terms Defined
- **Intermediate Hop ACK:** An acknowledgment returned by an intermediate node confirming that it has accepted custody of a packet and successfully forwarded it to the next hop.
- **End-to-End Recipient ACK:** A cryptographic confirmation originating strictly from the final destination node confirming complete message delivery.
- **`RawRepresentable` Opcode:** Backed by `UInt8`, mapping directly to 1 byte in the wire payload.

### Code-Block and Line-by-Line Walkthrough
```swift
// Line 1-13
//
//  ACKStatus.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum ACKStatus: UInt8, CaseIterable, Sendable {
    case deliveredToFriend = 0x01
    case relayedByMeshHop  = 0x02
}
```
- **Line 1–8:** Header comments and Foundation import.
- **Line 10:** Declares `public enum ACKStatus: UInt8, CaseIterable, Sendable`.
- **Line 11:** `case deliveredToFriend = 0x01`: End-to-end acknowledgment from the target recipient.
- **Line 12:** `case relayedByMeshHop = 0x02`: Intermediate relay acknowledgment confirming hop forwarding.
- **Line 13:** Closes enumeration.

### Engineering Rationale and Edge Cases
- **Why Separate Hop and Peer ACKs:** In an ad-hoc mesh network, knowing that a packet successfully hopped to a neighbor provides vital routing feedback (preventing unnecessary immediate retries), but must never be mistaken by the UI as proof that the recipient has read the message. Distinguishing `0x01` from `0x02` maintains complete delivery truth.

---

---

## 8. Teekum/Teekum/Core/Packets/Payloads/ACKPayload.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [ACKPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/ACKPayload.swift) |
| **Line Count (`wc -l`)** | 93 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct ACKPayload: Equatable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | 30-byte binary payload confirming message receipt with responder initials, sequence counter, and millisecond timestamp. |

### What This File Does
`ACKPayload.swift` defines the 30-byte binary payload for Type `0x06` (`ack`) packets. It carries delivery confirmations for chat messages, emergency alerts, and meeting point updates. The payload packs the acknowledged sequence number (4 bytes), sender initials (2 bytes), timestamp (4 bytes), ACK status (1 byte), received RSSI (1 byte), original event ID (4 bytes), responder initials (2 bytes), and 12 bytes of reserved zero-padding.

### ELI5 Analogy
Think of `ACKPayload` as a certified postal delivery receipt. When your friend receives your emergency alert or chat message, their phone fills out this little 30-byte receipt: "I (responder initials) received message number #X from you (sender initials) at time T with radio strength -68 dBm," signs it, and sends it back across the mesh so your phone knows the message arrived.

### Technical Terms Defined
- **Unix Epoch Timestamp:** Time measured as the number of elapsed seconds since January 1, 1970 UTC (`ackTimestamp.timeIntervalSince1970`). Stored here as a 32-bit unsigned big-endian integer.
- **Signed RSSI (`Int8`):** Received Signal Strength Indication represented as a signed 8-bit integer in dBm (e.g., `-75` dBm).
- **Reserved Zero-Padding:** Unused bytes at the end of a payload padded strictly with zeroes (`0x00`) to guarantee that the payload measures exactly 30 bytes for ChaCha20 encryption.

### Code-Block and Line-by-Line Walkthrough
#### Block 1: Struct Declaration and Initializer (Lines 1–40)
```swift
// Line 1-40
//
//  ACKPayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct ACKPayload: Equatable, Sendable {
    public var ackedSeqNumber: UInt32
    public var ackedSenderInitials: String // 3 uppercase characters
    public var ackTimestamp: Date
    public var ackStatus: ACKStatus
    public var receivedRssi: Int8
    public var originalEventId: UInt32
    public var responderInitials: String   // 3 uppercase characters
    
    public init(
        ackedSeqNumber: UInt32,
        ackedSenderInitials: String,
        ackTimestamp: Date = Date(),
        ackStatus: ACKStatus,
        receivedRssi: Int8,
        originalEventId: UInt32,
        responderInitials: String
    ) {
        self.ackedSeqNumber = ackedSeqNumber
        self.ackedSenderInitials = InitialsCodec.sanitize(ackedSenderInitials)
        self.ackTimestamp = ackTimestamp
        self.ackStatus = ackStatus
        self.receivedRssi = receivedRssi
        self.originalEventId = originalEventId
        self.responderInitials = InitialsCodec.sanitize(responderInitials)
    }
```
- **Line 10:** Declares `public struct ACKPayload: Equatable, Sendable`.
- **Line 11–17:** Stored properties: `ackedSeqNumber` (UInt32), `ackedSenderInitials` (String), `ackTimestamp` (Date), `ackStatus` (ACKStatus), `receivedRssi` (Int8), `originalEventId` (UInt32), and `responderInitials` (String).
- **Line 19–39:** Initializer sanitizes initials through `InitialsCodec.sanitize` to enforce uppercase alphanumeric boundaries.

#### Block 2: Serialization and Deserialization (Lines 42–93)
```swift
// Line 42-93
    public func serialize() -> Data {
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        var seq = ackedSeqNumber.bigEndian
        data.append(Data(bytes: &seq, count: 4))
        
        let ackedBytes = InitialsCodec.encode(ackedSenderInitials) ?? [0, 0]
        data.append(contentsOf: ackedBytes)
        
        var ts = UInt32(ackTimestamp.timeIntervalSince1970).bigEndian
        data.append(Data(bytes: &ts, count: 4))
        
        data.append(ackStatus.rawValue)
        
        var rssi = receivedRssi
        data.append(Data(bytes: &rssi, count: 1))
        
        var eventId = originalEventId.bigEndian
        data.append(Data(bytes: &eventId, count: 4))
        
        let respBytes = InitialsCodec.encode(responderInitials) ?? [0, 0]
        data.append(contentsOf: respBytes)
        
        // 12 bytes reserved padding (30 - 18 = 12)
        data.append(Data(repeating: 0, count: 12))
        return data
    }
    
    public static func deserialize(from data: Data) throws -> ACKPayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        let seq = data.subdata(in: 0..<4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let ackedBytes = [data[4], data[5]]
        let ackedInitials = InitialsCodec.decode(ackedBytes) ?? "UNK"
        
        let tsRaw = data.subdata(in: 6..<10).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let statusByte = data[10]
        let rssi = Int8(bitPattern: data[11])
        let eventId = data.subdata(in: 12..<16).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        
        let respBytes = [data[16], data[17]]
        let respInitials = InitialsCodec.decode(respBytes) ?? "UNK"
        
        let date = Date(timeIntervalSince1970: TimeInterval(tsRaw))
        let status = ACKStatus(rawValue: statusByte) ?? .deliveredToFriend
        
        return ACKPayload(
            ackedSeqNumber: seq,
            ackedSenderInitials: ackedInitials,
            ackTimestamp: date,
            ackStatus: status,
            receivedRssi: rssi,
            originalEventId: eventId,
            responderInitials: respInitials
        )
    }
}
```
- **Line 42–64:** `serialize()` packs exactly 30 bytes:
  - Bytes 0..3: `ackedSeqNumber` (4 bytes big-endian)
  - Bytes 4..5: `ackedSenderInitials` (2 bytes Base-27)
  - Bytes 6..9: `ackTimestamp` (4 bytes big-endian Unix epoch)
  - Byte 10: `ackStatus.rawValue` (1 byte)
  - Byte 11: `receivedRssi` (1 byte signed `Int8`)
  - Bytes 12..15: `originalEventId` (4 bytes big-endian)
  - Bytes 16..17: `responderInitials` (2 bytes Base-27)
  - Bytes 18..29: 12 bytes of reserved `0x00` padding ($4+2+4+1+1+4+2+12 = 30$ bytes).
- **Line 66–92:** `deserialize(from:)` guards `data.count >= 30`, extracts the fields using big-endian byte loading and `InitialsCodec.decode`, and returns the struct.

### Engineering Rationale and Edge Cases
- **Exact 30-Byte Payload Budget:** ChaCha20-Poly1305 operates on a strictly fixed 30-byte plaintext payload. Active data takes up 18 bytes, leaving exactly 12 bytes of zero-padding for forward-compatible future extensions (such as multi-hop route metrics).

---

---

## 9. Teekum/Teekum/Core/Packets/Payloads/AttendanceStatus.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [AttendanceStatus.swift](../../Teekum/Teekum/Core/Packets/Payloads/AttendanceStatus.swift) |
| **Line Count (`wc -l`)** | 22 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value enum (`public enum AttendanceStatus: UInt8, Sendable`) |
| **Concurrency Domain** | `Sendable` primitive enum. |
| **Architectural Role** | Rendezvous attendance status enumeration (attending, declined, pending) for meeting point synchronization. |

### What This File Does
`AttendanceStatus.swift` defines the rendezvous response states that group members broadcast in response to a proposed meeting point. It encodes whether a member will attend (`0x01`), cannot make it (`0x02`), or has physically arrived at the rendezvous coordinate (`0x09`).

### ELI5 Analogy
Think of `AttendanceStatus` as a quick three-way RSVP toggle on an event invite: "I'll be there", "Can't make it", or "I'm already standing here waiting for you".

### Technical Terms Defined
- **RSVP Opcode:** A 1-byte status flag serialized inside rendezvous packets to report attendance.
- **Arrival Detection:** Automatic status elevation to `atMeetingPoint` (`0x09`) triggered by CoreLocation geofencing when the device enters within 25 meters of the rendezvous point.

### Code-Block and Line-by-Line Walkthrough
```swift
// Line 1-22
//
//  AttendanceStatus.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum AttendanceStatus: UInt8, CaseIterable, Codable, Sendable {
    case attending      = 0x01
    case cantMakeIt     = 0x02
    case atMeetingPoint = 0x09
    
    public var title: String {
        switch self {
        case .attending:      return "I'll be there"
        case .cantMakeIt:     return "Can't make it"
        case .atMeetingPoint: return "Arrived"
        }
    }
}
```
- **Line 10:** Declares `public enum AttendanceStatus: UInt8, CaseIterable, Codable, Sendable`.
- **Line 11–13:** Enum cases: `attending = 0x01`, `cantMakeIt = 0x02`, and `atMeetingPoint = 0x09`.
- **Line 15–21:** `title` computed property returning human-friendly localized UI labels.

### Engineering Rationale and Edge Cases
- **Why `atMeetingPoint` is `0x09`:** Preserves opcode alignment with legacy prototype specs while leaving values `0x03...0x08` open for future intermediate states (such as "Running Late").

---

---

## 10. Teekum/Teekum/Core/Packets/Payloads/ChatMessagePayload.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [ChatMessagePayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/ChatMessagePayload.swift) |
| **Line Count (`wc -l`)** | 146 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct ChatMessagePayload: Equatable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | 30-byte binary payload packing sender initials, sequence counter, and up to 20 UTF-8 text bytes with byte-boundary clamping. |

### What This File Does
`ChatMessagePayload.swift` implements the 30-byte binary serialization for Type `0x07` (`chatMessage`) packets. It carries ephemeral tactical micro-dispatches between search-and-rescue squad members, enforcing a strict 20-byte maximum UTF-8 boundary. The payload packs the monotonic sequence counter (4 bytes), sender initials (2 bytes), Unix epoch timestamp (4 bytes), actual text length (1 byte), UTF-8 text bytes (up to 20 bytes), and 3 bytes of reserved zero-padding. It also includes standard preset chip quick replies.

### ELI5 Analogy
Think of `ChatMessagePayload` as a tactical field teletype strip or micro-dispatch. Because radio bandwidth through concrete rubble and collapsed structures is severely limited, each dispatch is restricted to 20 UTF-8 bytes—specifically optimized for urgent field directives such as "SQUAD 4 EN ROUTE", "TRIAGE ALPHA CLEAR", "NEED STRETCHER", or "GAS LEAK SECTOR B". If an adrenaline-fueled responder enters more text, the codec cleanly clamps at a valid Unicode character boundary, ensuring zero corrupt characters or broken words reach team members.

### Technical Terms Defined
- **UTF-8 Byte-Boundary Clamping:** The process of truncating a string to fit within a byte quota (20 bytes) without splitting multi-byte Unicode characters (such as emojis or accented letters), which would result in corrupted Unicode replacement characters (``).
- **RAM-Only Ephemeral Messaging:** Messages that are decrypted and held strictly in memory while the app runs, never persisted to disk, and completely purged on session exit.
- **Preset Chips:** Hardcoded 1-tap quick replies that fit comfortably within the 20-byte limit (e.g. `"I need help"`, `"Where are you?"`, `"I'm safe"`).

### Code-Block and Line-by-Line Walkthrough
#### Block 1: Struct Declaration, Constants & Presets (Lines 1–46)
```swift
// Line 1-46
//
//  ChatMessagePayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct ChatMessagePayload: Equatable, Sendable {
    public static let maxTextBytes: Int = 20
    public static let reservedBytesCount: Int = 3
    
    // MARK: - Quick Replies
    public static let presetINeedHelp = "I need help"
    public static let presetWhereAreYou = "Where are you?"
    public static let presetImSafe = "I'm safe"
    public static let presetAtTheShelter = "At the shelter"
    public static let presetIveArrived = "I've arrived"
    public static let presetCallMe = "Call me"
    
    public static let allPresets: [String] = [
        presetINeedHelp,
        presetWhereAreYou,
        presetImSafe,
        presetAtTheShelter,
        presetIveArrived,
        presetCallMe
    ]
    
    public var sequenceNumber: UInt32
    public var senderInitials: String // 3 uppercase characters
    public var timestamp: Date
    public var text: String           // Up to 20 bytes UTF-8
```
- **Line 10:** Declares `public struct ChatMessagePayload: Equatable, Sendable`.
- **Line 11–12:** Constants: `maxTextBytes = 20` and `reservedBytesCount = 3`.
- **Line 15–29:** Preset strings and `allPresets` array for horizontal chip pickers in the UI.
- **Line 31–34:** Stored properties: `sequenceNumber` (UInt32), `senderInitials` (String), `timestamp` (Date), and `text` (String).

#### Block 2: Initializer & UTF-8 Clamping (Lines 48–77)
```swift
// Line 48-77
    public init(
        sequenceNumber: UInt32,
        senderInitials: String,
        timestamp: Date = Date(),
        text: String
    ) {
        self.sequenceNumber = sequenceNumber
        self.senderInitials = InitialsCodec.sanitize(senderInitials)
        self.timestamp = timestamp
        self.text = ChatMessagePayload.clampToByteBoundary(text, maxBytes: ChatMessagePayload.maxTextBytes)
    }
    
    public static func clampToByteBoundary(_ string: String, maxBytes: Int) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        if data.count <= maxBytes { return string }
        
        var clampedData = data.prefix(maxBytes)
        while !clampedData.isEmpty {
            if let validString = String(data: clampedData, encoding: .utf8) {
                return validString
            }
            clampedData = clampedData.dropLast()
        }
        return ""
    }
```
- **Line 48–56:** Initializer sanitizes sender initials and clamps text to 20 UTF-8 bytes using `clampToByteBoundary`.
- **Line 58–76:** `clampToByteBoundary`: converts string to UTF-8 `Data`. If `<= maxBytes`, returns original string. Otherwise slices prefix to `maxBytes` and loops backwards dropping bytes until `String(data: clampedData, encoding: .utf8)` successfully decodes a valid Unicode character boundary.

#### Block 3: Wire Serialization & Deserialization (Lines 79–146)
```swift
// Line 79-146
    public func serialize() throws -> Data {
        guard let textData = text.data(using: .utf8), textData.count <= Self.maxTextBytes else {
            throw PacketCodecError.invalidTextLength(text.utf8.count)
        }
        
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        
        // Bytes 0..3: sequenceNumber (4 bytes)
        var seq = sequenceNumber.bigEndian
        data.append(Data(bytes: &seq, count: 4))
        
        // Bytes 4..5: senderInitials (2 bytes)
        let initialsBytes = InitialsCodec.encode(senderInitials) ?? [0, 0]
        data.append(contentsOf: initialsBytes)
        
        // Bytes 6..9: timestamp (4 bytes)
        var ts = UInt32(timestamp.timeIntervalSince1970).bigEndian
        data.append(Data(bytes: &ts, count: 4))
        
        // Byte 10: textLength (1 byte)
        data.append(UInt8(textData.count))
        
        // Bytes 11..<11+textLength: textData
        data.append(textData)
        
        // Remaining bytes zero-padded up to 27 bytes (11 + 20 - 4 reserved = 27)
        let paddingNeeded = Self.maxTextBytes - textData.count
        if paddingNeeded > 0 {
            data.append(Data(repeating: 0, count: paddingNeeded))
        }
        
        // Bytes 27..29: 3 reserved bytes
        data.append(Data(repeating: 0, count: Self.reservedBytesCount))
        
        guard data.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.payloadSerializationFailed
        }
        return data
    }
    
    public static func deserialize(from data: Data) throws -> ChatMessagePayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        
        let seq = data.subdata(in: 0..<4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let initialsBytes = [data[4], data[5]]
        let initials = InitialsCodec.decode(initialsBytes) ?? "UNK"
        
        let tsRaw = data.subdata(in: 6..<10).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let textLen = Int(data[10])
        guard textLen <= Self.maxTextBytes else {
            throw PacketCodecError.invalidTextLength(textLen)
        }
        
        let textBytes = data.subdata(in: 11..<(11 + textLen))
        guard let text = String(data: textBytes, encoding: .utf8) else {
            throw PacketCodecError.invalidTextEncoding
        }
        
        let date = Date(timeIntervalSince1970: TimeInterval(tsRaw))
        return ChatMessagePayload(
            sequenceNumber: seq,
            senderInitials: initials,
            timestamp: date,
            text: text
        )
    }
}
```
- **Line 79–110:** `serialize()`: verifies text length, encodes 4-byte big-endian `sequenceNumber`, 2-byte Base-27 `senderInitials`, 4-byte big-endian Unix timestamp, 1-byte `textLength`, raw UTF-8 `textData`, pads remaining text space with zeroes up to 20 bytes, and appends 3 reserved zero-bytes ($4+2+4+1+20+3 = 30$ bytes).
- **Line 112–145:** `deserialize(from:)`: unpacks 30 bytes, reading length at Byte 10, slicing Bytes 11..<(11+textLen), decoding UTF-8, and validating boundaries.

### Engineering Rationale and Edge Cases
- **Multi-Byte Unicode Slicing:** Naively slicing a Swift string by index or taking raw byte prefixes can bisect a 4-byte emoji (such as fire or warning symbols). `clampToByteBoundary` iteratively drops trailing bytes until `String(data:encoding:.utf8)` succeeds, ensuring malformed characters never reach the wire.
- **Fixed-Buffer Invariant:** Regardless of whether the chat message is 2 bytes or 20 bytes, the serialized output is padded to exactly 30 bytes to maintain the invariant 56-byte wire frame.

---

---

## 11. Teekum/Teekum/Core/Packets/Payloads/LocationPingPayload.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [LocationPingPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/LocationPingPayload.swift) |
| **Line Count (`wc -l`)** | 106 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct LocationPingPayload: Equatable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | 30-byte binary payload packing quantized latitude/longitude (Int32), horizontal accuracy, battery status, and sender initials. |

### What This File Does
`LocationPingPayload.swift` implements the 30-byte binary serialization for Type `0x01` (`locationPing`) packets. It encodes periodic GPS coordinates, horizontal accuracy, device battery percentage, movement speed, compass heading, and sender initials. Coordinates are packed into signed 32-bit integers (`Int32`) providing ~11cm resolution worldwide, accompanied by 12 bytes of reserved zero-padding.

### ELI5 Analogy
Think of `LocationPingPayload` as an automated radio beacon that your phone chirps every few seconds. It tells everyone in your disaster zone group: "This is NIC, I am standing at these exact GPS coordinates within 5 meters of accuracy, my compass is pointing 180 degrees south, and my battery is at 74%."

### Technical Terms Defined
- **Fixed-Point Coordinate Scaling Factor:** Multiplying latitude and longitude by $10^7$ (`10,000,000.0`) to convert floating-point degrees into signed 32-bit integers (`Int32`), achieving worldwide ~11mm precision at the equator.
- **Clamped Battery UInt8:** Converting a 0.0...1.0 normalized battery float into an 8-bit unsigned integer clamped between `0` and `100`.
- **Quantized Compass Byte:** Scaling 0..<360 compass degrees into 0...255 (`UInt8`) to occupy exactly 1 byte.

### Code-Block and Line-by-Line Walkthrough
#### Block 1: Struct Declaration and Properties (Lines 1–45)
```swift
// Line 1-45
//
//  LocationPingPayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation
import CoreLocation

public struct LocationPingPayload: Equatable, Sendable {
    public var coordinate: CLLocationCoordinate2D
    public var timestamp: Date
    public var accuracy: UInt8
    public var batteryLevel: UInt8
    public var speed: UInt8
    public var heading: UInt8
    public var senderInitials: String // 3 uppercase characters
    public var colorCode: UInt8
    
    public init(
        coordinate: CLLocationCoordinate2D,
        timestamp: Date = Date(),
        accuracy: UInt8,
        batteryLevel: UInt8 = 100,
        speed: UInt8 = 0,
        heading: UInt8 = 0,
        senderInitials: String,
        colorCode: UInt8 = 0x00
    ) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.accuracy = accuracy
        self.batteryLevel = min(batteryLevel, 100)
        self.speed = speed
        self.heading = heading
        self.senderInitials = InitialsCodec.sanitize(senderInitials)
        self.colorCode = colorCode
    }
```
- **Line 1–11:** Header and imports (`Foundation`, `CoreLocation`).
- **Line 12–20:** Stored properties: `coordinate` (CLLocationCoordinate2D), `timestamp` (Date), `accuracy` (UInt8 in meters), `batteryLevel` (UInt8 0...100), `speed` (UInt8 in m/s), `heading` (UInt8 quantized compass byte), `senderInitials` (String), and `colorCode` (UInt8 profile color).
- **Line 22–45:** Initializer clamping `batteryLevel` to `100` and sanitizing `senderInitials`.

#### Block 2: Serialization and Deserialization (Lines 47–106)
```swift
// Line 47-106
    public func serialize() throws -> Data {
        guard coordinate.latitude >= -90.0 && coordinate.latitude <= 90.0 &&
              coordinate.longitude >= -180.0 && coordinate.longitude <= 180.0 else {
            throw PacketCodecError.invalidCoordinateRange(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        
        var lat = coordinate.rawLatitude.bigEndian
        data.append(Data(bytes: &lat, count: 4))
        
        var lon = coordinate.rawLongitude.bigEndian
        data.append(Data(bytes: &lon, count: 4))
        
        var ts = UInt32(timestamp.timeIntervalSince1970).bigEndian
        data.append(Data(bytes: &ts, count: 4))
        
        data.append(accuracy)
        data.append(min(batteryLevel, 100))
        data.append(speed)
        data.append(heading)
        
        let initialBytes = InitialsCodec.encode(senderInitials) ?? [0, 0]
        data.append(contentsOf: initialBytes)
        
        data.append(colorCode)
        
        // 11 bytes reserved padding (30 - 19 = 11)
        data.append(Data(repeating: 0, count: 11))
        
        guard data.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.payloadSerializationFailed
        }
        return data
    }
    
    public static func deserialize(from data: Data) throws -> LocationPingPayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        
        let latRaw = data.subdata(in: 0..<4).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let lonRaw = data.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let tsRaw = data.subdata(in: 8..<12).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        
        let accuracy = data[12]
        let battery = data[13]
        let speed = data[14]
        let heading = data[15]
        
        let initialBytes = [data[16], data[17]]
        let initials = InitialsCodec.decode(initialBytes) ?? "UNK"
        let colorCode = data.count > 18 ? data[18] : 0
        
        let coord = CLLocationCoordinate2D.dequantize(latitudeRaw: latRaw, longitudeRaw: lonRaw)
        guard coord.latitude >= -90.0 && coord.latitude <= 90.0 && coord.longitude >= -180.0 && coord.longitude <= 180.0 else {
            throw PacketCodecError.invalidCoordinateRange(latitude: coord.latitude, longitude: coord.longitude)
        }
        
        let date = Date(timeIntervalSince1970: TimeInterval(tsRaw))
        
        return LocationPingPayload(
            coordinate: coord,
            timestamp: date,
            accuracy: accuracy,
            batteryLevel: min(battery, 100),
            speed: speed,
            heading: heading,
            senderInitials: initials,
            colorCode: colorCode
        )
    }
}
```
- **Line 47–75:** `serialize()` validates latitude in `[-90, 90]` and longitude in `[-180, 180]`. Packs 30 bytes:
  - Bytes 0..3: `lat` (4 bytes big-endian `Int32`)
  - Bytes 4..7: `lon` (4 bytes big-endian `Int32`)
  - Bytes 8..11: `timestamp` (4 bytes big-endian Unix epoch)
  - Byte 12: `accuracy` (1 byte `UInt8`)
  - Byte 13: `batteryLevel` (1 byte `UInt8`)
  - Byte 14: `speed` (1 byte `UInt8`)
  - Byte 15: `heading` (1 byte `UInt8`)
  - Bytes 16..17: `senderInitials` (2 bytes Base-27)
  - Byte 18: `colorCode` (1 byte `UInt8`)
  - Bytes 19..29: 11 bytes of reserved `0x00` padding ($4+4+4+1+1+1+1+2+1+11 = 30$ bytes).
- **Line 77–105:** `deserialize(from:)` guards 30 bytes, dequantizes raw integers into `CLLocationCoordinate2D`, validates boundaries, decodes initials, and returns the struct.

### Engineering Rationale and Edge Cases
- **Coordinate Boundary Validation:** Guarding against corrupted latitude/longitude prevents bogus coordinates from injecting NaN or out-of-bounds pins into MapKit or Tactical Radar projections.

---

---

## 12. Teekum/Teekum/Core/Packets/Payloads/MeetingAction.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [MeetingAction.swift](../../Teekum/Teekum/Core/Packets/Payloads/MeetingAction.swift) |
| **Line Count (`wc -l`)** | 15 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value enum (`public enum MeetingAction: UInt8, Sendable`) |
| **Concurrency Domain** | `Sendable` primitive enum. |
| **Architectural Role** | Rendezvous mutation action enumeration (propose, update, cancel) governing meeting point lifecycle. |

### What This File Does
`MeetingAction.swift` defines the mutation lifecycle actions for group rendezvous points. Carried inside `MeetingUpdatePayload` (Type `0x03`), it signals whether a packet proposes a new meeting point (`0x01`), cancels an existing meeting point (`0x02`), accepts a proposal (`0x03`), or declines a proposal (`0x04`).

### ELI5 Analogy
Think of `MeetingAction` as the action verbs on a disaster zone calendar invite: "Propose Meetup", "Cancel Meetup", "Accept", or "Decline".

### Technical Terms Defined
- **Rendezvous Action Verb:** A 1-byte opcode governing whether a meeting point is created, modified, or deleted across the mesh.
- **Setter Lock Mutation:** Only the member who holds the Setter Lock can issue `.propose` or `.cancel` actions.

### Code-Block and Line-by-Line Walkthrough
```swift
// Line 1-15
//
//  MeetingAction.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum MeetingAction: UInt8, CaseIterable, Sendable {
    case propose = 0x01
    case cancel  = 0x02
    case accept  = 0x03
    case decline = 0x04
}
```
- **Line 10:** Declares `public enum MeetingAction: UInt8, CaseIterable, Sendable`.
- **Line 11–14:** Cases: `propose = 0x01`, `cancel = 0x02`, `accept = 0x03`, `decline = 0x04`.

### Engineering Rationale and Edge Cases
- **Action Determinism:** Binding meeting actions to explicit 1-byte raw values prevents conflicting interpretation of rendezvous state across heterogeneous device builds.

---

---

## 13. Teekum/Teekum/Core/Packets/Payloads/MeetingUpdatePayload.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [MeetingUpdatePayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/MeetingUpdatePayload.swift) |
| **Line Count (`wc -l`)** | 147 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct MeetingUpdatePayload: Equatable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | 30-byte binary payload encoding rendezvous GPS coordinate, scheduled epoch time, setter slot, and action opcode. |

### What This File Does
`MeetingUpdatePayload.swift` implements the 30-byte binary serialization for Type `0x03` (`meetingUpdate`) packets. It synchronizes emergency rally points and field triage stations across the mesh network, encoding meeting GPS coordinates, target meetup epoch time, meeting name (up to 12 UTF-8 bytes), sender initials, target member slot, and action opcode. It enforces Setter Lock Rule arbitration on the wire.

### ELI5 Analogy
Think of `MeetingUpdatePayload` as an official Tactical Rendezvous & Field Triage dispatch broadcast by an Incident Commander. It informs every squad member: "Rally at Evac LZ Alpha at 14:30. Established by SQUAD_LEAD_01." Every responder's device in the session receives this 30-byte dispatch and automatically updates its navigation compass, radar target, and map pin.

### Technical Terms Defined
- **Setter Lock Rule:** A distributed arbitration rule stating that once a member establishes an active rendezvous point, other members cannot overwrite it until the original creator cancels it or the scheduled time passes.
- **Member Slot Targeting:** An 8-bit identifier targeting a specific group participant when issuing direct meeting acceptance or decline actions.
- **Short Name Clamping:** Clamping meeting place names to 12 UTF-8 bytes (e.g. `"Sound Booth"`), fitting within the tight 30-byte payload.

### Code-Block and Line-by-Line Walkthrough
#### Block 1: Struct Declaration and Properties (Lines 1–49)
```swift
// Line 1-49
//
//  MeetingUpdatePayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation
import CoreLocation

public struct MeetingUpdatePayload: Equatable, Sendable {
    public static let maxNameBytes: Int = 12
    
    public var coordinate: CLLocationCoordinate2D
    public var targetTime: Date
    public var name: String          // Up to 12 bytes UTF-8
    public var action: MeetingAction
    public var senderInitials: String // 3 uppercase characters
    public var targetMemberSlot: UInt8
    
    public init(
        coordinate: CLLocationCoordinate2D,
        targetTime: Date,
        name: String,
        action: MeetingAction,
        senderInitials: String,
        targetMemberSlot: UInt8 = 0
    ) {
        self.coordinate = coordinate
        self.targetTime = targetTime
        self.name = ChatMessagePayload.clampToByteBoundary(name, maxBytes: Self.maxNameBytes)
        self.action = action
        self.senderInitials = InitialsCodec.sanitize(senderInitials)
        self.targetMemberSlot = targetMemberSlot
    }
```
- **Line 1–11:** Imports Foundation and CoreLocation.
- **Line 12–19:** Stored properties: `maxNameBytes = 12`, `coordinate` (CLLocationCoordinate2D), `targetTime` (Date), `name` (String up to 12 UTF-8 bytes), `action` (MeetingAction), `senderInitials` (String), and `targetMemberSlot` (UInt8).
- **Line 21–48:** Initializer clamps `name` to 12 UTF-8 bytes and sanitizes `senderInitials`.

#### Block 2: Serialization and Deserialization (Lines 51–147)
```swift
// Line 51-147
    public func serialize() throws -> Data {
        guard coordinate.latitude >= -90.0 && coordinate.latitude <= 90.0 &&
              coordinate.longitude >= -180.0 && coordinate.longitude <= 180.0 else {
            throw PacketCodecError.invalidCoordinateRange(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        guard let nameData = name.data(using: .utf8), nameData.count <= Self.maxNameBytes else {
            throw PacketCodecError.invalidTextLength(name.utf8.count)
        }
        
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        
        var lat = coordinate.rawLatitude.bigEndian
        data.append(Data(bytes: &lat, count: 4))
        
        var lon = coordinate.rawLongitude.bigEndian
        data.append(Data(bytes: &lon, count: 4))
        
        var ts = UInt32(targetTime.timeIntervalSince1970).bigEndian
        data.append(Data(bytes: &ts, count: 4))
        
        data.append(UInt8(nameData.count))
        data.append(nameData)
        
        let paddingNeeded = Self.maxNameBytes - nameData.count
        if paddingNeeded > 0 {
            data.append(Data(repeating: 0, count: paddingNeeded))
        }
        
        data.append(action.rawValue)
        
        let initialBytes = InitialsCodec.encode(senderInitials) ?? [0, 0]
        data.append(contentsOf: initialBytes)
        
        data.append(targetMemberSlot)
        
        // 1 byte reserved padding (30 - 29 = 1)
        data.append(0x00)
        
        guard data.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.payloadSerializationFailed
        }
        return data
    }
    
    public static func deserialize(from data: Data) throws -> MeetingUpdatePayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        
        let latRaw = data.subdata(in: 0..<4).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let lonRaw = data.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let tsRaw = data.subdata(in: 8..<12).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        
        let nameLen = Int(data[12])
        guard nameLen <= Self.maxNameBytes else {
            throw PacketCodecError.invalidTextLength(nameLen)
        }
        
        let nameBytes = data.subdata(in: 13..<(13 + nameLen))
        guard let name = String(data: nameBytes, encoding: .utf8) else {
            throw PacketCodecError.invalidTextEncoding
        }
        
        let actionByte = data[25]
        guard let action = MeetingAction(rawValue: actionByte) else {
            throw PacketCodecError.payloadDeserializationFailed
        }
        
        let initialBytes = [data[26], data[27]]
        let initials = InitialsCodec.decode(initialBytes) ?? "UNK"
        let targetSlot = data[28]
        
        let coord = CLLocationCoordinate2D.dequantize(latitudeRaw: latRaw, longitudeRaw: lonRaw)
        guard coord.latitude >= -90.0 && coord.latitude <= 90.0 && coord.longitude >= -180.0 && coord.longitude <= 180.0 else {
            throw PacketCodecError.invalidCoordinateRange(latitude: coord.latitude, longitude: coord.longitude)
        }
        
        let date = Date(timeIntervalSince1970: TimeInterval(tsRaw))
        
        return MeetingUpdatePayload(
            coordinate: coord,
            targetTime: date,
            name: name,
            action: action,
            senderInitials: initials,
            targetMemberSlot: targetSlot
        )
    }
}
```
- **Line 51–87:** `serialize()` packs 30 bytes:
  - Bytes 0..3: `lat` (4 bytes big-endian `Int32`)
  - Bytes 4..7: `lon` (4 bytes big-endian `Int32`)
  - Bytes 8..11: `targetTime` (4 bytes big-endian Unix epoch)
  - Byte 12: `nameLength` (1 byte `UInt8`)
  - Bytes 13..<13+nameLen: `nameData` (raw UTF-8 bytes)
  - Zero-padding for name up to 12 bytes
  - Byte 25: `action.rawValue` (1 byte)
  - Bytes 26..27: `senderInitials` (2 bytes Base-27)
  - Byte 28: `targetMemberSlot` (1 byte)
  - Byte 29: 1 byte reserved zero-padding ($4+4+4+1+12+1+2+1+1 = 30$ bytes).
- **Line 89–146:** `deserialize(from:)` guards 30 bytes, parses coordinates, name, action opcode, initials, and target slot, returning the struct.

### Engineering Rationale and Edge Cases
- **Setter Lock Protection on Wire:** Carrying `senderInitials` and `action` in the sealed payload allows the recipient's `MeetingPointService` to verify that cancellation requests originate from the member who proposed the rendezvous, enforcing Setter Lock Rule integrity.

---

---

## 14. Teekum/Teekum/Core/Packets/Payloads/RouteReqPayload.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [RouteReqPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/RouteReqPayload.swift) |
| **Line Count (`wc -l`)** | 59 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct RouteReqPayload: Equatable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | 30-byte binary payload for AODV route discovery carrying target initials, originator sequence, and accumulated metric. |

### What This File Does
`RouteReqPayload.swift` implements the binary payload for Ad hoc On-Demand Distance Vector (AODV) route discovery requests (`PacketType.routeReq`, opcode `0x05`). When a device wishes to send unicast traffic to a peer whose next-hop relay is unknown or stale, it broadcasts a Route Request containing the originator's initials, the destination target's initials, a unique 32-bit discovery nonce, and an accumulated hop cost counter. The struct handles the bidirectional conversion between high-level Swift routing models and the 30-byte sealed payload slot inside the 56-byte wire datagram.

### ELI5 Analogy
Imagine Search Squad Lead Alice needs to coordinate with Field Medic Bob, who is operating behind a collapsed multi-story garage where direct line-of-sight radio cannot penetrate. Alice broadcasts an AODV Route Request across the mesh: "This is Alice searching for Medic Bob; Sequence #74829." Nearby volunteer relay nodes increment the hop count and forward the inquiry across the disaster sector. If a node has already seen token #74829, it drops it immediately to prevent echo storms. When Bob's device receives the query, it generates an authenticated Route Response along the reverse path, establishing a verified multi-hop route back to Alice.

### Technical Terms Defined
- **AODV (Ad hoc On-Demand Distance Vector):** A reactive routing protocol for mobile ad-hoc networks where routes are established dynamically only when needed by an active communication attempt, minimizing idle mesh control overhead.
- **RREQ (Route Request):** An AODV discovery message broadcast across the network seeking a path to an indicated destination node.
- **Discovery Nonce:** A 32-bit pseudo-random number generated by the route originator that, when paired with the originator's identity, uniquely identifies a discovery attempt and prevents broadcast loops.
- **Route Cost (Hop Metric):** A single-byte integer representing the cumulative link distance (number of radio hops) from the originator to the current node.
- **Unaligned Memory Loading (`loadUnaligned`):** Reading multi-byte integers from arbitrary memory byte boundaries without requiring memory addresses to be exact multiples of the integer's byte alignment (such as 4-byte boundaries for 32-bit words).

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–26: Type Declaration and Initializer
```swift
//
//  RouteReqPayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct RouteReqPayload: Equatable, Sendable {
    public var originatorInitials: String
    public var targetInitials: String
    public var discoveryNonce: UInt32
    public var routeCost: UInt8
    
    public init(
        originatorInitials: String,
        targetInitials: String,
        discoveryNonce: UInt32 = UInt32.random(in: 1...UInt32.max),
        routeCost: UInt8 = 0
    ) {
        self.originatorInitials = InitialsCodec.sanitize(originatorInitials)
        self.targetInitials = InitialsCodec.sanitize(targetInitials)
        self.discoveryNonce = discoveryNonce
        self.routeCost = routeCost
    }
```
- **Line 10:** Declares `RouteReqPayload` as an `Equatable`, `Sendable` value struct.
- **Lines 11–14:** Stores the four core AODV discovery fields: `originatorInitials` (who initiated the search), `targetInitials` (who is being searched for), `discoveryNonce` (the 32-bit unique search ID), and `routeCost` (hop counter).
- **Lines 16–26:** The public initializer sanitizes both initials strings through `InitialsCodec.sanitize` to guarantee uppercase ASCII letters/numbers. If unassigned, `discoveryNonce` defaults to a cryptographically uniform random integer in `1...UInt32.max`, while `routeCost` defaults to 0.

#### Lines 28–43: Serialization to 30 Bytes
```swift
    public func serialize() -> Data {
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        let origBytes = InitialsCodec.encode(originatorInitials) ?? [0, 0]
        data.append(contentsOf: origBytes)
        
        let targetBytes = InitialsCodec.encode(targetInitials) ?? [0, 0]
        data.append(contentsOf: targetBytes)
        
        var nonce = discoveryNonce.bigEndian
        data.append(Data(bytes: &nonce, count: 4))
        data.append(routeCost)
        
        // 21 bytes reserved (30 - 9 = 21)
        data.append(Data(repeating: 0, count: 21))
        return data
    }
```
- **Line 28–29:** Allocates a `Data` buffer with capacity 30 (`PacketConstants.encryptedPayloadSize`).
- **Lines 30–31:** Encodes `originatorInitials` into 2 Base-27 bytes; appends at Bytes 0..1.
- **Lines 33–34:** Encodes `targetInitials` into 2 Base-27 bytes; appends at Bytes 2..3.
- **Lines 36–37:** Converts `discoveryNonce` to big-endian and appends 4 bytes at Bytes 4..7.
- **Line 38:** Appends single-byte `routeCost` at Byte 8.
- **Lines 40–42:** Appends 21 bytes of zero-padding at Bytes 9..29 ($2 + 2 + 4 + 1 + 21 = 30$ bytes). Returns the 30-byte serialized payload.

#### Lines 45–58: Deserialization from Inbound Byte Stream
```swift
    public static func deserialize(from data: Data) throws -> RouteReqPayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        let origBytes = [data[0], data[1]]
        let orig = InitialsCodec.decode(origBytes) ?? "UNK"
        
        let targetBytes = [data[2], data[3]]
        let target = InitialsCodec.decode(targetBytes) ?? "UNK"
        
        let nonce = data.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let cost = data[8]
        return RouteReqPayload(originatorInitials: orig, targetInitials: target, discoveryNonce: nonce, routeCost: cost)
    }
}
```
- **Lines 46–48:** Validates that incoming payload has at least 30 bytes, throwing `PacketCodecError.bufferUnderflow` otherwise.
- **Lines 49–53:** Extracts and decodes `origBytes` from Bytes 0..1 and `targetBytes` from Bytes 2..3 via `InitialsCodec.decode`, defaulting to `"UNK"` if decoding fails.
- **Line 55:** Extracts Bytes 4..<8 and parses big-endian `UInt32` into `nonce` using `loadUnaligned`.
- **Line 56:** Reads Byte 8 as `routeCost`.
- **Lines 57–58:** Instantiates and returns the validated `RouteReqPayload`.

### Engineering Rationale and Edge Cases
- **21 Bytes Reserved Padding:** Over 70% of the payload space ($21/30$ bytes) is zero-padded. This maintains the strictly invariant 56-byte wire container across all packet types, preventing eavesdroppers from doing traffic-analysis classification based on datagram size.
- **Loop Prevention via Discovery Nonce:** Because AODV route requests are flooded across the mesh, intermediate nodes remember seen `(originatorInitials, discoveryNonce)` pairs in their routing caches. Any duplicate RREQ is discarded immediately before re-broadcasting.

---

---

## 15. Teekum/Teekum/Core/Packets/Payloads/RouteRespPayload.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [RouteRespPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/RouteRespPayload.swift) |
| **Line Count (`wc -l`)** | 59 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct RouteRespPayload: Equatable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | 30-byte binary payload for AODV route reply establishing return paths with destination sequence and hop count. |

### What This File Does
`RouteRespPayload.swift` defines the payload for AODV route response packets (`PacketType.routeResp`, opcode `0x06`). When a destination node (or an intermediate peer holding a fresh route to the destination) receives a Route Request, it replies with a unicast Route Response. This response informs the originator that a valid path exists, carrying the discovery nonce that matches the original request and the initial route cost.

### ELI5 Analogy
Following Alice's disaster zone search for Bob: Bob hears the shout, writes a return postcard: "Alice, this is Bob responding to your search token #74829! I am currently 0 hops away from this response." Bob hands the card back along the exact chain of friends who brought the search note to him, establishing the return path for Alice's messages.

### Technical Terms Defined
- **RREP (Route Response):** An AODV unicast message sent backwards along the reverse route formed by an RREQ to confirm reachability of the target node.
- **Reverse Path:** The sequence of intermediate relay nodes recorded in reverse routing tables while an RREQ travels from originator to target.
- **Unicast Mesh Forwarding:** Relaying a packet to a specific, targeted next-hop neighbor MAC/ID rather than broadcasting to all surrounding radios.
- **Gratuitous RREP:** A route response proactively generated by an intermediate relay that already knows a path to the requested destination, avoiding full network flooding.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–26: Type Declaration and Initializer
```swift
//
//  RouteRespPayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct RouteRespPayload: Equatable, Sendable {
    public var originatorInitials: String
    public var targetInitials: String
    public var discoveryNonce: UInt32
    public var routeCost: UInt8
    
    public init(
        originatorInitials: String,
        targetInitials: String,
        discoveryNonce: UInt32,
        routeCost: UInt8
    ) {
        self.originatorInitials = InitialsCodec.sanitize(originatorInitials)
        self.targetInitials = InitialsCodec.sanitize(targetInitials)
        self.discoveryNonce = discoveryNonce
        self.routeCost = routeCost
    }
```
- **Line 10:** Declares `RouteRespPayload` as an `Equatable`, `Sendable` struct.
- **Lines 11–14:** Matches `RouteReqPayload` field-for-field: `originatorInitials` (the searcher who will receive this reply), `targetInitials` (the target answering), `discoveryNonce` (the matching token), and `routeCost` (hop accumulator).
- **Lines 16–26:** Public initializer. Note that unlike `RouteReqPayload`, `discoveryNonce` has no default random generator because an RREP must strictly mirror the exact nonce received in the corresponding RREQ.

#### Lines 28–43: Serialization to 30 Bytes
```swift
    public func serialize() -> Data {
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        let origBytes = InitialsCodec.encode(originatorInitials) ?? [0, 0]
        data.append(contentsOf: origBytes)
        
        let targetBytes = InitialsCodec.encode(targetInitials) ?? [0, 0]
        data.append(contentsOf: targetBytes)
        
        var nonce = discoveryNonce.bigEndian
        data.append(Data(bytes: &nonce, count: 4))
        data.append(routeCost)
        
        // 21 bytes reserved (30 - 9 = 21)
        data.append(Data(repeating: 0, count: 21))
        return data
    }
```
- **Lines 28–43:** Mirrors `RouteReqPayload.serialize()` identically:
  - Bytes 0..1: `originatorInitials` (2 Base-27 bytes)
  - Bytes 2..3: `targetInitials` (2 Base-27 bytes)
  - Bytes 4..7: `discoveryNonce` (4 bytes big-endian UInt32)
  - Byte 8: `routeCost` (1 byte UInt8)
  - Bytes 9..29: 21 zero bytes reserved padding.

#### Lines 45–58: Deserialization
```swift
    public static func deserialize(from data: Data) throws -> RouteRespPayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        let origBytes = [data[0], data[1]]
        let orig = InitialsCodec.decode(origBytes) ?? "UNK"
        
        let targetBytes = [data[2], data[3]]
        let target = InitialsCodec.decode(targetBytes) ?? "UNK"
        
        let nonce = data.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let cost = data[8]
        return RouteRespPayload(originatorInitials: orig, targetInitials: target, discoveryNonce: nonce, routeCost: cost)
    }
}
```
- **Lines 46–48:** Buffer underflow guard requiring at least 30 bytes.
- **Lines 49–57:** Extracts initials, loads 32-bit unaligned big-endian nonce, and extracts hop cost, constructing `RouteRespPayload`.

### Engineering Rationale and Edge Cases
- **Symmetric Wire Footprint:** By sharing an identical binary layout with `RouteReqPayload`, codec logic is highly predictable. The protocol opcode in the cleartext envelope (`PacketType.routeResp` vs `PacketType.routeReq`) tells the router whether to treat the packet as broadcast flood traffic or reverse-path unicast forwarding.
- **Matching Nonce Requirement:** If an originator receives an RREP whose `discoveryNonce` does not match its outstanding search table, the packet is discarded as a stale or spoofed response.

---

---

## 16. Teekum/Teekum/Core/Packets/Payloads/SOSPayload.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [SOSPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSPayload.swift) |
| **Line Count (`wc -l`)** | 103 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct SOSPayload: Equatable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | 30-byte binary payload broadcasting emergency distress alert with GPS coordinate, horizontal accuracy, and sender initials. |

### What This File Does
`SOSPayload.swift` implements the high-priority emergency broadcast payload (`PacketType.sos`, opcode `0x03`). When a user triggers an emergency alert, this payload packs their quantized GPS coordinates, timestamp, horizontal accuracy, unique SOS event ID, sender initials, emergency categorization type (`SOSType`), battery percentage, and UI profile color code into the 30-byte sealed payload slot. It bypasses regular mesh congestion queues, activating siren audio, haptic alerts, and emergency UI overlays on all group devices.

### ELI5 Analogy
Imagine pulling a bright red fire alarm lever in a crowded stadium. Instantly, an emergency flare fires into the sky with a waterproof beacon attached. Stamped on the beacon are: your GPS coordinates, the time of the crisis, your medical triage tag ("Medical Assistance"), your remaining radio battery (84%), and a flashing beacon ID so everyone knows this is an active life-safety emergency.

### Technical Terms Defined
- **SOS Event ID:** A 32-bit unique identifier generated at the onset of an emergency. All subsequent emergency location updates broadcast during the same incident reuse this ID until explicitly resolved.
- **Fixed Status Marker Byte:** Byte 13 in the SOS payload, hardcoded to `0x01` to denote an urgent, active SOS status.
- **Emergency Categorization (`SOSType`):** A 1-byte triage classifier identifying the nature of the distress (`.general`, `.medical`, `.separated`, `.security`, or `.inactivity`).
- **Battery Clamping:** Enforcing `min(batteryLevel, 100)` to ensure corrupted or malformed sensor readings cannot exceed the valid percentage range.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–39: Type Declaration and Initializer
```swift
//
//  SOSPayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation
import CoreLocation

public struct SOSPayload: Equatable, Sendable {
    public var coordinate: CLLocationCoordinate2D
    public var timestamp: Date
    public var accuracy: UInt8
    public var sosEventId: UInt32
    public var senderInitials: String // 3 uppercase characters
    public var emergencyType: SOSType
    public var batteryLevel: UInt8
    public var colorCode: UInt8       // MemberColor code
    
    public init(
        coordinate: CLLocationCoordinate2D,
        timestamp: Date = Date(),
        accuracy: UInt8,
        sosEventId: UInt32 = UInt32.random(in: 1...UInt32.max),
        senderInitials: String,
        emergencyType: SOSType = .general,
        batteryLevel: UInt8,
        colorCode: UInt8 = 0
    ) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.accuracy = accuracy
        self.sosEventId = sosEventId
        self.senderInitials = InitialsCodec.sanitize(senderInitials)
        self.emergencyType = emergencyType
        self.batteryLevel = min(batteryLevel, 100)
        self.colorCode = colorCode
    }
```
- **Lines 11–20:** Defines the struct conforming to `Equatable` and `Sendable`. Holds GPS coordinates, timestamp, accuracy, 32-bit `sosEventId`, sender initials, `emergencyType` (`SOSType`), battery level, and `colorCode`.
- **Lines 21–39:** Custom initializer sanitizing initials, clamping battery to $\le 100$, and generating a random non-zero `sosEventId` if unassigned.

#### Lines 41–66: Serialization into 30 Bytes
```swift
    public func serialize() -> Data {
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        let latRaw = coordinate.rawLatitude.bigEndian
        let lonRaw = coordinate.rawLongitude.bigEndian
        let tsRaw = UInt32(timestamp.timeIntervalSince1970).bigEndian
        
        var lat = latRaw; data.append(Data(bytes: &lat, count: 4))
        var lon = lonRaw; data.append(Data(bytes: &lon, count: 4))
        var ts = tsRaw; data.append(Data(bytes: &ts, count: 4))
        data.append(accuracy)
        data.append(0x01) // Fixed urgent SOS status marker byte
        
        var eventId = sosEventId.bigEndian
        data.append(Data(bytes: &eventId, count: 4))
        
        let initialBytes = InitialsCodec.encode(senderInitials) ?? [0, 0]
        data.append(contentsOf: initialBytes)
        
        data.append(emergencyType.rawValue)
        data.append(min(batteryLevel, 100))
        data.append(colorCode)
        
        // 7 bytes reserved padding (30 - 23 = 7)
        data.append(Data(repeating: 0, count: 7))
        return data
    }
```
- **Lines 43–49:** Quantizes coordinates to fixed-point `Int32` and timestamp to `UInt32` big-endian Unix seconds:
  - Bytes 0..3: `rawLatitude` (4 bytes signed `Int32`)
  - Bytes 4..7: `rawLongitude` (4 bytes signed `Int32`)
  - Bytes 8..11: `timestamp` (4 bytes unsigned `UInt32`)
- **Line 50:** Appends `accuracy` at Byte 12 (1 byte UInt8).
- **Line 51:** Appends `0x01` at Byte 13 (urgent SOS marker byte).
- **Lines 53–54:** Appends `sosEventId` in big-endian at Bytes 14..17 (4 bytes).
- **Lines 56–57:** Appends `senderInitials` encoded as 2 Base-27 bytes at Bytes 18..19.
- **Line 59:** Appends `emergencyType.rawValue` at Byte 20 (1 byte).
- **Line 60:** Appends clamped `batteryLevel` at Byte 21 (1 byte).
- **Line 61:** Appends `colorCode` at Byte 22 (1 byte).
- **Lines 63–65:** Appends 7 bytes of zero-padding at Bytes 23..29 ($4 + 4 + 4 + 1 + 1 + 4 + 2 + 1 + 1 + 1 + 7 = 30$ bytes). Returns the 30-byte data buffer.

#### Lines 68–102: Deserialization and Verification
```swift
    public static func deserialize(from data: Data) throws -> SOSPayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        let latRaw = data.subdata(in: 0..<4).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let lonRaw = data.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let tsRaw = data.subdata(in: 8..<12).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let accuracy = data[12]
        let eventId = data.subdata(in: 14..<18).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        
        let initialBytes = [data[18], data[19]]
        let initials = InitialsCodec.decode(initialBytes) ?? "UNK"
        
        let emergencyByte = data[20]
        let battery = data[21]
        let colorCode = data.count > 22 ? data[22] : 0
        
        let coord = CLLocationCoordinate2D.dequantize(latitudeRaw: latRaw, longitudeRaw: lonRaw)
        guard coord.latitude >= -90.0 && coord.latitude <= 90.0 && coord.longitude >= -180.0 && coord.longitude <= 180.0 else {
            throw PacketCodecError.invalidCoordinateRange(latitude: coord.latitude, longitude: coord.longitude)
        }
        let date = Date(timeIntervalSince1970: TimeInterval(tsRaw))
        let emergency = SOSType(rawValue: emergencyByte) ?? .general
        
        return SOSPayload(
            coordinate: coord,
            timestamp: date,
            accuracy: accuracy,
            sosEventId: eventId,
            senderInitials: initials,
            emergencyType: emergency,
            batteryLevel: min(battery, 100),
            colorCode: colorCode
        )
    }
}
```
- **Lines 69–71:** Guards against underflow ($< 30$ bytes).
- **Lines 72–76:** Unpacks coordinates, timestamp, accuracy, and event ID using big-endian byte loading. Byte 13 is implicitly verified as part of the stream structure.
- **Lines 78–83:** Decodes initials from Bytes 18..19, reads `emergencyByte` from Byte 20, battery from Byte 21, and safely accesses `colorCode` from Byte 22.
- **Lines 85–88:** Dequantizes coordinate into IEEE 754 `CLLocationCoordinate2D` and strictly asserts valid planetary boundaries: $-90 \le 	ext{lat} \le 90$ and $-180 \le 	ext{lon} \le 180$, throwing `PacketCodecError.invalidCoordinateRange` on violation.
- **Lines 89–101:** Constructs and returns `SOSPayload`.

### Engineering Rationale and Edge Cases
- **Carrying Color Code in SOS:** In dense emergency situations, first responders and friends must immediately identify the victim's pin on the map. Packing `colorCode` in Byte 22 ensures the map UI displays the victim's personalized AMOLED neon avatar color even before full roster metadata has synced.
- **Safe Coordinate Range Guard:** A single corrupted bit in fixed-point coordinate decoding could produce invalid locations (such as latitude 140°). The deserializer explicitly guards against this before passing coordinates to CoreLocation.

---

---

## 17. Teekum/Teekum/Core/Packets/Payloads/SOSResolvedPayload.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [SOSResolvedPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSResolvedPayload.swift) |
| **Line Count (`wc -l`)** | 41 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct SOSResolvedPayload: Hashable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | 30-byte binary payload broadcasting cancellation and resolution of an active SOS emergency. |

### What This File Does
`SOSResolvedPayload.swift` implements the payload for resolving and dismissing active SOS alerts (`PacketType.sosResolved`, opcode `0x08`). When an emergency condition has ended (for example, when a lost member reunites with their group or medical aid arrives), the originating member broadcasts this resolution payload. Upon receipt, all receiving devices silence audible siren alarms, dismiss full-screen emergency banners, and restore normal UI navigation.

### ELI5 Analogy
After a fire alarm was pulled and the firefighters determine that the fire is extinguished, the fire chief unlocks the alarm box and keys in the "All Clear" code #91823. Immediately, the loud building sirens turn off, the flashing strobe lights stop, and people return to their normal seats.

### Technical Terms Defined
- **SOS Resolution:** The authoritative state transition in the emergency state machine from active alarm broadcast back to normal mesh operation.
- **All-Clear Broadcast:** A mesh-wide message propagated with high priority to silence ongoing siren sound effects and haptic alert loops across all connected peers.
- **Event ID Binding:** Enforcing that the resolution packet specifies the exact 32-bit `eventId` being dismissed so that old or mismatched cancellations cannot accidentally silence a separate, newer crisis.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–17: Type Declaration and Initializer
```swift
//
//  SOSResolvedPayload.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 13/11/26.
//

import Foundation

public struct SOSResolvedPayload: Hashable, Sendable {
    public let senderInitials: String
    public let eventId: UInt32

    public init(senderInitials: String, eventId: UInt32) {
        self.senderInitials = senderInitials
        self.eventId = eventId
    }
```
- **Line 10:** Conforms to `Hashable` and `Sendable`. Holds immutable `let` properties: `senderInitials` (who is canceling) and `eventId` (which emergency incident is being canceled).
- **Lines 14–17:** Standard memberwise initializer.

#### Lines 19–28: Serialization into 30 Bytes
```swift
    func serialize() throws -> Data {
        guard eventId != 0, let initials = InitialsCodec.encode(senderInitials) else {
            throw PacketCodecError.payloadSerializationFailed
        }
        var bigEndianId = eventId.bigEndian
        var data = Data(bytes: &bigEndianId, count: 4)
        data.append(contentsOf: initials)
        data.append(Data(repeating: 0, count: PacketConstants.encryptedPayloadSize - 6))
        return data
    }
```
- **Lines 20–22:** Guards that `eventId != 0` (zero is a reserved invalid sentinel) and that initials encode successfully into 2 Base-27 bytes. Otherwise throws `PacketCodecError.payloadSerializationFailed`.
- **Lines 23–24:** Packs `eventId` into Bytes 0..3 in big-endian order.
- **Line 25:** Appends 2-byte Base-27 initials at Bytes 4..5.
- **Line 26:** Appends 24 zero bytes of padding (`30 - 6 = 24`) at Bytes 6..29. Returns 30-byte data.

#### Lines 30–40: Deserialization
```swift
    static func deserialize(from data: Data) throws -> Self {
        guard data.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.payloadDeserializationFailed
        }
        let eventId = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let initials = Array(data.dropFirst(4).prefix(2))
        guard eventId != 0, let sender = InitialsCodec.decode(initials) else {
            throw PacketCodecError.payloadDeserializationFailed
        }
        return Self(senderInitials: sender, eventId: eventId)
    }
}
```
- **Lines 31–33:** Strictly requires `data.count == PacketConstants.encryptedPayloadSize` (exactly 30 bytes), throwing `PacketCodecError.payloadDeserializationFailed` if byte length mismatches.
- **Line 34:** Unpacks big-endian `UInt32` from Bytes 0..<4.
- **Line 35:** Slices Bytes 4..<6 for the 2 initials bytes.
- **Lines 36–38:** Guards that `eventId != 0` and that Base-27 decoding succeeds.
- **Line 39:** Returns the validated `SOSResolvedPayload`.

### Engineering Rationale and Edge Cases
- **Strict Buffer Equality Guard:** Unlike some forward-compatible payloads that use `>= 30`, `SOSResolvedPayload` enforces strict equality (`data.count == 30`), ensuring absolute wire format conformance before disarming safety alarms.
- **Non-Zero Event ID Guard:** Enforces `eventId != 0` in both serializer and deserializer, preventing zeroed memory buffers from being misinterpreted as valid resolution commands.

---

---

## 18. Teekum/Teekum/Core/Packets/Payloads/SOSType.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [SOSType.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSType.swift) |
| **Line Count (`wc -l`)** | 27 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value enum (`public enum SOSType: UInt8, CaseIterable, Codable, Sendable`) |
| **Concurrency Domain** | `Sendable` primitive enum. |
| **Architectural Role** | Emergency alert classification enumeration distinguishing manual user SOS swipes from automated inactivity triggers. |

### What This File Does
`SOSType.swift` defines the emergency taxonomy categories carried inside `SOSPayload` (Byte 20). It maps emergency situations into a compact 1-byte raw representation for radio transmission, providing descriptive user-facing strings for emergency banners, accessibility announcements, and emergency dispatch logs.

### ELI5 Analogy
When responding to a mass-casualty incident or trapped under structural debris, rapid triage classification saves lives. `SOSType` is the 1-byte emergency tag the responder or victim selects to broadcast their exact distress state across the mesh: `medical` (crush injury, severe hemorrhage, respiratory failure), `separated` (rescuer cut off from squad by rising floodwaters or structural collapse), `security` (hazard zone, active electrical fire, structural instability), or `inactivity` (man-down detection triggered by accelerometer stillness indicating unconsciousness).

### Technical Terms Defined
- **RawRepresentable:** A Swift protocol that allows an enum to be converted to and from an underlying primitive type (`UInt8` on the wire).
- **CaseIterable:** A Swift protocol providing an `allCases` collection containing all declared enum cases, enabling dynamic picker UI generation.
- **Inactivity Guard ("Man Down"):** An automated emergency detection mechanism that monitors device motion sensors and flags an emergency if a user remains stationary for an extended period after a suspected fall.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–27: Complete Enum Declaration
```swift
//
//  SOSType.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Payload-free emergency category codes carried in SOS alerts.
public enum SOSType: UInt8, CaseIterable, Codable, Sendable {
    case general   = 0x00
    case medical   = 0x01
    case separated = 0x02
    case security  = 0x03
    case inactivity = 0x04

    public var title: String {
        switch self {
        case .general:   return "General Emergency"
        case .medical:   return "Medical Assistance"
        case .separated: return "Lost / Separated"
        case .security:  return "Security Concern"
        case .inactivity: return "Inactivity / Man Down"
        }
    }
}
```
- **Line 11:** Declares `SOSType` backed by `UInt8`, conforming to `CaseIterable`, `Codable`, and `Sendable`.
- **Lines 12–16:** Defines the 5 emergency categories:
  - `0x00`: `.general` (unspecified or multi-factor crisis)
  - `0x01`: `.medical` (injury, dehydration, asthma, medical distress)
  - `0x02`: `.separated` (disoriented or physically lost in disaster zone)
  - `0x03`: `.security` (physical altercation, theft, harassment, safety threat)
  - `0x04`: `.inactivity` (triggered by automated accelerometer/CoreMotion inactivity detector)
- **Lines 18–26:** `title` computed property returning user-facing display titles for alert overlays.

### Engineering Rationale and Edge Cases
- **Single Byte Footprint:** Using `UInt8` fits the entire emergency taxonomy into a single byte on the wire, conserving precious space in the 30-byte sealed payload slot.
- **Graceful RawValue Fallback:** If an older client encounters a future opcode (such as `0x05`), `SOSPayload.deserialize` falls back gracefully via `SOSType(rawValue: emergencyByte) ?? .general`.

---

---

## 19. Teekum/Teekum/Core/Session/GroupSession.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [GroupSession.swift](../../Teekum/Teekum/Core/Session/GroupSession.swift) |
| **Line Count (`wc -l`)** | 185 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct GroupSession: Identifiable, Equatable, Sendable, Codable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | Core domain model representing an active disaster zone mesh group with 24-bit session ID, symmetric key, and local member profile. |

### What This File Does
`GroupSession.swift` defines the domain model representing an active ephemeral mesh group session. It encapsulates the 24-bit session identifier (`sessionId`), human-readable session name, 256-bit symmetric ChaCha20-Poly1305 encryption key (`symmetricKeyData`), local user initials, preferred profile color code, and session creation timestamp. In addition to state modeling, it provides serverless invite link generation (`meepo://join#...`) and URL regex parsing to enable joining groups without requiring any central authentication servers.

### ELI5 Analogy
Think of `GroupSession` as an encrypted tactical mission manifest and squad credential. It defines the responder's squad identity, tactical callsign initials (e.g. "SAR"), assigned team color, and a high-entropy 256-bit symmetric encryption key (`groupKey`). When two rescue units pair in the staging area, they exchange this deployment profile through an out-of-band QR scan or offline URL whose cryptographic key is securely isolated inside the URL `#fragment`. No external entity—not even an adversary, compromised cellular tower, or rogue radio sniffer—can decrypt squad telemetry or triage status.

### Technical Terms Defined
- **24-bit Session Identifier (`sessionId`):** A compact 3-byte integer identifying the mesh session on the wire (`0x000001` to `0xFFFFFF`), matching the cleartext envelope's SID field.
- **Symmetric Key Data:** A 32-byte (256-bit) cryptographically strong pseudorandom byte sequence used as the root key for ChaCha20-Poly1305 AEAD payload sealing and verification.
- **AutoMesh Secret Seed:** A deterministic pre-shared passphrase (`"TeeKum-disaster zone-AutoMesh-v2-SecretSeed"`) hashed via SHA-256 to allow zero-configuration ad-hoc mesh networking among unconfigured devices.
- **Serverless Invite Link:** A URL scheme (`meepo://join#...`) that carries session credentials entirely client-side.
- **URL Fragment (`#`):** The portion of a URL following the `#` symbol. RFC 3986 specifies that fragments are processed exclusively on the local client and are never sent to remote HTTP servers during web browsing, guaranteeing cryptographic key privacy.
- **Key Fingerprint:** A short 4-byte hexadecimal digest prefix derived from SHA-256 of the symmetric key, displayed in the UI for out-of-band visual verification between peers.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–47: Type Declaration and Properties
```swift
//
//  GroupSession.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CryptoKit

/// Active ephemeral group session model representing local participation.
/// Auto-mesh enabled: connects to nearby peers on a shared disaster zone key.
public struct GroupSession: Identifiable, Equatable, Sendable, Codable {
    public var id: UInt32 { sessionId }
    
    /// 24-bit session hash identifying the active disaster zone network.
    public let sessionId: UInt32
    
    /// Human-friendly name for the session (e.g., "disaster zone Mesh").
    public let sessionName: String
    
    /// 256-bit symmetric key bytes used for authenticated payload encryption.
    public let symmetricKeyData: Data
    
    /// Local user's 3-letter initials (e.g. "DNA").
    public var localInitials: String
    
    /// Local user's preferred 1-byte color code (MemberColor).
    public var localColorCode: UInt8
    
    /// Backward-compatibility alias for display name.
    public var localMemberName: String { localInitials }

    public var localMemberId: MemberID { .fromInitials(localInitials) }
    
    /// True if the user initiated the session (or host role).
    public let isHost: Bool
    
    /// Backward-compatibility slot calculation.
    public var memberSlot: UInt8 {
        let bytes = InitialsCodec.encode(localInitials) ?? [0, 0]
        return bytes[0] ^ bytes[1]
    }
    
    /// Timestamp when session was established.
    public let createdAt: Date
```
- **Lines 13–15:** Declares `GroupSession` conforming to `Identifiable`, `Equatable`, `Sendable`, and `Codable`. Conformance to `Identifiable` uses `sessionId` as the unique ID.
- **Lines 17–23:** Core immutable credentials: `sessionId` (24-bit integer), `sessionName` (String), and `symmetricKeyData` (256-bit raw binary key).
- **Lines 25–29:** Local identity properties: `localInitials` (sanitized 3-character initials) and `localColorCode` (1-byte `MemberColor` raw value).
- **Lines 31–37:** Convenience accessors: `localMemberName`, `localMemberId`, and `isHost`.
- **Lines 40–43:** `memberSlot` computed by XORing the 2 Base-27 encoded bytes of `localInitials`, providing deterministic slot derivation.
- **Lines 45–46:** `createdAt` records establishment time.

#### Lines 48–74: Default Constants and Initializer
```swift
    /// Default shared disaster zone key for auto-mesh.
    public static let defaultSymmetricKeyData: Data = {
        let seed = "TeeKum-disaster zone-AutoMesh-v2-SecretSeed"
        return Data(SHA256.hash(data: Data(seed.utf8)))
    }()
    
    /// Default 24-bit session identifier for the public disaster zone Mesh; matches the three-byte wire SID field.
    public static let defaultSessionId: UInt32 = 0x7E3AF5
    
    public init(
        sessionId: UInt32 = GroupSession.defaultSessionId,
        sessionName: String = "disaster zone Mesh",
        symmetricKeyData: Data = GroupSession.defaultSymmetricKeyData,
        localInitials: String,
        localColorCode: UInt8 = 0x00,
        memberSlot: UInt8? = nil,
        isHost: Bool = true,
        createdAt: Date = Date()
    ) {
        self.sessionId = sessionId & PacketConstants.sessionIdMask
        self.sessionName = sessionName
        self.symmetricKeyData = symmetricKeyData
        self.localInitials = InitialsCodec.sanitize(localInitials)
        self.localColorCode = localColorCode
        self.isHost = isHost
        self.createdAt = createdAt
    }
```
- **Lines 49–55:** Defines default static credentials for zero-touch auto-mesh: `defaultSymmetricKeyData` derived via SHA-256 over `"TeeKum-disaster zone-AutoMesh-v2-SecretSeed"`, and `defaultSessionId = 0x7E3AF5`.
- **Lines 57–74:** Memberwise initializer. Masks `sessionId` with `PacketConstants.sessionIdMask` (`0x00FFFFFF`) to strictly constrain it to 24 bits, and sanitizes initials.

#### Lines 76–103: Serverless Invite URL Generation
```swift
    // MARK: - Serverless Share Link & QR Encoding

    /// Short display fingerprint derived from the key's digest.
    var keyFingerprint: String {
        let prefix = SHA256.hash(data: symmetricKeyData).prefix(4)
        return "0x" + prefix.map { String(format: "%02X", $0) }.joined()
    }
    
    /// Generates a serverless invite URL where the 256-bit key is packed into the URL fragment (#).
    /// Using the URL fragment guarantees that if tapped on the web, the key is never transmitted
    /// to any remote HTTP web server.
    public func inviteURL() -> URL {
        var components = URLComponents()
        components.scheme = "meepo"
        components.host = "join"
        
        var payload = URLComponents()
        payload.queryItems = [
            URLQueryItem(name: "key", value: symmetricKeyData.base64EncodedString()),
            URLQueryItem(name: "sid", value: PacketConstants.formatSessionId(sessionId)),
            URLQueryItem(name: "name", value: sessionName)
        ]
        components.percentEncodedFragment = payload.percentEncodedQuery
        guard let url = components.url else {
            preconditionFailure("Unable to encode a Meepo invite URL.")
        }
        return url
    }
```
- **Lines 79–82:** Generates an 8-character hex fingerprint (`"0x..."`) from the first 4 bytes of the key's SHA-256 hash.
- **Lines 87–103:** Constructs a `meepo://join` URL where `key` (base64-encoded 32-byte key), `sid` (formatted hex string), and `name` are packed strictly into the `percentEncodedFragment` (`#`). This prevents credential leakage over HTTP proxies.

#### Lines 105–185: Regex Link Extraction and URL Parsing
```swift
    public static func extractInviteURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Direct URL parse if the string itself is a clean teekum URL
        if let directURL = URL(string: trimmed),
           let scheme = directURL.scheme?.lowercased(),
           scheme == "meepo" {
            return directURL
        }
        
        // Regex extraction to find meepo:// URL inside any arbitrary text
        let pattern = #"(?i)meepo://join[^\s<>"'\(\)\[\]\{\}]+"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        
        var rawMatched = String(text[range])
        
        // Trim trailing sentence punctuation if accidentally attached
        let trailingPunctuation = CharacterSet(charactersIn: ".,;:!?")
        while let last = rawMatched.unicodeScalars.last, trailingPunctuation.contains(last) {
            rawMatched.removeLast()
        }
        
        return URL(string: rawMatched)
    }
    
    public static func parseInvite(from text: String) -> GroupSessionInvite? {
        guard let url = extractInviteURL(from: text) else { return nil }
        return parseInvite(from: url)
    }
    
    public static func parseInvite(from url: URL) -> GroupSessionInvite? {
        guard let scheme = url.scheme?.lowercased(), scheme == "meepo" else { return nil }
        let host = (url.host ?? "").lowercased()
        guard host == "join" || url.path.lowercased().contains("join") else { return nil }
        
        let rawPayload = (url.fragment?.isEmpty == false ? url.fragment : url.query) ?? ""
        guard !rawPayload.isEmpty else { return nil }
        
        var keyData: Data?
        var sessionId: UInt32?
        var sessionName: String?
        
        let pairs = rawPayload.split(separator: "&")
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0])
            let value = String(parts[1])
            
            switch key {
            case "key":
                let clean = value.removingPercentEncoding ?? value
                keyData = Data(base64Encoded: clean) ?? Data(base64Encoded: clean.replacingOccurrences(of: " ", with: "+"))
            case "sid":
                let clean = value.removingPercentEncoding ?? value
                sessionId = UInt32(clean, radix: 16) ?? UInt32(clean)
            case "name":
                sessionName = value.removingPercentEncoding ?? value
            default:
                break
            }
        }
        
        guard let validKey = keyData, validKey.count == 32,
              let validSid = sessionId, PacketConstants.isValidSessionId(validSid),
              let validName = sessionName else {
            return nil
        }
        
        return GroupSessionInvite(sessionId: validSid, sessionName: validName, keyData: validKey)
    }
```
- **Lines 108–135:** `extractInviteURL(from:)` handles pasted strings containing boilerplate text (e.g. `"Deploy SAR Squad Alpha: meepo://join#..."`). Uses case-insensitive regex `(?i)meepo://join[^\s<>"'\(\)\[\]\{\}]+` and trims trailing sentence punctuation (`.,;:!?`).
- **Lines 138–141:** Convenience bridge parsing from arbitrary text strings.
- **Lines 144–184:** `parseInvite(from:)` verifies `meepo` scheme and `join` host. Extracts query or fragment string, iterates through key-value pairs (`key`, `sid`, `name`), decodes base64 key, parses session ID as hex or integer, and validates:
  - `validKey.count == 32` (256-bit requirement)
  - `PacketConstants.isValidSessionId(validSid)` ($1 \le 	ext{sid} \le 0xFFFFFF$)
  - Non-nil session name. Returns a `GroupSessionInvite` struct.

### Engineering Rationale and Edge Cases
- **Fragment Privacy Architecture:** Putting credentials in the URL fragment (`#key=...`) rather than query parameters (`?key=...`) is an essential zero-trust security pattern. If a user pastes an invite link into a web browser, web servers only receive the base path (`/join`), never the fragment, preventing key harvesting by third parties.
- **Base64 Space-Plus Sanitization:** When URL strings are copied across messaging apps (WhatsApp, iMessage, Slack), `+` characters in base64 strings frequently get converted to spaces. Line 166 defensively handles this via `.replacingOccurrences(of: " ", with: "+")`.

---

---

## 20. Teekum/Teekum/Core/Session/GroupSessionInvite.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [GroupSessionInvite.swift](../../Teekum/Teekum/Core/Session/GroupSessionInvite.swift) |
| **Line Count (`wc -l`)** | 22 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct GroupSessionInvite: Equatable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | Value type representing invitation credentials and QR code payload containing session ID, key fingerprint, and group name. |

### What This File Does
`GroupSessionInvite.swift` defines the decoded representation of an incoming group session invitation received via a URL deep link, QR barcode scan, or clipboard paste. It holds the target session's 24-bit identifier (`sessionId`), friendly name (`sessionName`), and the raw 32-byte symmetric key data (`keyData`) ready for acceptance by the user.

### ELI5 Analogy
Think of `GroupSessionInvite` as a sealed tactical mission briefing packet presented to a volunteer responder before they officially deploy into an operational sector. It specifies the operational incident zone (session ID), the squad designation (e.g., "Sector 4 Search Team"), and the ChaCha20-Poly1305 mission key. Once the responder confirms deployment by tapping "Join Mission", `SessionStore` converts the invitation into an active `GroupSession` and securely vaults the secret key into the iOS Keychain.

### Technical Terms Defined
- **Ephemeral Session Invite:** A transient data container holding credentials extracted from out-of-band channels (QR code, AirDrop, NFC, universal link) awaiting user confirmation.
- **Deep Link Ingestion:** The process of capturing a custom URI scheme (`meepo://`) from an external app or barcode scanner and routing it into the internal application state machine.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–22: Complete Struct Declaration
```swift
//
//  GroupSessionInvite.swift
//  Teekum
//
//  Created by Nicho on 07/11/26.
//

import Foundation

/// Decoded details from a serverless share link or QR barcode invite.
public struct GroupSessionInvite: Equatable, Sendable {
    /// 24-bit session identifier (`0x000001...0xFFFFFF`).
    public let sessionId: UInt32
    public let sessionName: String
    public let keyData: Data
    
    public init(sessionId: UInt32, sessionName: String, keyData: Data) {
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.keyData = keyData
    }
}
```
- **Line 11:** Declares `GroupSessionInvite` conforming to `Equatable` and `Sendable`.
- **Lines 13–15:** Declares three immutable properties: `sessionId` (UInt32), `sessionName` (String), and `keyData` (Data).
- **Lines 17–21:** Standard public memberwise initializer.

### Engineering Rationale and Edge Cases
- **Decoupled Confirmation Model:** `GroupSessionInvite` is intentionally decoupled from `GroupSession`. The app avoids immediately replacing the user's active session upon clicking a link; instead, it populates `SessionStore.pendingInvite` so the UI can present an explicit confirmation prompt ("Do you want to leave your current group and join 'Sector 4 Search Team'?").

---

---

## 21. Teekum/Teekum/Core/Session/MeetingAttendance.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [MeetingAttendance.swift](../../Teekum/Teekum/Core/Session/MeetingAttendance.swift) |
| **Line Count (`wc -l`)** | 34 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value enum (`public enum MeetingAttendance: UInt8, CaseIterable, Codable, Sendable`) |
| **Concurrency Domain** | `Sendable` primitive enum. |
| **Architectural Role** | Domain model tracking member RSVP attendance and arrival status for an active group rendezvous. |

### What This File Does
`MeetingAttendance.swift` defines the domain-level attendance states for the active group rendezvous point. It provides human-readable titles and SF Symbols icon identifiers for SwiftUI presentation, with raw `UInt8` values aligned with the binary `AttendanceStatus` wire protocol codes.

### ELI5 Analogy
When someone in your disaster zone group suggests meeting at the lemonade stand at 7:00 PM, this enum represents your RSVP options on screen: a clock icon for "Pending", a green checkmark for "I'll be there", a red cross for "Can't make it", and a pin marker for "Arrived".

### Technical Terms Defined
- **SF Symbols:** Apple's system-provided icon library integrated directly into SwiftUI via `Image(systemName:)`.
- **Rendezvous Attendance State:** The local and remote status of a peer relative to an agreed meeting point proposal.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–34: Complete Enum Declaration
```swift
//
//  MeetingAttendance.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Payload-free attendance choices for the active group meeting point.
public enum MeetingAttendance: UInt8, CaseIterable, Codable, Sendable {
    case pending  = 0x00
    case accepted = 0x01
    case declined = 0x02
    case arrived  = 0x09

    public var title: String {
        switch self {
        case .pending:  return "Pending"
        case .accepted: return "I'll be there"
        case .declined: return "Can't make it"
        case .arrived:  return "Arrived"
        }
    }

    public var systemImage: String {
        switch self {
        case .pending:  return "clock.fill"
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .arrived:  return "mappin.and.ellipse"
        }
    }
}
```
- **Line 11:** Backed by `UInt8`, conforming to `CaseIterable`, `Codable`, and `Sendable`.
- **Lines 12–15:** Declares the four states:
  - `0x00`: `.pending`
  - `0x01`: `.accepted`
  - `0x02`: `.declined`
  - `0x09`: `.arrived`
- **Lines 17–24:** `title` computed property providing clean user-facing strings.
- **Lines 26–33:** `systemImage` computed property returning standard SF Symbols names (`clock.fill`, `checkmark.circle.fill`, `xmark.circle.fill`, `mappin.and.ellipse`).

### Engineering Rationale and Edge Cases
- **Wire Code Parity:** The raw values (`0x00`, `0x01`, `0x02`, `0x09`) match `AttendanceStatus.swift` byte-for-byte, allowing zero-translation casting between network packets and domain storage.

---

---

## 22. Teekum/Teekum/Core/Session/MeetingPoint.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [MeetingPoint.swift](../../Teekum/Teekum/Core/Session/MeetingPoint.swift) |
| **Line Count (`wc -l`)** | 66 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct MeetingPoint: Identifiable, Equatable, Hashable, Codable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | Domain model representing a group rendezvous point with GPS coordinates, scheduled meetup time, and setter lock ownership. |

### What This File Does
`MeetingPoint.swift` models the single active rendezvous point proposal within a Meepo group session. It stores the meeting point's geographic coordinates, target meetup time, proposer's initials and `MemberID`, landmark association, individual member attendance mapping (`[MemberID: MeetingAttendance]`), arrival radius threshold, and expiration status.

### ELI5 Analogy
Think of `MeetingPoint` as a digital rally flag planted on your group's disaster zone map. The flag has a label ("Sound Booth"), a scheduled meetup time (8:30 PM), a guest list showing who accepted or declined, and an invisible 25-meter geofence circle around it. When you walk inside that circle, your status automatically switches to "Arrived".

### Technical Terms Defined
- **Single Active Meeting Point Rule:** A core product invariant in Meepo stating that only one group rendezvous can be active at any given moment, avoiding coordination confusion in chaotic environments.
- **Geofence Arrival Radius:** A circular distance boundary in meters (between 5m and 100m) around the meeting coordinate. When CoreLocation reports a distance less than this threshold, arrival is triggered.
- **Anchor to Proposer GPS:** A dynamic rendezvous mode where the meeting point follows the proposing user's moving location in real time rather than staying fixed to a static coordinate.
- **Expiry Window:** A 1-hour grace period ($3,600$ seconds) after the scheduled meetup time, after which the meeting point automatically transitions to expired.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–35: Type Declaration and Computed Properties
```swift
//
//  MeetingPoint.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CoreLocation

// Active proposal identity, coordinate, author and attendance data.
// Enforces the single active meeting point rule per group session.
public struct MeetingPoint: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UInt32
    public var name: String
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public var targetTime: Date?
    public let proposerId: MemberID
    public let proposerInitials: String
    public var landmarkId: UInt32?
    public var attendance: [MemberID: MeetingAttendance]
    public let createdAt: Date
    public var isRightNow: Bool
    public var anchorToProposerGPS: Bool
    public var arrivalRadiusMeters: Double

    public var meetupTime: Date { targetTime ?? createdAt }
    public var isExpired: Bool { Date.now.timeIntervalSince(meetupTime) > 3600 }
    public var formattedTitle: String { "\(proposerInitials)'s Rendezvous" }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
```
- **Line 13:** Conforms to `Identifiable`, `Equatable`, `Hashable`, `Codable`, and `Sendable`.
- **Lines 14–26:** Declares properties including `id` (UInt32), `name` (String), `latitude`/`longitude`, optional `targetTime`, `proposerId` (`MemberID`), `proposerInitials`, optional `landmarkId`, `attendance` dictionary, `createdAt`, `isRightNow` flag, `anchorToProposerGPS` flag, and `arrivalRadiusMeters`.
- **Line 28:** `meetupTime` resolves to `targetTime` if set, otherwise falling back to creation time for immediate ("right now") meetups.
- **Line 29:** `isExpired` evaluates whether current time is more than 3,600 seconds (1 hour) past `meetupTime`.
- **Line 30:** `formattedTitle` generates a title string like `"NIC's Rendezvous"`.
- **Lines 32–34:** `coordinate` synthesizes a `CLLocationCoordinate2D` struct from stored latitude and longitude degrees.

#### Lines 36–66: Initializer with Bounds Clamping
```swift
    public init(
        id: UInt32 = UInt32.random(in: 1...UInt32.max),
        name: String,
        coordinate: CLLocationCoordinate2D,
        targetTime: Date? = nil,
        proposerId: MemberID? = nil,
        proposerInitials: String,
        landmarkId: UInt32? = nil,
        attendance: [MemberID: MeetingAttendance] = [:],
        createdAt: Date = .now,
        isRightNow: Bool = false,
        anchorToProposerGPS: Bool = false,
        arrivalRadiusMeters: Double = 25
    ) {
        let cleanInitials = MemberID.sanitizeInitials(proposerInitials)
        let resolvedProposerId = proposerId ?? MemberID.fromInitials(cleanInitials)
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.targetTime = targetTime
        self.proposerId = resolvedProposerId
        self.proposerInitials = cleanInitials
        self.landmarkId = landmarkId
        self.attendance = attendance
        self.createdAt = createdAt
        self.isRightNow = isRightNow
        self.anchorToProposerGPS = anchorToProposerGPS
        self.arrivalRadiusMeters = min(100, max(5, arrivalRadiusMeters))
    }
}
```
- **Lines 36–49:** Parameter list with sensible defaults: random 32-bit ID, default 25m arrival radius, empty attendance table.
- **Lines 50–51:** Sanitizes `proposerInitials` and resolves `proposerId` via `MemberID.fromInitials`.
- **Lines 52–63:** Assigns properties.
- **Line 64:** Clamps `arrivalRadiusMeters` strictly between 5 meters and 100 meters using `min(100, max(5, arrivalRadiusMeters))`.

### Engineering Rationale and Edge Cases
- **Arrival Radius Clamping:** Setting an arrival radius below 5 meters would cause false negatives in disaster zone environments where GPS multipath interference creates 5–10m uncertainty. Conversely, setting it above 100 meters would mark users as "Arrived" while still across an entire disaster evacuation staging area.
- **Setter Lock Protection Support:** By storing `proposerInitials` directly, UI components and services can easily verify whether the local user has authority to edit or cancel the meeting point.

---

---

## 23. Teekum/Teekum/Core/Session/Member.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [Member.swift](../../Teekum/Teekum/Core/Session/Member.swift) |
| **Line Count (`wc -l`)** | 136 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct Member: Identifiable, Equatable, Hashable, Sendable`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | Domain model representing a disaster zone group peer, including telemetry, latest GPS fix, heading, and link reachability state. |

### What This File Does
`Member.swift` represents a peer member participating in an active Meepo group session. It tracks the peer's sanitized initials, display name, latest packet reception timestamp (`lastSeen`), sender hardware GPS measurement timestamp (`measurementTimestamp`), geographic coordinates, horizontal accuracy, emergency distress status, battery percentage, compass heading, direct 1-hop link status (`isDirectPeer`), direct radio RSSI, and personalized `MemberColor`. It also contains multi-stage stale detection logic for triggering AODV on-demand route rediscovery.

### ELI5 Analogy
Think of `Member` as a real-time tactical squad roster card for each responder deployed in the field. The front of the card displays their callsign initials, tactical badge color, live battery percentage (e.g. 84%), magnetic compass heading, and radial distance. The back tracks radio telemetry health: whether their device was heard over a direct 1-hop link (`isDirectPeer`) with strong RSSI (-58 dBm) or routed across multi-hop relay nodes, along with the precise age of their last ping. If a responder's card goes dark for more than 45 seconds, the system automatically flags them as stale and initiates an on-demand AODV search request across the mesh.

### Technical Terms Defined
- **Hardware Measurement Timestamp vs. Last Seen Time:** `measurementTimestamp` is when the peer's GPS hardware actually acquired the fix. `lastSeen` is when the local device received the packet over the mesh radio. Keeping these separate prevents stale buffered packets from overwriting fresh GPS readings.
- **Direct 1-Hop Peer:** A neighboring device within direct Bluetooth/Wi-Fi radio range (`envelope.hopCount == 0`).
- **RSSI (Received Signal Strength Indicator):** The observed radio signal power in dBm (typically $-30$ dBm for right next to the phone to $-90$ dBm at the fringe of reception).
- **Two-Stage Stale Detection Window:** An intelligent recovery state machine:
  - *Stage 1 (Passive Warning):* $t > 30\text{ s}$ (`stalePeerThreshold`).
  - *Stage 2 (AODV Route Discovery):* $45\text{ s} \le t \le 90\text{ s}$ (`staleRouteReqDelay` to `staleRecoveryTimeout`), prompting an active Route Request broadcast.
  - *Unreachable:* $t > $90\text{s}$$, peer is marked as lost contact.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–80: Struct Declaration, Properties, and Initializer
```swift
//
//  Member.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CoreLocation

/// Represents a peer member participating in an active TeeKum group session.
/// Uses the prototype's sanitized initials identity within a session.
public struct Member: Identifiable, Equatable, Hashable, Sendable {
    /// 3-letter uppercase initials identifying the member.
    public let id: String
    
    /// Display name / initials.
    public var name: String
    
    /// Initials accessor.
    public var initials: String { id }
    
    /// Latest local timestamp when a valid authenticated packet was received from this member.
    public var lastSeen: Date

    /// Hardware measurement time, kept separate from packet/peer receipt time.
    public var measurementTimestamp: Date?
    
    /// Latest reported geographical coordinate.
    public var coordinate: CLLocationCoordinate2D?
    
    /// Latest reported horizontal accuracy uncertainty radius in meters.
    public var horizontalAccuracy: CLLocationAccuracy?
    
    /// True if the member has an active Emergency SOS broadcast.
    public var isEmergency: Bool
    
    /// Latest reported battery percentage (0.0 to 1.0).
    public var batteryLevel: Float?
    
    /// Latest reported magnetic compass heading in degrees (0..<360).
    public var heading: CLLocationDirection?
    
    /// True if currently discovered within direct 1-hop radio range; false if reached via multi-hop relay.
    public var isDirectPeer: Bool
    
    /// Signal strength observed on the direct link in dBm (e.g. -65 dBm), if directly connected.
    public var rssi: Int8?
    
    /// Chosen or deterministically resolved personal member color.
    public var color: MemberColor
    
    public init(
        id: String,
        name: String? = nil,
        lastSeen: Date = Date(),
        coordinate: CLLocationCoordinate2D? = nil,
        horizontalAccuracy: CLLocationAccuracy? = nil,
        isEmergency: Bool = false,
        batteryLevel: Float? = nil,
        heading: CLLocationDirection? = nil,
        isDirectPeer: Bool = false,
        rssi: Int8? = nil,
        color: MemberColor? = nil,
        measurementTimestamp: Date? = nil
    ) {
        let cleanId = InitialsCodec.sanitize(id)
        self.id = cleanId
        self.name = name ?? cleanId
        self.lastSeen = lastSeen
        self.measurementTimestamp = measurementTimestamp
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.isEmergency = isEmergency
        self.batteryLevel = batteryLevel
        self.heading = heading
        self.isDirectPeer = isDirectPeer
        self.rssi = rssi
        self.color = color ?? MemberColor.deterministicColor(for: cleanId)
    }
```
- **Lines 13–15:** Declares `Member` conforming to `Identifiable`, `Equatable`, `Hashable`, and `Sendable`. Conformance to `Identifiable` uses sanitized initials `id`.
- **Lines 17–51:** Properties covering identification (`name`, `initials`), timestamps (`lastSeen`, `measurementTimestamp`), spatial state (`coordinate`, `horizontalAccuracy`, `heading`), emergency flag (`isEmergency`), telemetry (`batteryLevel`), link status (`isDirectPeer`, `rssi`), and UI styling (`color`).
- **Lines 53–80:** Initializer sanitizing `id` via `InitialsCodec.sanitize`. If `color` is not explicitly supplied, it computes a stable deterministic color using `MemberColor.deterministicColor(for: cleanId)`.

#### Lines 82–109: Stale Detection and Multi-Stage Recovery
```swift
    /// Determines whether the member's last seen time is older than the given threshold.
    public func isStale(threshold: TimeInterval = MeepoConfiguration.Timing.stalePeerThreshold) -> Bool {
        Date().timeIntervalSince(lastSeen) > threshold
    }
    
    /// Determines whether the member's last seen time is within the active stale probe recovery window.
    /// Active recovery begins after `stalePeerThreshold` (30s) and expires after `stalePeerThreshold + recoveryTimeout` (90s).
    public func isWithinStaleRecoveryWindow(
        now: Date = Date(),
        staleThreshold: TimeInterval = MeshTimingConfiguration.default.stalePeerThreshold,
        recoveryTimeout: TimeInterval = MeshTimingConfiguration.default.staleRecoveryTimeout
    ) -> Bool {
        let age = now.timeIntervalSince(lastSeen)
        return age > staleThreshold && age <= (staleThreshold + recoveryTimeout)
    }
    
    /// Determines whether the member is eligible for Stage 2 on-demand AODV route discovery.
    /// Stage 2 initiates after `stalePeerThreshold + routeReqDelay` (45s) and within recovery timeout (90s).
    public func isEligibleForStaleRouteDiscovery(
        now: Date = Date(),
        staleThreshold: TimeInterval = MeshTimingConfiguration.default.stalePeerThreshold,
        routeReqDelay: TimeInterval = MeshTimingConfiguration.default.staleRouteReqDelay,
        recoveryTimeout: TimeInterval = MeshTimingConfiguration.default.staleRecoveryTimeout
    ) -> Bool {
        let age = now.timeIntervalSince(lastSeen)
        return age >= (staleThreshold + routeReqDelay) && age <= (staleThreshold + recoveryTimeout)
    }
```
- **Lines 83–85:** `isStale(threshold:)` returns true if age $> $30\text{s}$$ (`MeepoConfiguration.Timing.stalePeerThreshold`).
- **Lines 89–96:** `isWithinStaleRecoveryWindow` checks if $$30\text{s}$ < 	ext{age} \le $90\text{s}$$ ($30 + 60$).
- **Lines 100–108:** `isEligibleForStaleRouteDiscovery` tests whether age has reached the Stage 2 threshold of 45 seconds ($30 + 15\text{ s}$) while remaining within the 90s window. When true, the background router issues an automated `RouteReqPayload` to find an alternate multi-hop path.

#### Lines 110–136: Custom Equatable and Hashable Implementations
```swift
    public static func == (lhs: Member, rhs: Member) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.lastSeen == rhs.lastSeen &&
        lhs.measurementTimestamp == rhs.measurementTimestamp &&
        lhs.coordinate?.latitude == rhs.coordinate?.latitude &&
        lhs.coordinate?.longitude == rhs.coordinate?.longitude &&
        lhs.horizontalAccuracy == rhs.horizontalAccuracy &&
        lhs.isEmergency == rhs.isEmergency &&
        lhs.batteryLevel == rhs.batteryLevel &&
        lhs.heading == rhs.heading &&
        lhs.isDirectPeer == rhs.isDirectPeer &&
        lhs.rssi == rhs.rssi &&
        lhs.color == rhs.color
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(lastSeen)
        if let coordinate {
            hasher.combine(coordinate.latitude)
            hasher.combine(coordinate.longitude)
        }
        hasher.combine(isEmergency)
    }
}
```
- **Lines 110–124:** Detailed equality comparator verifying identity, temporal, telemetry, and link fields.
- **Lines 126–135:** Efficient hashing focusing on `id`, `name`, `lastSeen`, coordinate components, and `isEmergency` for fast `Set` and `Dictionary` lookups.

### Engineering Rationale and Edge Cases
- **Why CoreLocation Floating Coordinates are Hashed Manually:** `CLLocationCoordinate2D` does not conform to `Hashable` out of the box in Foundation. `Member.hash(into:)` explicitly combines `latitude` and `longitude` doubles into the hasher, enabling members to be stored in Swift `Set` structures.
- **Staging Route Rediscovery at 45s:** If route requests were sent the instant a peer missed a single 10-second beacon, the mesh would become saturated with discovery spam in dense crowds. Waiting until 45 seconds ($$30\text{s}$ + 15	ext{s}$) ensures rediscovery only triggers for persistent link loss.

---

---

## 24. Teekum/Teekum/Core/Session/MemberColor.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [MemberColor.swift](../../Teekum/Teekum/Core/Session/MemberColor.swift) |
| **Line Count (`wc -l`)** | 84 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value enum (`public enum MemberColor: UInt8, CaseIterable, Identifiable, Sendable`) |
| **Concurrency Domain** | `Sendable` primitive enum. |
| **Architectural Role** | Domain enum defining the 8 selectable member identity colors with hex serialization and SwiftUI color bridges. |

### What This File Does
`MemberColor.swift` manages personal member color-coding across the Meepo application. Designed for AMOLED pure black (`#000000`) dark mode, it defines a vibrant neon disaster zone palette while strictly excluding and reserving Pure Red for Emergency SOS. The file handles wire coding (1 byte), SwiftUI `Color` mapping, backward compatibility with legacy retired swatches, user color picker options, and deterministic djb2 hashing for automatic color assignment when a peer does not select an explicit color.

### ELI5 Analogy
Imagine assigning distinct, high-visibility tactical team markers to search-and-rescue team leads during a zero-visibility night search: Squad Lead 1 gets high-contrast Amber, Squad Lead 2 gets tactical Emerald, and Squad Lead 3 gets rescue Blue. Each squad stands out clearly on tactical satellite maps and directional radar displays. Crucially, no squad member is ever assigned Siren Red (`alertRedFire`)—high-intensity red is strictly reserved across the entire system for life-critical SOS distress beacons and casualty alarms.

### Technical Terms Defined
- **AMOLED Dark Mode Optimization:** High-contrast saturated neon colors paired against pitch black background (`#000000`), reducing display power consumption on OLED screens while maintaining high outdoor visibility.
- **Pure Red Reservation Rule:** A safety design constraint reserving the red color family exclusively for emergency SOS alerts and banners, preventing visual ambiguity during critical incidents.
- **djb2 Hash Function:** A fast, highly-distributed non-cryptographic string hashing algorithm originally created by Daniel J. Bernstein (`hash = ((hash << 5) + hash) + c`), using initial seed 5381.
- **Wire Code Backward Compatibility:** Ensuring that previously assigned wire codes (such as retired swatches `0x02` orangeSalmon or `0x04` apricot) continue to decode gracefully and map to modern visual profiles.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–45: Enum Declaration and Naming
```swift
//
//  MemberColor.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import SwiftUI

/// 1-byte coded color enum for personal member color-coding in TeeKum.
/// Optimized for AMOLED #000000 dark mode with vibrant neon disaster zone colors.
/// Pure Red is intentionally excluded and strictly reserved for Emergency SOS.
public enum MemberColor: UInt8, CaseIterable, Identifiable, Sendable {
    case unset            = 0x00
    case reddish          = 0x01
    case orangeSalmon     = 0x02
    case artyClickOrange  = 0x03
    case apricot          = 0x04
    case sandrift         = 0x05
    case paleBlueLily     = 0x06
    case darkSkyBlue      = 0x07
    case greenishTeal     = 0x08
    case yellow           = 0x09
    case purple           = 0x0A
    case pink             = 0x0B
    
    public var id: UInt8 { rawValue }
    
    public var name: String {
        switch self {
        case .unset:          return "Automatic"
        case .reddish:        return "Reddish"
        case .orangeSalmon:   return "Orange Salmon"
        case .artyClickOrange:return "ArtyClick Orange"
        case .apricot:        return "Apricot"
        case .sandrift:       return "Sandrift"
        case .paleBlueLily:   return "Pale Blue Lily"
        case .darkSkyBlue:    return "Dark Sky Blue"
        case .greenishTeal:   return "Greenish Teal"
        case .yellow:         return "Yellow"
        case .purple:         return "Purple"
        case .pink:           return "Pink"
        }
    }
```
- **Line 13:** Declares `MemberColor` backed by `UInt8`, conforming to `CaseIterable`, `Identifiable`, and `Sendable`.
- **Lines 14–25:** Declares 12 color cases (`0x00` to `0x0B`), including `.unset` (`0x00`).
- **Line 27:** Conformance to `Identifiable` using `rawValue` as `id`.
- **Lines 29–44:** `name` computed property returning descriptive strings (e.g. `"Automatic"`, `"Greenish Teal"`).

#### Lines 46–64: SwiftUI Color Mapping and Selectable Palette
```swift
    /// The display color in SwiftUI.
    public var swiftUIColor: Color {
        switch self {
        case .unset:
            return Color(red: 0.0, green: 0.85, blue: 1.0)
        case .reddish: return .redProfile
        // Retired swatches keep their wire codes so saved and incoming profiles still decode.
        case .orangeSalmon, .pink: return .pinkProfile
        case .artyClickOrange, .apricot, .yellow: return .yellowProfile
        case .sandrift, .paleBlueLily, .darkSkyBlue, .purple: return .purpleProfile
        case .greenishTeal: return .greenProfile
        }
    }
    
    /// Explicit profile colors available to select.
    public static var selectableColors: [MemberColor] {
        [.yellow, .reddish, .greenishTeal, .purple, .pink]
    }
```
- **Lines 47–58:** `swiftUIColor` maps raw enum cases to UI colors. `.unset` maps to bright cyan (`Color(red: 0.0, green: 0.85, blue: 1.0)`). Other cases map to asset catalog color profile tokens (`.redProfile`, `.pinkProfile`, `.yellowProfile`, `.purpleProfile`, `.greenProfile`). Retired swatches are consolidated into active tokens to maintain backward compatibility.
- **Lines 61–63:** `selectableColors` defines the 5 curated colors presented to the user in profile settings (`.yellow`, `.reddish`, `.greenishTeal`, `.purple`, `.pink`).

#### Lines 65–84: Dynamic Resolution and djb2 Deterministic Hashing
```swift
    /// Resolves the color code into a specific `MemberColor`.
    /// If `code == 0x00` (unset / legacy zero-padding) or invalid, deterministically hashes `initials` mod 8.
    public static func resolve(code: UInt8, initials: String) -> MemberColor {
        if let specific = MemberColor(rawValue: code), specific != .unset {
            return specific
        }
        return deterministicColor(for: initials)
    }
    
    /// Uses the original eight-color palette to keep automatic colors stable.
    public static func deterministicColor(for initials: String) -> MemberColor {
        let clean = initials.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return .reddish }
        
        let hash = clean.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
        let index = abs(hash) % 8 // 0...7
        let raw = UInt8(index + 1) // 1...8
        return MemberColor(rawValue: raw) ?? .reddish
    }
}
```
- **Lines 67–72:** `resolve(code:initials:)` checks if `code` is a valid non-unset enum case. If valid, returns it; if `0x00` (unset/legacy), calls `deterministicColor(for: initials)`.
- **Lines 75–83:** `deterministicColor(for:)` cleans the initials and implements the djb2 hashing algorithm:
  - Seed value is 5381.
  - For each UTF-8 byte $c$, accumulates `(($0 << 5) &+ $0 &+ Int(c))`.
  - Calculates `index = abs(hash) % 8` (producing $0..7$).
  - Maps to raw value `raw = UInt8(index + 1)` (producing $1..8$).
  - Returns the corresponding `MemberColor`, defaulting to `.reddish` if empty.

### Engineering Rationale and Edge Cases
- **Why djb2 Hashing is Used for Colors:** Using djb2 provides two critical properties: (1) It produces an identical color on all devices for any given initials string without requiring network negotiation, and (2) It achieves high dispersion across the 8-color palette, minimizing color collisions among small groups.
- **Zero Byte Safety:** When a packet from an older client has `0x00` in the color code byte (legacy zero-padding), `resolve` automatically intercepts it and computes the deterministic color instead of rendering an unassigned state.

---

---

## 25. Teekum/Teekum/Core/Session/MemberID.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [MemberID.swift](../../Teekum/Teekum/Core/Session/MemberID.swift) |
| **Line Count (`wc -l`)** | 41 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`public struct MemberID: Hashable, Codable, Sendable, CustomStringConvertible`) |
| **Concurrency Domain** | `Sendable` value type. |
| **Architectural Role** | Compact member identifier value type binding 1-to-3 character initials with partitioned member slots. |

### What This File Does
`MemberID.swift` defines a stable, unique member identity within an active group session. It encapsulates both a string representation (derived from sanitized initials) and an 8-bit `memberSlot` (`0...255`) utilized for sequence-number bit partitioning in the cleartext envelope. By decoupling member identity from mere display strings, it provides a consistent dictionary key for attendance tracking, message routing, and contact loss logging.

### ELI5 Analogy
Think of `MemberID` as your official disaster zone credentials badge. Your nickname ("NIC") is printed on the front in bold letters so your friends recognize you, but the badge also has an encoded magnetic slot number stamped in the bottom corner. That slot number tells the mesh network which specific transmission frequency lane belongs to you.

### Technical Terms Defined
- **Sequence Number Bit Partitioning:** Allocating the top 8 bits of a 32-bit packet sequence number (`sequenceNumber >> 24`) to hold the sender's member slot, ensuring independent monotonic sequence spaces for up to 256 peers.
- **CustomStringConvertible:** A Swift standard library protocol allowing custom types to provide an explicit string description when printed or interpolated in string literals.
- **Deterministic Slot Derivation:** Computing an 8-bit slot number by XORing the two Base-27 encoded bytes of a member's sanitized initials (`bytes[0] ^ bytes[1]`).

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–23: Struct Declaration and Initializer
```swift
//
//  MemberID.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Stable session member identifier; independent of display initials.
public struct MemberID: Hashable, Codable, Sendable, CustomStringConvertible {
    /// Unique identifier string within the active session (e.g. derived from slot + initials or UUID).
    public let rawValue: String

    /// Assigned 8-bit member slot (0...255) used for sequence-number partitioning.
    public let memberSlot: UInt8

    public var description: String { rawValue }

    public init(rawValue: String, memberSlot: UInt8 = 0) {
        self.rawValue = rawValue
        self.memberSlot = memberSlot
    }
```
- **Line 11:** Declares `MemberID` conforming to `Hashable`, `Codable`, `Sendable`, and `CustomStringConvertible`.
- **Lines 13–16:** Defines immutable properties: `rawValue` (String) representing the identifier string and `memberSlot` (UInt8) representing the sequence partitioning slot.
- **Line 18:** Conforms to `CustomStringConvertible` by returning `rawValue`.
- **Lines 20–23:** Memberwise initializer defaulting `memberSlot` to 0.

#### Lines 25–41: Factory Methods and Slot Derivation
```swift
    /// Creates a deterministic MemberID from sanitized 1-to-3 letter initials and optional slot.
    public static func fromInitials(_ initials: String, slot: UInt8? = nil) -> MemberID {
        let clean = Self.sanitizeInitials(initials)
        let resolvedSlot = slot ?? Self.deriveSlot(from: clean)
        return MemberID(rawValue: clean, memberSlot: resolvedSlot)
    }

    /// Sanitizes arbitrary user input into 1 to 3 uppercase alphanumeric characters (A...Z, 0...9).
    public static func sanitizeInitials(_ input: String) -> String {
        InitialsCodec.sanitize(input)
    }

    private static func deriveSlot(from cleanInitials: String) -> UInt8 {
        let bytes = InitialsCodec.encode(cleanInitials) ?? [0, 0]
        return bytes[0] ^ bytes[1]
    }
}
```
- **Lines 26–30:** `fromInitials(_:slot:)` sanitizes input characters and resolves the slot: if `slot` is omitted, it calls `deriveSlot(from:)`.
- **Lines 33–35:** `sanitizeInitials(_:)` bridges to `InitialsCodec.sanitize(input)` to produce 1 to 3 uppercase characters.
- **Lines 37–40:** `deriveSlot(from:)` encodes the clean initials into 2 Base-27 bytes and returns their bitwise XOR (`bytes[0] ^ bytes[1]`).

### Engineering Rationale and Edge Cases
- **Why XOR Derivation is Deterministic:** In decentralized offline mesh networks without a coordinator to assign slot numbers, XORing the initials' Base-27 bytes allows all receiving nodes to derive the identical slot number without extra protocol handshakes.

---

---

## 26. Teekum/Teekum/Core/Session/SessionHolder.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [SessionHolder.swift](../../Teekum/Teekum/Core/Session/SessionHolder.swift) |
| **Line Count (`wc -l`)** | 19 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Reference type (`final class SessionHolder: @unchecked Sendable`) |
| **Concurrency Domain** | Thread-safe `@unchecked Sendable` synchronized via internal `NSLock`. |
| **Architectural Role** | Observable container holding the active GroupSession instance for reactive SwiftUI view observation. |

### What This File Does
`SessionHolder.swift` provides a thread-safe synchronous snapshot of the active `GroupSession` for background actors, transport delegates, and low-level packet dispatch closures. Because Swift actors can experience reentrancy and async suspension delays, `SessionHolder` allows performance-critical routing and cryptographic routines to inspect the current session credentials synchronously without crossing actor boundaries.

### ELI5 Analogy
Imagine a fast-paced airport security line. If every guard had to stop and radio the main supervisor across the building just to check the flight number, the entire line would grind to a halt. Instead, the supervisor writes the current flight number on a small whiteboard inside a glass lockbox right next to the gate (`NSLock`). Any guard can glance through the glass in a millisecond to verify credentials instantly.

### Technical Terms Defined
- **`@unchecked Sendable`:** A Swift concurrency attribute informing the compiler that a class does not meet automated compiler verification for `Sendable`, but the programmer manually guarantees thread safety through internal synchronization primitives (such as an `NSLock`).
- **`NSLock`:** A fundamental Foundation lock that synchronizes access to a critical section across multiple POSIX threads, blocking calling threads until the lock is acquired.
- **Actor Reentrancy:** A behavior in Swift Concurrency where an actor can interleave execution of another task while awaiting an asynchronous call, potentially modifying internal actor state before the original call resumes.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–19: Complete Class Declaration
```swift
//
//  SessionHolder.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation

/// Synchronous session snapshots for Sendable closures used by actors.
final class SessionHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var value: GroupSession?

    var session: GroupSession? {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}
```
- **Line 11:** Declares `SessionHolder` as `final class` conforming to `@unchecked Sendable`.
- **Lines 12–13:** Holds a private `NSLock` instance and an optional `value: GroupSession?`.
- **Lines 15–18:** `session` computed property provides synchronized thread-safe get and set accessors using `lock.withLock { ... }`.

### Engineering Rationale and Edge Cases
- **Why Synchronous Access is Necessary:** Background network packet dispatch handlers (such as `Network.framework` receive loops) run on low-level dispatch queues and must decrypt datagrams immediately. Awaiting an actor call on the main actor or a high-level manager could introduce queuing jitter and memory backlog; `SessionHolder` delivers sub-microsecond snapshot reads.

---

---

## 27. Teekum/Teekum/Core/Session/SessionPersistence.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [SessionPersistence.swift](../../Teekum/Teekum/Core/Session/SessionPersistence.swift) |
| **Line Count (`wc -l`)** | 43 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Reference type (`@MainActor final class SessionPersistence`) |
| **Concurrency Domain** | `@MainActor` isolated persistence coordinator. |
| **Architectural Role** | Actor managing secure on-disk persistence of active group session credentials and participant metadata. |

### What This File Does
`SessionPersistence.swift` manages the persistent storage and restoration of group session state across application launches. It implements a split-storage architecture: non-sensitive session metadata (session ID, session name, user initials, color code, host role, and creation date) is serialized as JSON in `UserDefaults`, while the highly sensitive 256-bit symmetric encryption key is stored securely in the hardware-backed iOS Keychain via `KeychainStore`.

### ELI5 Analogy
Think of securing your operational gear at an emergency field staging post. You write your unit callsign, squad designation, and operational sector on a laminated duty roster pinned to the command tent noticeboard (`UserDefaults`). But you take your encrypted cryptographic master key and lock it inside a biometric steel vault embedded in the command vehicle's chassis (`iOS Keychain`). If an unauthorized party wanders into the staging area, they might see your unit name, but they cannot access or steal your cryptographic communication keys.

### Technical Terms Defined
- **Split-Storage Architecture:** A security pattern separating public configuration metadata from sensitive cryptographic secrets across different storage subsystems with varying security levels.
- **Keychain Services:** Apple's secure hardware-backed database for storing small, sensitive secrets (passwords, private keys, symmetric tokens) protected by hardware encryption and device passcodes.
- **`UserDefaults`:** A lightweight, unencrypted property-list persistence store suitable only for user preferences and non-sensitive configuration flags.
- **Session Reconstitution:** The process of loading metadata from `UserDefaults`, retrieving the symmetric key from the Keychain, and reconstructing a valid `GroupSession` model.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–20: Class Declaration and Dependencies
```swift
//
//  SessionPersistence.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CryptoKit
import Foundation

@MainActor
final class SessionPersistence {
    private let defaults: UserDefaults
    private let keys: KeychainStore
    private let storageKey = "com.teekum.sessionMetadata"

    init(defaults: UserDefaults = .standard, keys: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keys = keys
    }
```
- **Line 11:** Isolated to `@MainActor`, declared as `final class`.
- **Lines 13–15:** Injects `UserDefaults`, `KeychainStore`, and defines the storage key `"com.teekum.sessionMetadata"`.
- **Lines 17–20:** Initializer providing default instances (`.standard` and `KeychainStore()`).

#### Lines 22–42: Save, Load, and Clear Operations
```swift
    func save(_ session: GroupSession) async throws {
        let data = try JSONEncoder().encode(SessionRecord(session))
        try await keys.storeKeyInKeychain(SymmetricKey(data: session.symmetricKeyData), forSessionId: session.sessionId)
        defaults.set(data, forKey: storageKey)
    }

    func load() async throws -> GroupSession? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        let record = try JSONDecoder().decode(SessionRecord.self, from: data)
        guard let key = try await keys.loadKeyFromKeychain(forSessionId: record.sessionId) else {
            defaults.removeObject(forKey: storageKey)
            return nil
        }
        return record.session(key: key.withUnsafeBytes { Data($0) })
    }

    func clear() async throws {
        let record = defaults.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(SessionRecord.self, from: $0) }
        defaults.removeObject(forKey: storageKey)
        if let record { try await keys.purgeKeyFromKeychain(forSessionId: record.sessionId) }
    }
}
```
- **Lines 22–26:** `save(_:)`: Encodes `SessionRecord(session)` to JSON. Converts `session.symmetricKeyData` to `CryptoKit.SymmetricKey` and writes it to Keychain keyed by `session.sessionId`. Finally writes metadata JSON to `UserDefaults`.
- **Lines 28–36:** `load()`: Reads metadata JSON from `UserDefaults`. If absent, returns `nil`. Decodes `SessionRecord`. Awaits key retrieval from Keychain for `record.sessionId`. If the key is missing from Keychain (e.g., cleared by OS or biometric failure), it cleans up `UserDefaults` and returns `nil`. Otherwise reconstitutes and returns `GroupSession`.
- **Lines 38–42:** `clear()`: Reads existing metadata record to extract `record.sessionId`, removes the entry from `UserDefaults`, and purges the key from Keychain via `keys.purgeKeyFromKeychain`.

### Engineering Rationale and Edge Cases
- **Self-Healing Broken State:** If the app crashed during a previous session clear, or if Keychain items were wiped, `load()` detects that `UserDefaults` has metadata but Keychain lacks the key. Instead of crashing, it purges the orphaned `UserDefaults` record and returns `nil`, presenting the clean pairing screen.
- **Zero Sensitive Data in Backups:** Because `UserDefaults` can be backed up to iCloud or unencrypted iTunes backups, omitting the symmetric key prevents session keys from ever entering backup files.

---

---

## 28. Teekum/Teekum/Core/Session/SessionRecord.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [SessionRecord.swift](../../Teekum/Teekum/Core/Session/SessionRecord.swift) |
| **Line Count (`wc -l`)** | 33 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Value type (`struct SessionRecord: Codable`) |
| **Concurrency Domain** | Implicitly `Sendable` value type. |
| **Architectural Role** | Codable persistence schema used to serialize and restore active session state across app restarts. |

### What This File Does
`SessionRecord.swift` defines the exact data transfer object (DTO) used by `SessionPersistence` for serializing group session metadata into `UserDefaults`. By design, `SessionRecord` holds only public recovery properties (`sessionId`, `sessionName`, `localInitials`, `localColorCode`, `isHost`, `createdAt`) and explicitly excludes the symmetric encryption key, member rosters, location trails, and message history.

### ELI5 Analogy
When you leave a hotel room, `SessionRecord` is the luggage tag tied to your suitcase. It shows your name, room number, and check-in date. It does not contain your room key, your private photos, or the conversations you had in the room.

### Technical Terms Defined
- **Data Transfer Object (DTO):** An object that carries data between processes or subsystems without containing business logic, tailored strictly for serialization.
- **Key-less Serialization:** Deliberately omitting cryptographic keys from serialized models to satisfy the principle of least privilege and zero-knowledge storage.
- **Reconstitution Guard:** Validating that all loaded fields conform to domain protocol invariants before re-creating runtime entities.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–33: Complete Struct Declaration
```swift
//
//  SessionRecord.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation

/// Recovery metadata contains no key, location, roster or conversation history.
struct SessionRecord: Codable {
    let sessionId: UInt32
    let sessionName: String
    let localInitials: String
    let localColorCode: UInt8
    let isHost: Bool
    let createdAt: Date

    init(_ session: GroupSession) {
        sessionId = session.sessionId
        sessionName = session.sessionName
        localInitials = session.localInitials
        localColorCode = session.localColorCode
        isHost = session.isHost
        createdAt = session.createdAt
    }

    func session(key: Data) -> GroupSession? {
        guard PacketConstants.isValidSessionId(sessionId), key.count == 32, InitialsCodec.isValid(localInitials) else { return nil }
        return GroupSession(sessionId: sessionId, sessionName: sessionName, symmetricKeyData: key,
            localInitials: localInitials, localColorCode: localColorCode, isHost: isHost, createdAt: createdAt)
    }
}
```
- **Lines 11–17:** Declares `SessionRecord` conforming to `Codable`. Holds 6 immutable properties representing session metadata.
- **Lines 19–26:** Initializer copying metadata fields from an active `GroupSession`.
- **Lines 28–32:** `session(key:)` combines the stored metadata with a securely loaded 32-byte key:
  - Validates `PacketConstants.isValidSessionId(sessionId)` ($1 \le 	ext{sid} \le 0xFFFFFF$).
  - Validates `key.count == 32` (256-bit requirement).
  - Validates `InitialsCodec.isValid(localInitials)`.
  - Reconstitutes and returns a full `GroupSession` struct, or `nil` on failure.

### Engineering Rationale and Edge Cases
- **Defense in Depth:** Even if an attacker gains access to `UserDefaults` via an unencrypted device backup or debugging dump, `SessionRecord` contains zero cryptographic material. Without physical device access to unlock the Keychain, session communications cannot be decrypted.

---

---

## 29. Teekum/Teekum/Core/Session/SessionStore.swift

### File Metadata
| Attribute | Specification |
| :--- | :--- |
| **Repository-Relative Path** | [SessionStore.swift](../../Teekum/Teekum/Core/Session/SessionStore.swift) |
| **Line Count (`wc -l`)** | 192 lines |
| **File Type** | Swift Source File |
| **Compilation Target** | `Teekum` (Application Target) |
| **Type Semantics** | Reference type (`@MainActor @Observable public final class SessionStore`) |
| **Concurrency Domain** | `@MainActor` observable domain state store. |
| **Architectural Role** | Central observable state store tracking participant rosters, active meeting points, contact loss events, and presence. |

### What This File Does
`SessionStore.swift` is the central observable source of truth for all active session state in the Meepo UI layer. Powered by the modern Swift Observation framework (`@Observable`), it maintains the currently joined `GroupSession`, pending invites, deep link URLs, peer member roster (`[Member]`), unreachable member tracking, contact loss audit log, and the single active group meeting point (`MeetingPoint`). It applies inbound packet updates (`LocationPingPayload`, `SOSPayload`, and transport peer snapshots) to member state, implementing monotonic timestamp guards to prevent stale packet rewinds.

### ELI5 Analogy
Imagine the master tactical status board at an Incident Command Post. The board tracks every responder deployed in the operational sector: their exact GPS coordinates, direct radio link signal strength, battery reserve levels, and whether any unit has triggered an emergency SOS distress beacon. When radio dispatchers receive incoming telemetry, they update the board. Because the board uses automated reactive tracking (`@Observable`), every responder display and situational map refreshes the instant an update is posted.

### Technical Terms Defined
- **`@Observable` (Observation Framework):** A Swift 5.9+ macro that enables property-level tracking for SwiftUI view invalidation without needing `@Published` wrappers or `ObservableObject` protocol boilerplate.
- **Monotonic Measurement Guard:** An update validation rule ensuring that incoming location and heading samples are accepted only if their hardware measurement timestamp is newer than existing recorded data, preventing out-of-order mesh delivery from jumping the user's location backwards.
- **Emergency Visibility Invariant:** A rule stating that peer members with an active emergency (`$0.isEmergency == true`) are never hidden from view, even if their radio signal has been lost past the unreachable cutoff threshold.
- **Contact Loss Auditing:** Logging the exact timestamp when a peer transitions from reachable to unreachable, maintaining a bounded FIFO queue of up to 100 historical contact loss events for diagnostic inspection.

### Code-Block and Line-by-Line Walkthrough
#### Lines 1–49: Class Declaration, Nested Types, and Properties
```swift
//
//  SessionStore.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CoreLocation
import Observation

/// Accepted session state shared by feature ViewModels; owns no background work.
@MainActor
@Observable
public final class SessionStore {
    struct MemberContactLoss: Identifiable, Equatable {
        let id = UUID()
        let initials: Member.ID
        let timestamp: Date
    }

    /// Active group session; nil when unpaired (AppRootView shows Pairing).
    public var activeSession: GroupSession?
    public var pendingInvite: GroupSessionInvite?
    public var pendingDeepLink: URL?

    /// Accepted peer members in the current group session.
    public var members: [Member]

    private var unreachableMemberIDs: Set<Member.ID> = []
    private(set) var memberContactLog: [MemberContactLoss] = []

    var visibleMembers: [Member] {
        members.filter { $0.isEmergency || !unreachableMemberIDs.contains($0.id) }
    }

    /// Single active group meeting point proposal, if any.
    public var activeMeetingPoint: MeetingPoint?

    public var hasActiveSession: Bool {
        activeSession != nil
    }

    func profileColor(for initials: String) -> MemberColor {
        if let activeSession, activeSession.localInitials == initials {
            return .resolve(code: activeSession.localColorCode, initials: initials)
        }
        return members.first { $0.id == initials }?.color ?? .deterministicColor(for: initials)
    }
```
- **Lines 13–15:** Annotated with `@MainActor` and `@Observable`, declared as `public final class`.
- **Lines 16–20:** `MemberContactLoss` model recording member ID and timestamp.
- **Lines 23–29:** Core observable properties: `activeSession`, `pendingInvite`, `pendingDeepLink`, and `members` array.
- **Lines 30–31:** Internal state tracking unreachable member IDs and an audit log of contact losses.
- **Lines 33–35:** `visibleMembers` dynamically filters members: emergency members are guaranteed visibility, while unreachable members without emergencies are filtered out.
- **Lines 38–42:** `activeMeetingPoint` and computed `hasActiveSession`.
- **Lines 44–49:** `profileColor(for:)` resolves the color for any member, prioritizing the active local session color, then roster color, then deterministic djb2 color.

#### Lines 51–100: State Mutations and Packet Ingestion
```swift
    public init(
        activeSession: GroupSession? = nil,
        members: [Member] = [],
        activeMeetingPoint: MeetingPoint? = nil
    ) {
        self.activeSession = activeSession
        self.members = members
        self.activeMeetingPoint = activeMeetingPoint
    }

    // MARK: - State Mutations

    func setEmergency(_ isEmergency: Bool, for initials: Member.ID) {
        guard let index = members.firstIndex(where: { $0.id == initials }) else { return }
        members[index].isEmergency = isEmergency
    }

    func applyLocationPing(_ ping: LocationPingPayload, inbound: InboundPacket) {
        let existing = members.first { $0.id == ping.senderInitials }
        upsertMember(Member(id: ping.senderInitials, lastSeen: inbound.receivedAt, coordinate: ping.coordinate,
            horizontalAccuracy: Double(ping.accuracy), isEmergency: existing?.isEmergency ?? false,
            batteryLevel: Float(ping.batteryLevel) / 100, heading: ping.headingDegrees,
            isDirectPeer: inbound.rawPacket.envelope.hopCount == 0, rssi: inbound.receivedRssi,
            color: .resolve(code: ping.colorCode, initials: ping.senderInitials), measurementTimestamp: ping.timestamp))
    }

    func applySOSLocation(_ payload: SOSPayload, inbound: InboundPacket) {
        let existing = members.first { $0.id == payload.senderInitials }
        let hasLocation = payload.timestamp.timeIntervalSince1970 > 0
        upsertMember(Member(id: payload.senderInitials, lastSeen: inbound.receivedAt,
            coordinate: hasLocation ? payload.coordinate : nil,
            horizontalAccuracy: hasLocation ? Double(payload.accuracy) : nil,
            isEmergency: existing?.isEmergency ?? false, batteryLevel: Float(payload.batteryLevel) / 100,
            heading: existing?.heading, isDirectPeer: inbound.rawPacket.envelope.hopCount == 0,
            rssi: inbound.receivedRssi, color: .resolve(code: payload.colorCode, initials: payload.senderInitials),
            measurementTimestamp: hasLocation ? payload.timestamp : nil))
    }

    func applyPeerSnapshot(_ peers: [PeerInfo], connected: Set<String>) {
        for index in members.indices {
            members[index].isDirectPeer = connected.contains(members[index].id)
        }
        for peer in peers where peer.isGroupMember && peer.isDirectLink && peer.id != activeSession?.localInitials {
            var member = members.first { $0.id == peer.id } ?? Member(id: peer.id, lastSeen: peer.lastSeen)
            member.isDirectPeer = true
            member.rssi = peer.rssi
            member.lastSeen = max(member.lastSeen, peer.lastSeen)
            upsertMember(member)
        }
    }
```
- **Lines 51–59:** Initializer with optional starting state.
- **Lines 63–66:** `setEmergency(_:for:)` modifies emergency flag for a specific member ID.
- **Lines 68–75:** `applyLocationPing(_:inbound:)` maps inbound ping fields to a `Member` struct: extracts coordinate, accuracy, battery, heading, direct peer status (`hopCount == 0`), RSSI, and resolves color code before calling `upsertMember`.
- **Lines 77–87:** `applySOSLocation(_:inbound:)` ingests emergency telemetry, preserving existing heading and updating coordinates.
- **Lines 89–100:** `applyPeerSnapshot(_:connected:)` syncs direct radio connectivity flags from the transport layer.

#### Lines 102–152: Visibility Refresh, Upsert with Monotonic Guard, and Reset
```swift
    func refreshMemberVisibility(now: Date, peers: [PeerInfo]) -> [MemberContactLoss] {
        let timing = MeshTimingConfiguration.default
        let cutoff = now.addingTimeInterval(-(timing.stalePeerThreshold + timing.staleRecoveryTimeout))
        let connected = Set(peers.lazy.filter { $0.isGroupMember && $0.isDirectLink }.map(\.id))
        let unreachable = Set(members.lazy.filter {
            $0.lastSeen < cutoff && !connected.contains($0.id)
        }.map(\.id))
        guard unreachable != unreachableMemberIDs else { return [] }
        let losses = unreachable.subtracting(unreachableMemberIDs).sorted().map {
            MemberContactLoss(initials: $0, timestamp: now)
        }
        unreachableMemberIDs = unreachable
        if !losses.isEmpty {
            memberContactLog.append(contentsOf: losses)
            if memberContactLog.count > 100 {
                memberContactLog.removeFirst(memberContactLog.count - 100)
            }
        }
        return losses
    }

    /// Inserts or updates a member record only if the incoming sample is not older than existing state.
    public func upsertMember(_ incoming: Member) {
        if let index = members.firstIndex(where: { $0.id == incoming.id }) {
            let existing = members[index]
            var accepted = incoming
            if let existingTime = existing.measurementTimestamp,
               incoming.measurementTimestamp.map({ $0 < existingTime }) ?? true {
                accepted.coordinate = existing.coordinate
                accepted.horizontalAccuracy = existing.horizontalAccuracy
                accepted.measurementTimestamp = existingTime
                accepted.heading = existing.heading
            }
            accepted.lastSeen = max(existing.lastSeen, incoming.lastSeen)
            members[index] = accepted
        } else {
            members.append(incoming)
        }
    }

    /// Resets all in-memory session state on leave or expiry.
    public func resetSessionState() {
        activeSession = nil
        pendingInvite = nil
        pendingDeepLink = nil
        members.removeAll()
        unreachableMemberIDs.removeAll()
        memberContactLog.removeAll()
        activeMeetingPoint = nil
    }
}
```
- **Lines 102–121:** `refreshMemberVisibility(now:peers:)` calculates cutoff threshold as $$30\text{s}$ + 60	ext{s} = $90\text{s}$$ ago. Identifies unreachable peers who are not directly connected. If new members became unreachable, it logs `MemberContactLoss` records (capped at a FIFO buffer of 100 entries) and returns them to trigger user alerts.
- **Lines 124–140:** `upsertMember(_:)` implements the Monotonic Measurement Guard. If an existing record exists, it checks if `incoming.measurementTimestamp < existing.measurementTimestamp`. If incoming telemetry is older (due to network delay), it discards incoming spatial data (`coordinate`, `horizontalAccuracy`, `heading`), retaining the newer existing fix while still updating `lastSeen` to `max(existing.lastSeen, incoming.lastSeen)`.
- **Lines 143–151:** `resetSessionState()` cleanly wipes all session, member, and meeting point state upon leaving or session teardown.

#### Lines 154–192: SwiftUI Preview Fixtures
```swift
// MARK: - Preview Fixtures for UI Migration

extension SessionStore {
    /// Ready-to-use fixture store for MainMapView, MeetingPointsView, and FriendDetailView previews.
    public static var preview: SessionStore {
        let baseCoord = CLLocationCoordinate2D(latitude: -6.1988, longitude: 106.8225) // Thamrin / Central Jakarta area

        let session = GroupSession(
            sessionId: 0x4321,
            sessionName: "Fantasix disaster zone Crew",
            localInitials: "DAF",
            isHost: true
        )

        let adiat = Member(id: "ADI", name: "Adiat", coordinate: .init(latitude: baseCoord.latitude + 0.0004, longitude: baseCoord.longitude + 0.0003), horizontalAccuracy: 6, batteryLevel: 0.84, heading: 90, isDirectPeer: true, rssi: -62, measurementTimestamp: .now.addingTimeInterval(-8))
        let nicho = Member(id: "NIC", name: "Nicho", coordinate: .init(latitude: baseCoord.latitude - 0.0005, longitude: baseCoord.longitude + 0.0006), horizontalAccuracy: 12, batteryLevel: 0.65, heading: 180, isDirectPeer: true, rssi: -74, measurementTimestamp: .now.addingTimeInterval(-95))
        let hasan = Member(id: "HAS", name: "Hasan", coordinate: .init(latitude: baseCoord.latitude + 0.0008, longitude: baseCoord.longitude - 0.0004), horizontalAccuracy: 25, batteryLevel: 0.42, heading: 270, measurementTimestamp: .now.addingTimeInterval(-360))

        var meeting = MeetingPoint(
            name: "Main Stage Sound Booth",
            coordinate: CLLocationCoordinate2D(
                latitude: baseCoord.latitude + 0.0002,
                longitude: baseCoord.longitude - 0.0002
            ),
            targetTime: .now.addingTimeInterval(1800),
            proposerInitials: "ADI",
            landmarkId: 1
        )
        meeting.attendance[.fromInitials(adiat.id)] = .accepted
        meeting.attendance[.fromInitials(nicho.id)] = .accepted
        meeting.attendance[.fromInitials(hasan.id)] = .pending

        return SessionStore(
            activeSession: session,
            members: [adiat, nicho, hasan],
            activeMeetingPoint: meeting
        )
    }
}
```
- **Lines 158–191:** Static `preview` fixture configured with Central Jakarta coordinates (`-6.1988, 106.8225`), creating realistic mock members ("Adiat", "Nicho", "Hasan") with varied battery, accuracy, headings, and an active rendezvous point at "Main Stage Sound Booth".

### Engineering Rationale and Edge Cases
- **Out-of-Order Multi-Hop Delivery Protection:** In a wireless mesh network, packet A (sent at 12:00:00) might take a 3-hop path and arrive at 12:00:03, while packet B (sent at 12:00:01) takes a 1-hop direct path and arrives at 12:00:02. Without the `upsertMember` monotonic check, packet A's arrival would overwrite packet B, causing the UI map marker to jump backwards in time.
- **Bounded Audit Log (100 Entries):** To prevent unbounded memory consumption during extended multi-day disaster operations with fluctuating connectivity, `memberContactLog` trims oldest records once count exceeds 100.

---

---

## Footer Navigation

| Navigation Target | Path |
| :--- | :--- |
| **Previous Volume** | [Volume 01: Application Lifecycle, Architecture & Shared UI](01_app_lifecycle.md) |
| **Master Index** | [Volume 00: Index and System Architecture](00_index_and_architecture.md) |
| **Next Volume** | [Volume 03: Transport Layer, Stream Framing & Security](03_transport_and_security.md) |
