# Meepo — Offline Communication for Disaster Relief Posts

Meepo helps relief-post teams, volunteers, and people at the post establish local communication after a disaster when mobile data or internet access is unavailable. Participants can exchange short updates about services and supplies, coordinate at a meeting point, and send an SOS to their group if they need help. Fantasix develops Meepo for iPhone with SwiftUI, Feature-Driven MVVM, and a minimum target of iOS 27.0.

## At the Relief Post

1. **Open a local group.** A coordinator uses **Create Group** and shows the group's QR code to people at the post. Participants use **Join Group** to scan the code or paste an invite they already have.
2. **Share concise updates.** Use Group Chat for information such as `Water at Tent A`, changes to a distribution point, and check-ins such as **I'm safe**. Use a meeting point for a shared destination. Orbit shows directions and distance when location readings are available.
3. **Request help from the group.** Swipe up on **SOS** to send an alert. **I'll be there!** acknowledges the alert on the receiver's phone. When the sender is safe, **End SOS** sends the update that clears the alert on receiving devices. Use the post's established emergency channels for official response. Meepo's SOS goes to the local group.

## How Offline Relay Works

Meepo discovers nearby participating iPhones over local peer-to-peer connections using Bonjour TCP or Bluetooth Low Energy. When a coordinator is beyond direct reach, compatible phones on the path can forward encrypted packets hop by hop. For example, a volunteer at supply distribution can send an update through a nearby relay phone to a coordinator at the relief post.

```text
Supply volunteer ── ≈30 m ── Relay phone ── ≈30 m ── Relief-post coordinator
                  hop 1                  hop 2
```

**About 30 m per hop** is an illustrative spacing for this example. A hop needs a usable radio link between consecutive phones. Walls, interference, phone placement, and available relays affect the path. In the current code, 30 m is a GPS threshold for adjusting location-update cadence. The measured distance does not decide whether a packet is relayed.

Chat delivery status distinguishes an acknowledgment from a recipient device from a packet that has only been relayed. An acknowledgment shows device receipt. For urgent coordination, ask the recipient to confirm in chat or in person. See [Networking](docs/NETWORKING.md#offline-relay-at-a-relief-post) for forwarding, carry, and radio limits.

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

For a physical device, save your signing settings once in `Config/Device.local.xcconfig`. Use the Team ID shown in your Apple Developer account and a development bundle ID available to that team:

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
MEEPO_DEBUG_BUNDLE_ID = com.yourname.meepo.dev
MEEPO_DEBUG_DISPLAY_NAME = Meepo Dev
```

The file is ignored by Git and read by Debug after a normal XcodeGen run. The widget and test targets use the same bundle ID prefix. Choose your iPhone and run the **Teekum** scheme. Release uses the shared Meepo bundle ID and the Time Sensitive Notifications entitlement. Use the team that owns Meepo for TestFlight and for testing that entitlement.

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

Use the **Teekum** scheme to run XCTest on an iOS simulator. Keep local simulator signing enabled for the Keychain cases. Use physical iPhones to verify relay reach, reconnect, SOS feedback, GPS, and locked-screen behavior.

## Documentation

| Document | Purpose |
| :--- | :--- |
| [Technical requirements](docs/TechnicalRequirements.md) | Product scope, frameworks, architecture, feature ownership, and verification plan. |
| [Networking](docs/NETWORKING.md) | Offline relay, radio discovery, queues, connection lifecycle, and diagnostics. |
| [Payload guide](docs/PAYLOAD_GUIDE.md) | Packet layouts, encoding, and message examples. |
| [Protocol specification](docs/PROTOCOL_SPECIFICATION.md) | Authentication, encryption, keys, sequence numbers, and replay handling. |
| [Developer guide](docs/agent.md) | Source organization, review, and verification conventions. |

## Troubleshooting

| Issue | First check |
| :--- | :--- |
| `xcodegen: command not found` | Install XcodeGen and check your terminal PATH. |
| Source not found during generation | Run from the root; confirm `project.yml` points to `Teekum/Teekum` and that the folder exists. |
| Teekum scheme is missing | Regenerate and make sure you opened the latest generated project. |
| iOS 27 destination is unavailable | Check your Xcode SDK and installed simulator runtimes. |
| Development Team/provisioning is missing | Configure signing for physical devices; use a simulator for the initial UI if no team is available. |
| Swift language version is unsupported | Check the active Xcode/toolchain; the YAML selects Swift 6 language mode. |
| Configuration changes disappear | Keep shared configuration in `project.yml`, then regenerate. |
| QR scanning or peer discovery fails | Check the relevant camera, local-network or Bluetooth permission on the iPhone. Use physical phones for radio verification. |

## Contribution & Verification

Create `f/ui/*` or `f/logic/*` branches from `develop` and merge changes back through PRs. `develop` runs CI checks only. Promote release candidates to `main` through a PR for TestFlight distribution and App Store release. The four-developer scope and reviewer split are in the Architecture section. Use commit prefixes such as `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, or `test:`. [Git Workflow](docs/TechnicalRequirements.md#5-git-workflow)

Use the [developer guide](docs/agent.md) for review and verification conventions.

## License

[MIT](LICENSE) — FantasticEnam.
