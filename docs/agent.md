# Meepo — Developer & Agent Guide

Use the [relief-post workflow](../README.md#at-the-relief-post) in user-facing examples. Report a relay dispatch separately from a recipient acknowledgment, and describe about 30 m per hop as scenario spacing until field tests establish actual reach. [Networking](NETWORKING.md#offline-relay-at-a-relief-post)

## 1. Read Before Starting

1. Start at the [Feature Map](TechnicalRequirements.md#33-feature-map) to find the screen, state owner, and related services.
2. Read [Networking](NETWORKING.md), [Payload Guide](PAYLOAD_GUIDE.md), and [Protocol Specification](PROTOCOL_SPECIFICATION.md) when changing communication behavior.
3. Inspect `project.yml` and the connected callers of the feature you are changing.

Source paths below are relative to `Teekum/Teekum/`.

## 2. Architecture Rules

- Minimum target: iOS 27.0. Use SwiftUI, Observation and Feature-Driven MVVM.
- Features own their UI, ViewModels, and feature-specific behavior. Core owns shared domain and infrastructure. `Shared/UI` holds reusable presentation. `Shared/Formatters.swift` holds shared formatting helpers.
- Views keep focus, modal, selection and interaction state. ViewModels expose feature actions/presentation. Use MainActor for UI-observed state and appropriate isolation for services.
- Keep SessionStore as the shared roster and meeting-state owner. It applies accepted location and SOS measurements and peer snapshots. Preserve the agreed initials/SID contracts and original GPS measurement time.
- Place feature-only models and enums under the feature. Put shared session records in `Core/Session` and wire schemas in `Core/Packets/Payloads`. In Core, keep types, protocols and `Type+Responsibility.swift` extensions together in the owner folder. Keep test-only fixtures in `TeekumTests/Support`.
- Native navigation stays feature-local: Pairing → Agreement push, local session root switch to Orbit, friends/map modal presentation and dismissal. No mandatory Coordinator, AppDependencies, Repository, UseCase or package split.
- TeekumApp retains SessionController, which composes dependencies and starts/stops work with the session. Screens do not own radio or publisher lifetime.
- The intended dependency direction is Features → Core. PacketRouter stays in Core and receives callbacks from App composition; do not add feature dependencies or a second raw inbound consumer.
- Give inbound streams and background/retry/maintenance tasks explicit ownership and cancellation. Do not let separate screens race to consume the raw inbound stream.
- Do not introduce external dependencies, global locators or broad refactors for unrelated work.

## 3. Four-Developer Workflow

Use the responsibility slots in [Section 3.5](TechnicalRequirements.md#35-four-developer-collaboration-baseline); confirm actual assignees/reviewers in the issue. Shared identity, packet, key and lifecycle changes require the affected owners' review.

1. Identify the change, its callers, and the owner of each affected contract.
2. Use **f/ui/<feature>** for presentation and **f/logic/<feature>** for feature behavior. Branch from `develop`.
3. Confirm compatibility before changing shared packet, identity, key, or lifecycle contracts.

TestFlight and App Store delivery use `main`. See [Git workflow](TechnicalRequirements.md#5-git-workflow).

## 4. Documentation and Handoff

In the change description, record the owner, affected contracts and files, revision, checks that ran, and device behavior still to verify. Update the relevant product or technical document when behavior or configuration changes.

## 5. Verification and Product Integrity

- Record compilation and XCTest results separately from device verification. Follow the [verification plan](TechnicalRequirements.md#4-verification-plan).
- The user handles UI testing. **Do not create/run UI tests automatically**, or restore removed testing files/targets without a request. Report manual UI checks still needed.
- Use the XCTest target in `project.yml`.
- For nontrivial logic delivery, agree meaningful executable checks with the owner and record actual results. Generation, parsing, building, testing and physical-device verification are different evidence levels.
- Preserve original location measurement timestamps and accuracy; receipt time is not a fresh GPS fix. Disconnection/stale samples do not prove stillness or danger.
- An SOS swipe, local send, TCP completion, or relay ACK establishes a different stage from receipt at the recipient's device.
- Review the 56-byte frame, three-byte SID, and key and identity contracts before changing wire behavior.
- Never publish real keys, invite secrets or private location traces. Do not treat the built-in shared default key as production private-group provisioning.
- Changes to session services must preserve cancellation, history/key cleanup and old-session callback rejection. The durable sequence record intentionally survives leave.
- Inactivity defaults are not research-backed thresholds or a validated safety feature. Obtain use-case evidence and consent/cancellation/fallback decisions before enabling automatic alerts.
- Do not promise locked-screen reception, offline map availability, radio range, battery savings, UWB precision or safety reliability without the relevant device/field evidence.

## 6. New File Headers

Add an author header to each new file that supports comments, including Swift app, widget, and XCTest files. Use the actual filename and the creation date in `d/M/yy` format. Preserve existing author headers on files brought over from another source.

```swift
//
//  FileName.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on d/M/yy.
//
```

Use the file format's comment syntax for Markdown, YAML, and XML. In XML, put the comment after the XML declaration.
