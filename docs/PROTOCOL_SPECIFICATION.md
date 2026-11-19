# Meepo — Wire Protocol and Cryptography

Meepo uses this protocol to exchange relief-post messages and safety alerts across local radio links.

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

`Core/Packets/RawWirePacket.swift` assembles and parses the frame using `CleartextEnvelope.swift`. The envelope stores the full 24-bit SID. See [Payload guide](PAYLOAD_GUIDE.md) for payload fields and example bytes.

## Key, AAD and nonce

`CryptoService.seal/open` use CryptoKit ChaChaPoly. `GroupSessionFactory` generates a random 256-bit key for private relief-post groups. The validated QR/invite data contains the key in the URL fragment, so the invite grants access to group content. `SessionPersistence` stores recovery metadata separately from the device-only Keychain key. Keychain errors are surfaced instead of silently substituting a volatile key cache.

AAD is the ten-byte canonical envelope with hop count masked to zero. The twelve-byte nonce is the three-byte SID, four-byte sequence, version/type byte and ASCII `TKM3`:

```text
sequence = (UInt32(memberSlot) << 24) | counter
nonce    = SID[3] || sequence[4] || versionAndType[1] || TKM3[4]
```

App composition injects one `PacketSequenceAllocator` into location, chat, SOS, meeting and route discovery. It reserves the low 24-bit counter durably before sealing and fails closed on Keychain errors or exhaustion. ACK emitters use the same allocator and routing uses the actual sender slot. Counter records are keyed by a digest of group key, SID and slot and survive leave; group key bytes do not remain in that record. Retransmission of the same encrypted frame does not allocate a new number. A newly sealed retry uses the relevant service's sequence path.

Member slots are eight bits derived from initials. Devices may share a slot, especially when they reuse initials. The persistent counter applies per device, so devices that share a slot and group key can still reuse a nonce.

## Authentication, replay and relaying

- A valid group tag proves possession of the shared key. It does not prove individual identity. SID and Bonjour membership are hints, not authentication. Cleartext headers, packet timing and peer discovery metadata remain visible.
- Hop count is mutable. The tag cannot establish the actual distance or prevent a forwarder from changing hop count. Budget, hop and dedup rules are separate controls.
- Own-group content is authenticated before shared state, chat/SOS alerts or ACKs. Chat and ACK have a 600-second age bound; duplicates of authenticated chat/SOS can re-ACK without a second presentation. Location updates keep the original measurement time; an older measurement cannot replace a newer one.
- A Follow intent uses a reserved ACK subtype with a 60-second age bound. The router checks the sender slot and sequence deduplication before notifying the addressed member. A helper banner additionally requires the matching active SOS event.
- An SOS measurement timestamp is not the send time. Epoch/255 accuracy denotes the no-GPS fallback and still produces a receiver alert; the UI does not plot that fallback as a location.
- SOS resolution (`0x08`) uses the same 56-byte frame and sequence allocator. A valid group tag, matching sender slot, sender initials and original event ID are required to clear that event. Resolution received before its SOS suppresses a later alert for that event during the same session. The shared group key still permits a holder to impersonate a member.
- Blind foreign relay does not authenticate ciphertext. A same-SID SOS with a failed tag may be forwarded within hop and deduplication rules. It cannot update group state, show an alert, or trigger an ACK.
- Replay checks use the router’s `SeenPacketCache` and the feature engines’ deduplication and age rules. Leave clears their in-memory state. In particular, a captured authenticated SOS can be accepted again after that state is cleared if the same key is rejoined. Do not claim persistent replay protection.

Keep actual keys, invite secrets, private location traces and chat contents out of logs and docs. Changes to layout, identity, key/nonce/counter, relay, ACK or retry behavior require protocol review. The test suite records selected verified cases; on-device behavior and remaining trust/replay decisions are separate work.
