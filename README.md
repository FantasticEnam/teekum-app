# TeeKum — Offline Concert Companion

An iPhone app that helps friends find each other at concerts and festivals when internet connectivity is weak or unavailable. Developed by **Fantasix** using **SwiftUI**, with a target **Feature-Driven MVVM** architecture and a minimum deployment target of **iOS 27.0**.

Planned features include private groups through QR codes or invite links, peer-to-peer location and status sharing, maps and meeting points, friend finding, and SOS alerts. Multi-hop mesh relaying is planned for a later phase.

**Repository status:** a single iPhone app starter displaying “Hello, world!”. The planned features, feature-driven folder structure, Widget Extension, and test targets are not implemented in this starter. Prototype documents come from earlier development; that prototype's source code is not included. Completion reports and test results in older documents do not establish that those features exist in this repository.

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
├── docs/                       // Requirements, proposed architecture, review and prototype reports
├── README.md                   // Overview, setup and documentation reading guide
└── LICENSE                     // MIT License
```

The current source layout does not yet follow the target structure. File names, feature/core folders, responsibility comments, `Models/Enums/` conventions, and the proposed four-developer ownership split are documented in [Technical Requirements — Architecture](docs/TechnicalRequirements.md#3-architecture--mvvm-feature-driven).

## Where to Start Reading the Docs

1. **[TechnicalRequirements.md](docs/TechnicalRequirements.md)** — read Section 1 for the product goals, Section 3 for architecture, foldering and ownership, then Section 5 for the Git workflow. Section 2 contains prototype framework references; read its examples and older paths alongside the target structure.
2. **[DOCUMENTATION_REVIEW.md](docs/DOCUMENTATION_REVIEW.md)** — read before making implementation decisions. It tracks inconsistencies, assumptions to validate, and open decisions such as packet size, transport, member identity, and background execution.
3. **Choose references for your task:** networking/payload/security documents for infrastructure, `agent.md` for detailed product flows, and device checklists for verification planning. Check them against the review before adopting older contracts.
4. **Read prototype reports as historical context**, then check the latest entries in `DEVELOPMENT_LOG.md` for recent changes and decisions.

### Documentation Summary

| Document | Contents / when to read |
| :--- | :--- |
| [TechnicalRequirements.md](docs/TechnicalRequirements.md) | Product overview, stack, target Feature-Driven MVVM architecture, files/folders, ownership, testing strategy and Git workflow. Primary reference for the target structure. |
| [DOCUMENTATION_REVIEW.md](docs/DOCUMENTATION_REVIEW.md) | Anomaly register, evidence limits and decisions the team needs to resolve. |
| [agent.md](docs/agent.md) | User stories, product rules, feature behavior and prototype development guidance. Architecture points to Technical Requirements. |
| [NETWORKING.md](docs/NETWORKING.md) | Peer discovery, connections, framing, packet queues, ingestion and network diagnostics. |
| [PAYLOAD_GUIDE.md](docs/PAYLOAD_GUIDE.md) | Payload field/byte breakdowns, encoding and message-type examples. |
| [PROTOCOL_SPECIFICATION.md](docs/PROTOCOL_SPECIFICATION.md) | Wire format, AEAD, nonce, AAD and security validation reference. Still needs reconciliation with the other protocol documents. |
| [POC_IMPLEMENTATION_PLAN.md](docs/POC_IMPLEMENTATION_PLAN.md) | Historical prototype milestones, service contracts and agent assignments. Does not define the current team's ownership split. |
| [PHASE_1_DEVELOPMENT_REPORT.md](docs/PHASE_1_DEVELOPMENT_REPORT.md) | Historical report of claimed Phase 1 features and development results. |
| [POC_ACCEPTANCE_REPORT.md](docs/POC_ACCEPTANCE_REPORT.md) | Historical acceptance report, build/test claims and physical-device sign-off limitations. |
| [P2P_TRANSPORT_REPORT.md](docs/P2P_TRANSPORT_REPORT.md) | Historical transport implementation, framing, outbox and peer-verification guidance. |
| [PHYSICAL_DEVICE_TEST_CHECKLIST.md](docs/PHYSICAL_DEVICE_TEST_CHECKLIST.md) | Two-iPhone location, status, connectivity and battery checks to perform once features are available. |
| [PHYSICAL_DEVICE_SOS_VALIDATION.md](docs/PHYSICAL_DEVICE_SOS_VALIDATION.md) | SOS, receipt, ACK, audio and unauthorized-message rejection scenarios to test once features are available. |
| [DEVELOPMENT_LOG.md](docs/DEVELOPMENT_LOG.md) | Changes, decision rationale, verification and follow-up work; newest entries appear first. |

**Resolving conflicts:** use Technical Requirements Section 3 for the target structure and DOCUMENTATION_REVIEW for unresolved decisions. Do not select a packet format or runtime behavior solely because a document labels it “approved” or “PASS”. Resolve the decision with the responsible owners, then align the specifications and tests.

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

Read the requirements and review before adding frameworks, permissions, or protocol changes. Include the changes, rationale and actual verification results in your PR and the [Development Log](docs/DEVELOPMENT_LOG.md). Do not record group keys or private location data.

`project.yml` currently defines only the app and build scheme; there is no test target. Successful generation or compilation does not mean tests have run. Future radio, location and background testing will require physical iPhones; use the simulator for UI and logic that can be tested without physical radios.

## License

[MIT](LICENSE) — FantasticEnam.
