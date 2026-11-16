# Meepo — Networking and Runtime Integration

Meepo uses local radio links to exchange relief-post updates and SOS within a group when internet access is unavailable.

## Offline relay at a relief post

When two participating iPhones can connect directly, a packet can travel between them in one hop. When a recipient is beyond direct reach, an eligible phone in between can receive the packet and forward it over another active link. Each adjacent pair needs iOS Wi‑Fi Aware pairing and a usable link while that transfer takes place.

| Example hop | Route | Illustrative spacing |
| :--- | :--- | :--- |
| 1 | Volunteer at the supply area → relay phone near the walkway | ≈30 m |
| 2 | Relay phone → coordinator at the relief post | ≈30 m |

The distance is illustrative. Obstructions, interference, device state, and relay availability affect connectivity. The implementation's 30 m value is `MeepoConfiguration.Timing.distantDistanceThresholdMeters`. `SessionController.hasDistantMembers` uses it with the latest available GPS measurements, and `LocationService.currentCadenceInterval` uses the result to adjust location publishing. `PacketRouter` bases forwarding on connected links, hop limits, deduplication, and relay eligibility. GPS distance does not set the physical reach of a hop or trigger forwarding.

This route can carry a short supply update or a group SOS without internet. Relay dispatch shows that a phone forwarded the packet. A recipient ACK shows receipt at a group device. If the path breaks, delivery remains unconfirmed. The carry queue can retry supported packet types after reconnection.

## Session ownership

`TeekumApp` retains `SessionController`. After group acceptance or recovery, the controller starts the location service, feature engines, radio and publisher. Its session task consumes `inboundPackets` once and separately observes peer snapshots and runs power/route maintenance. `PacketRouter` owns app forwarding and calls injected feature handlers; it does not import feature ViewModels. Closing a screen has no effect on the radio session.

```text
Wi-Fi Aware TCP → framing → SessionController → PacketRouter
                          → accepted telemetry → SessionStore → Orbit / map
                          → chat / SOS / meeting handlers → feature UI
location / chat / SOS / meeting / routing → sequence + crypto → outbox → radio
```

Leave/rejoin stops the router, cancels the session task and probes, stops publishing and sensors, and resets retry, roster, route, replay and carry state. The transport closes connections and finishes per-session streams; new sessions get new streams. Generation checks reject delayed callbacks from old sessions. The counter's durable Keychain record survives leave.

## Discovery and framing

- Group invites establish the Meepo session and group key. **Group settings → Nearby device pairing** uses DeviceDiscoveryUI and the separate `_meepo-pair._tcp` service to pair each pair of iPhones that needs a Wi‑Fi Aware link. This lets the pairing UI publish while the mesh service is active. iOS manages the pairing records across Meepo sessions.
- `PeerTransportService+Discovery.swift` watches the system's paired devices and publishes and browses `_meepo-mesh._tcp` for that set. Both roles use Wi‑Fi Aware bulk mode. A visible peer with a lost connection is eligible for another dial after a short delay.
- `WiFiAwareLinkHello` sends a 23-byte TCP preface between paired phones. It contains a version, relay flag, 24-bit SID, two-byte initials, and a random 16-byte token for resolving simultaneous dials. Listings use the SID as a group hint. A link between different SIDs is eligible for traffic when both peers permit relaying. A relay toggle refreshes the preface by reconnecting those links.
- `StreamMessageFramer` reads the original 56-byte Meepo frames after the preface. PacketRouter and the feature engines continue to apply packet authentication and delivery rules.
- `project.yml` and `Config/Meepo.entitlements` declare the service and permissions to publish and subscribe. Test the local-network prompt and iOS scheduling on physical devices with a provisioned build.

## Queue, relay and carry

`Core/Transport/PriorityOutboxQueue.swift` drains urgent SOS, SOS resolution, ACK and meeting, FIFO chat, other foreign relay, then coalesced telemetry. Foreign SOS, SOS resolution and ACK use the urgent lane; foreign chat uses the chat lane. Queueing and link sends are not recipient confirmation.

`Core/Mesh/PacketRouter.swift` authenticates own-group updates before callbacks. `SessionStore` applies accepted measurements and peer snapshots. It relays within the existing hop/dedup rules and processes foreign ciphertext without opening it. The opaque SOS fallback for equal SID with failed authentication never produces a local alert or ACK. Foreign relay needs opt-in, sufficient battery and Low Power Mode off; ordinary relay budget is eight per second, with telemetry reservation for reliable traffic. See [Protocol specification](PROTOCOL_SPECIFICATION.md) for residual trust and replay limits.

`CarryMessageStore` retains encrypted chat, ACK, and SOS resolution packets for up to 600 seconds in memory. Custody excludes the inbound peer, increments a received frame's hop once and replays the stored frame on eligible links with shorter intervals for initial attempts and longer intervals afterward. The initial SOS uses its own bounded retry path. Leaving clears the store. The app does not persist chat history.

`Core/Mesh/Routing/RouteDiscoveryService.swift` handles authenticated requests, responses and route invalidation. Its extensions sit in the same folder. The maintenance loop triggers faster updates for stale members and staggered route probes; target arrival can burst location pings. Keep route discovery, request timeouts and late callback cancellation within the session lifetime.

Member departure is inferred from contact loss. Orbit hides a member from its radar and friend list after 90 seconds without contact, unless the member still has a ready group link or an active SOS. A reconnect attempt counts as contact once the link is ready. Fresh location traffic can also make the member visible again. Routing and chat still use the session roster.

Acknowledging an SOS closes the receiver's banner. The red edge glow stays active while any incoming SOS remains unresolved. During an outgoing SOS, the sender has a persistent banner with one action, **End SOS**, which queues the resolution immediately. A queued resolution is retained in memory for up to 10 minutes using the existing carry mechanism. A receiver clears the matching SOS when it receives the resolution.

While the receiver's app is active, the SOS tone and vibration repeat every two seconds before acknowledgment and every 90 seconds afterward. The first reminder is due 90 seconds after acknowledgment. A new SOS returns to the urgent cadence. Resolution of the final pending SOS or session teardown stops the loop. Background reception uses the existing iOS notification.

When a member becomes unreachable, the receiving device shows a **Lost contact** notification and records the member's initials and detection time under **Group settings → Group activity**. Each device detects the loss from its own radio state. The log keeps the latest 100 losses for the active session. Recovery lets a later loss generate a new entry, and leaving clears the log.

## Verification boundary

`OrbitSettingsView` shows the paired-device count, connected peers, Wi‑Fi Aware signal strength when available, and the latest 100 packet events for the active session. Signal strength is Apple's normalized 0–100% indicator. A dispatch entry records local link completion. Recipient confirmation still uses the protocol ACK. Simulator XCTest covers preface validation, framing, queue/carry policy, auth boundaries and selected feature behavior. See the [payload guide](PAYLOAD_GUIDE.md) for wire fields.

### Field test

1. Install the same signed build on compatible physical iPhones. Leave Wi‑Fi enabled and run without internet access. Pair two phones at close range. Use **Make this iPhone discoverable** on one phone, then **Find a nearby iPhone** on the other and select the first phone. The PIN appears after selection. Check that both phones report a paired device and a direct peer.
2. Use the same devices and location as the BLE and peer-to-peer Wi‑Fi baseline. Try 25, 30, 35 and 40 m. Record signal strength where available, chat and SOS delivery, returned ACKs, and whether the phones reconnect when already at the measured distance.
3. Add a third iPhone. Pair A–B and B–C and keep A and C out of direct reach. Send from A to C through B and verify the ACK at A. Repeat with B on another Meepo group and enable relay participation on the phones to exercise opaque forwarding.
4. Test a path break and recovery, locked-screen behavior, and battery impact separately. Use measured link conditions when estimating range for a relief post.
