# TeeKum — Technical Requirements

**Fantasix · Last reviewed: 11 November 2026**

## 1. Project Overview

TeeKum helps groups coordinate at concerts and festivals when internet access is poor. The app connects private group invitations, an explicit public group, Orbit and friend finding, geographic meeting points, chat, SOS and optional inactivity monitoring. [Session migration](features/session-migration.md) records the comparison with prototype `f4c6393` and the verification limits. The original UI/import baseline is `796f586`.

- Team: Fantasix. Developers: Adiat, Daffa, Hasan and Nicho. Designers: Ayu and Ivanna.
- Minimum iOS 27.0, Swift 6, SwiftUI with Observation and Feature-Driven MVVM.
- The XcodeGen spec names the app Teekum and sets the bundle ID to `com.fantasticenam.meepo`.

## 2. Technologies and Configuration

| Framework | Owner and responsibility |
| :--- | :--- |
| SwiftUI / Observation | `App`, `Features` and `Shared/UI` render and observe session/feature state. |
| MapKit | `Features/MeetingPoint/Views/Components/MapLayerView.swift` draws the map and meeting pin. Offline map availability needs device evidence. |
| AVFoundation / UIKit | Pairing's `QRScannerService` and camera preview handle QR scanning. |
| Network / CoreBluetooth | `Core/Transport` manages Bonjour TCP and BLE. [Networking](NETWORKING.md) |
| CryptoKit / Security | `Core/Security` seals/opens payloads, stores session keys and reserves outgoing sequence numbers. [Protocol specification](PROTOCOL_SPECIFICATION.md) |
| CoreLocation / CoreMotion | `Core/Location` collects location/heading. `Features/SOS/Services/InactivityGuardService.swift` owns the opt-in inactivity timer. |
| ActivityKit / WidgetKit | `Core/LiveActivity` manages the activity. `TeekumWidgets` renders the companion. |

`project.yml` declares the app, widget and XCTest targets along with privacy strings, Bonjour, the invite URL scheme and background modes. `project-parity.yml` adds the optional reference test targets. The specs declare no external dependencies.

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
│   ├── Packets/       V3 envelope, wire frame and Payloads/
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

| Feature or behavior | Entry point | State or behavior owner | XCTest to inspect |
| :--- | :--- | :--- | :--- |
| Create/join, QR, link and fingerprint | [GroupPairingView](../Teekum/Teekum/Features/Pairing/Views/GroupPairingView.swift), [GroupQRCodeView](../Teekum/Teekum/Features/Pairing/Views/GroupQRCodeView.swift) | [PairingViewModel](../Teekum/Teekum/Features/Pairing/ViewModels/PairingViewModel.swift), [GroupSessionFactory](../Teekum/Teekum/Features/Pairing/Services/GroupSessionFactory.swift), [GroupSession](../Teekum/Teekum/Core/Session/GroupSession.swift) | `PairingMeetingMigrationTests` |
| Agreement, restore and leave | [AgreementView](../Teekum/Teekum/Features/Pairing/Views/AgreementView.swift), [AppRootView](../Teekum/Teekum/App/AppRootView.swift) | [SessionController](../Teekum/Teekum/App/SessionController.swift), [SessionPersistence](../Teekum/Teekum/Core/Session/SessionPersistence.swift) | `SessionSafetyTests`, `PairingMeetingMigrationTests` |
| Orbit markers, friend highlight and finder | [OrbitMapView](../Teekum/Teekum/Features/OrbitMap/Views/OrbitMapView.swift), [FriendListSheet](../Teekum/Teekum/Features/OrbitMap/Views/FriendListSheet.swift) | [OrbitMapViewModel](../Teekum/Teekum/Features/OrbitMap/ViewModels/OrbitMapViewModel.swift), [OrbitProjection](../Teekum/Teekum/Features/OrbitMap/Models/OrbitProjection.swift), [SessionStore](../Teekum/Teekum/Core/Session/SessionStore.swift) | `SessionSafetyTests` |
| GPS, heading and outgoing pings | [LocationService](../Teekum/Teekum/Core/Location/LocationService.swift), [LocationPublisher](../Teekum/Teekum/Core/Location/LocationPublisher.swift) | `Core/Location` for cadence and sending, `SessionStore.applyLocationPing` for accepted peer measurements | `ParityContractTests`, `SessionSafetyTests` |
| Set, show and cancel meeting point, RSVP | [MainMapView](../Teekum/Teekum/Features/MeetingPoint/Views/MainMapView.swift), `OrbitMapView` for its marker | [MeetingPointViewModel](../Teekum/Teekum/Features/MeetingPoint/ViewModels/MeetingPointViewModel.swift), [MeetingPointService](../Teekum/Teekum/Features/MeetingPoint/Services/MeetingPointService.swift), `SessionStore.activeMeetingPoint` | `PairingMeetingMigrationTests`, `SessionSafetyTests` |
| Send chat and track recipient ACK | [ChatSheetView](../Teekum/Teekum/Features/Chat/Views/ChatSheetView.swift) | [ChatViewModel](../Teekum/Teekum/Features/Chat/ViewModels/ChatViewModel.swift), [ChatMessageEngine](../Teekum/Teekum/Features/Chat/Services/ChatMessageEngine.swift) and its inbound/outbound/delivery extensions | `ChatSOSMigrationTests`, `ParityContractTests` |
| SOS hold, receiver alert, sound/haptics and retry | [SOSHoldButtonView](../Teekum/Teekum/Shared/UI/SOSHoldButtonView.swift), [IncomingSOSAlertBannerView](../Teekum/Teekum/Features/SOS/Views/IncomingSOSAlertBannerView.swift) | [SOSViewModel](../Teekum/Teekum/Features/SOS/ViewModels/SOSViewModel.swift), [SOSForwardingEngine](../Teekum/Teekum/Features/SOS/Services/SOSForwardingEngine.swift), [DefaultSOSAudioAlerter](../Teekum/Teekum/Features/SOS/Services/DefaultSOSAudioAlerter.swift) | `ChatSOSMigrationTests`, `ParityContractTests` |
| Inactivity opt-in and countdown | [InactivitySettingsView](../Teekum/Teekum/Features/SOS/Views/InactivitySettingsView.swift), [InactivityWarningView](../Teekum/Teekum/Features/SOS/Views/InactivityWarningView.swift) | [InactivityGuardService](../Teekum/Teekum/Features/SOS/Services/InactivityGuardService.swift), `SOSViewModel` | `ChatSOSMigrationTests`, `ParityContractTests` |
| Discovery, framing and carry | [PeerTransportService](../Teekum/Teekum/Core/Transport/PeerTransportService.swift) | `Core/Transport` owns Wi-Fi/BLE links, framing, priority queue and carry | `NetworkMigrationTests`, `ParityContractTests` |
| Relay and route discovery | [PacketRouter](../Teekum/Teekum/Core/Mesh/PacketRouter.swift) | [RelayPolicyManager](../Teekum/Teekum/Core/Mesh/Relay/RelayPolicyManager.swift), [RouteDiscoveryService](../Teekum/Teekum/Core/Mesh/Routing/RouteDiscoveryService.swift), [SeenPacketCache](../Teekum/Teekum/Core/Mesh/SeenPacketCache.swift) | `NetworkMigrationTests` |
| Wire bytes, key and sequence | [RawWirePacket](../Teekum/Teekum/Core/Packets/RawWirePacket.swift), [CleartextEnvelope](../Teekum/Teekum/Core/Packets/CleartextEnvelope.swift) | [CryptoService](../Teekum/Teekum/Core/Security/CryptoService.swift), [PacketSequenceAllocator](../Teekum/Teekum/Core/Security/PacketSequenceAllocator.swift) | `ParityContractTests`, `SessionSafetyTests` |
| Connection diagnostics and packet log | [OrbitSettingsView](../Teekum/Teekum/Features/OrbitMap/Views/OrbitSettingsView.swift) | [PeerTransportService+Diagnostics](../Teekum/Teekum/Core/Transport/PeerTransportService+Diagnostics.swift), [TransportDiagnostics](../Teekum/Teekum/Core/Transport/TransportDiagnostics.swift) | `NetworkMigrationTests` |
| Lost-contact notification and Group activity log | [OrbitSettingsView](../Teekum/Teekum/Features/OrbitMap/Views/OrbitSettingsView.swift) | [SessionStore](../Teekum/Teekum/Core/Session/SessionStore.swift) records losses. [SessionController](../Teekum/Teekum/App/SessionController.swift) sends notifications. | `SessionSafetyTests` |
| Live Activity | [LiveActivityManager](../Teekum/Teekum/Core/LiveActivity/LiveActivityManager.swift), [TeekumWidgets](../TeekumWidgets) | `SessionController` drives updates and teardown. Widget verification requires a device. | Device check |

### 3.4 Session Data Flow

`GroupPairingView` pushes Agreement. Accepting activates the session and the root shows Orbit. Closing the friends or map modal returns to Orbit. Confirming Leave calls `SessionController.leave()`, which tears down session work and returns to Pairing.

Radio → transport framing → `SessionController` → `PacketRouter` → authenticated callbacks → shared state or feature engine → observing UI. The outgoing location, chat, SOS, meeting and route paths use the shared sequence allocator and crypto before transport queues.

### 3.5 Four-Developer Collaboration Baseline

| Role | Scope | Review boundary |
| :--- | :--- | :--- |
| A | Pairing, session identity, invites, app composition and recovery | B reviews protocol/security. Feature owners review shared models. |
| B | Transport, packet/security contracts, mesh and diagnostics data | A reviews key/session changes. C/D review consumers. |
| C | Orbit, friends, geographic UI, location and power | A reviews lifecycle. B reviews telemetry mapping. |
| D | Meeting behavior, chat, SOS and inactivity | B reviews delivery contracts. C reviews location/UI integration. |

Confirm names and reviewers in the issue. See [agent.md](agent.md#4-documentation-and-handoff) for the handoff format and [migration backlog](MIGRATION_BACKLOG.md) for historical scope.

## 4. Verification Plan

- Run the focused XCTest target from the `Teekum` scheme. `TeekumParity` adds the same contract cases against the read-only prototype. The older Swift Testing file remains excluded. See [Session migration](features/session-migration.md#verification) for the executed cases and setup.
- Keep UI verification manual. Exercise create/join, restore, location and Orbit, chat, meeting, SOS and leave/rejoin on physical iPhones. Use physical devices for Bonjour/BLE, backgrounding, GPS, Live Activity and notification feedback.
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
| [Migration Backlog](MIGRATION_BACKLOG.md) | Historical migration tasks and feature scope. |
| [Networking](NETWORKING.md) | Discovery, transport, mesh and diagnostics. |
| [Payload Guide](PAYLOAD_GUIDE.md) | V3 field layouts and encoding. |
| [Protocol Specification](PROTOCOL_SPECIFICATION.md) | Authentication, keys, nonce, sequence, relay and replay. |
| [Session Migration](features/session-migration.md) | Reference comparison, verification and remaining protocol decisions. |

## 7. Open Team Decisions

The [session migration note](features/session-migration.md#remaining-protocol-decisions) tracks open decisions about sender identity, slot collisions, replay, same-SID SOS forwarding and meeting conflict ordering. G1–G12 below record the static findings at the pre-integration baseline `796f586`.

<details>
<summary>Historical findings at 796f586</summary>

| ID | Finding / decision | Source evidence and next action |
| :--- | :--- | :--- |
| G1 | Session contract split | GroupSession.id is UInt16 while sessionId is UInt32. PairingViewModel passes localMemberId, and MapPointViewModel reads it, but the imported GroupSession has no such API. Reconcile identity, initializers and fixtures before claiming the UI builds. |
| G2 | Member/sample split | Member now uses String initials IDs, coordinate/lastSeen/color. SessionStore/preview, FriendListSheet and FriendListMemberView still expect parts of the previous MemberID/latestLocation API. LocationSample and LocationPin both exist. Agree canonical state, measurement versus receipt time and color mapping. |
| G3 | Missing or renamed legacy dependencies | PacketRouter references GroupSessionViewModel, SOSViewModel, MeetingPointViewModel, ChatViewModel and NotificationService; their definitions were not located. LocationService conforms to LocationServiceProvider while the imported protocol is LocationServiceProtocol. Compare legacy and adapt responsibilities; do not add empty stand-ins. |
| G4 | Session ID width and wire compatibility | Constants/serializers describe V3, 56 bytes and a 24-bit SID. Both CleartextEnvelope.deserialize and PacketCodec.decodeEnvelope narrow to UInt16; invite/replay APIs also retain UInt16. Resolve all consumers and roundtrip/authentication inputs together. |
| G5 | Key, member-slot and counter lifecycle | Imported GroupSession has a deterministic default key and an initials-derived slot; independent engines maintain counters. Private-group key generation, unique sender allocation, restart/wrap behavior, rotation and purging are not established. See PROTOCOL_SPECIFICATION. |
| G6 | Actual inbound ownership / layering | Core PacketRouter depends on feature engines/ViewModels, includes special ACK/SOS paths and relay alternatives. Decide one authoritative authenticated ingestion/forwarding path; review replay ordering and teardown before wiring it. |
| G7 | Status and delivery semantics | Current ping has no status/target fields; chat presets and old SessionStore fields coexist. ACK relay receipt is not friend delivery. Agree status transport and meeting/chat/SOS state mappings. |
| G8 | SOS / inactivity thresholds | UI hold is 1.5 s versus configuration 3 s. Local guard uses 180 s + 30 s defaults and lacks app wiring. Confirm research/use-case evidence, consent, cancellation, unavailable sensors and false-positive handling before enabling safety alerts. |
| G9 | Location, power and background | Reconcile duplicate configuration sources and effective cutoffs, sharing intent, permission denial, sampling and stale data. No configured background/Live Activity runtime or continuous execution guarantee is established. |
| G10 | Meeting synchronization | Local MapPoint changes are not sent. Imported payload has createdAt/radius/flags rather than the old landmark layout. Agree identities, conflict ordering, cancellation, expiry and reconnect behavior. |
| G11 | Relay policy and routing | Imported Mesh includes multiple forwarding paths/policies. Confirm Phase 1 versus later scope, opt-in UX, neighbor eligibility, hop/rate limits and abuse handling; comments marked “approved” are not new team acceptance. |
| G12 | Missing/deferred feature support and configuration | Recovery storage, Live Activity/Finder/Diagnostics UI and notification service were not located as complete features. Local-network/Bonjour/motion/URL/background configuration and legacy helpers need comparison. Classify unknown/missing/deferred explicitly. |


</details>
