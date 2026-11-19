# Meepo — Technical Requirements

**Fantasix · Product scope updated 15 November 2026**

## 1. Project Overview

Meepo supports initial communication at a disaster relief post while internet or mobile data is unavailable. Relief-post coordinators share local instructions with volunteers and people at the post. Participants exchange short updates on services and supplies, check in with the group, and use meeting points to coordinate at a named location.

- Use a private QR/invite group for relief-post communication. Chat carries short messages and check-ins such as **I'm safe**. Orbit displays the latest available member locations, and meeting-point updates identify a shared destination.
- SOS alerts the local group and displays location when available. **I'll be there!** acknowledges the alert at the receiver. **End SOS** on the sender's device sends the resolution. Official emergency response follows the relief post's established channels.
- Nearby participating iPhones can relay packets along multiple radio links. Use **about 30 m per hop** as the spacing in examples and field trials. Actual links govern forwarding. See [the relay example and runtime limits](NETWORKING.md#offline-relay-at-a-relief-post).
- Team: Fantasix. Developers: Adiat, Daffa, Hasan and Nicho. Designers: Ayu and Ivanna.
- Minimum iOS 27.0, Swift 6, SwiftUI with Observation and Feature-Driven MVVM.
- The product name is **Meepo**. XcodeGen uses the existing `Teekum` project and scheme names and the bundle ID `com.fantasticenam.meepo`.

## 2. Technologies and Configuration

| Framework | Owner and responsibility |
| :--- | :--- |
| SwiftUI / Observation | `App`, `Features` and `Shared/UI` render and observe session/feature state. |
| MapKit | `Features/MeetingPoint/Views/Components/MapLayerView.swift` draws the map and meeting pin. Offline map availability needs device evidence. |
| AVFoundation / UIKit | Pairing's `QRScannerService` and camera preview handle QR scanning. |
| Network / CoreBluetooth | `Core/Transport` manages Bonjour TCP and BLE. [Networking](NETWORKING.md) |
| CryptoKit / Security | `Core/Security` seals/opens payloads, stores session keys and reserves outgoing sequence numbers. [Protocol specification](PROTOCOL_SPECIFICATION.md) |
| CoreLocation / CoreMotion | `Core/Location` collects location/heading. `Features/SOS/Services/InactivityGuardService.swift` owns the opt-in inactivity timer. |
| AudioToolbox / UIKit / UserNotifications | SOS audio and haptics run while the app is active. Local notifications handle alerts when iOS permits background reception. |
| ActivityKit / WidgetKit | `Core/LiveActivity` manages the activity. `TeekumWidgets` renders Lock Screen and Dynamic Island updates for group, chat, and SOS status. |

`project.yml` declares the app, widget and XCTest targets, privacy strings, Bonjour, URL handling, and background modes for location and Bluetooth central/peripheral. The app uses no external Swift dependencies.

## 3. Architecture — MVVM Feature-Driven

### 3.1 Dependency and Ownership

- A View owns presentation, focus and gestures. Its ViewModel exposes feature actions and observable state. Feature services own rules, tasks and retries specific to that feature.
- `App/TeekumApp.swift` retains `SessionController`. The controller assembles dependencies, handles join/restore/leave, and owns the inbound consumer, peer stream and maintenance tasks.
- `Core/Session/SessionStore.swift` owns the accepted roster and meeting point. Its member updates retain the newest measurement separately from receipt time. Chat and SOS delivery state stay in their respective engines.
- Features depend on Core. `Core/Mesh/PacketRouter.swift` takes callbacks from app composition for accepted packets. The router has no ViewModel dependency.
- Group Core files by responsibility and keep extensions beside the type they extend as `Type+Responsibility.swift`. Keep feature-only types inside that feature and wire payload models in `Core/Packets/Payloads`. Use `Shared/UI` for presentation reused across features.

### 3.2 Source Layout

```text
Teekum/Teekum/
├── App/               Session composition and lifecycle
├── Features/
│   ├── Pairing/       Create, join, invite and agreement
│   ├── OrbitMap/      Radar, friends and connection settings
│   ├── MeetingPoint/ Geographic map, meeting rules and RSVP
│   ├── Chat/          Chat UI and delivery
│   └── SOS/           SOS, alerts and inactivity
├── Core/
│   ├── Session/       Identity, roster, shared meeting state and recovery
│   ├── Location/      Sensor samples, adaptive cadence and publishing
│   ├── Packets/       Wire envelope, wire frame and Payloads/
│   ├── Transport/     Bonjour, TCP/BLE, framing, queue and carry
│   ├── Mesh/          Packet dispatch and dedup, with Routing/ and Relay/
│   ├── Security/      Crypto, Keychain and sequence allocation
│   ├── Notifications/
│   ├── LiveActivity/
│   └── Configuration/
└── Shared/            Reusable UI and formatters
TeekumWidgets/         Live Activity UI
TeekumTests/           XCTest and Support/ fixtures
```

### 3.3 Feature Map

Start at the entry point for a screen or action. Follow the owner column when changing behavior.

| Feature or behavior | Entry point | State or behavior owner |
| :--- | :--- | :--- |
| Create/join, QR, link and fingerprint | [GroupPairingView](../Teekum/Teekum/Features/Pairing/Views/GroupPairingView.swift), [GroupQRCodeView](../Teekum/Teekum/Features/Pairing/Views/GroupQRCodeView.swift) | [PairingViewModel](../Teekum/Teekum/Features/Pairing/ViewModels/PairingViewModel.swift), [GroupSessionFactory](../Teekum/Teekum/Features/Pairing/Services/GroupSessionFactory.swift), [GroupSession](../Teekum/Teekum/Core/Session/GroupSession.swift) |
| Agreement, restore and leave | [AgreementView](../Teekum/Teekum/Features/Pairing/Views/AgreementView.swift), [AppRootView](../Teekum/Teekum/App/AppRootView.swift) | [SessionController](../Teekum/Teekum/App/SessionController.swift), [SessionPersistence](../Teekum/Teekum/Core/Session/SessionPersistence.swift) |
| Orbit markers, Friend List highlight and SOS finder | [OrbitMapView](../Teekum/Teekum/Features/OrbitMap/Views/OrbitMapView.swift), [FriendListSheet](../Teekum/Teekum/Features/OrbitMap/Views/FriendListSheet.swift) | [OrbitMapViewModel](../Teekum/Teekum/Features/OrbitMap/ViewModels/OrbitMapViewModel.swift), [OrbitProjection](../Teekum/Teekum/Features/OrbitMap/Models/OrbitProjection.swift), [SessionStore](../Teekum/Teekum/Core/Session/SessionStore.swift) |
| GPS, heading and outgoing pings | [LocationService](../Teekum/Teekum/Core/Location/LocationService.swift), [LocationPublisher](../Teekum/Teekum/Core/Location/LocationPublisher.swift) | `Core/Location` for cadence and sending, `SessionStore.applyLocationPing` for accepted peer measurements |
| Set, show and cancel meeting point, RSVP | [MainMapView](../Teekum/Teekum/Features/MeetingPoint/Views/MainMapView.swift), `OrbitMapView` for its marker | [MeetingPointViewModel](../Teekum/Teekum/Features/MeetingPoint/ViewModels/MeetingPointViewModel.swift), [MeetingPointService](../Teekum/Teekum/Features/MeetingPoint/Services/MeetingPointService.swift), `SessionStore.activeMeetingPoint` |
| Send chat and track recipient ACK | [ChatSheetView](../Teekum/Teekum/Features/Chat/Views/ChatSheetView.swift) | [ChatViewModel](../Teekum/Teekum/Features/Chat/ViewModels/ChatViewModel.swift), [ChatMessageEngine](../Teekum/Teekum/Features/Chat/Services/ChatMessageEngine.swift) and its inbound/outbound/delivery extensions |
| SOS swipe, receiver alert, sound/haptics and retry | [SOSSwipeButtonView](../Teekum/Teekum/Features/SOS/Views/SOSSwipeButtonView.swift), [IncomingSOSAlertBannerView](../Teekum/Teekum/Features/SOS/Views/IncomingSOSAlertBannerView.swift) | [SOSViewModel](../Teekum/Teekum/Features/SOS/ViewModels/SOSViewModel.swift), [SOSForwardingEngine](../Teekum/Teekum/Features/SOS/Services/SOSForwardingEngine.swift), [DefaultSOSAudioAlerter](../Teekum/Teekum/Features/SOS/Services/DefaultSOSAudioAlerter.swift) |
| Inactivity opt-in and countdown | [InactivitySettingsView](../Teekum/Teekum/Features/SOS/Views/InactivitySettingsView.swift), [InactivityWarningView](../Teekum/Teekum/Features/SOS/Views/InactivityWarningView.swift) | [InactivityGuardService](../Teekum/Teekum/Features/SOS/Services/InactivityGuardService.swift), `SOSViewModel` |
| Discovery, framing and carry | [PeerTransportService](../Teekum/Teekum/Core/Transport/PeerTransportService.swift) | `Core/Transport` owns Wi-Fi/BLE links, framing, priority queue and carry |
| Relay and route discovery | [PacketRouter](../Teekum/Teekum/Core/Mesh/PacketRouter.swift) | [RelayPolicyManager](../Teekum/Teekum/Core/Mesh/Relay/RelayPolicyManager.swift), [RouteDiscoveryService](../Teekum/Teekum/Core/Mesh/Routing/RouteDiscoveryService.swift), [SeenPacketCache](../Teekum/Teekum/Core/Mesh/SeenPacketCache.swift) |
| Wire bytes, key and sequence | [RawWirePacket](../Teekum/Teekum/Core/Packets/RawWirePacket.swift), [CleartextEnvelope](../Teekum/Teekum/Core/Packets/CleartextEnvelope.swift) | [CryptoService](../Teekum/Teekum/Core/Security/CryptoService.swift), [PacketSequenceAllocator](../Teekum/Teekum/Core/Security/PacketSequenceAllocator.swift) |
| Connection diagnostics and packet log | [OrbitSettingsView](../Teekum/Teekum/Features/OrbitMap/Views/OrbitSettingsView.swift) | [PeerTransportService+Diagnostics](../Teekum/Teekum/Core/Transport/PeerTransportService+Diagnostics.swift), [TransportDiagnostics](../Teekum/Teekum/Core/Transport/TransportDiagnostics.swift) |
| Lost-contact notification and Group activity log | [OrbitSettingsView](../Teekum/Teekum/Features/OrbitMap/Views/OrbitSettingsView.swift) | [SessionStore](../Teekum/Teekum/Core/Session/SessionStore.swift) records losses. [SessionController](../Teekum/Teekum/App/SessionController.swift) sends notifications. |
| Live Activity | [LiveActivityManager](../Teekum/Teekum/Core/LiveActivity/LiveActivityManager.swift), [TeekumWidgets](../TeekumWidgets) | `SessionController` drives updates and teardown. Widget verification requires a device. |

Tap a member marker in Orbit or select a member in the Friend List to follow them. Overlapping Orbit markers share a +N badge, and split as soon as the projected circles have enough room. The badge follows the group’s bearing as the device rotates. Tap it to reveal the members and select one to follow. The badge keeps an SOS outline when a member in the group has an active SOS. Members beyond the outer ring keep the bloom treatment.

### 3.4 Session Data Flow

`GroupPairingView` pushes Agreement. Accepting activates the session and the root shows Orbit. Closing the friends or map modal returns to Orbit. Confirming Leave calls `SessionController.leave()`, which tears down session work and returns to Pairing.

Radio → transport framing → `SessionController` → `PacketRouter` → authenticated callbacks → shared state or feature engine → observing UI. The outgoing location, chat, SOS, meeting and route paths use the shared sequence allocator and crypto before transport queues.

Session restore reads metadata from UserDefaults and the group key from the device Keychain. Chat history and the relay carry queue are in memory. Orbit uses GPS and heading to place members and the meeting point. Member and local user circles share a 36-point base diameter and contain their profile nicknames. The map pin sits above Chat. The rounded friends panel shows your nickname on the left and up to four friends on the right. When more than four friends are visible, the last slot shows the number of friends whose names are hidden. Tap the panel or swipe up on it to open the friends sheet. While following a friend, the panel shows their nickname, current straight-line distance, and progress relative to the first available distance after starting Follow. The dot moves back if the distance increases. When Follow starts, the friends slide toward the target avatar and the track fades in from the left. Stop reveals the room roster again. A missing coordinate shows a waiting state. The Orbit header shows the room count below the group name. It counts you and all currently visible members. In the friends sheet, the invite button beside search opens Share Invite QR. Your profile aligns with the first column of the friend grid, and the empty state is centered in the list area. The panel and sheet pulse red on any avatar with an active SOS, including your own. The panel prioritizes active SOS members when it has more friends than slots. With Reduce Motion enabled, those avatars stay red. Labeled distance rings provide the visible distance scale for friends. A yellow battery indicator appears below a marker only at 10% or less, including the local user. A filled profile-colored direction pointer shows a friend’s received heading relative to the local heading. Distance rings and markers share one points-per-metre scale. Friends beyond the largest labeled ring render as profile-colored glows and can project up to 20 points past it. Marker initials, direction pointers, battery indicators and selection/SOS outlines appear within the ring boundary. The complete local marker, including its nickname and direction arrow, renders above member markers and target lines. While Orbit is visible in the active app, it enables the existing tactical radar GPS profile with navigation accuracy and no distance or heading filter. Leaving Orbit or putting the app in the background restores adaptive sampling. Location publishing targets 4 seconds while moving and 20 seconds while stationary, with the existing 2-second distant/stale recovery and 60-second low-battery/Low Power Mode overrides. Movement classification follows the prototype Core Motion path, with GPS speed as a fallback when Core Motion is unavailable. Pending location ticks coalesce to the newest fix, and the publisher reads the latest available GPS measurement before encoding a tick. Radar sampling is reapplied when session tracking starts, including when Orbit appeared before session preparation completed. Packets preserve the original measurement timestamp. The zoom scale starts at 15 m and pinching adjusts it between 5 and 120 m. Orbit initially shows 5 m, 10 m and 15 m circles. Circles resize continuously during zoom. Ring lines and their labels fade with the gray radial background and disappear beyond its edge. Ring intervals adapt through 5, 10, 20 and 50 m to keep a maximum of four circles, with each distance label beneath its ring’s lower edge.

Orbit shows gray in-app banners for incoming chat, a new meeting point, and a friend choosing Follow. Tap a chat banner to open the conversation or swipe it up to dismiss it. When someone follows a member with an active SOS or taps “I’ll be there,” the SOS sender sees a red banner naming the helper. “Okay” dismisses that notice and returns to the active SOS banner. Only “End SOS” sends a resolution.

### 3.5 Four-Developer Collaboration Baseline

| Role | Scope | Review boundary |
| :--- | :--- | :--- |
| A | Pairing, session identity, invites, app composition and recovery | B reviews protocol/security. Feature owners review shared models. |
| B | Transport, packet/security contracts, mesh and diagnostics data | A reviews key/session changes. C/D review consumers. |
| C | Orbit, friends, geographic UI, location and power | A reviews lifecycle. B reviews telemetry mapping. |
| D | Meeting behavior, chat, SOS and inactivity | B reviews delivery contracts. C reviews location/UI integration. |

See the [developer guide](agent.md#4-documentation-and-handoff) for the review handoff.

## 4. Verification Plan

- Run XCTest from the `Teekum` scheme with local simulator signing for Keychain access. Coverage includes session recovery, packet encoding and authentication, sequence allocation, framing and relay, Orbit projection, meeting points, chat acknowledgments, and SOS. An existing envelope fixture still expects byte `0x31` while the app emits `0x11`. See [payload encoding](PAYLOAD_GUIDE.md#5-envelope-and-nonce-example) for the current format.
- Keep UI verification manual. Exercise create/join, restore, location and Orbit, chat, meeting, SOS and leave/rejoin on physical iPhones. Use physical devices for Bonjour/BLE, backgrounding, GPS, Live Activity and notification feedback.
- Verify the relief-post workflow with three physical iPhones and internet access unavailable. Exercise a direct link, then a path through a relay with the endpoints out of direct reach. Start with roughly 30 m between adjacent phones where conditions allow. Record the actual distances, link conditions, dispatch, and recipient ACK. Repeat with the relay removed and check how the UI reports incomplete delivery. Verify that a receiver's SOS alert clears only after its device receives the sender's resolution.
- Verify QR and pasted invitations separately from opening a shared link directly. The invite parser accepts `meepo://join`, while the generated project registers `teekum` for system URL handling.
- Record the revision, environment, command and result. Simulator tests establish selected logic contracts. Device runs establish radio and sensor behavior in the tested conditions.

## 5. Git Workflow

The following is the team's intended workflow; it does not establish that branch protection or delivery automation has been configured.

The team uses two protected branches, `develop` and `main`, plus short-lived `f/ui/*` and `f/logic/*` branches. UI slicing and logic implementation are separate work scopes.

### 5.1 Branches

| Branch | Purpose | Who can push directly? | Protected? |
| :--- | :--- | :--- | :--- |
| `main` | Stable release candidates and the source for TestFlight and App Store delivery. | None (PR only). | Protected. |
| `develop` | Integrate features and run CI build and test checks. TestFlight uploads are disabled for this branch. | None (PR only). | Protected. |
| `f/ui/<feature>` | UI slicing, components, presentation state and navigation, branched off `develop`. | Feature developer. | Unprotected. |
| `f/logic/<feature>` | Feature logic and service/data integration, branched off `develop` after the relevant contracts are discussed. | Feature developer. | Unprotected. |

### 5.2 Branch Diagram

```text
f/ui/<feature> ─────┐
                   ├─→ PR to develop (CI checks) → PR to main
f/logic/<feature> ──┘                                  └─→ TestFlight → approval → App Store
```

### 5.3 Merging Rules

| Merge | When does it happen? | Who does it? | What must be true first? |
| :--- | :--- | :--- | :--- |
| `f/ui/*` → `develop` | The declared UI slice is complete and reviewed locally. | PR owner. | Code review approved; include UI verification evidence and identify placeholders. UI completion does not imply logic completion. |
| `f/logic/*` → `develop` | The declared logic/integration scope is complete and verified locally. | PR owner. | Relevant contracts reviewed, code review approved and applicable local checks pass. |
| `develop` → `main` | Milestone features are verified as a stable release candidate. | Integration PIC. | Full offline peer-to-peer verification succeeds on physical devices. |

### 5.4 Step by Step: How One Feature Moves Through Our Workflow

1. Developer creates `f/ui/<feature>` for UI slicing or `f/logic/<feature>` for logic work from the latest `develop`. List any prerequisite PRs when the slice depends on other work.
2. Implements focused changes within the declared UI or logic scope. A UI PR may include presentation state and navigation; it must label mock data and unconnected actions.
3. Opens a Pull Request (PR) to `develop` detailing changes and verification evidence.
4. Reviewer reviews code; developer addresses feedback before merging.
5. Stable features are promoted from `develop` to `main` via PRs.
6. The Release PIC starts the TestFlight workflow from `main` after CI checks pass. Record the source commit, app version, and build number.
7. After TestFlight validation and release approval, the Release PIC selects that same App Store-eligible build for submission. Tag the corresponding release commit on `main`.

### 5.5 Naming and Commit Conventions

**Branch naming:** `f/ui/<feature>` or `f/logic/<feature>`. Use lowercase and hyphens for the feature name (*kebab-case*). Examples:

| Feature | UI slicing | Logic/integration |
| :--- | :--- | :--- |
| Orbit map | `f/ui/orbit-map` | `f/logic/orbit-map` |
| Pairing and group QR | `f/ui/pairing-group-qr` | `f/logic/pairing-group-qr` |
| Geographic map and meeting point | `f/ui/map-point` | `f/logic/map-point` |

The `f/` branch prefix does not change the conventional commit types below.

**Commit message format:** `type: short description` or `type(scope): short description`.  

| Type | Usage | Example |
| :--- | :--- | :--- |
| `feat:` | New application feature or behavior. | `feat(radio): add network.framework p2p transport` |
| `fix:` | Bug fix or corrected behavior. | `fix(packet): correct int32 coordinate quantization` |
| `docs:` | Documentation updates. | `docs: update technical requirements wire protocol` |
| `refactor:`| Code restructuring without visual or functional changes. | `refactor(crypto): isolate keychain storage actor` |
| `chore:` | Repository maintenance, build settings, or `.gitignore`. | `chore: update xcode build settings` |
| `test:` | Adding or improving tests. | `test(packet): cover high-session-id roundtrips` |
| `ci:` | Configuration atau workflow continuous integration. | `ci: add pull request checks` |

---


## 6. Documentation Ownership

| Document | Purpose |
| :--- | :--- |
| [Technical Requirements](#33-feature-map) | Feature entry points, file ownership, team workflow and verification. |
| [Developer & Agent Guide](agent.md) | File placement, contracts and handoff. |
| [Networking](NETWORKING.md) | Discovery, transport, mesh and diagnostics. |
| [Payload Guide](PAYLOAD_GUIDE.md) | Packet field layouts and encoding. |
| [Protocol Specification](PROTOCOL_SPECIFICATION.md) | Authentication, keys, nonce, sequence, relay and replay. |

## 7. Technical Limits

- Radio reach, multi-hop delivery, locked-screen reception and offline map availability depend on device and operating conditions. Verify them on physical iPhones before relying on them in a relief-post drill.
- Group-key possession authenticates group traffic. Initials and eight-bit sender slots can collide, and the receiver cannot verify individual identity from the group key. Replay state is scoped to the active session. [Protocol specification](PROTOCOL_SPECIFICATION.md#authentication-replay-and-relaying)
- The inactivity guard is opt-in. Its default timing is an app setting and needs field validation for this use case.
