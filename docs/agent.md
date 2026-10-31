# TeeKum — Developer & Agent Guide

**Status:** Working guide for the four-developer team. This file describes how to work on the current starter; it does not claim that planned features are implemented.

## 1. Read Before Starting

1. [README.md](../README.md) — actual repository status, local setup and documentation map.
2. [TechnicalRequirements.md](TechnicalRequirements.md) — product intent, iOS 27 minimum, target architecture and scope.
3. [Architecture & Ownership](TechnicalRequirements.md#3-architecture--mvvm-feature-driven) — file placement, dependency boundaries and Developer A–D responsibilities.
4. [Open Team Decisions](TechnicalRequirements.md#7-open-team-decisions) — unresolved contracts to settle before dependent work.
5. Read [NETWORKING.md](NETWORKING.md), [PAYLOAD_GUIDE.md](PAYLOAD_GUIDE.md) and [PROTOCOL_SPECIFICATION.md](PROTOCOL_SPECIFICATION.md) only as relevant to your scope. They are draft technical inputs, not accepted implementation evidence.

Technical Requirements owns the target architecture and team decisions. Keep detailed networking behavior in NETWORKING, byte/encoding examples in PAYLOAD_GUIDE, and cryptographic invariants in PROTOCOL_SPECIFICATION. Resolve conflicts in an owner/reviewer PR and update affected references together.

## 2. Architecture Rules

- Minimum deployment target: **iOS 27.0**. Use SwiftUI and **Feature-Driven MVVM**.
- Keep feature UI, ViewModels and feature-only behavior under `Features/<Feature>/`.
- Keep shared session state, messaging and platform infrastructure under `Core/`; reusable presentation belongs in `Shared/UI/`.
- Put payload-free category/status enums in their owner's `Models/Enums/`. Structured records and associated-value enums stay in `Models/`.
- Views render state and forward actions. UI-observed ViewModels/state use explicit MainActor isolation.
- Inject dependencies from App composition. Core must not depend on Features; features must not depend directly on one another.
- SessionStore owns accepted shared session state; SessionRuntime owns session-scoped ingestion, publishing and teardown. Do not duplicate their state or consume the inbound stream from multiple ViewModels.
- Use actors where shared mutable state requires isolation; do not make every service an actor mechanically.
- Use native SwiftUI navigation. No mandatory Coordinator, Repository, UseCase, DI framework or package-per-feature split.
- Preserve the native-framework baseline. Discuss new external dependencies and permissions with the relevant owner before adoption.

## 3. Four-Developer Workflow

The proposed split is defined in [Technical Requirements Section 3.5](TechnicalRequirements.md#35-four-developer-collaboration-baseline). The [migration backlog](MIGRATION_BACKLOG.md) provides candidate tickets, dependencies and acceptance rules. Assign names and reviewers together; role letters are placeholders.

| Role | Primary work |
| :--- | :--- |
| A | Pairing, session lifecycle, key lifecycle, recovery and App composition. |
| B | Transport, wire codec/validation, delivery pipeline and Diagnostics. |
| C | Map/status/sharing, location and power; Live Activity if selected. |
| D | MeetingPoint, SOS interaction and Finder; integrate shared contracts with B/C. |

Before starting a feature:

1. Agree scope, owner/reviewer, dependencies and acceptance criteria in the issue or PR.
2. Resolve any blocking contract from Technical Requirements Section 7. Do not independently invent competing member IDs, packet formats or session states.
3. Follow the [Git Workflow](TechnicalRequirements.md#5-git-workflow) and keep changes small enough to review.
4. Include implementation and relevant tests in the same delivery. Changes to shared contracts need the affected owners' review.
5. Update the relevant core specification when a decision changes. Add feature documentation when there is concrete behavior or an agreed contract to hand off.

## 4. Documentation and Handoff

There is **no mandatory shared development log**. Do not recreate historical POC plans, acceptance reports or pass counts as team starting documents.

Each developer owns documentation for the behavior they deliver. Keep a short feature note at `docs/features/<feature-name>.md` when needed; create it with the actual work, not as an empty onboarding placeholder. Infrastructure changes can update the relevant core reference directly instead of adding another document. Avoid a diary per developer: document the feature/contract so another teammate can maintain it.

A feature note should contain:

- **Owner/reviewer and status:** planned, in progress, implemented, or verified; link the relevant issue/PR.
- **Scope:** behavior delivered, entry points and relevant files.
- **Contracts/dependencies:** commands, state, events, permissions and decisions other features rely on.
- **Verification:** commands or device steps actually run, results and environment; identify checks not run.
- **Limits/next steps:** known gaps and the next integration task.

Keep detailed changes and discussion in PRs. Keep lasting architecture/product decisions in the five core documents. Link useful feature notes from README as they are added; do not duplicate the entire requirements document.

## 5. Verification and Product Integrity

- The Hello-world source is the migration destination. Inspect the legacy feature and agree behavior to preserve/correct/defer/remove before porting. Reuse sound source where available; otherwise identify the work as reviewed behavior reconstruction. The target file tree is a placement guide, not completed source.
- Add executable test targets with the behavior being implemented. Generation/build success is not test execution.
- Validate radio, location, battery and locked-screen behavior on physical devices; mocks/simulators cannot establish field reliability.
- Preserve location measurement timestamps and accuracy. Never display an old coordinate as a fresh live position.
- Distinguish local send, peer/relay receipt and recipient-confirmed SOS delivery.
- Use standard cryptography. Review nonce/key/replay behavior before freezing the wire format; packet-size goals must not weaken security.
- Never put group keys, invite secrets or private location traces in documentation, PR evidence or diagnostics.
- Stop publishers, close transport, cancel tasks and purge session secrets/recovery state on teardown. Check that late callbacks cannot repopulate a later session.
