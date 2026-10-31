# TeeKum — Migration Backlog

Migrate the existing vibe-coded prototype into **Feature-Driven MVVM** on **iOS 27+**. Use its behavior as a reference, agree what to preserve or fix, and migrate one feature at a time.

This backlog groups work by **feature/area**, not by development phase. Owners A–D are proposed roles; assign actual names with the team. The issue titles below are suggestions, not a record of GitHub issue creation or completion.

## How the Backlog Works

| Element | Purpose | Example |
| :--- | :--- | :--- |
| Parent issue | Describes the larger feature/area and its expected result. Groups related subtasks. | `[Migration] Pairing & Session` |
| Subtask / child issue | A concrete piece of work with one owner, reviewer and clear acceptance criteria. | `[UI Migration] Pairing & Group QR` |
| Task type | Explains what kind of work the subtask involves. It is the title prefix, not a status. | `[Review]`, `[Contract]`, `[Logic Migration]` |
| Status | Shows the current progress of a parent or subtask. | `Todo`, `In progress`, `Done` |

Example:

```text
[Migration] Pairing & Session                     // Parent: In progress
├── [Review] Pairing & Session                    // Subtask: Done
├── [Contract] Session State & Feature Actions    // Subtask: In progress
├── [UI Migration] Pairing & Group QR             // Subtask: Todo
├── [Logic Migration] Session Lifecycle           // Subtask: Todo
└── [Validation] Pairing & Session Flow            // Subtask: Todo
```

These statuses illustrate the structure; they do not describe work already completed. Keep the parent visible as the feature summary and expand its children to see individual work. Parent ownership means coordination; each child still has its own assignee.

### Task Types

| Type | Meaning / expected output |
| :--- | :--- |
| Review | Understand the prototype. Capture flows, unknowns and behavior to preserve, fix or defer. |
| Contract | Agree shared data, commands, events, message formats and behavior rules before dependent implementation. A technical agreement, not a legal contract. |
| UI Migration | Migrate screens and interactions into feature-based Views/ViewModels. Use fixture (sample) data until services are ready. |
| Logic Migration | Migrate or reconstruct actual behavior behind the agreed contracts, add relevant tests and connect it to the feature. |
| Integration | Connect existing feature/service implementations. Use a separate child only when this is substantial work beyond a logic task. |
| Validation | Compare with the agreed reference and verify normal/error/device scenarios. Add relevant tests during implementation too. |
| Cleanup & Handoff | Remove temporary production wiring and document verified behavior, limitations and remaining work. |

### Status Rules

| Status | Meaning |
| :--- | :--- |
| Todo | Not started. Confirm prerequisites, owner/reviewer and acceptance criteria before starting. |
| In progress | Actively being investigated, implemented or verified. |
| Done | Agreed scope is complete, reviewed and supported by actual evidence. Implementation changes are merged. |

An optional `In review` status can distinguish completed implementation awaiting review. Mark blocked work with its reason and prerequisite; do not treat it as Done.

**A parent is Done only when all required subtasks and the agreed end-to-end feature behavior are accepted.** UI completion alone does not complete a feature. Explicitly move deferred scope out of the parent rather than counting unfinished work as delivered.

## Main Parent Issues

| Parent | What this area covers | Coordinator |
| :--- | :--- | :--- |
| `[Migration] Pairing & Session` | Group entry/exit, invites, consent, shared session state and key lifecycle. | A |
| `[Migration] Networking & Security` | Peer connections, message format/protection, delivery infrastructure and Diagnostics. | B |
| `[Migration] Map & Live Sharing` | Map presentation, member locations/status, publishing and power policy. | C |
| `[Migration] Meeting Point` | Proposals, attendance and consistent meeting state across members. | D |
| `[Migration] Emergency SOS` | Hold/cancel interaction, urgent delivery, recipient confirmation and alerts. | D; B owns shared delivery logic |

Start with these five parents. Finder is a later parent; cross-feature validation is listed separately below. These are responsibility areas, not five tasks that must be finished sequentially.

## 1. [Migration] Pairing & Session

**Goal:** Migrate the complete create/join/leave experience into a single, well-owned session lifecycle.

| Subtask title | Short description | Owner |
| :--- | :--- | :--- |
| [Review] Pairing & Session | Identify available prototype source/builds; review create, join, share and leave flows and record agreed changes. | A |
| [Contract] Session State & Feature Actions | Agree state ownership, feature commands, dependency injection, consent and session task lifetime. | A; B reviews |
| [UI Migration] Pairing & Group QR | Migrate group forms, QR/share screens and consent into feature-based Views/ViewModels. | A |
| [Logic Migration] Session Lifecycle | Migrate invite validation, create/join/leave, key lifecycle and cleanup; connect the Pairing UI. | A; B reviews |
| [Validation] Pairing & Session Flow | Verify valid/invalid invites, consent, leave/rejoin and cleanup without leaking secrets or accepting late callbacks. | A |

## 2. [Migration] Networking & Security

**Goal:** Provide one shared, reviewed pipeline for discovering peers and exchanging authenticated messages.

| Subtask title | Short description | Owner |
| :--- | :--- | :--- |
| [Review] Networking & Security | Inspect transport, payload, identity, encryption and delivery; list conflicting or unknown behavior. | B |
| [Contract] Protocol & Security | Agree transport, packet format, identity, nonce/replay rules and ACK meaning with the session owner. | B; A reviews |
| [Logic Migration] Peer Transport & Message Pipeline | Migrate discovery, connections, codecs, encryption, replay checks, queues and reconnect behavior. Split into focused children before starting. | B; A reviews |
| [UI Migration] Diagnostics | Migrate the HUD with distinct connection, sample freshness and packet states; show missing metrics as unavailable. | B |
| [Integration] Diagnostics | Connect the HUD to actual transport, session and location snapshots as those services become available. | B; C reviews |
| [Validation] Offline Message Exchange | Test agreed wire fixtures, invalid messages, duplicate/reordered data and reconnect; verify two-device exchange. | B |

Keep generic queues, transport and cryptography here. SOS-specific retry/recipient behavior belongs to the SOS parent and uses this shared pipeline.

## 3. [Migration] Map & Live Sharing

**Goal:** Preserve the useful Map experience while presenting honest location state and respecting sharing/power policy.

| Subtask title | Short description | Owner |
| :--- | :--- | :--- |
| [Review] Map & Live Sharing | Capture map, friend detail, status and sharing states, including stale locations and permission failures. | C |
| [Contract] Location & Power Policy | Agree sample freshness, sharing behavior, battery boundaries and supported background behavior. | C; A reviews |
| [UI Migration] Main Map & Live Sharing | Migrate map, friend detail, status selection and sharing controls, including empty and stale states. | C |
| [Logic Migration] Location & Publishing | Migrate location/status updates, adaptive publishing and power policy; connect the Map UI and shared message pipeline. | C; B reviews publishing |
| [Validation] Location & Sharing Behavior | Verify sharing OFF, denied permissions, old samples, reconnect and power changes without presenting stale data as live. | C |

## 4. [Migration] Meeting Point

**Goal:** Migrate meeting proposals and attendance so all members converge on the agreed active meeting point.

| Subtask title | Short description | Owner |
| :--- | :--- | :--- |
| [Review] Meeting Point | Review proposal, map selection, active/empty state and attendance behavior; record unknowns and agreed changes. | D |
| [Contract] Meeting Point Sync | Agree proposal identity, attendance references, conflict resolution and reconnect behavior with the messaging owner. | D; B reviews |
| [UI Migration] Meeting Point | Migrate meeting selection, proposal and attendance screens using shared fixture state. | D |
| [Logic Migration] Meeting Point Sync | Migrate proposal/attendance exchange and apply the agreed conflict rules to shared state. | D; B reviews |
| [Validation] Meeting Point Flow | Verify proposals, attendance, concurrent updates and consistent state after reconnect across Map and meeting screens. | D |

## 5. [Migration] Emergency SOS

**Goal:** Preserve the SOS interaction while making urgent delivery, failure and recipient confirmation explicit.

| Subtask title | Short description | Owner |
| :--- | :--- | :--- |
| [Review] Emergency SOS | Review hold/cancel, alert presentation and delivery feedback; distinguish observed behavior from unverified claims. | D; B contributes |
| [Contract] SOS Delivery | Agree trigger/cancel behavior, unavailable GPS/peers, retry limits, recipient ACKs and alert deduplication. | B; D reviews UX |
| [UI Migration] SOS | Migrate the hold button, early cancellation and distinct pending, failed and recipient-confirmed feedback. | D |
| [Logic Migration] SOS Delivery | Migrate urgent dispatch, retries, recipient ACKs and duplicate-alert protection; connect interaction/audio with D. | B; D reviews |
| [Validation] SOS Flow | Verify early release, sharing-OFF trigger, no peers, retries, recipient receipt and duplicate-alert prevention. | D; B verifies delivery |

## Later Parent: [Migration] Friend Finder

Prioritize Meeting Point and SOS first. Precision finding requires a separate capability/scope decision.

| Subtask title | Short description | Owner |
| :--- | :--- | :--- |
| [Review] Friend Finder | Review compass, radar, beacon and unsupported-device behavior. | D |
| [Contract] Finder Capabilities & Fallback | Agree target/sample inputs, supported precision mode, token exchange and fallback behavior. | D; C/B review |
| [UI Migration] Finder | Migrate compass, radar and beacon presentation with unavailable-location and unsupported-device states. | D |
| [Logic Migration] Finder | Migrate bearing/distance calculations and fallback; add precision integration only if agreed. | D; C reviews |
| [Validation] Finder Behavior | Verify target changes, location uncertainty, interruption and supported-device behavior on real devices where needed. | D |

## Cross-Feature Follow-Up

Track these as separate shared issues once the feature integrations are runnable. Use one named assignee per issue and split device scenarios between owners.

| Issue title | Short description | Coordinator |
| :--- | :--- | :--- |
| [Validation] Prototype Parity | Run create/join → location/status → meeting point → SOS → leave; record accepted differences and regressions. | A; each feature owner contributes |
| [Validation] Two-Device Offline Test | Verify the integrated journey, disconnect/reconnect, locked-screen behavior and power changes on two physical iPhones. | C; all contribute |
| [Cleanup & Handoff] Migration Acceptance | Remove temporary production wiring after validation; retain test fixtures and update feature notes with actual results and gaps. | A; all contribute |

## Where to Start

**Per feature:** Review → Contract → UI + Logic → Integration → Validation → Cleanup. UI and logic can run in parallel against agreed contracts and fixtures. Do not wait for all reviews or every screen to finish before progressing a ready feature.

| Developer | First task | Next work |
| :--- | :--- | :--- |
| A | [Review] Pairing & Session | Session contract → Pairing UI + session lifecycle. |
| B | [Review] Networking & Security | Protocol/security contract → focused transport/message pipeline children. |
| C | [Review] Map & Live Sharing | Location/power contract → Map UI + location provider/publisher. |
| D | [Review] Meeting Point | Meeting contract → Meeting UI/logic; review SOS next and defer Finder. |

- Align session/member identity and message/security contracts early; dependent features must not invent their own versions.
- Live peer exchange needs session and transport services. Location-dependent behavior needs the location provider. Preparatory work can use fakes, but final integration must use the agreed real services.
- Review existing source where available. If only screenshots or a running reference are accessible, document unknowns and agree behavior reconstruction before claiming a logic migration.
- D's Meeting Point, SOS and Finder work is a queue, not simultaneous assignments. Rebalance UI work if this becomes a bottleneck.
- Keep one active implementation subtask per developer plus review work. Split broad subtasks and agree acceptance criteria before starting.

## Place Existing Issues Under Their Parents

Keep the issues already created; attach them to the matching parent rather than creating duplicates.

| Existing issue title | Parent |
| :--- | :--- |
| [Review] Pairing & Session | [Migration] Pairing & Session |
| [Review] Networking & Security | [Migration] Networking & Security |
| [Contract] Session State & Feature Actions | [Migration] Pairing & Session |
| [Contract] Protocol & Security | [Migration] Networking & Security |

References: [Architecture & ownership](TechnicalRequirements.md#3-architecture--mvvm-feature-driven), [open decisions](TechnicalRequirements.md#7-open-team-decisions), [working rules](agent.md).
