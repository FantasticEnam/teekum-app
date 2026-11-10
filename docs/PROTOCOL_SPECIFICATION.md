# TeeKum — Imported Protocol and Cryptographic Integration Reference

**Last reviewed: 11 November 2026 · Source-observed V3 construction; security acceptance pending**

> UI/local navigation and imported logic are **not connected**. Some legacy logic/helpers may be missing or partially copied; full parity is unverified. This reference records what the current code attempts and which invariants must be resolved before integration. It is not a build result, security audit, approved release protocol or proof that protected peer exchange works.

Related: [TechnicalRequirements G1–G12](TechnicalRequirements.md#7-open-team-decisions), [NETWORKING.md](NETWORKING.md), [PAYLOAD_GUIDE.md](PAYLOAD_GUIDE.md), [agent.md](agent.md).

## 1. Source and Status

Source paths below are relative to `Teekum/Teekum/`.

| Responsibility | Located source | Status |
| :--- | :--- | :--- |
| Sizes/version/domain tag | Core/Configuration/TeeKumConfiguration.swift; Core/Messaging/Models/PacketConstant.swift | V3, 56-byte frame, 10-byte envelope, 30-byte payload, 16-byte tag, 12-byte nonce. |
| Envelope/AAD/nonce | Core/Messaging/Models/CleartextEnvelope.swift | Separate hop bytes and three-byte SID serialization; decoder still narrows SID to UInt16. |
| Alternate codec | Core/Messaging/Service/PacketCodec.swift | Duplicates envelope assembly/decode; also narrows SID to UInt16. |
| Wire assembly | Core/Messaging/Models/RawWirePacket.swift | Uses CleartextEnvelope path; validates wire/ciphertext/tag sizes. |
| AEAD | Core/Security/Services/CryptoService.swift | Imported ChaChaPoly actor; not assembled by App. |
| Replay | Core/Security/Services/ReplayProtectionFilter.swift | Independent API; UInt16 session cache keys and initials-keyed state remain. |
| Key storage | Core/Security/Services/KeychainStore.swift and Protocols/KeychainStoreProtocol.swift | UInt32 session key API with memory fallback; not called by UI session lifecycle. |
| Routing/feature ingestion | Core/Messaging/Service/PacketRouter.swift; Features/Chat/Services/Extensions; Features/SOS/Services/Extensions | Multiple paths and missing router dependencies; no agreed single runtime consumer. |

Imported comments such as “authoritative,” “guaranteed” and “approved Phase 2” are not inherited team decisions. Validate actual call sites and compare the legacy revision before claiming migration completeness.

## 2. Wire Format Described by Current Serializers

All ranges are zero-based and inclusive. Numeric multi-byte fields use big-endian encoding.

| Wire bytes | Field |
| :--- | :--- |
| 0 | High nibble version=3, low nibble packet type 0x01...0x08 as declared in PacketType. |
| 1 | hopLimit UInt8. Configured maximum currently 15. |
| 2 | hopCount UInt8. |
| 3..5 | Low 24 bits of sessionId UInt32. |
| 6..9 | sequenceNumber UInt32. |
| 10..39 | 30 ciphertext bytes. |
| 40..55 | 16 Poly1305 tag bytes. |

The UWB token type is declared but has no complete payload/feature flow located. Field layouts for the seven located payload structs are in PAYLOAD_GUIDE. Current ping carries sensor telemetry/color, not the old status/target fields. Meeting payload now carries createdAt/radius/flags, not landmarkId.

**Known wire blocker:** Current decode paths truncate the three-byte SID to its low 16 bits and pass that narrowed value toward a UInt32 initializer. GroupSession.id/invite/replay contracts also differ. Source/type reconciliation and high-SID roundtrip/authentication checks are required; a 56-byte count alone does not prove interoperability.

The old 54-byte/nibble-hop and 54-byte/29-byte-payload evolution proposals are historical references, not active supported modes. Do not silently change constants back to them.

## 3. Cryptographic Inputs in Source

### 3.1 Cipher and key handling

CryptoService.seal/open use **CryptoKit.ChaChaPoly** with a supplied SymmetricKey, deterministic nonce and envelope AAD. They require a 30-byte payload/ciphertext and 16-byte tag. Authentication failure in open throws instead of returning plaintext.

Key generation methods using SymmetricKey(size: .bits256) exist. However, imported GroupSession also supplies a deterministic shared default key and stores raw key data in its model; Pairing's local action does not establish production per-group key provisioning. Do not copy the default into new groups or assert private-group separation without an agreed lifecycle.

KeychainStore uses kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly and contains an in-memory fallback for unavailable keychain conditions. This is Keychain storage code, not evidence of a Secure Enclave-bound symmetric key, durable storage on every path or purging on current Leave Group. Neither storage nor key generation is connected to the App's session path.

### 3.2 Associated Authenticated Data

CleartextEnvelope.authenticatedAssociatedData() constructs ten bytes:

```text
AAD byte 0:     version/type
AAD byte 1:     hopLimit
AAD byte 2:     00 (hopCount masked)
AAD bytes 3..5: sessionId, 24-bit big-endian
AAD bytes 6..9: sequenceNumber, 32-bit big-endian
```

Given correctly preserved envelope fields and a valid group key, the tag binds version/type, hopLimit, SID, sequence and ciphertext. A relay can change hopCount without altering the tag because hopCount is omitted from authenticated content.

That also means **the tag does not prove the true traversal count**. A hostile forwarder can lie about/reset this mutable value. An authenticated hopLimit is not proof of immunity to loops, replay or flooding. Cache identity, bounded budgets, neighbor eligibility, rate limits and duplicate handling need their own reviewed enforcement. Relays without the key cannot verify the group tag or authenticate foreign payload content.

### 3.3 Nonce construction

CleartextEnvelope.constructNonce() produces twelve bytes:

```text
Bytes 0..2:  sessionId, low 24 bits
Bytes 3..6:  sequenceNumber, UInt32 big-endian
Byte 7:      version/type
Bytes 8..11: ASCII TKM3 = 54 4B 4D 33 (hex)
```

Sequence construction currently is:

```text
sequenceNumber = (UInt32(memberSlot) << 24) | (counter & 0x00FFFFFF)
```

Nonce uniqueness requires more than this formula. Every message of the same type under the same key/SID must have a unique sequence. The source does not establish that condition:

- GroupSession computes memberSlot by XOR of the two initials-code bytes. Collisions are possible; duplicate initials are also possible.
- LocationPublisher, ChatMessageEngine and SOSForwardingEngine maintain independent counters beginning at 1. LocationPublisher also has its own dispatchSOS method, so more than one component can emit the same SOS type. No shared allocator is connected to prevent overlap.
- The low 24-bit mask allows a counter's wire value to repeat after exhaustion. Using wrapping arithmetic does not make reuse safe.
- Recreating/resetting an engine while keeping the same key/SID can restart its sequence space.
- SID decode truncation can alter both AAD and nonce reconstruction, causing disagreement with the sender.

**Integration requirement:** agree sender allocation, per-type/shared sequence ownership, restart/counter persistence or key rotation, wrap handling and collision/rejoin behavior before using real session keys. Do not claim “mathematically collision-free” from an initials-derived slot or resetting actor alone.

## 4. Identity, Privacy and Replay Boundaries

- SID/Bonjour metadata are routing hints, not authentication. Group-key possession authenticates group-key knowledge; it does not by itself prove which individual member generated a claimed initials/slot value.
- A fixed-length frame does not hide packet type, SID, sequence, hops, timing or Bonjour peer metadata. Payload encryption is not traffic-analysis immunity or a formal zero-knowledge proof.
- Keep keys, full invite secrets, plaintext location traces and chat contents out of documentation, routine diagnostics and production logs. Use test-only material in verified fixtures.
- Imported invite methods live in GroupSession and retain UInt16 parsing/GroupSessionInvite APIs, while newer SID fields are UInt32/24-bit. They accept fragment/query forms. Do not assume link compatibility, safe secret handling or real UI validation merely from these methods existing.

ReplayProtectionFilter has separate methods for duplicate lookup/recording, sender-sequence advancement, measurement freshness and purge. Its default duplicate window and future-skew bound are 300 s; its timestamp age check uses window × 12 (one hour), despite comments implying one window. Sender state is keyed by sanitized initials and packet cache SID is UInt16. These observations are not endorsement of those limits or keys.

CryptoService.open does not call every replay method. SeenPacketCache, chat/SOS duplicate state and router relay caches are additional mechanisms, not automatically one consistent authenticated filter. Define which state is recorded only after authentication and semantic acceptance; untrusted packets must not poison accepted sender state.

## 5. Inbound Paths That Need Reconciliation

| Source path | Observation / review needed |
| :--- | :--- |
| Transport framing | Recognizes/slices fixed frames and yields streams; no AEAD acceptance there. |
| PacketRouter | Refers to missing legacy presenters; ACK/SOS are delegated before common open. Review delegated checks and duplicate/relay side effects before making this the shared entry point. |
| SOSForwardingEngineInbound | Contains session check, open, payload decode, own-sender suppression, ±300 s timestamp check and event-ID duplicate handling before new audio/alert callbacks. Not connected to the UI; not a proof of all lifecycle/replay invariants. |
| ChatMessageEngineInbound | Separate inbound/relay/decode handling. Verify strict payload validation, cache timing, recipient state and cleanup on the actual selected entry path. |
| Payload deserializers | Several accept minimum rather than exact size and default unknown initials/enums. Chat has an additional strict decoder. There is no basis for claiming uniform rejection across all types. |

The required behavior is: structurally validate untrusted frames, authenticate own-group content, enforce the accepted identity/replay/freshness/semantic rules, then mutate shared state or trigger alerts. Foreign relay processing must remain a separately budgeted policy. This is a requirement for the integration PR, not a claim that a fixed six- or ten-step pipeline is already wired.

Do not render a missing/expired GPS fix as a current position. For example, LocationPublisher.dispatchSOS currently has a zero-coordinate/epoch fallback while the SOS inbound path checks a 300-second timestamp window. Decide the agreed unavailable-location semantics and review both sides before connecting an emergency action.

## 6. Session Lifecycle and Configuration

The future integration must explicitly define:

1. Fresh key/session creation versus validated invite join, uniqueness/membership and sender allocation.
2. Retained owners for transport, authenticated ingestion, publishers, feature engines and cache/counter state.
3. Cancellation and purge on leave, expiry, error and rejoin: sockets, sensor/maintenance/retry tasks, chat/SOS history, replay/dedup state, key caches and Keychain entries.
4. Rejection of delayed callbacks from the previous session and safe counter/key restart behavior.
5. Required local-network/Bonjour/motion/URL/background configuration, based on the selected features. It is not currently declared by project.yml beyond camera/When-In-Use location descriptions.

Current Orbit leave resets SessionStore after modal dismissal. It does not implement this imported-service teardown. No recovery/Live Activity/notification runtime should be inferred from old descriptions or approval copy on the Agreement screen.

## 7. Evidence Required Before Accepting Protocol Integration

- Compare the full legacy revision, including missing dependencies/extensions/error paths; mark unknown/partial/deferred items explicitly.
- Reconcile all SID widths and duplicated codec paths; verify high-SID roundtrips and authentication inputs.
- Verify known-input sealing/opening, wrong key, ciphertext/tag/authenticated-header tampering, and the intended mutable hopCount behavior.
- Verify collision/restart/wrap/rejoin cases for slots and counters across every emitter, especially duplicate SOS paths.
- Verify strict bounds and payload semantics, replay/out-of-order/future/stale handling, authenticated recipient ACK versus relay receipt, and cleanup/late callbacks.
- Check the selected routing path without assuming imported comments prove abuse protection, privacy or correct delivery.
- Record actual commands, revision, environment and limits. PacketCodecTest.swift exists but project.yml has no test target/action; this documentation update ran no build, tests or device checks. UI testing is handled by the developer.

Resolve these findings in reviewed source changes before removing the warnings. This guide must not be used by another migration agent as evidence that missing legacy logic has already been restored or that the protocol is release-ready.
