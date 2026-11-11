# TeeKum — Technical Requirements

**Fantasix · Last reviewed: 11 November 2026**

> **Current implementation:** See [Session migration](features/session-migration.md) for the connected behavior, source changes, test evidence and open protocol decisions. The inventory and G1–G12 below describe the pre-integration baseline `796f586`; they are retained as comparison history. The architecture and workflow rules still apply.

## 1. Project Overview

TeeKum is an iPhone concert/festival companion intended to help friends coordinate when internet access is poor. The desired product includes group entry, location sharing, a directional Orbit overview, geographic meeting points, chat and SOS. Offline radio, privacy, delivery and safety behavior require integration and physical-device evidence before release.

- Team: Fantasix. Developers: Adiat, Daffa, Hasan and Nicho; designers: Ayu and Ivanna.
- Minimum deployment target: **iOS 27.0**, from `project.yml`.
- SwiftUI with Observation and **Feature-Driven MVVM**. Swift 6 language mode; XcodeGen minimum 2.46.0.
- The configured app identifier is `com.fantasticenam.meepo`; display name/scheme remain Teekum. Confirm release naming with the team rather than changing it through a doc assumption.

### 1.1 Current State by Area

| Area | Source present | Integration status |
| :--- | :--- | :--- |
| Pairing / Agreement | Form, color picker, focus handling, QR artwork, camera preview and local activation action | Local demo navigation only. GroupInvite/GroupInvitedCodec/QRCodeGenerator remain placeholders. Imported GroupSession invite methods do not make the UI a real join flow. |
| Orbit / friends | Header, scene, hold control, roster/search, curved panel and leave confirmation | Group title and roster read SessionStore; marker positions/heading are fixtures. SOS, chat, settings, add-friend and member-selection callbacks remain unconnected. |
| MapPoint | MainMapView, MapLayerView, pin and ViewModel | Local candidate/proposal/attendance state only; no peer synchronization. Old session identity access needs reconciliation with imported models. |
| Messaging / security / transport | Packet codecs, router, crypto, replay, keychain, framing and peer actor | Imported, not assembled/started by TeekumApp. Missing dependencies and conflicting contracts remain. |
| Mesh | Neighbor/routing/forwarding/policy/telemetry services and protocols | Imported source, not verified multi-hop behavior or an approved Phase 1 scope expansion. |
| Location / power | LocationService, LocationPublisher and adaptive hardware extensions | Imported, not connected to Orbit. MapPoint's local CLLocationManager permission request is not the shared publisher. |
| Chat / SOS / inactivity | Engines, protocol/model files, audio adapter and guard | Imported logic, not connected to buttons, warning UI, app interaction events or session teardown. |
| Recovery / Live Activity / Finder / strobe beacon / Diagnostics UI | No implementation located for these complete features in this snapshot | Missing, deferred or not yet migrated; compare with legacy before deciding which. No widget target is configured. |

### 1.2 Product Intent versus Imported Defaults

| Topic | Current observation / decision still required |
| :--- | :--- |
| Private groups | Intended product behavior. Imported GroupSession also contains a deterministic shared-key/auto-mesh default; that is not approval for private-group key management. |
| Location and status | Current LocationPingPayload contains sensor telemetry/color, **not statusCode or targetRefId**. Chat presets exist separately. SessionStore still has localStatus/localTargetRefId. Agree their intended behavior before integration. |
| SOS hold | Shared/UI currently requires **1.5 seconds**. TeeKumConfiguration.SOS.holdDuration is **3 seconds** and is not used by that control. Resolve the difference; do not silently choose a value. |
| Inactivity | Imported guard defaults to disabled, 180 seconds of local stillness plus a 30-second warning. These are unvalidated tunables, not research-backed safety thresholds or a shipped remote-friend idle alert. |
| Location cadence | Configuration contains moving 4 s, stationary 20 s, distant 2 s and survival 60 s defaults. Other configuration/defaults also exist; trace the active consumer before documenting effective behavior. |
| Meeting point | One shared local point is the UI intent. Conflict resolution, expiry, attendance identity and network reconciliation remain integration tasks. |
| Relay consent | Imported relay policy/discovery logic exists. Final consent UX, stranger eligibility, rate budgets and background scope still need owner review. |
| UWB / offline maps / battery | Capability, map availability, runtime limits and battery impact remain unverified. No fixed distance, energy-saving percentage, guaranteed delivery or continuous background execution is established here. |

Custom venue overlays and an Apple Watch companion remain later product proposals, not prerequisites or implemented targets. Preserve the legacy compass/radar/strobe behavior in the parity review before deciding what to restore, replace or defer.

## 2. Technologies and Configuration

| Framework | Located source/use | Status |
| :--- | :--- | :--- |
| SwiftUI / Observation | App, Features, Shared/UI, SessionStore | UI/local state structure present; integration conflicts can still prevent a complete build. |
| MapKit | Features/MapPoint/Views/Components/MapLayerView.swift | Geographic UI and user annotation; offline map availability is not established. |
| AVFoundation / UIKit bridge | Pairing QRScannerService, CameraPreviewView/Surface | Preview/permission lifecycle, not QR decoding. |
| Network | Core/Transport/Services and Extensions | Imported Bonjour/TCP-oriented implementation with optional UDP branch. See NETWORKING. |
| CryptoKit / Security | Core/Security/Services | Imported ChaChaPoly/key storage, not app-wired. See PROTOCOL_SPECIFICATION. |
| CoreLocation / CoreMotion | Core/Location and Features/SOS/Services/InactivityGuardService.swift | Imported sensor logic. Permissions, lifecycle and policy need integration. |
| NearbyInteraction / ActivityKit / SQLite recovery | No complete corresponding implementation/target located | Planned or missing from this migration; do not invent completed services. |

`project.yml` currently declares a single application target, the Teekum scheme, camera usage text and When-In-Use location usage text. Local-network/Bonjour declarations, motion usage text, URL scheme registration, background modes and a Live Activity widget target are not configured there. Review the relevant APIs/required configuration during integration; do not add capabilities merely because imported code mentions them. No external dependency is declared in this spec.

## 3. Architecture — MVVM Feature-Driven

### 3.1 Architecture Name & Status

Feature-Driven MVVM remains the intended structure. Imported legacy classes are migration inputs, not automatic architecture decisions. In particular, PacketRouter currently depends on old feature ViewModels; this conflicts with the desired Core boundary and needs a reviewed adaptation.

### 3.2 Dependency & Ownership Rules

- Views own presentation, focus, selection and gestures. ViewModels own feature actions/presentation state. Keep UI-observed state on MainActor.
- Retain the existing SessionStore for accepted cross-feature state; agree model compatibility before wiring imports. Do not maintain independently writable copies of the roster/meeting state.
- Create/retain shared service instances at App composition when integration is ready. Direct initializer injection is sufficient; no mandatory Coordinator, AppDependencies, Repository, UseCase or runtime layer.
- The intended boundary is Feature → shared Core contracts. Core should not require feature UI/ViewModel types. The current router violates this intention; do not conceal that with empty replacement classes.
- Use actors for shared mutable service state where needed, and one explicitly owned inbound consumer. Service lifetimes must not depend on which map/modal is visible.
- Put payload-free enums in the owning Models/Enums folder; structured records and associated-value enums remain data/state types. Some imported files currently contain multiple types; the inventory below reports reality, not approval of every placement.
- Names/comments do not establish semantics: MemberID still exists, but imported Member uses a String ID and GroupSession derives a slot from initials. Resolve identity jointly rather than assuming the earlier typed-ID migration survived intact.

### 3.3 Current Folder Structure

Paths below are relative to `Teekum/Teekum/` and list the Swift source actually present. `//` comments identify key responsibilities/limits; an unannotated imported file is still unverified. Assets.xcassets also exists at this source root. No proposed widget/test/persistence tree is presented as implemented.

```text
Teekum/Teekum/
├── App/
│   ├── AppRootView.swift // Local session-based Pairing/Orbit root switch
│   └── TeekumApp.swift // Retains SessionStore; does not assemble imported services
├── Features/
│   ├── Chat/
│   │   ├── Models/
│   │   │   └── InFlightMessage.swift
│   │   ├── Protocols/
│   │   │   └── ChatMessagingService.swift
│   │   └── Services/
│   │       ├── Extensions/
│   │       │   ├── ChatMessageEngineDelivery.swift
│   │       │   ├── ChatMessageEngineInbound.swift
│   │       │   └── ChatMessageEngineOutbound.swift
│   │       └── ChatMessageEngine.swift // Imported chat actor; no current chat UI wiring
│   ├── MapPoint/
│   │   ├── ViewModels/
│   │   │   └── MapPointViewModel.swift // Local candidate and shared meeting edits; old session identity API still referenced
│   │   └── Views/
│   │       ├── Components/
│   │       │   ├── MapLayerView.swift // MapKit viewport, annotations and long-press selection
│   │       │   └── MapPointPinView.swift
│   │       └── MainMapView.swift // Geographic modal and native local meeting alerts
│   ├── OrbitMap/
│   │   ├── Models/
│   │   │   └── Enums/
│   │   │       └── OrbitModal.swift
│   │   ├── ViewModels/
│   │   │   ├── FriendListViewModel.swift // Roster filtering and seconds-or-minutes age formatting
│   │   │   └── OrbitMapViewModel.swift // Group title and local SessionStore reset only
│   │   └── Views/
│   │       ├── Components/
│   │       │   ├── FriendListMemberView.swift
│   │       │   ├── OrbitBloomView.swift
│   │       │   ├── OrbitControlsView.swift
│   │       │   ├── OrbitHeaderView.swift
│   │       │   ├── OrbitMarkerMemberView.swift // Declares OrbitMemberMarkerView
│   │       │   ├── OrbitPanelShape.swift // Curved panel and chevron-handle surface
│   │       │   ├── OrbitSceneView.swift // Rings, stars and fixture heading/member positions
│   │       │   ├── OrbitUserMarkerView.swift
│   │       │   └── StarfieldView.swift // Decorative twinkle with scene/motion/power handling
│   │       ├── FriendListSheet.swift // Roster/search and native leave confirmation; model reconciliation pending
│   │       └── OrbitMapView.swift // Friends/map modal composition; SOS/chat/invite callbacks are placeholders
│   ├── Pairing/
│   │   ├── Models/
│   │   │   ├── Enums/
│   │   │   │   ├── PairingField.swift // Payload-free input focus choices
│   │   │   │   ├── PairingMode.swift // Create/join UI mode
│   │   │   │   └── PairingProfileColor.swift // Draft UI color selection
│   │   │   ├── GroupInvite.swift // Placeholder, not an implemented invite contract
│   │   │   └── PairingForm.swift
│   │   ├── Services/
│   │   │   ├── GroupInvitedCodec.swift // Placeholder; filename retained as currently spelled
│   │   │   ├── QRCodeGenerator.swift // Placeholder; screen uses static QR artwork
│   │   │   └── QRScannerService.swift // AVFoundation camera preview lifecycle; no QR decoding
│   │   ├── ViewModels/
│   │   │   └── PairingViewModel.swift // Local navigation demo; session-model compatibility unresolved
│   │   └── Views/
│   │       ├── AgreementViewComponents/
│   │       │   ├── AggrementGroupSummaryView.swift // Declares AgreementGroupSummaryView
│   │       │   ├── CardAgreement.swift
│   │       │   ├── FooterAgreement.swift
│   │       │   └── HeadAgreement.swift
│   │       ├── PairingViewComponents/
│   │       │   ├── CameraPreviewSurface.swift
│   │       │   ├── CameraPreviewView.swift
│   │       │   ├── GroupNameField.swift
│   │       │   ├── GroupPairingInviteView.swift // Static QR artwork; share action unconnected
│   │       │   ├── GroupPairingProfileView.swift
│   │       │   └── ProfilePickerView.swift
│   │       ├── AgreementView.swift // Consent screen; product copy is not runtime evidence
│   │       ├── GroupPairingView.swift // Form, focus/color-picker presentation and Agreement push
│   │       ├── GroupQRCodeView.swift // Group title and static invitation UI
│   │       ├── MeshAgreementView.swift // Unused Hello-world placeholder
│   │       └── QRScannerView.swift
│   └── SOS/
│       ├── Protocols/
│       │   └── SOSAudioAlerting.swift
│       └── Services/
│           ├── Extensions/
│           │   ├── SOSForwardingEngineACK.swift
│           │   ├── SOSForwardingEngineInbound.swift
│           │   ├── SOSForwardingEngineOutbound.swift
│           │   └── SOSForwardingEngineRetries.swift
│           ├── DefaultSOSAudioAlerter.swift // Imported alert feedback adapter
│           ├── InactivityGuardService.swift // Imported opt-in local stillness/countdown service; not connected
│           └── SOSForwardingEngine.swift // Imported SOS actor; hold callback is not connected
├── Core/
│   ├── Configuration/
│   │   └── TeeKumConfiguration.swift // Imported constants; values are not approved field evidence
│   ├── Location/
│   │   ├── Models/
│   │   │   ├── Enums/
│   │   │   │   └── LocationServiceError.swift
│   │   │   └── CadenceConfiguration.swift
│   │   ├── Protocols/
│   │   │   ├── Extensions/
│   │   │   │   └── LocationServiceProtocolConfiguration.swift
│   │   │   └── LocationServiceProtocol.swift
│   │   └── Services/
│   │       ├── Extensions/
│   │       │   ├── LocationServiceAdaptiveHardware.swift
│   │       │   ├── LocationServiceDelegate.swift
│   │       │   ├── LocationServiceLifecycle.swift
│   │       │   ├── LocationServicePublishing.swift
│   │       │   └── LocationServiceTesting.swift
│   │       ├── LocationPublisher.swift // Imported sensor-only ping publisher; not started by current app
│   │       └── LocationService.swift // Imported location/motion/battery service; protocol naming mismatch
│   ├── Mesh/
│   │   ├── Models/
│   │   │   ├── InFlightDiscovery.swift
│   │   │   ├── NeighborEntry.swift
│   │   │   ├── PacketKey.swift
│   │   │   └── SeenRREQEntry.swift
│   │   ├── NeighborManagement/
│   │   │   ├── Models/
│   │   │   │   ├── Enums/
│   │   │   │   │   ├── NeighborEvent.swift
│   │   │   │   │   └── NeighborState.swift
│   │   │   │   ├── InboundFrame.swift
│   │   │   │   ├── NeighborInfo.swift
│   │   │   │   ├── QueueDepth.swift
│   │   │   │   ├── SendOutcome.swift
│   │   │   │   └── TransportCapabilities.swift
│   │   │   └── Protocols/
│   │   │       ├── MeshTransport.swift
│   │   │       └── NeighborManaging.swift
│   │   ├── PacketForwarding/
│   │   │   ├── Models/
│   │   │   │   └── Enums/
│   │   │   │       └── ForwardingDecision.swift
│   │   │   └── Protocols/
│   │   │       ├── ForwardingBudgetManaging.swift
│   │   │       └── PacketForwarding.swift
│   │   ├── Protocols/
│   │   │   └── MeshClock.swift
│   │   ├── RelayDiagnostic/
│   │   │   ├── Models/
│   │   │   │   ├── Enums/
│   │   │   │   │   └── DropReason.swift
│   │   │   │   └── RelayTelemetry.swift
│   │   │   └── Protocols/
│   │   │       └── RelayDiagnosticProviding.swift
│   │   ├── RelayParticipation/
│   │   │   ├── Models/
│   │   │   │   └── Enums/
│   │   │   │       ├── RelayParticipationMode.swift
│   │   │   │       └── RelayStatus.swift
│   │   │   ├── Protocols/
│   │   │   │   └── RelayPolicyManaging.swift
│   │   │   └── Services/
│   │   │       └── RelayPolicyState.swift
│   │   ├── Routing/
│   │   │   ├── "Models "/
│   │   │   │   ├── Enums/
│   │   │   │   │   ├── RouteDiscoveryFailure.swift
│   │   │   │   │   ├── RouteReqHandlingResult.swift
│   │   │   │   │   └── RouteRespHandlingResult.swift
│   │   │   │   ├── ReverseRouteEntry.swift
│   │   │   │   ├── RouteDiscoveryDiagnostics.swift
│   │   │   │   └── RouteEntry.swift
│   │   │   └── Protocols/
│   │   │       ├── RouteDiscoveryManaging.swift
│   │   │       └── RouteTableManagingProtocol.swift // Declares RoutingTableManaging
│   │   ├── SOSForwarding/
│   │   │   └── Protocols/
│   │   │       └── SOSForwardingManaging.swift
│   │   └── Services/
│   │       ├── Extensions/
│   │       │   ├── NeighborTable/
│   │       │   │   ├── NeighborTableHealth.swift
│   │       │   │   └── NeighborTableRegistry.swift
│   │       │   ├── PacketForwarder/
│   │       │   │   ├── PacketForwarderDispatch.swift
│   │       │   │   └── PacketForwarderEvaluation.swift
│   │       │   └── RouteDiscoveryService/
│   │       │       ├── RouteDiscoveryServiceInbound.swift
│   │       │       ├── RouteDiscoveryServiceInitiation.swift
│   │       │       └── RouteDiscoveryServiceMaintenance.swift
│   │       ├── ForwardRateLimiter.swift // Declares ForwardingRateLimiter
│   │       ├── MeshTimingConfiguration.swift
│   │       ├── NeighborTable.swift
│   │       ├── PacketForwarder.swift
│   │       ├── RelayPolicyManager.swift
│   │       ├── RouteDiscoveryService.swift
│   │       ├── RoutingTable.swift
│   │       ├── SeenPacketCache.swift
│   │       ├── SystemMeshClock.swift
│   │       └── TestMeshClock.swift // Imported deterministic clock helper; not an executed test
│   ├── Messaging/
│   │   ├── Models/
│   │   │   ├── Enums/
│   │   │   │   ├── ACKStatus.swift
│   │   │   │   ├── PacketCodecError.swift
│   │   │   │   └── PacketType.swift
│   │   │   ├── Payloads/
│   │   │   │   ├── ACKPayload.swift
│   │   │   │   ├── ChatMessagePayload.swift
│   │   │   │   ├── LocationPingPayload.swift
│   │   │   │   ├── MeetingUpdatePayload.swift
│   │   │   │   ├── RouteReqPayload.swift
│   │   │   │   ├── RouteRespPayload.swift
│   │   │   │   └── SOSPayload.swift
│   │   │   ├── CleartextEnvelope.swift // V3 envelope, AAD and nonce; decoder still narrows session ID
│   │   │   ├── PacketConstant.swift // PacketConstants facade over TeeKumConfiguration
│   │   │   ├── PacketReader.swift
│   │   │   ├── PacketWritter.swift // Declares PacketWriter; current spelling retained
│   │   │   └── RawWirePacket.swift // 10 + 30 + 16-byte assembly/slicing
│   │   └── Service/
│   │       ├── InitialsCodec.swift
│   │       ├── PacketCodec.swift // 56-byte codec; decoder still narrows session ID to UInt16
│   │       ├── PacketRouter.swift // Imported demultiplexer; missing legacy dependencies and Core-to-Features coupling
│   │       └── PriorityOutboxQueue.swift
│   ├── Models/
│   │   ├── Enums/
│   │   │   ├── AcknowledgementStage.swift
│   │   │   ├── AttandanceStatus.swift // Declares AttendanceStatus; separate from MeetingAttendance
│   │   │   ├── ChatDeliveryState.swift
│   │   │   ├── ChatEngineError.swift
│   │   │   ├── InboundChatOutcome.swift
│   │   │   ├── LocationFreshness.swift
│   │   │   ├── MeetingAction.swift
│   │   │   ├── MeetingAttendance.swift
│   │   │   ├── MeetingTimePreset.swift
│   │   │   ├── MemberColor.swift
│   │   │   ├── RecipientDeliveryState.swift
│   │   │   ├── SOSDeliveryState.swift
│   │   │   ├── SOSType.swift
│   │   │   └── Status.swift
│   │   ├── ChatMessage.swift
│   │   ├── GroupSession.swift // Imported key/invite/initials-based model; incompatible with some UI callers
│   │   ├── GroupSessionInvite.swift
│   │   ├── IncomingSOSAlert.swift
│   │   ├── LocationPin.swift // Imported geographic sample and coordinate helpers
│   │   ├── LocationSample.swift // Existing UI sample representation
│   │   ├── MeetingPoint.swift
│   │   ├── Member.swift // Imported String-initials identity model; differs from UI fixtures
│   │   ├── MemberID.swift // Existing typed identity; not consistently adopted by imports
│   │   ├── RouteChoice.swift
│   │   ├── SOSDiagnostics.swift
│   │   └── SOSEvent.swift
│   ├── Security/
│   │   ├── Models/
│   │   │   └── Enums/
│   │   │       └── CryptoServiceError.swift
│   │   ├── Protocols/
│   │   │   ├── CryptoServiceProtocol.swift
│   │   │   └── KeychainStoreProtocol.swift
│   │   └── Services/
│   │       ├── CryptoService.swift // Imported ChaChaPoly sealing/opening; not wired by app
│   │       ├── KeychainStore.swift // Imported key storage with memory fallback; not wired by app
│   │       └── ReplayProtectionFilter.swift // Imported replay API; UInt16 session keys need reconciliation
│   ├── Session/
│   │   └── SessionStore.swift // Existing shared UI state/fixtures; expects older Member API
│   └── Transport/
│       ├── Models/
│       │   ├── Enums/
│       │   │   ├── TransportError.swift
│       │   │   └── TransportState.swift
│       │   ├── DiagnosticEvent.swift
│       │   ├── InboundPacket.swift
│       │   ├── PeerConnection.swift
│       │   ├── PeerInfo.swift
│       │   └── TransportDiagnostics.swift
│       ├── Protocols/
│       │   └── PeerTransport.swift
│       └── Services/
│           ├── Extensions/
│           │   ├── PeerTransportServiceConnection.swift
│           │   ├── PeerTransportServiceDiagnostics.swift
│           │   ├── PeerTransportServiceDiscovery.swift
│           │   ├── PeerTransportServiceFraming.swift
│           │   └── PeerTransportServiceTransmission.swift
│           ├── PeerTransportService.swift // Imported peer transport actor; not started by current app
│           └── StreamMessageFramer.swift // 56-byte stream frame accumulation and resynchronization
└── Shared/
    ├── UI/
    │   ├── PrimaryButtonView.swift // Shared capsule CTA with injected action
    │   ├── SOSHoldButtonView.swift // Declares SOSHoldButton; current UI hold is 1.5 seconds, callback only
    │   └── Theme.swift // Semantic/profile colors, blackCard and hex initializer
    └── Formatters.swift // Imported geographic/time/heading formatting helpers
```

Current spelling is retained, including `PacketWritter.swift`, `AttandanceStatus.swift`, `AggrementGroupSummaryView.swift`, `GroupInvitedCodec.swift`, `ForwardRateLimiter.swift` and `OrbitMarkerMemberView.swift`. `Core/Mesh/Routing/"Models "/` has a trailing space in the directory name. Do not guess a normalized path in scripts or links. Renaming these is separate source work.

### 3.4 Feature Boundaries & Data Flow

**Source-visible local UI path:** TeekumApp retains SessionStore → AppRootView selects Pairing or Orbit → feature ViewModels read local state. Pairing activation changes local session state; MapPoint edits local shared meeting data. These call sites have not been proven compatible with the latest imported models.

**Not connected:** transport start/stop, inbound routing, crypto/key lifecycle, publisher start/stop, chat/SOS engines, inactivity callbacks, relay policy and route maintenance. TeekumApp does not construct those services. No end-to-end ingestion loop is assembled by the current App files.

**Intended integration:** reviewed service inputs → validation/authentication → accepted domain events/state → SessionStore → observing feature UI. Choose the smallest owner/lifecycle arrangement that existing code needs. Preserve original measurement time separately from receipt time. PacketRouter and engine entry points require review before this can become the real path.

### 3.5 Four-Developer Collaboration Baseline

These are responsibility slots, not newly assigned GitHub owners. Confirm names/reviewers in each issue.

| Role | Scope | Review boundary |
| :--- | :--- | :--- |
| A | Pairing, identity/session/key lifecycle, invite flow, App composition and recovery comparison | B reviews shared protocol/security; feature owners review model changes. |
| B | Transport, codec, authentication/replay integration, routing/mesh and diagnostics data | A reviews key/session changes; C/D review consumers. |
| C | Orbit/friends/geographic UI, location/heading, publishing and power integration | A reviews lifecycle; B reviews telemetry/message mapping. |
| D | Meeting behavior, SOS/inactivity and chat/Finder scope with team | B reviews delivery contracts; C reviews location/UI integration. Rebalance workload explicitly. |

### 3.6 Mapping & Migration Sequence

1. Freeze the actual legacy repository/branch/commit (or identify accessible evidence). The full legacy baseline was not available for this docs review.
2. For the assigned feature, compare entry points, helpers, extensions, models, protocols, configuration, lifecycle hooks and errors. Source that was not copied may be missing, deliberately deferred, renamed or replaced: record which, with evidence.
3. Resolve Section 7 contract blockers before connecting imported services. Do not recreate missing symbols as no-op stubs to get a superficial build.
4. Adapt one complete slice into the existing Feature-Driven MVVM structure; wire its UI/service/lifecycle and preserve agreed behavior. Copied source and integrated behavior are separate milestones.
5. Verify the changed slice at the current revision. Legacy tests, historical logs and merged branches do not transfer acceptance. Report unverified areas explicitly.

Use the parity table and handoff format in [agent.md](agent.md#4-documentation-and-handoff). No new shared development log is required.

### 3.7 Orbit Design & UI Slicing

| UI area | Current placement / behavior |
| :--- | :--- |
| Header and controls | OrbitMap/Views/Components; map/chevron actions are local navigation, settings/chat/SOS actions remain placeholders. |
| Scene | OrbitSceneView combines rings, StarfieldView, OrbitBloomView and separate center/peer markers. Heading/positions are fixtures, not a real compass projection. |
| Friends | FriendListSheet + FriendListViewModel + FriendListMemberView; search, compact age, color display and native leave alert. Imported member fields/identity must be reconciled with these callers. |
| Shared UI | PrimaryButtonView, SOSHoldButtonView and Theme; the shared hold control emits a callback, not an authenticated delivery result. |
| Pairing editing | PairingField/FocusState and screen-owned picker visibility support keyboard/color-picker dismissal. Keep this transient state in Views. |

| Navigation | Source-visible method |
| :--- | :--- |
| Pairing → Agreement | NavigationStack + navigationDestination(isPresented:). |
| Agreement → Orbit | Local activation → root session switch; not a real peer join. |
| Orbit → friends / MainMapView | One optional OrbitModal with fullScreenCover(item:). |
| Close modal → Orbit | dismiss(); does not leave the group. |
| Confirm Leave → Pairing | Close panel, then onDismiss calls local session reset. Imported tasks/sockets/keys are not torn down by this path yet. |

Ring distance/orientation, real member placement/color mapping, banner/detail interactions, status/Live Sharing placement and remote idle indication still need contracts. Local inactivity detection is not proof that a remote friend has stopped moving or is in danger.

## 4. Verification Plan

**Baseline review at `796f586`:** static source/configuration and documentation consistency inspection only. No build, unit test, UI test, radio run, battery measurement or legacy parity run was performed for this update. Current source has visible unresolved symbols/model mismatches; do not assume it compiles.

- `TeekumTests/PacketCodecTest.swift` is present. `project.yml` does not declare a test target or test action, and this review did not run it. Some old test declarations still use UInt16 session IDs against UInt32 APIs.
- The user's workflow reserves UI testing for the developer. Do not create/run UI tests automatically; report manual checks needed. Do not restore previously removed test targets as an incidental migration step.
- For implemented logic, agree meaningful unit/integration checks with its owner; record the exact revision, command, configuration and result. Test helper source is not a passing test run.
- Before device work, resolve type/symbol blockers and configuration, then verify invite → session → peers → location/chat/meeting/SOS → leave/rejoin incrementally.
- Physical-device evidence is required for discovery, disconnect/reconnect, lock/background states, stale GPS, power policy and recipient confirmation. Do not claim venue range, delivery guarantees or battery savings from source inspection.

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


## 6. Team Starting Point

Start from existing UI plus **partially migrated, disconnected logic**, not a Hello-world starter and not a finished prototype. The immediate priority is source parity and model/API reconciliation, followed by explicit integration. Reuse existing work where sound; do not automatically rewrite every imported service or assume every missing class should be restored unchanged.

Documentation ownership:

| Document | Purpose |
| :--- | :--- |
| TechnicalRequirements | Status, source inventory, boundaries, team workflow and open decisions. |
| agent | Reading order, evidence rules and safe migration handoff. |
| MIGRATION_BACKLOG | Feature parents and source-comparison/integration tasks; no inferred GitHub completion. |
| NETWORKING | Imported discovery/transport/mesh behavior and absent runtime wiring. |
| PAYLOAD_GUIDE | Source-observed packet fields and encoding, including compatibility gaps. |
| PROTOCOL_SPECIFICATION | Source-observed crypto inputs and security invariants still needing integration/review. |

## 7. Open Team Decisions

These are the static findings at baseline `796f586`. See the migration note for implemented resolutions and decisions that remain open.

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

A new agent must verify these observations against the current files before acting; a later PR can make a finding obsolete. Resolve a finding with source changes, affected-owner review and actual evidence, not by deleting its warning from the docs alone.
