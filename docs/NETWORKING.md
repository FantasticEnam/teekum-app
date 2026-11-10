# TeeKum — Networking and Runtime Integration Reference

**Last reviewed: 11 November 2026 · Static source snapshot, not a working-network report**

> The UI/local navigation and recently imported networking/mesh logic are **not connected**. Some legacy logic, dependencies or configuration may not have been copied, or may only be partially migrated. Full migration parity is unverified. Descriptions below report code that exists; they do not establish successful compilation, authentication, radio operation or delivery.

Read [TechnicalRequirements Section 7](TechnicalRequirements.md#7-open-team-decisions) for blockers, [agent.md](agent.md) for comparison/handoff rules, [PAYLOAD_GUIDE.md](PAYLOAD_GUIDE.md) for fields and [PROTOCOL_SPECIFICATION.md](PROTOCOL_SPECIFICATION.md) for crypto/replay review.

## 1. Current Runtime Boundary

The current App creates SessionStore and passes it through AppRootView to feature UI. It does not construct/start PeerTransportService, PacketRouter, LocationPublisher, ChatMessageEngine, SOSForwardingEngine or InactivityGuardService. Source searches found no constructor wiring for those services in App/feature UI.

```text
Source-visible local UI:
TeekumApp -> SessionStore -> Pairing / Orbit / MapPoint

Imported components awaiting adaptation and explicit assembly:
transport/framing -> authenticated routing -> accepted state -> observing UI
location publisher / chat / meeting / SOS -> codec + crypto -> outbox -> transport
mesh neighbor/routing/forwarding/policy -> explicit lifecycle owner
```

The second group is an integration direction, not an already-connected pipeline. Local Leave Group currently resets SessionStore only. Once services are connected, that reset alone will not stop sockets, publishers, sensor/retry tasks, key storage or stale callbacks.

## 2. Source Map

All paths are relative to `Teekum/Teekum/`.

| Area | Located source | Current evidence |
| :--- | :--- | :--- |
| Peer lifecycle | Core/Transport/Services/PeerTransportService.swift | Actor with start/stop and stream construction; no App caller. |
| Discovery/connections | Core/Transport/Services/Extensions/PeerTransportServiceDiscovery.swift and PeerTransportServiceConnection.swift | Network parameters, Bonjour metadata, tie-breaking, recovery and connection handlers. |
| Framing/transmission | PeerTransportServiceFraming.swift / PeerTransportServiceTransmission.swift in the same Extensions directory; Core/Transport/Services/StreamMessageFramer.swift | Framing, inbound stream yields, queue flush/send paths. |
| Flow control | Core/Messaging/Service/PriorityOutboxQueue.swift | Four queue lanes, coalescing, bounded defaults and retry bookkeeping. |
| Wire/authentication | Core/Messaging/Models; Core/Messaging/Service/PacketCodec.swift; Core/Security | V3/56-byte source, with unresolved SID-width and lifecycle conflicts. |
| Demultiplexing | Core/Messaging/Service/PacketRouter.swift | Legacy feature dependencies not located; not a usable integrated consumer yet. |
| Mesh | Core/Mesh/NeighborManagement, Routing, PacketForwarding, RelayParticipation, RelayDiagnostic and Services | Imported protocols/models/services; no verified assembled topology. |
| Feature engines | Features/Chat/Services and Features/SOS/Services | Imported chat/SOS/inactivity logic; no UI/runtime connection. |

For exact paths and current spelling, use the [source inventory](TechnicalRequirements.md#33-current-folder-structure). Do not recreate old flat Services/ or ViewModels/ trees from earlier docs.

## 3. Discovery and Connection Code

### 3.1 Parameters and service metadata

Source-observed behavior:

- The actor starts with `_teekum._tcp`; start(serviceType:session:) selects UDP if the supplied service type contains `udp`.
- Discovery parameters set includePeerToPeer = true. TCP options request keepalive idle 5 s, interval 2 s, count 3.
- Bonjour advertising uses localInitials as localPeerId/service name. TXT fields include `sid` formatted as eight hex characters, `name` and `relay`.
- Discovery rejects self/prefix matches. Same-session results are group candidates; foreign-session results can remain eligible if local and advertised remote relay switches permit it. A SID TXT match is not cryptographic membership/authentication.
- Peer IDs are compared lexically to prefer one initiator; fallback/reconciliation logic also exists. Duplicate initials and prefix-based self-filtering need identity review, not a “collision-free” claim.

This is Network.framework configuration, not evidence of a specific active radio interface. No direct BLE data transport is implemented by these files. AWDL selection, range, airtime, congestion and behavior without an access point need physical-device verification. Fixed frame length does not establish any measured radio/energy benefit.

### 3.2 Configuration still to integrate

project.yml currently contains camera and When-In-Use location descriptions, but no NSLocalNetworkUsageDescription, NSBonjourServices, motion usage description, URL scheme registration or background-mode declaration. A Widget Extension/Live Activity target is also absent. Configure only what the accepted slice requires; inspect generated settings/device behavior before declaring setup complete.

The optional UDP parameter branch is not proof of a verified datagram path: the current receive extension uses NWConnection.receive and the shared stream framer. Review message boundaries and error handling for the chosen mode before enabling it.

## 4. Framing and Outbox

### 4.1 StreamMessageFramer

The imported framer uses PacketConstants.wirePacketSize, currently **56 bytes**:

- Accumulate chunks; a 20-byte read is incomplete, 112 bytes can hold two frames, and 70 bytes can hold one frame plus 14 bytes.
- When enough bytes exist, inspect the version/type nibble and extract one fixed-size frame.
- Otherwise discard one byte and keep seeking a recognizable header.
- Default maximum buffer is 65,536 bytes; overflow clears it and throws.

Header resynchronization is only framing. It is not tag verification, replay rejection or validation of all payload fields. Some nearby comments still mention obsolete versions/types; current constants and executable branches must be traced together.

### 4.2 Four lanes in PriorityOutboxQueue

| Dequeue priority | Lane | Source default / behavior |
| :--- | :--- | :--- |
| 1 | Urgent | Capacity 16; SOS, ACK, meeting and UWB token types. Overflow throws and increments a drop counter. |
| 2 | Local chat | Capacity 16 FIFO; overflow throws and records a drop. |
| 3 | Stranger relay | Capacity 32 ring-style FIFO; overflow drops the oldest queued relay. |
| 4 | Normal/coalesced | Latest unsent item per destination key; no retry for normal pings. |

Retry insertion and separate engine retries also exist. Review their combined limits rather than reporting one universal retry count. TeeKumConfiguration.Timing.outboxQueueCapacity is 64, but the queue constructor above has separate lane defaults; configuration names alone do not determine runtime capacity.

Enqueue/send completion is not friend delivery. Preserve separate local, next-hop/relay and recipient-confirmed states.

## 5. Inbound Ownership and Authentication Gaps

The framing extension parses frames into RawWirePacket where possible and yields inboundFrames/inboundPackets with source peer, receipt time and nil RSSI. This layer does not decrypt/authenticate the payload. Transport counters are not counts of accepted application updates.

PacketRouter attempts to route same-group and foreign packets, call feature handlers, decrypt and relay. However:

- It references GroupSessionViewModel, SOSViewModel, MeetingPointViewModel, ChatViewModel and NotificationService; definitions were not located in this source tree.
- It is under Core but directly depends on feature engines/ViewModels, contrary to the intended ownership direction.
- ACK/SOS paths delegate before its common decryption branch. Verify the delegated handler's authentication and state-mutation rules; do not assert one uniform validated pipeline.
- Router and PacketForwarder/feature engines provide overlapping relay paths. Decide which owns each packet and cache/budget update to avoid duplicate forwarding or inconsistent rejection.
- SeenPacketCache/ReplayProtectionFilter and source comments do not prove that every inbound type passes replay/freshness checks. Trace actual calls before changing shared state.
- Envelope decode currently loses the upper SID byte. This affects session matching and reconstructed cryptographic inputs, not just display formatting.

A future integration slice must nominate one inbound stream consumer, define validated events/state, and retain/cancel that consumer independently of modal visibility. Do not create a second roster to satisfy the old router API.

## 6. Imported Mesh and Feature Engines

| Component | Imported responsibility to compare with legacy | Not established |
| :--- | :--- | :--- |
| NeighborTable | Registry, activity/health and neighbor events | Live peer association, periodic pruning ownership and field liveness. |
| RoutingTable / RouteDiscoveryService | Route entries, requests/responses, reverse routes and maintenance | Complete legacy helper parity, trusted route inputs or an active maintenance loop. |
| PacketForwarder | Evaluation/dispatch, hop/cache/budget decisions | Selection versus router/engine forwarding paths. |
| RelayPolicyManager / RelayPolicyState | Participation, power policy and telemetry | App consent UX, real power/event feeds and final Phase 1/later scope. |
| SeenPacketCache / ForwardingRateLimiter | Duplicate/cache and token budget helpers | Correct use across every path or protection against hostile mutable hop metadata. |
| LocationPublisher | Observes location stream, creates/seals broadcasts | App start/stop, protocol compatibility and accepted member updates in UI. Current ping is sensor-only despite stale status comments. |
| ChatMessageEngine | Encoding, delivery/retry state and message stream | Chat UI/recipient wiring and current-revision verification. |
| SOSForwardingEngine | Dispatch/inbound authentication/ACK/retries/audio hooks | Connection to the hold callback, warning UI and verified recipient delivery. |
| InactivityGuardService | Disabled-by-default local accelerometer/activity timer and warning callbacks | Touch/resume feed, guard UI/consent, SOS connection or research-backed timing. |

Imported “Phase 2/3,” “approved,” or “guaranteed” comments do not authorize enabling those areas. Resolve scope and record evidence with the responsible owner.

## 7. Diagnostics and Runtime Constraints

TransportDiagnostics declares session/peer state, counters, last error and recent events; peer snapshots currently use nil RSSI. Diagnostic data types exist, but no complete Diagnostics HUD was located. Never synthesize signal strength or authenticated membership from a static label.

Location code includes motion/battery/background-related branches, but the app does not assemble them with transport. Continuous locked-screen reception, SOS delivery while suspended, an offline base map, Live Activity behavior and battery impact are unverified. An indicator, requested API setting or timer does not establish a runtime guarantee.

Current local leave/reset is only UI state cleanup. Before activating imports, define stop/cancel/purge responsibilities for transport, publisher, route/neighbor maintenance, retries, inactivity monitoring, message history, replay caches and keys. Reject previous-session callbacks after rejoin.

## 8. Migration and Verification Handoff

1. Compare the relevant legacy source at a named commit, including extensions/protocols/configuration and error paths. Record missing/partial/unknown items; the full baseline was not available for this review.
2. Resolve model/missing-symbol/SID/key/counter blockers before enabling radio operations.
3. Wire one accepted slice with explicit start/stop and state ownership; update this document with actual call sites.
4. Record build and meaningful packet/transport checks actually run. PacketCodecTest.swift exists but no test target is declared in project.yml; no current pass count is established here. UI testing remains developer-managed.
5. Verify discovery, loss/reconnect, old/future GPS, sharing OFF, peer/recipient ACK, locked/background states and leave/rejoin on physical devices. Report conditions and limits instead of transferring prototype results.

Older 54-byte/nibble-hop diagrams, synthetic authentication dumps, fixed radio ranges and battery-saving percentages were removed from this active reference. Historical proposals can be inspected in Git history; they are not a compatibility mode supported by the current code merely because they once appeared in docs.
