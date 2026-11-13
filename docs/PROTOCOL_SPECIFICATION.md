# TeeKum — V3 protocol and cryptographic integration

The migration preserves the `f4c6393` V3 wire construction. See [Session migration](features/session-migration.md) for the comparison, test evidence and unresolved protocol decisions. This is not a security acceptance or a claim of physical interoperability.

## Wire contract

All offsets are zero-based and inclusive. Multi-byte values are big-endian.

| Bytes | Field |
| :--- | :--- |
| 0 | Version in the high nibble (current app uses `0x01`); packet type in the low nibble. |
| 1 | Hop limit, UInt8. |
| 2 | Hop count, UInt8. |
| 3..5 | 24-bit session ID (`0x000001...0xFFFFFF`) in a three-byte big-endian field. |
| 6..9 | Sequence number, UInt32. |
| 10..39 | 30 ciphertext bytes. |
| 40..55 | 16 Poly1305 tag bytes. |

`Core/Packets/RawWirePacket.swift` assembles and parses the frame using `CleartextEnvelope.swift`. Envelope encoding and decoding use the full 24-bit SID (`UInt32` masked to `0x00FFFFFF`); note that the frozen `f4c6393` prototype uses a 16-bit `UInt16` SID with byte 3 zeroed, so session IDs `> 0xFFFF` (including `defaultSessionId = 0x7E3AF5`) do not wire-interoperate with unmodified `f4c6393` builds. The old 54-byte proposals are not compatibility modes. See [Payload guide](PAYLOAD_GUIDE.md) for actual fields. UWB token exchange remains a type code without a connected payload flow.

## Key, AAD and nonce

`CryptoService.seal/open` use CryptoKit ChaChaPoly. `GroupSessionFactory` generates a random 256-bit key for private groups; validated QR/invite data contains the key in the URL fragment. The explicit public festival option uses the inherited shared key, which participants can use to read its messages and locations. `SessionPersistence` stores recovery metadata separately from the device-only Keychain key. Keychain errors are surfaced instead of silently substituting a volatile key cache.

AAD is the ten-byte canonical envelope with hop count masked to zero. The twelve-byte nonce is the three-byte SID, four-byte sequence, version/type byte and ASCII `TKM3`:

```text
sequence = (UInt32(memberSlot) << 24) | counter
nonce    = SID[3] || sequence[4] || versionAndType[1] || TKM3[4]
```

App composition injects one `PacketSequenceAllocator` into location, chat, SOS, meeting and route discovery. It reserves the low 24-bit counter durably before sealing and fails closed on Keychain errors or exhaustion. ACK emitters use the same allocator and routing uses the actual sender slot. Counter records are keyed by a digest of group key, SID and slot and survive leave; group key bytes do not remain in that record. Retransmission of the same encrypted frame does not allocate a new number. A newly sealed retry uses the relevant service's sequence path.

Member slots still use the prototype's initials-derived eight bits. Two devices may collide, especially if initials are reused. Per-device counter persistence does not solve cross-device collision or old implementations that reuse nonces. Keep those decisions separate from the approved local counter fix.

## Authentication, replay and relaying

- A valid group tag proves possession of the shared key. It does not prove individual identity. SID and Bonjour membership are hints, not authentication. Cleartext headers, packet timing and peer discovery metadata remain visible.
- Hop count is mutable. The tag cannot establish the actual distance or prevent a forwarder from changing hop count. Budget, hop and dedup rules are separate controls.
- Own-group content is authenticated before shared state, chat/SOS alerts or ACKs. Chat and ACK have a 600-second age bound; duplicates of authenticated chat/SOS can re-ACK without a second presentation. Location updates keep the original measurement time; an older measurement cannot replace a newer one.
- An SOS measurement timestamp is not the send time. Epoch/255 accuracy denotes the prototype's no-GPS fallback and still produces a receiver alert; the UI does not plot that fallback as a location.
- SOS resolution (`0x09`) uses the same 56-byte frame and sequence allocator. A valid group tag, matching sender slot, sender initials and original event ID are required to clear that event. Resolution received before its SOS suppresses a later alert for that event during the same session. The shared group key still permits a holder to impersonate a member. Older builds reject the new packet type.
- Blind foreign relay does not authenticate ciphertext. The prototype's same-SID opaque SOS fallback remains: a failed tag may still be forwarded within hop/dedup rules, but does not enter group state or alert/ACK handling. Review this rule together with SID collisions.
- Replay checks use the router’s `SeenPacketCache` and the feature engines’ deduplication and age rules. Leave clears their in-memory state. In particular, a captured authenticated SOS can be accepted again after that state is cleared if the same key is rejoined. Do not claim persistent replay protection.

Keep actual keys, invite secrets, private location traces and chat contents out of logs and docs. Changes to layout, identity, key/nonce/counter, relay, ACK or retry behavior require protocol review. The test suite records selected verified cases; on-device behavior and remaining trust/replay decisions are separate work.
