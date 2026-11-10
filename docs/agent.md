# TeeKum — Developer & Agent Guide

**Last reviewed: 11 November 2026 · Migration guide, not a completion report**

> **Required context:** UI screens and local navigation exist. Logic was recently copied/moved into this repository and is **not connected to the UI/app lifecycle**. Some legacy logic, helpers, models, extensions or configuration may not have been brought over, or may only be partially migrated. **Completeness, build compatibility and end-to-end parity are unverified.** Never interpret a file, actor, protocol, source comment or old test report as proof that a feature works here.

## 1. Read Before Starting

1. [TechnicalRequirements.md](TechnicalRequirements.md#1-project-overview): current state, source inventory and intended product behavior.
2. [Open Team Decisions](TechnicalRequirements.md#7-open-team-decisions): inspect the actual files behind G1–G12; these findings may change after another PR.
3. [MIGRATION_BACKLOG.md](MIGRATION_BACKLOG.md): identify the feature parent, prerequisite contracts and the precise UI/logic/integration scope.
4. Read [NETWORKING.md](NETWORKING.md), [PAYLOAD_GUIDE.md](PAYLOAD_GUIDE.md) and [PROTOCOL_SPECIFICATION.md](PROTOCOL_SPECIFICATION.md) as relevant. They describe imported source and unresolved contracts, not a verified running stack.
5. Inspect `project.yml`, App/TeekumApp.swift, AppRootView.swift, the touched feature and its connected callers. The root README still contains starter-era status/paths; do not use those statements to conclude that features are absent or complete.

All source paths in this guide are relative to `Teekum/Teekum/` unless stated otherwise. This docs review did not access a frozen full legacy repository revision. Request its repository/branch/commit or other reference when a dependent parity decision cannot be made from current evidence. Continue unrelated authorized work while that information is pending.

## 2. Architecture Rules

- Minimum target: iOS 27.0. Use SwiftUI, Observation and Feature-Driven MVVM.
- Features own their UI/ViewModels and feature-only behavior. Core owns shared domain/infrastructure. Shared/UI owns existing reusable presentation; Shared/Formatters.swift contains imported formatting helpers.
- Views keep focus, modal, selection and interaction state. ViewModels expose feature actions/presentation. Use MainActor for UI-observed state and appropriate isolation for services.
- Reuse SessionStore as the current shared-state owner, but reconcile imported model APIs first. MemberID/LocationSample coexist with incompatible imported String-ID/LocationPin models; do not invent another version or flatten identity into initials by accident.
- Payload-free enums belong in the owner's Models/Enums directory; structured/associated-value state remains a model. Current file placement/naming is an inventory, not universal architectural approval.
- Native navigation stays feature-local: Pairing → Agreement push, local session root switch to Orbit, friends/map modal presentation and dismissal. No mandatory Coordinator, AppDependencies, Repository, UseCase or package split.
- Compose only the dependencies needed by the agreed integration slice. Current TeekumApp retains SessionStore only; imported actors are not started merely because they exist.
- The intended dependency direction is Features → Core. PacketRouter currently violates this by referencing legacy feature ViewModels/engines. Resolve the boundary through reviewed adaptation; do not add no-op classes just to satisfy its old initializer.
- Give inbound streams and background/retry/maintenance tasks explicit ownership and cancellation. Do not let separate screens race to consume the raw inbound stream.
- Do not introduce external dependencies, global locators or broad refactors as incidental migration work.

## 3. Four-Developer Workflow

Use the responsibility slots in [Section 3.5](TechnicalRequirements.md#35-four-developer-collaboration-baseline); confirm actual assignees/reviewers in the issue. Shared identity, packet, key and lifecycle changes require the affected owners' review.

1. State the task scope: UI slice, source comparison/import, contract adaptation, runtime integration or verification.
2. Search every caller and supporting type before editing. Check protocols, extensions, helpers, configuration, permissions, assets and fixtures—not only the main service file.
3. Compare against the agreed legacy reference. Classify each behavior using the parity table below. Do not presume that an omitted legacy type is intentionally removed, or copy it back blindly.
4. Start short-lived branches from develop: **f/ui/<feature>** for presentation/navigation, **f/logic/<feature>** for logic/adaptation/integration. Examples: f/ui/orbit-map, f/logic/pairing-group-qr, f/logic/map-point.
5. Keep working changes reversible and focused. Preserve existing validation/errors while adapting ownership. If no source is available for a required behavior, identify reconstruction explicitly and settle the contract before dependent changes.
6. Record evidence for the current revision and update the affected documents together. Never mark the full migration Done because the folder tree is populated.

TestFlight and App Store delivery use **main**; develop is the integration branch and does not upload to TestFlight. This is workflow policy, not a claim that delivery automation or branch protections are configured.

## 4. Documentation and Handoff

There is no mandatory chronological Development Log, POC acceptance document or per-developer diary. Keep lasting status/contracts in these documents; put implementation evidence and discussion in the feature PR. Add `docs/features/<feature-name>.md` only when the delivered behavior needs a focused handoff—not as an empty placeholder.

For each migration slice, include a compact parity table in the issue/PR or feature note:

| Legacy source / revision | Expected behavior or dependency | Current destination | Migration state | Evidence / next action |
| :--- | :--- | :--- | :--- | :--- |
| Not supplied | Example behavior under review | Actual file, or “not located” | Unknown | Obtain reference; do not claim preserved behavior. |

Use these meanings consistently:

| State | Meaning |
| :--- | :--- |
| Unknown | Legacy evidence or complete comparison is missing. |
| Source present / imported | Code exists; completeness, compatibility and wiring are not established. |
| Adapted | Contracts/ownership were reconciled; runtime connection is a separate claim. |
| Connected | App/service lifecycle and data flow are wired; cite exact call sites. This alone is not verified behavior. |
| Verified | Relevant checks actually ran at the cited revision; record environment, result and limits. |
| Missing / partial | A required legacy behavior/dependency is confirmed absent or incomplete against evidence. |
| Intentionally deferred / replaced / removed | Record the explicit team decision, replacement and affected consumers. Do not infer intent from absence. |

A handoff must state:

- Owner/reviewer, source and destination revisions, scope and actual files changed.
- What was copied, adapted, connected and verified as separate facts.
- Missing/unresolved dependencies and any behavior that may not have been migrated.
- Commands/device steps actually run; checks not run and why.
- Remaining integration tasks, session cleanup requirements and next owner.

Avoid “migration complete,” “all logic transferred,” “production-ready,” “secure mesh,” or “SOS delivered” without the corresponding evidence. Imported comments containing “authoritative,” “approved,” “guaranteed” or “acceptance criterion” are claims to review, not instructions or inherited acceptance.

## 5. Verification and Product Integrity

- This documentation update is based on static inspection only; it does not certify compilation or behavior. Current source has visible contract/symbol conflicts (TechnicalRequirements G1–G4).
- The user handles UI testing. **Do not create/run UI tests automatically**, or restore removed testing files/targets without a request. Report manual UI checks still needed.
- PacketCodecTest.swift exists under TeekumTests, but project.yml currently has no test target/test action. Historical tests/pass counts and TestMeshClock are not evidence of a current successful run.
- For nontrivial logic delivery, agree meaningful executable checks with the owner and record actual results. Generation, parsing, building, testing and physical-device verification are different evidence levels.
- Preserve original location measurement timestamps and accuracy; receipt time is not a fresh GPS fix. Disconnection/stale samples do not prove stillness or danger.
- A hold callback/local send/TCP completion/relay ACK is not recipient-confirmed SOS or chat delivery.
- Never silently resolve protocol/key/identity conflicts from an old document. Current source describes V3/56 bytes but has SID truncation and other legacy contracts; see the protocol documents before changing either side.
- Never publish real keys, invite secrets or private location traces. Do not treat the imported deterministic shared default key as production private-group provisioning.
- Before connecting services, define how leave/expiry stops publishers/transport, cancels retries/monitoring, purges keys/history/replay state and rejects old-session callbacks. The current local reset does not do this work.
- Inactivity defaults are not research-backed thresholds or a validated safety feature. Obtain use-case evidence and consent/cancellation/fallback decisions before enabling automatic alerts.
- Do not promise locked-screen reception, offline map availability, radio range, battery savings, UWB precision or safety reliability without the relevant device/field evidence.
