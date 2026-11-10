# TeeKum — Migration Backlog

**Last reviewed: 11 November 2026 · Candidate work, not GitHub status synchronization**

> UI/local navigation exists; logic has recently been imported and is not connected to it. Some old logic/dependencies may be missing or only partially migrated. **Full source parity and integrated behavior are unverified.** Source present ≠ adapted ≠ connected ≠ verified. Use the evidence states in [agent.md](agent.md#4-documentation-and-handoff).

Do not restart UI slicing from zero, mark imported engines Done, or recreate existing GitHub issues. Review current source, map existing issues under the parents below and update acceptance criteria. Owners A–D are responsibility slots; confirm actual assignees/reviewers.

## How the Backlog Works

| Element | Purpose |
| :--- | :--- |
| Parent | Large feature/area; explains the expected user outcome and groups child issues. |
| Subtask | One reviewable result, owner, reviewer, dependency and evidence requirement. |
| Task type | Review, Contract, UI Migration, Logic Migration, Integration or Validation; not a progress status. |
| Status | Todo, In progress, In review or Done in GitHub. This document does not infer those values from source files. |

```text
[Migration] Pairing & Session
├── [Review] Legacy Pairing Parity
├── [Contract] Session Identity & Invites
├── [UI Migration] Pairing & Agreement Follow-up
├── [Logic Migration] Session Contract Adaptation
├── [Integration] Real Create, Join & Leave
└── [Validation] Pairing & Session Lifecycle
```

| Task type | Expected output |
| :--- | :--- |
| Review | Compare the frozen legacy reference with current source; list preserved, partial, missing, deferred and unknown behavior. |
| Contract | Agree data, commands, events, errors, protocol and lifecycle behavior before dependent wiring. |
| UI Migration | Finish/review a UI slice using existing screens/components and explicit fixture boundaries. |
| Logic Migration | Restore/adapt required behavior and dependencies; imported code alone is not completion. |
| Integration | Connect the adapted service to App/session/UI data flow with ownership and teardown. |
| Validation | Run agreed checks and compare behavior against the reference; identify limits and unrun checks. |

A parent is Done only when required child scopes and its end-to-end behavior are accepted. Explicitly defer excluded work; do not count it as completed. A source-import PR can be complete for its narrow import scope while the feature parent remains unfinished.

## Start Here: Shared Blockers

| Order | Issue title | Result |
| :--- | :--- | :--- |
| 1 | [Review] Legacy Source & Missing Logic | Identify legacy repository/branch/commit and compare supporting types, extensions, configuration and lifecycle hooks. Record unknowns if the reference is unavailable. |
| 2 | [Contract] Shared Model Reconciliation | Resolve GroupSession/Member identity, LocationSample versus LocationPin and affected UI/preview APIs (G1–G2). |
| 3 | [Logic Migration] Imported Dependency Reconciliation | Resolve missing router ViewModels/notifications and LocationService protocol mismatch without no-op replacements (G3). |
| 4 | [Contract] Wire, Key & Counter Compatibility | Resolve 24-bit SID truncation, UInt16 APIs, key provisioning, slot collisions and independent counters before real packet exchange (G4–G5). |
| 5 | [Integration] Session Service Lifecycle | Decide retained instances, one inbound consumer, start/stop/cancellation and old-session rejection (G6). Wire one slice at a time. |

See [TechnicalRequirements Section 7](TechnicalRequirements.md#7-open-team-decisions) for source evidence. These are prerequisite candidates, not a claim that the list exhausts missing logic.

## 1. [Migration] Pairing & Session

**Goal:** Real group entry/exit with a consistent identity, invite/key contract and service lifecycle. **Present:** form/Agreement/local demo flow, static QR, camera preview; imported invite helpers exist separately in GroupSession.

| Subtask title | Short description | Owner |
| :--- | :--- | :--- |
| [Review] Legacy Pairing Parity | Compare create/join/share/expiry/recovery and all dependencies; classify missing or unknown logic. | A |
| [Contract] Session Identity & Invites | Reconcile GroupSession, MemberID, initials/slots, key provisioning and SID widths. | A; B reviews |
| [UI Migration] Pairing & Agreement Follow-up | Reuse current screens; connect approved real invite/consent feedback without duplicating pages. | A |
| [Logic Migration] Session Contract Adaptation | Restore/adapt invite validation and required helpers; identify deliberately deferred recovery. | A |
| [Integration] Real Create, Join & Leave | Replace local demo activation; retain/start/stop reviewed services and purge session data/secrets. | A; B reviews |
| [Validation] Pairing & Session Lifecycle | Verify invalid invites, duplicate initials, leave/rejoin, key/counter restart and late callbacks. | A |

## 2. [Migration] Networking & Security

**Goal:** A reviewed authenticated packet path. **Present:** imported transport, codec, router, crypto/replay/keychain and queue sources; no App assembly.

| Subtask title | Short description | Owner |
| :--- | :--- | :--- |
| [Review] Imported Network Parity | Compare legacy discovery, framing, ingestion, replay, keys and cleanup; list omissions. | B |
| [Contract] Protocol & Security | Reconcile V3 layout, SID width, identities, nonce lifecycle and ACK meaning (G4–G7). | B; A reviews |
| [Logic Migration] Transport & Codec Adaptation | Resolve source/API mismatches; preserve framing, bounded queues and validation. Split broad changes. | B |
| [Integration] Authenticated Inbound Pipeline | Adapt PacketRouter dependencies/layering and wire one service-owned consumer to accepted shared state. | B; A reviews |
| [UI Migration] Diagnostics | Add only agreed measured/unavailable states; no Diagnostics screen exists yet. | B |
| [Validation] Offline Packet Exchange | Verify current golden vectors, tampering/replay/restarts and two-device exchange. | B |

## 3. [Migration] Map & Live Sharing

**Goal:** Orbit/friends UI driven by honest live location state. **Present:** Orbit/local navigation and imported LocationService/LocationPublisher, not connected.

| Subtask title | Short description | Owner |
| :--- | :--- | :--- |
| [Review] Map & Location Parity | Compare legacy status, sharing, heading, freshness, power and supporting helpers. | C |
| [Contract] Location, Status & Power | Reconcile sample/receipt time, current sensor-only ping, status transport, permission and cadence policy. | C; A/B review |
| [UI Migration] Orbit & Friends Follow-up | Reuse scene/roster/panel; resolve marker projection, member colors, status/sharing placement and missing states. | C |
| [Logic Migration] Location Contract Adaptation | Resolve LocationService protocol/model differences and actual configuration consumers. | C |
| [Integration] Live Location & Orbit | Connect publisher/accepted peer samples, heading and sharing/power controls to the shared state. | C; B reviews |
| [Validation] Location & Sharing Behavior | Check stale/invalid samples, sharing OFF, permission denial, reconnect and power changes. | C |

## 4. [Migration] Meeting Point

**Goal:** One agreed meeting point across devices. **Present:** MainMapView/MapLayerView/local proposal and RSVP edits; imported meeting wire payload, no synchronization.

| Subtask title | Short description | Owner |
| :--- | :--- | :--- |
| [Review] Legacy Meeting Parity | Compare proposal, attendance, arrival, expiry and conflict behavior; inspect missing ViewModel dependencies. | D |
| [Contract] Meeting State & Sync | Reconcile MemberID/initials, attendance enums, createdAt/radius/flags and conflict/reconnect rules. | D; B reviews |
| [Logic Migration] Meeting Behavior Adaptation | Restore/adapt required inbound/outbound rules; do not create a second writable active point. | D |
| [Integration] MapPoint Synchronization | Connect existing local alerts/shared state to reviewed meeting message handling. | D; B/C review |
| [Validation] Meeting Point Flow | Verify create/cancel/RSVP, concurrent proposals, reopening map and reconnect convergence. | D |

## 5. [Migration] Emergency SOS & Inactivity

**Goal:** Explicit trigger/cancel and honest recipient delivery. **Present:** shared 1.5-second UI hold, imported SOS engine/audio and local inactivity guard; callback not connected.

| Subtask title | Short description | Owner |
| :--- | :--- | :--- |
| [Review] SOS & Inactivity Parity | Compare all legacy trigger, warning, alert, retry and cancellation paths, including missing presenters. | D; B contributes |
| [Contract] SOS Trigger & Delivery | Resolve hold-duration mismatch, sample validity, no-peer fallback, retries, ACK and deduplication. | D/B |
| [Contract] Inactivity Evidence & Consent | Review use cases/research, false positives, opt-in, warning cancellation and sensor/background fallback. Defaults are not approved thresholds. | D; team reviews |
| [Logic Migration] SOS Engine Adaptation | Adapt imported forwarding/audio/state dependencies and counter lifecycle; identify missing logic. | B; D reviews |
| [Integration] SOS & Guard Wiring | Connect hold, warning UI, interaction callbacks, recipients and teardown only after contracts are accepted. | D; B/C review |
| [Validation] SOS Safety Scenarios | Verify early release, no peers/GPS, retries, recipient versus relay ACK, duplicates and warning cancellation. | D/B |

Local guard monitoring and a remote-friend idle badge are separate requirements. Do not implement one as proof of the other or label inactivity as confirmed danger.

## Additional Imported Areas

| Parent / candidate children | Current source and next scope decision |
| :--- | :--- |
| [Migration] Mesh & Routing — Review → Contract → Adaptation → Integration → Validation | NeighborTable, RoutingTable, RouteDiscoveryService, PacketForwarder, relay policy/cache/budgets exist as imports. Confirm Phase 1/later scope and reconcile alternate forwarding paths before enabling them. |
| [Migration] Group Chat — Review → Contract → UI → Integration → Validation | ChatMessageEngine and 20-byte UTF-8 payload exist; chat button is a placeholder, no ChatViewModel/screen located. Resolve recipient state, identity, retries, privacy and teardown. |
| [Migration] Friend Finder — Review → Contract → UI/Logic → Validation | No complete Finder/UWB source located. Check legacy before treating it as intentionally deferred; capabilities/thresholds are unverified. |
| [Migration] Recovery & Live Activity — Review → Scope → Migration → Validation | Complete persistence/widget implementations were not located. Classify missing versus deferred with the team before creating targets/services. |

## Cross-Feature Integration and Delivery

| Parent / subtask | Short description |
| :--- | :--- |
| [Integration] Phase 1 Features | Integrate reviewed slices on develop; resolve shared contracts before merging incompatible source. |
| [Validation] Prototype Parity | Compare real create/join → peers → location/chat/meeting/SOS → leave against the frozen reference; document accepted differences. |
| [Validation] Two-Device Offline Flow | Verify disconnect/reconnect, stale data, locked/background states, power and teardown on physical iPhones. |
| [Cleanup & Handoff] Migration Acceptance | Remove obsolete/demo production wiring only after replacements are verified; record omissions, deferred scope and next owners. |
| [CI/CD] TestFlight & App Store | Parent with only two children: [CI/CD] TestFlight and [CI/CD] App Store. Both use main; develop does not upload to TestFlight. |

Branches: **f/ui/<feature>** and **f/logic/<feature>**, from develop. UI checks are performed by the developer; do not auto-create/run UI tests. Existing test sources are not proof of an executable target or current pass results.

**Per slice:** compare source → agree contract → adapt missing/incompatible logic → connect lifecycle/UI → verify → hand off. UI and logic can proceed independently where contracts permit, but no parent is complete until its accepted integrated behavior has evidence.
