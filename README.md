# TeeKum — Offline Concert Companion

An iPhone app that helps friends find each other at concerts and festivals when internet connectivity is weak or unavailable. Developed by **Fantasix** using **SwiftUI**, with a target **Feature-Driven MVVM** architecture and a minimum deployment target of **iOS 27.0**.

Planned features include private groups through QR codes or invite links, peer-to-peer location and status sharing, maps and meeting points, friend finding, and SOS alerts. Multi-hop mesh relaying is planned for a later phase.

**Repository status:** a single iPhone app starter displaying “Hello, world!”. The planned features, feature-driven folder structure, Widget Extension, and test targets are not implemented in this starter. The five core documents define the team starting point. Legacy prototype logs, completion reports and checklists have been removed; feature documentation and verification evidence will be written by the developers as implementation proceeds.

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

The output is **`Teekum.xcodeproj` at the repository root**. Select the **Teekum** scheme, choose an iPhone simulator running iOS 27+, and press **Run** (`⌘R`). The expected initial screen displays “Hello, world!”.

For a physical device, select the **Teekum target → Signing & Capabilities**, set your Development Team, and choose a compatible iPhone. If signing requires a different bundle identifier, adjust `PRODUCT_BUNDLE_IDENTIFIER` through the configuration agreed on by the team.

The starter does not use external Swift packages, CocoaPods, a backend, or cloud-service configuration. Running the initial UI does not require `pod install` or service credentials. Location, local network, camera, and motion permissions for the planned features are not configured yet.

### 4. Regenerate After Configuration Changes

```sh
xcodegen generate --spec project.yml
open Teekum.xcodeproj
```

Regenerate after changing `project.yml`, adding/removing/moving source files, or changing targets or dependencies. Editing the contents of an existing source file does not require regeneration every time.

Use **`project.yml` as the source of truth for shared configuration**. Commit source and YAML changes; the generated `.xcodeproj` is ignored by `.gitignore`. Target or scheme changes made only in Xcode may be lost when the project is regenerated.

## Repository Structure

```text
teekum-app/
├── project.yml                 // XcodeGen configuration: Teekum target, scheme, sources and iOS 27 minimum
├── Teekum/Teekum/
│   ├── TeekumApp.swift         // Starter app entry point
│   ├── ContentView.swift       // Initial “Hello, world!” screen
│   └── Assets.xcassets/        // App icon and color assets
├── docs/                       // Five core planning and technical references
├── README.md                   // Overview, setup and documentation reading guide
└── LICENSE                     // MIT License
```

The current source layout does not yet follow the target structure. File names, feature/core folders, responsibility comments, `Models/Enums/` conventions, and the proposed four-developer ownership split are documented in [Technical Requirements — Architecture](docs/TechnicalRequirements.md#3-architecture--mvvm-feature-driven).

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

Follow the [Git Workflow](docs/TechnicalRequirements.md#5-git-workflow): `develop → feat/feature-name → PR to develop → main → prod`. The four-developer scope and reviewer split are in the Architecture section. Use commit prefixes such as `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, or `test:`.

Read the requirements and open decisions before adding frameworks, permissions, or protocol changes. Include the scope, rationale and actual verification results in your PR; update the relevant specification or feature note as needed. Do not record group keys or private location data.

`project.yml` currently defines only the app and build scheme; there is no test target. Successful generation or compilation does not mean tests have run. Future radio, location and background testing will require physical iPhones; use the simulator for UI and logic that can be tested without physical radios.

## License

[MIT](LICENSE) — FantasticEnam.
