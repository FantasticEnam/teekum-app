# TeeKum — Migration Backlog

**Status:** Proposed backlog for team refinement; no GitHub issues have been created by this document.  
**Date:** 31 October 2026  
**Team:** Four developers; A–D are unassigned responsibility slots.  
**Target:** iOS 27+, SwiftUI, Feature-Driven MVVM.

## 1. What We Are Migrating

Treat the existing vibe-coded prototype as a product/behavior reference, then migrate accepted behavior into the maintainable target architecture. The current repository is the destination starter; it does not contain the prototype implementation.

For each feature, agree which behavior to **preserve**, **correct**, **defer**, or **remove**. Screenshots establish visible states, not transport, security or background correctness. Preserve useful UX; do not reproduce an anomaly merely to match the prototype.

There are two possible migration paths per feature:

- **Source available:** inspect and characterize the old behavior, then extract/adapt code where it meets the new boundaries and invariants. Avoid rewriting valid behavior unnecessarily.
- **Source unavailable:** inspect the running reference/screenshots, document unknowns, and reconstruct only the behavior agreed by the team. Label this explicitly as behavior reconstruction; do not claim that old logic has been ported or verified.

This is not a live production cutover plan. User-data/key migration and old/new peer interoperability have not been established. Decide whether either is needed before reusing a session format or recovery schema.

Related references: [Architecture & ownership](TechnicalRequirements.md#3-architecture--mvvm-feature-driven), [open technical decisions](TechnicalRequirements.md#7-open-team-decisions), [working rules](agent.md).

## 2. Backlog Shape and Board Use

Use one parent issue per feature, with independently reviewable child issues. A parent is complete only when its accepted UI, logic and verification scope is complete. Child issues can close in different PRs.

Suggested parents:

- `[Migration] Baseline & Shared Contracts`
- `[Migration] Pairing & Group Session`
- `[Migration] Main Map & Live Sharing`
- `[Migration] Meeting Point`
- `[Migration] Emergency SOS`
- `[Migration] Friend Finder`
- `[Migration] Diagnostics & Cross-Feature Validation`

Use these child prefixes: `[Discovery]`, `[Contract]`, `[UI Migration]`, `[Logic Migration]`, `[Integration]`, and `[Validation]`. They describe the work, rather than implying all migration is a file move.

Keep board fields small: **Status**, **Assignee**, **Priority**, and **Parent**. Put reviewer, dependencies, reference evidence and acceptance criteria in the issue body. Use `Backlog → Ready → In progress → In review → Done` if these statuses fit the team's board; otherwise map them to the existing statuses. Put a `blocked` label/reason on an item waiting for input.

Priority: **P0** unblocks dependent work; **P1** delivers the direct offline journey; **P2** optional or later. Priority is not an execution order—dependencies still apply. Start with no effort estimates; estimate/split after reviewing the actual legacy scope. A ticket that cannot fit one focused review should be split before entering Ready.

The local IDs below are planning references, not GitHub issue numbers. All are initially **Backlog**. The first four discovery items are candidates for Ready once owner/reviewer and available reference access are confirmed.

## 3. Proposed Ownership

| Slot | Primary migration scope | Main reviewer |
| :--- | :--- | :--- |
| A | Pairing, session state/lifecycle, key lifecycle, recovery and App composition | B; C reviews UI |
| B | Transport, wire/security validation, outbox, delivery and Diagnostics | A; D reviews delivery/UI |
| C | Map, status/sharing, location and power; app-side Live Activity if selected | D for UI; A/B for shared behavior |
| D | Meeting Point, SOS interaction and Finder | C for UI/location; B for messaging |

The owner carries the feature through UI, logic and verification. This avoids a handoff where one person only produces screens and another owns every service. Shared infrastructure is still implemented once by its owner. D's Finder work is optional until the core journey is stable; B's diagnostics UI is lower priority than transport/security. Rebalance after the first baseline review.

## 4. Migration Tickets

The acceptance column is the minimum observable outcome, not a substitute for refining source-specific details.

### Wave 0 — Capture the Legacy Baseline

These four tasks can proceed in parallel. They do not require a new architecture implementation first.

| ID | Proposed issue title | Owner / reviewer | Priority | Dependencies | Acceptance outcome |
| :--- | :--- | :--- | :--- | :--- | :--- |
| M01 | [Discovery] Inventory prototype source, access and pairing/session behavior | A / B | P0 | None | Identify available source/build/device access and reference revision; capture create/join/share/leave behavior. Record unavailable evidence explicitly. |
| M02 | [Discovery] Trace transport, identity, crypto and delivery behavior | B / A | P0 | None; use available docs first | Compare reference claims with observable/source evidence; list contradictions and proposed decisions for M06. Unknown implementation details remain unknown. |
| M03 | [Discovery] Inventory Main Map, status and live-sharing states | C / D | P0 | Supplied screenshots; running reference if available | Capture normal/empty/stale/denied/offline/sharing-OFF states; classify preserve/correct/defer. Include measurement age versus receipt time. |
| M04 | [Discovery] Inventory Meeting Point, SOS and Finder interactions | D / C; B reviews SOS semantics | P0 | Supplied screenshots; running reference if available | Record modal/navigation flows, hold/cancel, delivery states, meeting actions and finder fallback. Identify unobserved states instead of inventing them. |

**Wave 0 output:** one reviewed baseline issue with a compact checklist/table per feature. Do not recreate a large historical POC report. Source access and unresolved cases can remain open follow-ups; their dependent logic tickets must remain blocked until resolved.

### Wave 1 — Agree Shared Boundaries

Each contract can land separately. UI migration can use agreed fixture state while production infrastructure is being migrated.

| ID | Proposed issue title | Owner / reviewer | Priority | Dependencies | Acceptance outcome |
| :--- | :--- | :--- | :--- | :--- | :--- |
| M05 | [Contract] Establish session ownership and feature command/state seams | A / B; C/D consume | P0 | M01, reviewed scope from M03/M04 | Agree SessionStore/SessionRuntime responsibilities, member identity needs, view state and task lifetime. Add only required composition/test seams; current starter builds. UI fixtures need no real key/socket. |
| M06 | [Contract] Reconcile wire, sender identity, transport and crypto invariants | B / A | P0 | M02 plus M01 access findings | Agree transport/service type, version/layout, identity/nonce/counter lifecycle, replay rules and recipient ACK meaning. Update retained references consistently; define expected fixtures before codecs. Decide whether old/new peers or stored sessions must interoperate. |
| M07 | [Contract] Agree location, power and background availability policy | C / A; B reviews transport impact | P0 | M03 | Define sample validity/freshness, sharing intent versus actual publishing, battery boundaries and locked/suspended behavior to validate. Do not promise continuous background delivery from a UI indicator. |
| M08 | [Contract] Agree meeting conflict and SOS delivery behavior | D / B; A reviews shared state | P0 | M04, M05; align message fields with M06 | Define proposal identity/order/attendance references, concurrent updates, SOS trigger/cancel/retry/ACK states and behavior when GPS/peers are unavailable. |

If M06 remains too broad after M02, split it into transport selection, identity/nonce design, and wire fixtures before assigning implementation. The same rule applies to any contract with independent unresolved decisions.

### Wave 2 — Migrate UI with Deterministic State

UI tickets produce runnable screens/previews and interactions against fixtures or injected commands. They do not claim production integration. Layout parity includes behavior and accessibility corrections agreed in Wave 0; it is not blind pixel copying.

| ID | Proposed issue title | Owner / reviewer | Priority | Dependencies | Acceptance outcome |
| :--- | :--- | :--- | :--- | :--- | :--- |
| M09 | [UI Migration] Pairing, group QR and consent flow | A / C | P1 | M01, M05 | Create/scan mode, initials validation, QR/share presentation and accepted consent flow match baseline; invalid invite/permission states are visible with fixtures. No secrets in previews/screenshots. |
| M10 | [UI Migration] Main Map, friend detail, status and sharing controls | C / D | P1 | M03, M05; display policy from M07 | Map/overlays and actions match approved reference states; stale location, accuracy, unknown data and sharing intent are distinct. Hand off meeting/SOS/finder actions through composition. |
| M11 | [UI Migration] Meeting Point proposal and attendance sheets | D / C | P1 | M04, M05, M08 | Empty/active/proposal/attendance states render; selected coordinate and label stay distinct. Conflicting/unavailable state has agreed feedback. |
| M12 | [UI Migration] SOS hold, cancellation and delivery feedback | D / B | P1 | M04, M05, M08 | Three-second continuous hold and early cancellation work with deterministic time; pending, no-peer and recipient-confirmed states are distinct. UI disappearance does not own message retries. |
| M13 | [UI Migration] Finder compass and visual beacon | D / C | P2 | M04, M05; supported scope agreed | Target/uncertainty/fallback and beacon controls render from fixture data. Basic navigation stays usable without precision hardware; agree accessible beacon behavior before implementation. |
| M14 | [UI Migration] Diagnostics with honest runtime states | B / C | P1 | M02, M05, M07 | Separate connection, authentication, location freshness and availability. Missing telemetry renders as unavailable; no hard-coded “Live”, RSSI or radio-technology claims. |

M11–M13 are a queue for D, not simultaneous assignments. Prioritize Meeting Point and SOS; delegate one UI child after the first wave if D becomes the bottleneck.

### Wave 3 — Migrate Logic and Integrate Each Feature

For every ticket below, inspect the available legacy implementation first. Record what is reused, adapted, reconstructed or intentionally changed. Production logic requires source inspection or a reviewed behavior reconstruction decision for that feature; completing a screenshot inventory alone does not satisfy this gate.

| ID | Proposed issue title | Owner / reviewer | Priority | Dependencies | Acceptance outcome |
| :--- | :--- | :--- | :--- | :--- | :--- |
| M15 | [Logic Migration] Session creation, invite/QR handling, keys and teardown | A / B | P1 | M05, M06, M09; consent decision | Real create/join/leave flow drives Pairing UI; input/key lifecycle, expiry and late callbacks are tested. Recovery scope is explicit; no unimplemented persistence is presented as working. Split key/recovery implementation if needed. |
| M16 | [Logic Migration] Peer discovery, transport and protected message pipeline | B / A | P1 | M06, runtime seam in M05 | Selected transport, framing if needed, codecs/AEAD/replay checks and bounded outbox deliver validated events. Fixtures cover valid/invalid/reordered data; no update on invalid authentication. Split transport, codec/security and outbox children before implementation. |
| M17 | [Logic Migration] Location, adaptive publishing, power and Map integration | C / A; B reviews outbound flow | P1 | M07, M10, M15, M16 | Actual location/status drive state; sharing OFF stops normal publishing, old measurement time remains old, and policy changes cancel/reconfigure tasks. Permission failure and stale samples are covered. Split location acquisition and publisher integration if needed. |
| M18 | [Logic Migration] Meeting proposals, attendance and reconnect reconciliation | D / B | P1 | M08, M11, M15, M16 | Two members converge on the agreed meeting rule, attendance references the correct proposal, and reconnect/out-of-order cases are tested. Map and meeting sheet read the same accepted state. |
| M19 | [Logic Migration] Urgent SOS dispatch, retries, ACKs and alert presentation | B / D; A reviews identity/auth | P1 | M08, M12, M15, M16, location availability contract from M07 | Urgent event works independently of normal publishing; bounded retries, recipient confirmation, unauthorized messages and duplicate alert handling are tested. D wires interaction/audio; B owns shared delivery logic. |
| M20 | [Integration] Connect Diagnostics and verify peer/location state transitions | B / C | P1 | M14, M16, M17 | HUD reflects actual snapshots during connection, stale GPS, denial and reconnect; UI never manufactures missing values. Use it to help field validation, not as proof by itself. |
| M21 | [Logic Migration] Finder calculations and optional precision integration | D / C; B reviews token transport | P2 | M13, M17; precision scope/capability decision | Compass uses accepted sample/heading with uncertainty. Precision mode, if selected, exchanges tokens and handles unsupported/interrupted states on devices; no unverified fixed-distance switch. Split precision work into a later child. |

M15/M16 are parent-sized until their source inventory is known. Use them for backlog organization, then create small implementation children with their own acceptance checks. Transport, location and session owners can work in parallel with fakes/contracts; the table's integration dependencies block completion, not all preparatory coding.

### Wave 4 — Accept the Migrated Journey

| ID | Proposed issue title | Owner / reviewer | Priority | Dependencies | Acceptance outcome |
| :--- | :--- | :--- | :--- | :--- | :--- |
| M22 | [Validation] Compare migrated user journeys with the approved baseline | A coordinates; feature owners verify / cross-review | P1 | M15, M17–M20; M21 only if in scope | Create/join → exchange location/status → meeting point → SOS confirmation → leave runs as one journey. Every baseline difference is either accepted correction/deferment or a linked regression. Split per feature for clear assignees. |
| M23 | [Validation] Verify direct offline behavior on two physical iPhones | C coordinates; A/B/D own scenarios / B reviews evidence | P1 | M22 | Capture devices/OS/reference revision, offline conditions, disconnect/reconnect, stale GPS, sharing OFF, locked screen, power changes and SOS receipt. Record failures honestly; validate permissions and no-peer paths. |
| M24 | [Migration] Remove temporary fixtures/wiring and accept feature handoffs | A / B; all feature owners contribute | P1 | M22, M23; critical failures resolved or scope explicitly reduced | Production paths use real dependencies; fixtures remain only for preview/test. Old paths are removed only when unused and accepted. Core specs and feature notes reflect actual behavior; no unsupported release guarantees remain. |

**Not part of the first migration commitment:** stranger multi-hop mesh, production-scale routing, venue intelligence, Apple Watch and guaranteed pocket operation. Keep them as separate P2 discovery candidates after direct offline acceptance; a matching consent screenshot does not make them implemented.

## 5. First Team Session and Parallel Start

Use the first team session to assign names to A–D, select the accessible reference build/source, and agree what “same behavior” means. Do not schedule all waves into a sprint before this review.

| Developer | First candidate | Next ready work |
| :--- | :--- | :--- |
| A | M01: pairing/session and reference-access inventory | M05 → M09; refine M15 with B |
| B | M02: transport/security/delivery inventory | M06 → M16 children; M14 when infrastructure permits |
| C | M03: map/location/sharing inventory | M07 → M10 → M17 children |
| D | M04: meeting/SOS/finder inventory | M08 → M11 → M12; defer M13/M21 if capacity is tight |

After the baseline review, select only dependency-ready tasks for the first implementation iteration. Each developer has at most one active implementation item plus review work. Integration happens per feature as dependencies become available; do not wait until every screen is finished before connecting the first real journey.

## 6. Copyable GitHub Issue Example

Use this body for M10 after refining its actual baseline. Add it under the Main Map parent issue. IDs below are local references until real issue links exist.

**Title:** `[UI Migration] Main Map, friend detail, status and sharing controls`

```markdown
## Goal
Migrate the approved prototype Main Map experience into Features/Map,
using injected state/actions and the agreed MVVM boundaries.

## Reference and migration decisions
- Reference build/revision/screenshots: <attach available evidence>
- Preserve: <approved layout and interactions>
- Correct: <agreed state-label or accessibility problems>
- Defer/remove: <explicit scope decisions>
- Unknown: <unobserved reference behavior requiring review>

## Ownership and dependencies
- Owner: <Developer C's name>
- Reviewer: <Developer D's name>
- Depends on: M03, M05; M07 display policy
- Production location/transport integration is tracked in M17.

## Scope
- MainMapView, FriendDetailView, StatusPickerView and LiveSharingControlView.
- MapViewModel presentation state and injected commands.
- Normal, empty, stale, denied and sharing-OFF fixture states.
- Emit meeting/SOS/finder actions to composition; do not import other features.

## Acceptance criteria
- [ ] Screens/interactions match the approved reference or listed corrections.
- [ ] Sharing intent, actual publishing availability and sample age are distinct.
- [ ] Old/missing coordinates are not presented as fresh live positions.
- [ ] Status selection and feature actions reach the injected command/callback once.
- [ ] Relevant text sizes and VoiceOver labels remain usable.
- [ ] Previews or a runnable screen demonstrate each agreed fixture state.
- [ ] Meaningful state/action checks pass; visual comparison evidence is attached.
- [ ] Reviewer approves; real-network integration is not claimed by this UI issue.

## Verification and handoff
- Commands/devices actually used: <fill in after work>
- Results and remaining gaps: <fill in after work>
- PR: <link>
```

## 7. Ready and Done Rules

**Ready:** named owner/reviewer, reachable reference evidence, migration decisions scoped, relevant contract agreed, dependencies available for the work being committed, and acceptance criteria small enough for focused review. A discovery task can be Ready without production contracts if its output is the evidence/decision needed to establish them.

**Done:** reviewed code/decision is merged, applicable acceptance checks have actual evidence, differences from the reference are accounted for, and affected contracts/feature notes are updated. UI-only Done means UI migration accepted—not an end-to-end feature delivered. A parent is not Done merely because its UI child is Done.

Document implementations when they exist, following [the handoff convention](agent.md#4-documentation-and-handoff). This backlog is a planning artifact, not a replacement for tests or a mandatory chronological log.
