# TeeKum — Offline Concert Companion

An iPhone app that helps friends find each other at concerts and festivals when internet connectivity is weak or unavailable. Developed by **Fantasix** using **SwiftUI**, with a target **Feature-Driven MVVM** architecture and a minimum deployment target of **iOS 27.0**.

The app connects private QR/invite groups and a public festival mesh to Orbit, location, meeting points, chat and SOS. See [Session migration](docs/features/session-migration.md) for the prototype baseline, XCTest coverage and remaining device checks.

## Prerequisites

- macOS compatible with your Xcode version.
- **Xcode 27.1 recommended**, with the iOS 27 SDK or later. The minimum deployment target in `project.yml` is **iOS 27.0**.
- **XcodeGen 2.46.0 or later** and Git.
- An iOS 27+ simulator runtime. Download it through Xcode Settings if the destination is unavailable.
- GitHub repository access. An Apple Account/Development Team and a device running iOS 27+ are required to run on a physical device; the simulator does not require a signing team.

Tool versions checked when this README was created: Xcode 27.1 and XcodeGen 2.46.0. `SWIFT_VERSION: "6.0"` in the YAML selects **Swift 6 language mode**; it does not require a separate installation of the Swift 6.0 compiler.

## Setup

### 1. Install XcodeGen

If you use Homebrew:

```sh
brew install xcodegen
xcodegen --version
```

If XcodeGen is already installed but older than 2.46.0, update it before generating the project.

### 2. Clone the Repository

```sh
git clone git@github.com:FantasticEnam/teekum-app.git
cd teekum-app
```

This command uses SSH. Make sure your GitHub account has a configured SSH key and repository access. Alternatively, clone through HTTPS:

```sh
git clone https://github.com/FantasticEnam/teekum-app.git
cd teekum-app
```

Use either clone method. Do not include access tokens in the README or shared commands.

### 3. Generate and Open the Project

Run from the repository root containing `project.yml`:

```sh
xcodegen generate --spec project.yml
open Teekum.xcodeproj
```

The output is **`Teekum.xcodeproj` at the repository root**. Select the **Teekum** scheme, choose an iPhone simulator running iOS 27+, and press **Run** (`⌘R`). On a fresh install the app opens Pairing. An existing saved group can be restored from device-only Keychain and local metadata.

For a physical device, set your Development Team for **Teekum** and **TeekumWidgets** in Signing & Capabilities, and choose a compatible iPhone. If signing requires a different bundle identifier, adjust `PRODUCT_BUNDLE_IDENTIFIER` through the configuration agreed on by the team.

No external Swift packages, CocoaPods or backend credentials are required. The app requests camera, local network, Bluetooth, location, motion and notification permissions as needed.

### 4. Regenerate After Configuration Changes

```sh
xcodegen generate --spec project.yml
open Teekum.xcodeproj
```

Regenerate after changing `project.yml`, adding/removing/moving source files, or changing targets or dependencies. Editing the contents of an existing source file does not require regeneration every time.

Use **`project.yml` as the source of truth for shared configuration**. Commit source and YAML changes; the generated `.xcodeproj` is ignored by `.gitignore`. Target or scheme changes made only in Xcode may be lost when the project is regenerated.

## Source and XCTest

`Teekum/Teekum/App` composes the session. `Core` owns shared services and contracts; `Features` owns UI and feature logic; `Shared/UI` contains reusable presentation. `TeekumWidgets` contains the Live Activity companion. `TeekumTests` contains the focused XCTest suite.

Use the **Teekum** scheme to run destination XCTest on an iOS simulator. Leave local simulator signing enabled for the Keychain cases. To compare the same tests with the clean sibling `TeeKum-Prototype` at `f4c6393`:

```sh
xcodegen generate --spec project-parity.yml
xcodebuild -project Teekum.xcodeproj -scheme TeekumParity \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  CODE_SIGN_IDENTITY=- test
```

The standalone project uses `project.yml` and does not require the sibling prototype. No UI test target is configured.

## Where to Start Reading the Docs

1. **[TechnicalRequirements.md](docs/TechnicalRequirements.md)** — read Section 1 for product intent, Section 3 for architecture/file placement and the four-developer split, Section 7 for open decisions, and Section 5 for the Git workflow.
2. **[agent.md](docs/agent.md)** — read the working rules, owner/reviewer workflow and feature documentation convention before starting implementation.
3. **Read the technical reference for your scope:** NETWORKING for discovery/transport, PAYLOAD_GUIDE for fields/encoding, and PROTOCOL_SPECIFICATION for cryptography and validation. Resolve conflicting details through the owner/reviewer decisions in Technical Requirements Section 7 before implementing them.

### Core Documentation

| Document | Purpose |
| :--- | :--- |
| [TechnicalRequirements.md](docs/TechnicalRequirements.md) | Product intent, stack, Feature-Driven MVVM file tree, four-developer ownership, verification plan, Git workflow and open team decisions. |
| [agent.md](docs/agent.md) | Developer/agent working rules, feature boundaries, collaboration and documentation handoff. |
| [NETWORKING.md](docs/NETWORKING.md) | Draft peer discovery, connection lifecycle, framing, queues and diagnostics reference. |
| [PAYLOAD_GUIDE.md](docs/PAYLOAD_GUIDE.md) | Draft payload field/byte breakdowns, encoding and worked message examples. |
| [PROTOCOL_SPECIFICATION.md](docs/PROTOCOL_SPECIFICATION.md) | Draft wire/security reference covering AEAD, nonce, AAD, key lifecycle and rejection rules. |

The technical references retain design material for review; they are not proof of implemented or verified features. Packet size/version, transport and identity/security rules still need reconciliation. Use [Open Team Decisions](docs/TechnicalRequirements.md#7-open-team-decisions) to resolve them with the responsible owners and update the affected references together.

### Starting Work as a Team

Assign names to Developer A–D and confirm reviewers using [Architecture & Ownership](docs/TechnicalRequirements.md#35-four-developer-collaboration-baseline). Agree shared contracts and acceptance criteria before dependent features are developed in parallel.

Developers document their delivered scope as work proceeds. Add a concise `docs/features/<feature-name>.md` when useful, following [Documentation and Handoff](docs/agent.md#4-documentation-and-handoff), or update the relevant core reference for infrastructure work. Record actual verification results in the feature PR/note. No shared development log or upfront completion report is required.

## Troubleshooting

| Issue | First check |
| :--- | :--- |
| `xcodegen: command not found` | Install XcodeGen and check your terminal PATH. |
| Source not found during generation | Run from the root; confirm `project.yml` points to `Teekum/Teekum` and that the folder exists. |
| Target/scheme still named Nursitor | Use the latest Teekum YAML, regenerate, and open `Teekum.xcodeproj` at the root. |
| Teekum scheme is missing | Regenerate and make sure you opened the latest generated project. |
| iOS 27 destination is unavailable | Check your Xcode SDK and installed simulator runtimes. |
| Development Team/provisioning is missing | Configure signing for physical devices; use a simulator for the initial UI if no team is available. |
| Swift language version is unsupported | Check the active Xcode/toolchain; the YAML selects Swift 6 language mode. |
| Configuration changes disappear | Keep shared configuration in `project.yml`, then regenerate. |
| QR, maps, permissions or P2P are missing | The starter only displays the initial UI; these features are not implemented in this repository yet. |

## Contribution & Verification

Create `feat/*` branches from `develop` and merge changes back through PRs. `develop` runs CI checks only. Promote release candidates to `main` through a PR for TestFlight distribution and App Store release. The four-developer scope and reviewer split are in the Architecture section. Use commit prefixes such as `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, or `test:`. [Git Workflow](docs/TechnicalRequirements.md#5-git-workflow)

Read the requirements and open decisions before adding frameworks, permissions, or protocol changes. Include the scope, rationale and actual verification results in your PR; update the relevant specification or feature note as needed. Do not record group keys or private location data.

`project.yml` currently defines only the app and build scheme; there is no test target. Successful generation or compilation does not mean tests have run. Future radio, location and background testing will require physical iPhones; use the simulator for UI and logic that can be tested without physical radios.

## License

[MIT](LICENSE) — FantasticEnam.
