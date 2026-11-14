<!--
session-migration.md
Teekum

Created by DIMAS DAFFA ERNANDA on 11/11/26.
-->

# Session migration from `f4c6393`

Reference: clean, read-only `TeeKum-Prototype` at `f4c63936e85dae54f055f57cef3c11cf0f5097f8`. The destination migration started at `796f586c9c09fa15562498fdab266155c9819a80` and landed in `9d9d09b`. Destination paths below reflect the ownership refactor based on `9d9d09b`. See the [Feature Map](../TechnicalRequirements.md#33-feature-map) for entry points and owners. The legacy comparison is against executable callers, including the prototype `SOSViewModel`, rather than similarly named unused imports.

Source paths in the table are relative to each app's Swift source root. **Connected** means app callers are present; only the cases listed under Verification were executed.

| Behavior | Reference | Destination | State / next check |
| :--- | :--- | :--- | :--- |
| Create private group, scan/paste invite, explicit public mesh, leave and restore | App/TeeKumApp.swift; Features/Pairing/ViewModels/GroupSessionViewModel.swift; Core/Models/GroupSession.swift | Features/Pairing; Core/Session; App/SessionController.swift | Adapted and connected. Private keys are random; only the labeled public group uses the shared key. Verify camera and link handling on-device. |
| Session ID, wire and sequence | Core/Models/GroupSession.swift; Core/Messaging/Models/CleartextEnvelope.swift; Core/Mesh/RouteDiscoveryService.swift | Core/Session/GroupSession.swift; Core/Packets; Core/Security/PacketSequenceAllocator.swift | Updated to 24-bit SID (`0x000001...0xFFFFFF`, `%06X` formatting, 3-byte SID input to sequence identity digest). Note: `f4c6393` remains `UInt16`; shared allocator replaces separate counters and routing's constant slot. Wire layout and nonce inputs remain V3. |
| Discovery, radio, carry and relay | Core/Transport/PeerTransportService.swift; Core/Transport/BLEPeerLink.swift; Core/Transport/CarryMessageStore.swift; Core/Messaging/PacketRouter.swift | Core/Transport; Core/Mesh/PacketRouter.swift; Core/Mesh/Relay; Core/Mesh/Routing | Connected. Bonjour TCP plus BLE; bounded foreign relay and 600-second chat/ACK carry. Verify actual discovery, path loss and reconnect with phones. |
| Location, Orbit and friend finding | App/TeeKumApp.swift; Core/Location; Features/Finder/Views/Radar/RadarView.swift | Core/Location; Core/Session/SessionStore.swift; Features/OrbitMap | Adapted and connected. Preserve measurement time separately from reception; use GPS/compass and the visual beacon. The unused UWB token exchange was removed. |
| Chat and recipient ACK | Features/Chat/Services/ChatMessageEngine.swift; Core/Messaging/PacketRouter.swift | Features/Chat; App/SessionController.swift | Connected with UTF-8 limit, history, cooldown, power gate and recipient states. Authenticate before recording; duplicate receipt re-ACKs; app router owns the only forwarding path. |
| SOS and inactivity | Features/SOS/ViewModels/SOSViewModel.swift; Features/SOS/Services/InactivityGuardService.swift | Features/SOS; Core/Notifications/NotificationService.swift | Connected. The sender swipes the SOS control upward by 64 pt and releases to send. Touch reveals a pulsing track and an upward-moving chevron. VoiceOver activation opens a send confirmation. The receiver gets alert and system feedback. Recipient ACK, retry with latest measurement and no-fix support remain connected. The inactivity guard defaults off with a 30 s warning. |
| Meeting point | Features/MeetingPoint/ViewModels/MeetingPointViewModel.swift | Features/MeetingPoint/Services/MeetingPointService.swift; Features/MeetingPoint/Views | Connected. Shared state, setter lock, time options, RSVP, arrival and expiry. Reconnect and simultaneous proposals need device verification. |
| Session companion and diagnostics | Core/LiveActivity/LiveActivityManager.swift; TeeKumWidgets; Features/Diagnostics | Core/LiveActivity; TeekumWidgets; OrbitSettingsView | Companion, connection summary and a bounded packet metadata log connected. Legacy packet injection, virtual debugger UI and report export were not ported. |

`SessionController` owns the session and the one consumer of `inboundPackets`. `PacketRouter` accepts callbacks and has no feature ViewModel dependency. `SessionStore` owns roster and meeting state and applies accepted member updates. Chat and SOS engines own their respective delivery and retry state. On leave, the controller invalidates callbacks, cancels publishers/probes/retries, stops sensor and radio work, clears messages/alerts/routes/replay/carry and ends the activity. Recovery metadata is in UserDefaults; the key is in device-only Keychain. The allocator keeps its counter record after leave so a rejoin with the same key, SID and slot cannot restart it on that phone.

## Remaining Protocol Decisions

- Distinct devices can still share an initials-derived 8-bit slot, and initials themselves can collide. The allocator fixes overlap within a device; it cannot allocate a unique slot across devices. Use distinct initials during device verification. Group-key possession does not prove individual identity.
- The prototype forwards same-SID SOS ciphertext with a failing tag under the existing hop/dedup rule. The destination preserves that opaque path, without displaying an alert or emitting an ACK. Review whether to change it before release; cross-group SID collisions and unverified relay traffic are the tradeoff.
- The active checks use in-memory message/event deduplication, chat/ACK age bounds and a newest-measurement rule. An SOS timestamp is the GPS measurement time. Epoch indicates a missing fix. Key rotation, cross-device counter migration and a stronger replay contract are outside this change.
- Reconnect meeting sync and sender identity follow the legacy packet semantics. An authenticated peer sharing the group key can claim initials; the transport TXT `sid` field alone does not authenticate a member. Review proposer conflict ordering and shared-key trust before hardening those semantics.

## Verification

On 11 November 2026, the ownership refactor based on `9d9d09b` passed `TeekumParity` on iPhone 18 Pro Simulator (iOS 27.2, Xcode 27.2). The scheme built the app and widget and ran **35 destination XCTest cases and 9 prototype cases**, including the same nine contract cases on both. The standalone `Teekum` scheme also passed all 35 destination cases. The prototype worktree stayed clean.

Generate the standalone app with `xcodegen generate --spec project.yml`. For the reference comparison, keep the clean sibling prototype at `f4c6393`, use `xcodegen generate --spec project-parity.yml` and run XCTest with the `TeekumParity` scheme. The optional reference framework compiles the original source in Swift 5 mode and shares `TeekumTests/ParityContractTests.swift` with the destination suite. It is not an app dependency. Use local simulator signing; an unsigned test host cannot access Keychain (`errSecMissingEntitlement`).

The shared cases cover the V3 frame/envelope/nonce/AAD, GPS telemetry, 20-byte UTF-8, BLE fragmentation/carry, urgent queue order, chat final-hop/duplicate ACK, inactivity cancellation, SOS with no GPS, and SOS retry with a newer measurement. Destination-only tests cover the durable counter, Keychain recovery/leave, projection, session and meeting rules, and feature/routing adaptations. The roster test applies out-of-order pings and a no-fix SOS through `SessionStore` and checks that the newest GPS fix survives.

No UI test target was added. Physical Bonjour/BLE, haptics/sound, lock screen/Live Activity, GPS accuracy, map cache, power and end-to-end radio delivery still need device checks. Test private create/join and public mesh separately, including a cold restore and leave/rejoin. A system alert still respects iOS notification permissions, mute and Focus.
