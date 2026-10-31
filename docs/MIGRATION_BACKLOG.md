# TeeKum — Migration Backlog

Migrate the existing vibe-coded prototype into **Feature-Driven MVVM** on **iOS 27+**. Review each feature, preserve useful behavior, and fix agreed issues rather than copying them.

**Owners A–D are suggestions, not assigned names.** These 24 items are draft issue titles and descriptions; no GitHub issues have been created.

## Task Types

| Type | Meaning / expected output |
| :--- | :--- |
| Review | Understand the prototype before changing it. List existing flows, unknowns and behavior to preserve, fix or defer. |
| Contract | Agree how parts of the app work together: shared data, commands, events, message formats and behavior rules. This is a technical agreement, not a legal contract or a complete implementation. |
| UI Migration | Move screens and interactions into feature-based Views/ViewModels. Use fixture (sample) data while real services are being migrated. |
| Logic Migration | Move or reconstruct the actual behavior—session, location, networking and delivery—behind the agreed contracts, with relevant tests. |
| Integration | Connect migrated UI and services, then check that state and actions flow correctly across them. |
| Validation | Check migrated behavior against the approved reference and test real-device scenarios. Add feature-level checks during implementation too. |
| Cleanup & Handoff | Remove temporary production wiring after validation and document verified behavior, limits and remaining work. |

## 1. Review the Prototype

| ID | Issue title | Description | Owner |
| :--- | :--- | :--- | :--- |
| M01 | [Review] Pairing & Session | Identify available prototype source/builds. Review create, join, share and leave flows; record what to preserve or fix. | A |
| M02 | [Review] Networking & Security | Review transport, payload, identity, encryption and delivery. List conflicting or unknown behavior. | B |
| M03 | [Review] Map & Live Sharing | Capture map, friend detail, status and sharing states, including stale locations and permission failures. | C |
| M04 | [Review] Meeting Point, SOS & Finder | Review meeting actions, SOS hold/cancel, delivery feedback and Finder fallback as migration references. | D |

## 2. Agree Shared Contracts

| ID | Issue title | Description | Owner |
| :--- | :--- | :--- | :--- |
| M05 | [Contract] Session State & Feature Actions | Agree shared state ownership, feature commands, dependency injection and session task lifetime. | A |
| M06 | [Contract] Protocol & Security | Resolve transport, packet format, member identity, nonce/replay rules and ACK meaning before migrating the message pipeline. | B, reviewed by A |
| M07 | [Contract] Location & Power Policy | Define location freshness, sharing behavior, battery thresholds and supported background behavior. | C |
| M08 | [Contract] Meeting Sync & SOS Delivery | Agree meeting conflict resolution, attendance references, SOS retries and recipient-confirmed delivery states. | D, reviewed by B |

## 3. Migrate UI

Use fixture data and injected actions until production logic is ready.

| ID | Issue title | Description | Owner |
| :--- | :--- | :--- | :--- |
| M09 | [UI Migration] Pairing & Group QR | Migrate group forms, QR/share screens and the agreed consent flow into feature-based Views and ViewModels. | A |
| M10 | [UI Migration] Main Map & Live Sharing | Migrate map, friend detail, status selection and sharing controls, including empty and stale states. | C |
| M11 | [UI Migration] Meeting Point | Migrate meeting selection, proposal and attendance screens using shared fixture state. | D |
| M12 | [UI Migration] SOS | Migrate the hold button, early cancellation and distinct pending, failed and recipient-confirmed feedback. | D |
| M13 | [UI Migration] Finder | Migrate compass, radar and beacon presentation with unsupported-device and unavailable-location states. | D |
| M14 | [UI Migration] Diagnostics | Migrate the HUD with separate connection, location freshness and packet states; show unavailable metrics honestly. | B |

## 4. Migrate Logic & Integrate

Inspect and reuse sound prototype code where available. Otherwise, agree the behavior to reconstruct before implementation.

| ID | Issue title | Description | Owner |
| :--- | :--- | :--- | :--- |
| M15 | [Logic Migration] Session Lifecycle | Migrate invite handling, create/join/leave, key lifecycle and cleanup; connect the Pairing UI. | A |
| M16 | [Logic Migration] Peer Transport & Message Pipeline | Migrate discovery, connections, codecs, encryption, replay checks, queues and reconnect behavior. Split into focused implementation issues. | B |
| M17 | [Logic Migration] Location & Publishing | Migrate location/status updates, adaptive publishing and power policy; connect the Map UI. | C |
| M18 | [Logic Migration] Meeting Point Sync | Migrate proposal/attendance exchange and conflict resolution; verify consistent state after reconnect. | D |
| M19 | [Logic Migration] SOS Delivery | Migrate urgent dispatch, bounded retries, recipient ACKs and duplicate-alert protection; connect SOS interaction/audio with D. | B |
| M20 | [Integration] Diagnostics | Connect the HUD to actual transport, session and location snapshots; verify state transitions. | B |
| M21 | [Logic Migration] Finder | Migrate bearing/distance calculations and fallback; add precision finding only after capability and scope review. | D |

## 5. Validate & Complete the Migration

| ID | Issue title | Description | Owner |
| :--- | :--- | :--- | :--- |
| M22 | [Validation] Prototype Parity | Compare migrated journeys with the approved reference; record accepted changes and fix regressions. | Each feature owner |
| M23 | [Validation] Two-Device Offline Test | Test location, meeting points, SOS, disconnect/reconnect, locked-screen behavior and power changes on two iPhones. | C coordinates; all contribute |
| M24 | [Migration] Cleanup & Handoff | Remove temporary production wiring, retain useful test fixtures, and update feature documentation with verified behavior and remaining gaps. | A coordinates; all contribute |

## Suggested Starting Order

**Per feature:** Review → Contract → UI + Logic → Integration → Validation → Cleanup. UI and logic can run in parallel once the relevant contract is agreed; these sections are not a requirement to finish every screen before starting services.

| Step | Start these tasks | What must be ready first? |
| :--- | :--- | :--- |
| 1. Review in parallel | A: M01, B: M02, C: M03, D: M04 | Available prototype source/build/screenshots; record gaps rather than guessing. |
| 2. Agree contracts | A: M05, B: M06, C: M07, D: M08 | Relevant review findings. Align M08 with session state in M05 and message rules in M06. |
| 3. Migrate UI and shared logic | M09–M14 alongside session/transport work in M15–M16 | Relevant review and contract. M05 defines shared state/actions; M06 defines messaging; M07 defines location/power; M08 defines meeting/SOS behavior. |
| 4. Connect feature behavior | M17–M20; M21 after core priorities | Related UI and service contracts. Live peer exchange needs session/transport from M15–M16; location-dependent behavior needs the provider from M17. Preparatory work can use fakes. |
| 5. Validate and clean up | M22 per completed journey → M23 → M24 | Integrated behavior is runnable. Resolve blocking failures before removing temporary production paths. |

- Prioritize Pairing/session, transport and location because other features depend on them.
- D should take M11 (Meeting Point), then M12 (SOS); queue Finder M13/M21 later. These are not simultaneous assignments.
- A/B/C can migrate their services while D works on UI. Connect each feature as its dependencies become available.
- Assign one owner/reviewer to each implementation issue. Split broad items before starting and rebalance workload after review.

**Done:** reviewed work meets its agreed behavior and has actual verification evidence. UI completion alone does not complete a feature migration.

References: [Architecture & ownership](TechnicalRequirements.md#3-architecture--mvvm-feature-driven), [open decisions](TechnicalRequirements.md#7-open-team-decisions), [working rules](agent.md).
