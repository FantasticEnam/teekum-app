# TeeKum — Networking and Runtime Integration

The connected path below is based on prototype `f4c6393` and the destination migration. See [Session migration](features/session-migration.md) for exact baselines, verification and remaining device checks. Source connection and simulator XCTest do not establish physical radio performance.

## Session ownership

`TeekumApp` retains `SessionController`. After group acceptance or recovery, the controller starts the location service, feature engines, radio and publisher. Its session task consumes `inboundPackets` once and separately observes peer snapshots and runs power/route maintenance. `PacketRouter` owns app forwarding and calls injected feature handlers; it does not import feature ViewModels. Closing a screen has no effect on the radio session.

```text
Bonjour TCP / BLE → framing → SessionController → PacketRouter
                          → accepted telemetry → SessionStore → Orbit / map
                          → chat / SOS / meeting handlers → feature UI
location / chat / SOS / meeting / routing → sequence + crypto → outbox → radio
```

Leave/rejoin stops the router, cancels the session task and probes, stops publishing and sensors, and resets retry, roster, route, replay and carry state. The transport closes connections and finishes per-session streams; new sessions get new streams. Generation checks reject delayed callbacks from old sessions. The counter's durable Keychain record survives leave.

## Discovery and framing

- `Core/Transport/PeerTransportService.swift`, `PeerTransportService+Discovery.swift` and `PeerTransportService+Connection.swift` start Bonjour `_teekum._tcp` with peer-to-peer interfaces enabled, TCP keepalive and bounded reconnect. The optional UDP code path exists; the app uses TCP.
- Bonjour service identity comes from initials; TXT fields contain SID, name and relay participation. Same-SID results are candidates, not authenticated members. Foreign connections depend on the local and advertised remote relay switches. Lexical initiator selection and fallback are inherited.
- `StreamMessageFramer` extracts fixed 56-byte frames from partial or coalesced TCP reads. `BLEPeerLink` and `BLEFrameCodec` carry the same frame via Bluetooth fragments. Framing validates structure; payload authentication happens after transport. RSSI is unavailable for the exposed links.
- `project.yml` declares Bonjour, local network, Bluetooth, camera, location, motion, URL scheme and background configuration. Runtime permissions and iOS suspension still apply. This configuration does not guarantee AWDL choice, background delivery, range or battery performance.

## Queue, relay and carry

`Core/Transport/PriorityOutboxQueue.swift` drains urgent SOS/ACK/meeting, FIFO chat, other foreign relay, then coalesced telemetry. Foreign SOS/ACK use the urgent lane; foreign chat uses the chat lane. Queueing and link sends are not recipient confirmation.

`Core/Mesh/PacketRouter.swift` authenticates own-group updates before callbacks. `SessionStore` applies accepted measurements and peer snapshots. It relays within the existing hop/dedup rules and processes foreign ciphertext without opening it. The inherited opaque SOS fallback for equal SID with failed authentication never produces a local alert or ACK. Foreign relay needs opt-in, sufficient battery and Low Power Mode off; ordinary relay budget is eight per second, with telemetry reservation for reliable traffic. See [Protocol specification](PROTOCOL_SPECIFICATION.md) for residual trust and replay limits.

`CarryMessageStore` retains encrypted chat and ACK packets for up to 600 seconds in memory. Custody excludes the inbound peer, increments a received frame's hop once and replays the stored frame on eligible links with the prototype's fast/slow attempt spacing. Leaving clears the store. The app does not persist chat history.

`Core/Mesh/Routing/RouteDiscoveryService.swift` handles authenticated requests, responses and route invalidation. Its extensions sit in the same folder. The maintenance loop triggers the legacy stale-member cadence and staggered route probes; target arrival can burst location pings. Keep route discovery, request timeouts and late callback cancellation within the session lifetime.

## Verification boundary

`OrbitSettingsView` shows the transport snapshot, relay/power state, and the latest 100 packet events for the active session. The log uses header and link metadata and distinguishes packets received with another group ID from relays dispatched on TCP or BLE. A dispatch entry records local link completion and recipient confirmation still uses the protocol ACK. Simulator XCTest covers framing, queue/carry policy, auth boundaries and selected feature behavior. Physical phones are needed to verify radio discovery, multi-hop, reconnect, locked/background behavior, permissions and end-to-end delivery. See [Payload guide](PAYLOAD_GUIDE.md) for wire fields.
