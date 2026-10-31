# TeeKum

**Technical Requirements · Fantasix Team**
**Last updated:** 29 October 2026
**Status:** Team planning baseline for the current SwiftUI starter. Feature implementation and verification start from the source in this repository; no prototype completion or test results carry over. See [README.md](../README.md) for setup.

> **Reading priority:** Sections 1 and 3 define product intent and the MVVM Feature-Driven structure. Section 3.5 proposes four-developer ownership. Section 7 tracks open team decisions and takes precedence over conflicting details in the retained technical references. Framework examples and legacy paths in Section 2 are design references, not existing starter features.

---

## 1. Project Overview

**App name:** TeeKum  
**Team name:** Fantasix  
**Team members:** Adiat (Developer), Daffa (Developer), Hasan (Developer), Nicho (Developer), Ayu (Designer), Ivanna (Designer)
**Platform and minimum version:** iOS 27+
**UI framework:** SwiftUI (Modern Swift Observation `@Observable`, MVVM Feature-Driven)

**Description:**  
TeeKum is an offline-first iOS app designed to help friends locate one another in crowded concerts, music festivals, and large venues where cellular data or internet access is weak or unavailable. Users form private groups, share their real-time coordinates and current activity status, view friends on an offline map, establish meeting points, and navigate directly toward a selected person.

The system is designed to be completely serverless (*100% serverless*). Devices communicate directly peer-to-peer (Phase 1 MVP) via Apple Wireless Direct Link (AWDL) and Wi-Fi Direct using `Network.framework`. Devices can also opportunistically relay encrypted packets across a multi-hop mesh network for fellow festival attendees (Phase 2). Relay participation is entirely opt-in, and privacy is strictly guaranteed through end-to-end authenticated encryption (zero-knowledge relaying).

### 1.1 Scope and Product Decisions

- **100% Serverless:** No cloud backend, external databases, or user accounts are required. Groups are formed either offline (via QR barcodes) or online (via URL share links) with symmetric encryption keys embedded directly inside the URL fragment.
- **Location + Status Coded Hash:** Periodic updates transmit location coordinates and current status together. Status strings are processed locally, and only a 1-byte compact coded hash is broadcast over the air to minimize radio bandwidth.
- **SOS Is Exceptional:** The SOS emergency button requires a 3-second continuous press-and-hold to prevent accidental triggers while dancing. SOS packets are dispatched immediately through an urgent priority path, preempting normal queues, and receive maximum forwarding priority.
- **User-Controlled Live Sharing:** Users maintain complete control via a *Live Sharing* toggle on the map screen. When OFF, GPS polling and broadcasting are paused to preserve battery and privacy while watching performances. When ON, updates are broadcast every 3–5 seconds while moving, or 15–30 seconds while stationary.
- **Single Active Meeting Point:** A group has strictly one active meeting point at any given time to eliminate confusion. Friends confirm attendance with a single tap (*"I'll be there"*).
- **Compass to Ultra-Wideband Transition:** Long-range navigation (>8m) utilizes a 360° magnetic compass arrow calculating GPS bearing, then transitions automatically and seamlessly to an Ultra-Wideband (Nearby Interaction U1/U2) precision radar upon approaching within ~5–8 meters.
- **Visual Strobe Beacon:** A 1-tap button turns the screen into a high-visibility, high-contrast flashing neon torch to hold above dark, dense crowds.
- **Communal Mesh Compact (Phase 2):** Group membership is an all-in community agreement: joining a group requires agreeing to be a mesh relay node (*"Join the Mesh: Relay for others while others relay for you. Battery-protected; shuts off at 20%"*). Participating devices forward multi-hop encrypted packets for group members and blindly relay encrypted packets for outside festival attendees. Relaying is strictly zero-knowledge (only 4-byte cleartext header inspected; payloads remain AES-GCM encrypted), rate-capped at $\le 2$ pkts/sec with 256 LRU deduplication, and automatically suspends at 20% battery.
- **Festival Survival Mode:** When device battery drops below 20% or enters Low Power Mode, the app automatically suspends stranger mesh relaying, terminates background execution, and throttles GPS sampling to reserve battery strictly for emergency SOS and viewing the offline meeting map.
- **Radical Simplicity:** Targeted to use MVVM Feature-Driven architecture without Coordinators (no MVVM+C) and built with 100% native Apple frameworks (zero third-party dependencies).

### 1.2 Product & Technical Proposals

D1–D9 capture intended behavior from the initial design. Protocol, consent and runtime details remain subject to the owner/reviewer decisions in Section 7; this table is not an implementation acceptance record.

| Proposal | Intended Behavior |
| :--- | :--- |
| **D1 — 100% Serverless Group Pairing** | Groups are formed without cloud servers. A shareable link (`teekum://join#key=Base64Key&sid=%04X&name=GroupName`) carries the 256-bit symmetric encryption key and 16-bit session ID in the URL fragment for online sharing (iMessage/WhatsApp), while an on-screen QR barcode renders the exact same URL string for offline camera scanning at the venue. |
| **D2 — User-Controlled Live Sharing Toggle** | Location broadcasting only occurs when the user enables the *Live Sharing* toggle. When relaxing or watching a show, users turn sharing off to preserve privacy and battery. Emergency SOS alerts broadcast immediately regardless of toggle state. |
| **D3 — Single Active Meeting Point** | Exactly one active rendezvous spot is permitted per group at a time. Any member can propose a meeting point (venue landmark, custom pin, or current location), and friends respond with 1-tap confirmation (*"I'll be there"* or *"Can't make it"*). |
| **D4 — Continuous Directional Finding** | Long-range guidance (>8m) displays a 360° compass arrow and estimated meter distance. Once within ~5–8 meters, the interface smoothly transitions to centimeter-accurate Nearby Interaction (UWB) radar, paired with a 1-tap flashing Screen Strobe beacon. |
| **D5 — Communal Mesh Compact & Background Execution** | **Phase 1 MVP:** Live Activity (`ActivityKit`) displays session status, active meeting point, connected peer count, and emergency SOS alerts across the Dynamic Island and Lock Screen, keeping the app alive in the pocket via Apple's official location status indicator (`showsBackgroundLocationIndicator = true` and `allowsBackgroundLocationUpdates = true`).<br>**Phase 2 Mesh Compact:** Group membership requires an explicit "Join the Mesh" consent agreement during pairing. Once in a group, the device acts as a continuous background relay for fellow group members and blindly forwards stranger festival packets (zero-knowledge, 2 pkts/sec rate cap, 256 LRU deduplication cache). Relaying is an inseparable condition of staying in the group, with an automatic hard shutoff at 20% battery (Festival Survival Mode). |
| **D6 — Festival Survival Mode (Hard 20% Cutoff)** | Automatic critical battery detection. When battery reaches 20% (or Low Power Mode), stranger mesh relaying and background sessions are instantly terminated, reducing CoreLocation sampling to once every 1–2 minutes or on-demand, reserving remaining power strictly for SOS and meeting maps. |
| **D7 — 54-Byte Binary Packet (Protocol v2), 16-Bit Session ID & Coordinate Quantization** | CoreLocation `Double` (`CLLocationDegrees`) coordinates are quantized into big-endian signed 32-bit integers `Int32` (`degrees * 1_000_000`) for ~11 cm resolution. Wire packets are fixed at 54 bytes (8B cleartext envelope + 30B encrypted payload + 16B Poly1305 authentication tag). Group session ID is 16 bits (`UInt16`, `0x0001...0xFFFF`) derived via SHA-256 over timestamp, GPS coordinates, and CSPRNG salt. See [docs/PAYLOAD_GUIDE.md](PAYLOAD_GUIDE.md) for the complete byte-by-byte visual breakdown. |
| **D8 — 2-Byte Base-27 1-to-3 Letter Sender Initials & Serverless QR Group Formation** | Ephemeral member identification inside the 30-byte encrypted payload is compressed from 4 bytes down to exactly 2 bytes (`UInt16`) using base-27 radix encoding of 1 to 3 uppercase letters ($A \dots Z$, e.g. "D", "AB", "DNA", total $18,278 \le 65,535$). Every packet is self-describing, rendering member avatars instantly on the receiving map/radar and completely eliminating runtime P2P radio handshakes. Group formation and 256-bit key exchange are handled serverless via CoreImage QR barcode generation and AVFoundation camera scanning. |
| **D9 — Phase 2 Expanded 2-Byte Hop Control (hopLimit & hopCount UInt8)** | In Phase 2 multi-hop mesh development, expand hop control from a single 1-byte nibble split (`hopLimit: 4 bits`, `hopCount: 4 bits`, range 0..15) into two dedicated 8-bit bytes (`hopLimit: UInt8` and `hopCount: UInt8`, range 0..255). To maintain cryptographic integrity and prevent unauthenticated broadcast storm attacks, `hopLimit` is authenticated verbatim in ChaCha20-Poly1305 AEAD Associated Data (AAD), while `hopCount` is masked to `0x00` in AAD and incremented by intermediate relays. The total 54-byte datagram size is preserved by absorbing 1 byte from the inner payload's 8-byte reserved padding. |

---

## 2. Technologies and Frameworks

This project utilizes **100% Native Apple Frameworks (Zero External Packages / Zero Backend)** to ensure maximum stability, minimal binary footprint, zero supply-chain vulnerabilities, and instant compilation times.

### 2.1 Technology Overview

| Technology | Type | Why we use it | Used in which component |
| :--- | :--- | :--- | :--- |
| **Network.framework** | Apple Framework | Sends and receives 54-byte binary datagrams peer-to-peer offline via AWDL (Wi-Fi Direct & Bluetooth) | `Services/PeerTransportService.swift` |
| **CoreLocation** | Apple Framework | Retrieves GPS coordinates (`CLLocationDegrees` as `Double`), magnetic compass heading, and horizontal accuracy | `Services/LocationService.swift` |
| **CoreMotion** | Apple Framework | Detects physical movement (walking vs stationary) via motion coprocessor to sleep GPS and save ~70% battery | `Services/LocationService.swift` |
| **CryptoKit** | Apple Framework | Authenticated encryption (ChaCha20-Poly1305 / AES-256-GCM), symmetric key exchange, and tamper verification | `Services/CryptoService.swift` |
| **NearbyInteraction** | Apple Framework | High-precision relative distance and 3D directional pointing (Ultra-Wideband U1/U2) within a 5–8 meter radius | `Views/FinderBeaconView.swift` |
| **MapKit** | Apple Framework | Renders venue maps, friend pins, accuracy circles, and rendezvous points using cached offline map data | `Views/MainMapView.swift` |
| **ActivityKit** | Apple Framework | Presents persistent session status, friend proximity, and interactive communal relay approval on Lock Screen & Dynamic Island | `Views/DiagnosticsView.swift` & Widgets |
| **Security (Keychain)** | Apple Framework | Securely stores 256-bit group session encryption keys inside the iOS Keychain / Secure Enclave | `Services/CryptoService.swift` |
| **libsqlite3** | Native C Library | Lightweight local SQLite database for ephemeral session crash-recovery if the app is backgrounded by iOS | `Services/SessionStorage.swift` |

---

### 2.2 Technology Details

#### Network.framework (Peer-to-Peer Transport)

> *Reference Documentation:* See [docs/NETWORKING.md](NETWORKING.md) for the complete networking architecture, protocol specifications, flow control pipelines, and connection lifecycle diagrams.

**What it is:**  
`Network.framework` is Apple's modern low-level networking library. In this application, `NWListener` and `NWConnection` are configured with peer-to-peer Bonjour (`includePeerToPeer: true`) to establish direct datagram connections over Apple Wireless Direct Link (AWDL) and Wi-Fi Direct. This is the exact underlying protocol powering Apple AirDrop, allowing 54-byte binary packets to transmit in single-digit milliseconds without cellular data or Wi-Fi routers.

**Setup required:**
- Add `NSLocalNetworkUsageDescription` to `Info.plist` (e.g., *"This app uses the local network to discover and connect with friends at concerts without internet"*).
- Add `NSBonjourServices` array to `Info.plist` declaring the custom service type (e.g., `_teekum._udp`).

**Methods / functions / classes we use:**

| Method / Function / Class | What it does | How we use it in our app | File |
| :--- | :--- | :--- | :--- |
| `NWListener` | Listens for inbound connections from nearby devices without a central server. | Operated by `PeerTransportService` to accept incoming peer links over AWDL. | `PeerTransportService.swift` |
| `NWConnection` | Manages a bi-directional transmission channel to a specific peer. | Sends and receives 54-byte binary datagrams to neighboring devices. | `PeerTransportService.swift` |
| `NWParameters.peerToPeer` | Enables peer-to-peer radio transport options (AWDL and Wi-Fi Direct). | Configured on listeners and connections to operate offline without Wi-Fi routers. | `PeerTransportService.swift` |
| `NWBrowser` | Scans for nearby peers advertising the group's Bonjour service. | Discovers friend devices and eligible relays within a 30–50 meter radio range. | `PeerTransportService.swift` |
| `send(content:contentContext:isComplete:completion:)` | Transmits raw binary data across an active connection. | Enqueues encrypted 54-byte packets into the radio outbox queue. | `PeerTransportService.swift` |

**Code example from our project:**

```swift
import Foundation
import Network

actor PeerTransportService {
    private var listener: NWListener?
    private var activeConnections: [String: NWConnection] = [:]
    
    func startAdvertisingAndListening(serviceType: String) throws {
        let params = NWParameters.udp
        params.includePeerToPeer = true
        
        let listener = try NWListener(using: params)
        listener.service = NWListener.Service(name: UUID().uuidString, type: serviceType)
        listener.newConnectionHandler = { [weak self] newConn in
            Task { await self?.handleIncomingConnection(newConn) }
        }
        listener.start(queue: .global(qos: .userInitiated))
        self.listener = listener
    }
    
    func sendPacket(data: Data, to connection: NWConnection) async throws {
        guard data.count == 54 else { throw TransportError.invalidPacketSize }
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            })
        }
    }
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receivePacket(from: connection)
    }
    
    private func receivePacket(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 54, maximumLength: 54) { [weak self] content, _, _, error in
            if let data = content, data.count == 54 {
                Task { await self?.processInboundPacket(data) }
            }
            if error == nil { self?.receivePacket(from: connection) }
        }
    }
    
    private func processInboundPacket(_ data: Data) {
        // Dispatched to the 6-step Inbound Ingestion Pipeline
    }
}
```

---

#### CoreLocation

**What it is:**  
`CoreLocation` delivers device geographical coordinates (latitude, longitude, accuracy) and magnetic compass heading. Coordinates are represented natively as `CLLocationDegrees` (`Double`). In this application, `LocationService` manages adaptive battery sampling (every 3–5s while walking, 15–30s while stationary) and quantizes 64-bit `Double` coordinates into 32-bit `Int32` integers for binary transmission.

**Setup required:**
- Add `NSLocationWhenInUseUsageDescription` to `Info.plist`.
- Enable *Background Modes* (Location Updates) in Signing & Capabilities for emergency SOS navigation.

**Methods / functions / classes we use:**

| Method / Function / Class | What it does | How we use it in our app | File |
| :--- | :--- | :--- | :--- |
| `CLLocationManager` | Central controller for configuring and receiving location and heading updates. | Managed in `LocationService` to monitor GPS coordinates and compass orientation. | `LocationService.swift` |
| `CLLocationCoordinate2D` | Stores latitude and longitude as 64-bit `Double` (`CLLocationDegrees`). | Standard representation of device and peer positions on the map. | `LocationPin.swift` |
| `CLLocation.horizontalAccuracy` | Provides coordinate uncertainty radius in meters (`Double`). | Renders visual accuracy circles on the map and populates the packet accuracy byte. | `LocationService.swift` |
| `startUpdatingLocation()` | Initiates periodic GPS positioning callbacks. | Activated only when the *Live Sharing* master toggle is enabled. | `LocationService.swift` |
| `startUpdatingHeading()` | Initiates built-in magnetometer sensor callbacks. | Drives the 360° directional arrow during navigation toward a friend. | `LocationService.swift` |

---

#### CoreMotion

**What it is:**  
`CoreMotion` accesses data generated by the iPhone's low-power motion coprocessor, accelerometer, and gyroscope. In this application, `CMMotionActivityManager` detects whether the user is actively walking or stationary (e.g., standing still watching a band or dancing in place). By feeding this motion state into `LocationService`, the app automatically powers down or throttles the battery-hungry GPS receiver when the user is not moving, saving ~70% of GPS power consumption during long festival hours.

**Setup required:**
- Add `NSMotionUsageDescription` to `Info.plist` (e.g., *"This app monitors motion activity to power down GPS when you are stationary, conserving battery during long festival hours"*).
- Check `CMMotionActivityManager.isActivityAvailable()` at runtime before requesting updates.

**Methods / functions / classes we use:**

| Method / Function / Class | What it does | How we use it in our app | File |
| :--- | :--- | :--- | :--- |
| `CMMotionActivityManager` | Manages motion activity updates from the low-power motion coprocessor. | Monitored in `LocationService` to govern adaptive GPS sampling. | `LocationService.swift` |
| `CMMotionActivityManager.isActivityAvailable()` | Checks whether the current device supports motion activity tracking. | Verifies hardware motion capability before subscribing to activity updates. | `LocationService.swift` |
| `startActivityUpdates(to:withHandler:)` | Subscribes to live motion state changes on a background queue. | Delivers `CMMotionActivity` events (`stationary`, `walking`, `running`) to trigger GPS power-down. | `LocationService.swift` |
| `CMMotionActivity.stationary` | Boolean flag indicating whether the device is currently stationary. | When `true`, instructs `LocationService` to pause high-accuracy GPS and sleep. | `LocationService.swift` |
| `CMMotionActivity.confidence` | Rating (`low`, `medium`, `high`) of motion detection accuracy. | Filters out brief micro-movements to avoid false GPS wakeups. | `LocationService.swift` |

**Code example from our project:**

```swift
import CoreLocation
import CoreMotion
import Foundation

final class LocationSamplingPolicy {
    private let motionManager = CMMotionActivityManager()
    private let operationQueue = OperationQueue()
    private(set) var isStationary: Bool = false
    
    func startMotionMonitoring(onMotionStateChanged: @escaping (Bool) -> Void) {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        
        motionManager.startActivityUpdates(to: operationQueue) { [weak self] activity in
            guard let activity = activity, activity.confidence != .low else { return }
            let stationary = activity.stationary
            if self?.isStationary != stationary {
                self?.isStationary = stationary
                DispatchQueue.main.async {
                    onMotionStateChanged(stationary)
                }
            }
        }
    }
}
```

**Challenges or limits we found (optional):**
- **Dancing in Place:** At a concert, rhythmic dancing in place can occasionally be classified as walking; the sampling policy pairs motion activity with a small CoreLocation displacement filter to prevent false continuous GPS locks.
- **Classification Lag:** The motion coprocessor requires ~2–3 seconds of continuous motion to transition confidence from low to high; initial walking pings use a conservative 5-second fallback.

---

#### CryptoKit

**What it is:**  
`CryptoKit` is Apple's native hardware-accelerated cryptographic framework. In this application, `CryptoKit` provides authenticated symmetric encryption (ChaCha20-Poly1305 / AES-256-GCM) to seal the 30-byte inner payload with a 16-byte authentication tag, while binding the 8-byte cleartext outer envelope as Associated Authenticated Data (AAD).

**Setup required:**
- Import `CryptoKit`. No special `Info.plist` entries required.

**Methods / functions / classes we use:**

| Method / Function / Class | What it does | How we use it in our app | File |
| :--- | :--- | :--- | :--- |
| `SymmetricKey` | Represents a 256-bit symmetric key for a group session. | Generated on group creation and exchanged via URL fragment or QR barcode. | `CryptoService.swift` |
| `ChaChaPoly.seal(_:using:nonce:authenticating:)` | Encrypts payload and computes a 16-byte Poly1305 authentication tag over ciphertext and AAD. | Encrypts 30 bytes of private coordinates and binds the 8-byte outer envelope as AAD. | `CryptoService.swift` |
| `ChaChaPoly.open(_:using:authenticating:)` | Decrypts ciphertext and verifies the Poly1305 tag against AAD. | Validates inbound packets; forged packets or altered envelope fields are dropped instantly. | `CryptoService.swift` |
| `ChaChaPoly.Nonce(data:)` | Creates a unique 96-bit initialization vector per packet. | Derived from 16-bit session ID (2B) + 32-bit sequence number (4B) + version/type (1B) + 5-byte domain tag "TKM02" (5B). | `CryptoService.swift` |

---

#### NearbyInteraction

**What it is:**  
`NearbyInteraction` leverages Apple's Ultra-Wideband (UWB U1/U2) chip available on iPhone 11 and later. In this application, it solves the *"Last 10 Meters in the Dark"* problem by computing high-precision relative distance and 3D directional vectors (accurate to centimeters) toward a friend's device within an 8-meter radius.

**Setup required:**
- Add `NSNearbyInteractionUsageDescription` to `Info.plist`.
- Check device compatibility at runtime via `NISession.isSupported`.

**Methods / functions / classes we use:**

| Method / Function / Class | What it does | How we use it in our app | File |
| :--- | :--- | :--- | :--- |
| `NISession` | Coordinates an active Ultra-Wideband distance and direction tracking session. | Activated when a user approaches within ~5–8 meters of a targeted friend. | `FinderBeaconView.swift` |
| `NIDiscoveryToken` | Ephemeral radio token exchanged between peers to pair a UWB session. | Exchanged over the local peer-to-peer transport to initiate UWB ranging. | `FinderBeaconView.swift` |
| `session(_:didUpdate:)` | Delegate callback delivering distance (`Float` meters) and direction (`simd_float3`). | Updates the close-range precision radar arrow on the screen. | `FinderBeaconView.swift` |

---

#### MapKit

**What it is:**  
`MapKit` renders venue maps, friend pins, navigation paths, and festival landmarks. In this application, MapKit utilizes Apple's offline cached map capabilities (*MapKit Offline Map System*), ensuring base maps, streets, and venue footprints remain visible without cellular data.

**Setup required:**
- Import `MapKit`. Requires location authorization to display user location.

**Methods / functions / classes we use:**

| Method / Function / Class | What it does | How we use it in our app | File |
| :--- | :--- | :--- | :--- |
| `Map` (SwiftUI) | Declarative container for presenting camera viewports, overlays, and annotations. | Renders the primary festival map interface in `MainMapView`. | `MainMapView.swift` |
| `Annotation` | Displays custom interactive map pins at specified coordinates. | Renders friend avatars, current status emoji badges, and meeting point icons. | `MainMapView.swift` |
| `MapCircle` | Renders a geographic circle overlay with an explicit radius in meters. | Displays coordinate accuracy rings that fade as signals degrade in crowds. | `MainMapView.swift` |

---

#### ActivityKit

**What it is:**  
`ActivityKit` manages Live Activities presented across the iPhone Lock Screen, StandBy, and Dynamic Island. In this application, ActivityKit displays ongoing session status and friend proximity passively, and presents interactive prompts for *Communal Relay* approval when nearby peers require a mesh forwarding hop.

**Setup required:**
- Add `NSSupportsLiveActivities = YES` to `Info.plist`.
- Create a Widget Extension target containing an `ActivityConfiguration`.

**Methods / functions / classes we use:**

| Method / Function / Class | What it does | How we use it in our app | File |
| :--- | :--- | :--- | :--- |
| `ActivityAttributes` | Protocol defining static and dynamic properties of a Live Activity. | Encapsulates festival session data, group name, and relay approval states. | `RelayActivityAttributes.swift` |
| `LiveActivityIntent` | Protocol enabling interactive buttons directly on the Lock Screen. | Powers **[Approve Relay]** and **[Decline]** actions without unlocking the device. | `RelayAppIntents.swift` |
| `Activity.request(...)` | Starts a Live Activity instance on Dynamic Island and Lock Screen. | Called upon creating or joining an active festival session. | `DiagnosticsView.swift` |

---

#### Security (Keychain Services)

**What it is:**  
The `Security` framework provides hardware-backed credential and key storage within the Secure Enclave. In this application, the 256-bit symmetric session key is stored in the iOS Keychain during active sessions, and is permanently purged when the user leaves the group or ends the session.

**Setup required:**
- Import `Security`.

**Methods / functions / classes we use:**

| Method / Function / Class | What it does | How we use it in our app | File |
| :--- | :--- | :--- | :--- |
| `SecItemAdd(_:_:)` | Stores a secret item in the iOS Keychain database. | Saves the symmetric session key extracted from a QR barcode or URL link. | `CryptoService.swift` |
| `SecItemCopyMatching(_:_:)` | Retrieves a secret item from the Keychain using query attributes. | Reads the symmetric key when decrypting incoming packets. | `CryptoService.swift` |
| `SecItemDelete(_:)` | Permanently deletes a secret item from the Keychain. | Purges session keys when the user taps *"Leave Group"* or the session expires. | `CryptoService.swift` |

---

#### libsqlite3 (Native SQLite)

**What it is:**  
`libsqlite3` is the native C database engine pre-installed on all iOS devices. In this application, SQLite is utilized strictly as an ephemeral crash-recovery store. If a user switches to the Camera app to record a 4K concert video and iOS temporarily suspends the app in the background, this snapshot ensures active group membership and member states are restored upon relaunch. The database is wiped clean upon session teardown.

**Setup required:**
- `import SQLite3` (built into iOS; zero third-party dependencies).

**Methods / functions / classes we use:**

| Method / Function / Class | What it does | How we use it in our app | File |
| :--- | :--- | :--- | :--- |
| `sqlite3_open_v2(...)` | Opens a connection to a local database file in the Application Support directory. | Initializes the ephemeral session SQLite storage. | `SessionStorage.swift` |
| `sqlite3_prepare_v2(...)` | Compiles an SQL query string into an efficient byte-code statement. | Prepares queries for updating member states and checking deduplication caches. | `SessionStorage.swift` |
| `sqlite3_step(...)` | Executes a compiled SQL statement. | Writes latest coordinate snapshots and reads recovery state. | `SessionStorage.swift` |
| `sqlite3_finalize(...)` | Finalizes a prepared statement and frees allocated memory. | Prevents memory leaks on background actor threads. | `SessionStorage.swift` |

---

## 3. Architecture — MVVM Feature-Driven

### 3.1 Architecture Name & Status

**Target architecture:** MVVM Feature-Driven with SwiftUI and Swift Observation (`@Observable`), minimum iOS 27+. This is a documentation design baseline for the four-developer team, pending implementation and team review. It is not a claim that the prototype already uses this structure.

**Deployment baseline:** Set the app and any included Widget Extension deployment targets to iOS 27.0. Configure test targets and destinations against that baseline, using an SDK/toolchain that supports it. Field-test devices must run iOS 27 or later. This docs-only change does not modify Xcode build settings.

MVVM defines responsibilities inside a feature. Feature-Driven defines where related files live. Each feature owns its Views, ViewModels, feature-specific Models, and feature-specific Services. Cross-feature session state and platform infrastructure have explicit shared owners.

No Coordinator framework, dependency injection package, mandatory Repository/UseCase layer, or separate Swift package per feature is required. Start with folders in one app target. A Live Activity, if included, needs its own widget extension target; it is not an additional app platform.

### 3.2 Dependency & Ownership Rules

```text
App (creates dependencies, owns their lifetime, composes screens)
  ├── Features/Pairing, Map, MeetingPoint, SOS, Finder, Diagnostics
  │      View -> ViewModel -> injected service / SessionStore
  │                               |
  └── Core (shared models, session state, messaging, platform services)
                 |
          Apple frameworks

Shared/UI -> SwiftUI only (reusable presentation)
Core must not depend on Features. Features must not import each other.
```

1. **View:** Render state and forward actions. Keep transient presentation state (sheet selection, focus, navigation path) local where appropriate. No sockets, packet parsing, keys, or database access.
2. **ViewModel:** `@MainActor @Observable` screen state and user actions. Call injected dependencies and map results to UI state. Never own the entire networking pipeline or create global services. A simple reusable view does not need a ViewModel.
3. **Model:** Swift value types for app data. Payload-free categorical enums belong to the owning `Models/Enums/` folder (Section 3.3). A member's initials are a display label, not a unique identity. Packet DTOs and byte codecs belong to Messaging, not to a map ViewModel.
4. **Service:** Own a concrete operation or platform lifecycle. Feature-only behavior stays in that feature; shared transport, cryptography, location, and persistence live in Core.
5. **SessionStore:** One `@MainActor @Observable` owner of accepted session state (membership, latest member samples, active meeting point, emergency state). Feature ViewModels derive screen state from it; do not keep independently writable copies of the same roster or meeting point. Sample receipt time and location measurement time are separate fields.
6. **SessionRuntime:** Own session-scoped tasks: transport event ingestion, validation, publishing, and teardown. It updates SessionStore through a MainActor boundary. It has no navigation or view references. Feature commands that affect shared state go through this session boundary, rather than each feature constructing encrypted packets.
7. **Composition:** `AppDependencies` explicitly creates shared dependencies and injects only the capabilities each ViewModel needs. No global singleton/service locator. Create shared services once per intended lifecycle, never during `body` evaluation.
8. **Concurrency:** Use actors for shared mutable networking/storage state where needed. Do not make every service an actor mechanically: UI-facing state and CoreLocation delegate integration need an explicit isolation plan. Pass immutable `Sendable` snapshots across isolation boundaries. Keep byte processing and blocking persistence work off the MainActor.
9. **Event delivery:** SessionRuntime is the single consumer of inbound transport packets. It publishes validated state to SessionStore. Do not give multiple ViewModels a competing iterator over the same inbound stream. Cancel subscriptions and timers when their owner ends.
10. **Shared promotion:** Move code to Core or Shared only when multiple features actually need it. Core contains behavior/data; Shared/UI contains presentation. Avoid catch-all `Utils`, `Helpers`, or `Managers` folders.

`SessionRuntime` is a session service, not a navigation Coordinator. Its concrete execution context and protocol signatures must be settled against the actual code before implementation.

### 3.3 Target Folder Structure

Paths below are proposed implementation files, not an inventory of source available in this repository. Comments use `//` to explain each file's responsibility. This is a placement guide: do not create empty files or placeholder folders just to complete the tree. Conditional files are marked explicitly.

```text
TeeKum/
├── App/
│   ├── TeeKumApp.swift                       // App entry point; create and retain app dependencies
│   ├── AppRootView.swift                     // Switch pairing/session roots; own navigation and sheet presentation
│   └── AppDependencies.swift                 // Construct and inject services, SessionStore, SessionRuntime and ViewModels
├── Features/
│   ├── Pairing/
│   │   ├── Views/
│   │   │   ├── GroupPairingView.swift        // Create-group form, initials input, scan-to-join and invite entry
│   │   │   ├── GroupQRCodeView.swift         // Show current group's QR invite and native sharing action
│   │   │   ├── QRScannerView.swift           // Camera preview bridge; forward scanned strings for validation
│   │   │   └── MeshAgreementView.swift       // Present agreed relay/privacy policy before session activation
│   │   ├── ViewModels/
│   │   │   └── PairingViewModel.swift        // Form validation, pending invite, consent actions and pairing feedback
│   │   ├── Models/
│   │   │   ├── GroupInvite.swift             // Parsed invite data; contains sensitive key material, never log it
│   │   │   └── Enums/
│   │   │       └── PairingMode.swift         // Payload-free UI choices: create group or scan to join
│   │   └── Services/
│   │       ├── GroupInviteCodec.swift        // Encode/decode QR and deep-link invite formats; validate input
│   │       ├── QRCodeGenerator.swift         // Generate QR image from invite content using CoreImage
│   │       └── QRScannerService.swift        // Own AVFoundation capture session, permission and scan callbacks
│   ├── Map/
│   │   ├── Views/
│   │   │   ├── MainMapView.swift             // MapKit viewport, member pins, accuracy rings and feature action callbacks
│   │   │   ├── FriendDetailView.swift        // Show selected member's last sample, status, distance and finder action
│   │   │   ├── StatusPickerView.swift        // Horizontal status choices; send selection to MapViewModel
│   │   │   └── LiveSharingControlView.swift  // Sharing intent toggle plus actual publishing availability feedback
│   │   └── ViewModels/
│   │       └── MapViewModel.swift            // Map screen state, selected member, status/sharing commands and freshness display
│   ├── MeetingPoint/
│   │   ├── Views/
│   │   │   ├── MeetingPointsView.swift       // Active group meeting point, proposal controls and attendance actions
│   │   │   └── SetMeetingPointSheet.swift    // Confirm selected map coordinate and landmark label before proposing
│   │   ├── ViewModels/
│   │   │   └── MeetingPointViewModel.swift   // Proposal/attendance actions and screen state from shared session data
│   │   └── Models/
│   │       └── Enums/
│   │           └── PremadeMeetingLocation.swift // Payload-free landmark label choices; not venue coordinates
│   ├── SOS/
│   │   ├── Views/
│   │   │   ├── SOSButtonView.swift           // Three-second continuous hold, progress ring and early-release cancellation
│   │   │   └── SOSDeliveryStatusView.swift   // Present pending, recipient-confirmed or failed delivery honestly
│   │   ├── ViewModels/
│   │   │   └── SOSViewModel.swift            // Hold interaction, trigger command and observed delivery feedback
│   │   └── Services/
│   │       └── SOSAudioAlert.swift           // Audible/haptic presentation for accepted alerts; no packet verification
│   ├── Finder/
│   │   ├── Views/
│   │   │   ├── FinderBeaconView.swift        // Compose compass, supported precision mode and visual beacon controls
│   │   │   ├── CompassView.swift             // Render estimated bearing, distance and location uncertainty
│   │   │   ├── PrecisionRadarView.swift      // Render available NearbyInteraction distance/direction observations
│   │   │   └── StrobeBeaconView.swift        // Visual beacon presentation with explicit start/stop control
│   │   ├── ViewModels/
│   │   │   └── FinderViewModel.swift         // Selected target, capability state, compass/radar selection and beacon state
│   │   ├── Models/
│   │   │   ├── ProximityObservation.swift    // Relative distance/direction, observation timestamp and availability
│   │   │   └── Enums/
│   │   │       └── FinderMode.swift          // Payload-free display modes: compass, precision radar or unavailable
│   │   └── Services/
│   │       └── NearbyInteractionService.swift // Own NISession, discovery-token exchange integration and interruption handling
│   └── Diagnostics/
│       ├── Views/
│       │   └── DiagnosticsView.swift        // Debug HUD for measured session, location and transport snapshots
│       └── ViewModels/
│           └── DiagnosticsViewModel.swift   // Read-only diagnostic formatting; distinguish unavailable from measured values
├── Core/
│   ├── Models/
│   │   ├── GroupSession.swift               // Active group metadata, membership and expiry; no invite parsing
│   │   ├── Member.swift                     // Member identity, initials, latest location, status and reported battery
│   │   ├── MemberID.swift                   // Stable session member identifier; independent of display initials
│   │   ├── LocationSample.swift             // Coordinate, hardware measurement time and horizontal accuracy
│   │   ├── MeetingPoint.swift               // Active proposal identity, coordinate, author and attendance data
│   │   ├── SOSEvent.swift                   // Emergency event identity, originator, sample and delivery records
│   │   └── Enums/
│   │       ├── Status.swift                 // Payload-free festival activity cases; wire code mapping must be agreed
│   │       ├── SOSDeliveryState.swift       // Payload-free delivery phases; event/recipient details stay in SOSEvent
│   │       ├── MeetingAttendance.swift      // Payload-free attendance choices: pending, accepted or declined
│   │       └── LocationFreshness.swift      // Payload-free sample classifications; age/accuracy remain in LocationSample
│   ├── Session/
│   │   ├── SessionStore.swift               // MainActor observable owner of accepted shared state; no sockets or keys
│   │   ├── SessionRuntime.swift             // Session commands, inbound consumer, shared-state updates and task teardown
│   │   └── SessionCommands.swift            // Narrow command contract injected into feature ViewModels
│   ├── Messaging/
│   │   ├── Models/
│   │   │   ├── Packet.swift                 // Envelope and encrypted wire packet data; final schema pending reconciliation
│   │   │   ├── LocationPingPayload.swift    // Normal location/status message data, separate from UI models
│   │   │   ├── SOSPayload.swift             // Emergency message data; preserve source sample timestamp
│   │   │   ├── MeetingUpdatePayload.swift   // Meeting proposal/attendance wire data with agreed conflict references
│   │   │   ├── ACKPayload.swift             // Acknowledged event and recipient data; not a local-send success flag
│   │   │   └── Enums/
│   │   │       └── PacketType.swift          // Payload-free message-kind codes for the selected protocol version
│   │   ├── PacketCodec.swift                // Encode/decode agreed binary layout, endianness, bounds and coordinate quantization
│   │   ├── InitialsCodec.swift              // Encode/decode display initials using the reconciled radix and test vectors
│   │   ├── PacketValidator.swift            // Inbound structural/authentication/freshness checks; reject invalid state updates
│   │   ├── ReplayFilter.swift               // Bounded deduplication and replay state using agreed sender/sequence rules
│   │   ├── PriorityOutboxQueue.swift         // Urgent bounded FIFO plus coalesced unsent normal location updates
│   │   └── SOSDispatcher.swift              // Urgent send, bounded retries and recipient ACK tracking outside UI lifecycle
│   ├── Transport/
│   │   ├── PeerTransport.swift              // Injectable transport contract, inbound events and connection lifecycle
│   │   ├── PeerTransportService.swift       // Network.framework discovery, connections, reconnects and transport isolation
│   │   ├── StreamMessageFramer.swift         // Conditional: TCP stream buffering/framing; omit if datagrams are selected
│   │   └── Models/
│   │       ├── PeerInfo.swift               // Transport peer identifier, endpoint and connection observations
│   │       ├── TransportDiagnostics.swift   // Measured connection/packet/error counters; no fabricated radio metrics
│   │       └── Enums/
│   │           └── TransportState.swift     // Payload-free lifecycle phases; peer/error details travel in event data
│   ├── Security/
│   │   ├── CryptoServiceProtocol.swift      // Testable seal/open and key-lifecycle contract
│   │   ├── CryptoService.swift              // CryptoKit AEAD using agreed nonce/AAD construction; never invent primitives
│   │   └── KeychainStore.swift              // Session-key storage, retrieval and deletion; never expose keys to diagnostics
│   ├── Location/
│   │   ├── LocationServiceProtocol.swift    // Testable location/heading updates, permission and availability contract
│   │   ├── LocationService.swift            // CoreLocation lifecycle/delegates with explicit isolation and original timestamps
│   │   ├── MotionActivityService.swift      // CoreMotion movement observations, permission and unsupported-state handling
│   │   ├── LocationSamplingPolicy.swift     // Select sampling policy from sharing intent, movement and power state
│   │   └── LocationPublisher.swift          // Cancellable publish cadence; preserve stale/invalid sample semantics
│   ├── Persistence/
│   │   ├── SessionStorageProtocol.swift     // Testable recovery read/write/purge contract
│   │   ├── SessionStorage.swift             // Isolated ephemeral SQLite snapshot operations and expiry cleanup
│   │   └── Models/
│   │       └── SessionSnapshot.swift        // Recovery data only; no raw session key or historical location track
│   ├── Power/
│   │   ├── PowerMonitor.swift               // Observe battery and Low Power Mode, including unknown battery state
│   │   ├── SurvivalModePolicy.swift         // Apply agreed cutoff/recovery rules to publishing and relay availability
│   │   └── Models/
│   │       └── Enums/
│   │           └── PowerMode.swift          // Payload-free normal/survival modes; readings remain in monitor state
│   └── LiveActivity/
│       ├── SessionActivityAttributes.swift  // Conditional: minimal ActivityKit attributes shared with widget target
│       └── SessionActivityService.swift     // Conditional: start/update/end Live Activity; no background-runtime guarantee
├── Shared/
│   └── UI/
│       ├── StatusBadgeView.swift            // Reusable status presentation; accepts display data, no SessionStore access
│       └── Theme.swift                      // Shared semantic colors/type styles used across feature views
└── Resources/
    ├── Assets.xcassets                      // App icon, semantic color assets and shipped images
    └── Localizable.xcstrings                // User-facing strings and localization catalog

TeeKumLiveActivity/                           // Conditional Widget Extension target if Live Activity is in scope
├── TeeKumLiveActivityBundle.swift            // Widget extension entry point
└── SessionLiveActivity.swift                 // Lock Screen/Dynamic Island UI; no session engine or encryption keys

TeeKumTests/
├── Features/
│   ├── Pairing/PairingViewModelTests.swift   // Form validation, invite rejection, consent and pending-action behavior
│   ├── Map/MapViewModelTests.swift           // Sharing intent, stale sample display and status commands
│   ├── MeetingPoint/MeetingPointViewModelTests.swift // Proposal/attendance actions against shared state
│   ├── SOS/SOSViewModelTests.swift           // Hold timing, early cancellation and honest delivery presentation
│   ├── Finder/FinderViewModelTests.swift     // Unsupported/interrupted precision mode and compass fallback
│   └── Diagnostics/DiagnosticsViewModelTests.swift // Unknown metrics and separate connection/sample states
├── Core/
│   ├── Session/SessionRuntimeTests.swift    // Single inbound consumer, task cancellation and late-event rejection
│   ├── Messaging/PacketCodecTests.swift     // Golden wire vectors, byte boundaries, coordinates and initials codec
│   ├── Messaging/ReplayFilterTests.swift    // Duplicates, per-sender replay checks and bounded-cache behavior
│   ├── Transport/PeerTransportTests.swift   // Connection lifecycle, framing if applicable and reconnect behavior
│   ├── Security/CryptoSecurityTests.swift   // AEAD tampering, nonce invariants, wrong-key rejection and key lifecycle
│   ├── Location/LocationPublishingTests.swift // Cadence, sharing OFF, sample timestamp and cancellation rules
│   ├── Persistence/SessionStorageTests.swift // Recovery expiry and session teardown purge
│   └── Power/SurvivalModePolicyTests.swift  // Exact cutoff, unknown battery, Low Power Mode and recovery boundaries
├── Integration/
│   ├── SessionLifecycleTests.swift          // Pair/join, inbound state, leave/rejoin and cleanup across services
│   ├── MeetingPointSyncTests.swift          // Concurrent proposals/reconnect reconciliation after protocol decision
│   └── SOSEndToEndTests.swift               // Urgent dispatch, retries, recipient ACKs and duplicate-alert suppression
└── TestDoubles/
    ├── FakePeerTransport.swift              // Deterministic inbound/outbound events without physical radio
    ├── FakeLocationService.swift            // Controlled samples, permissions and stale/invalid location scenarios
    └── TestClock.swift                      // Deterministic cadence, hold, retry and expiry time advancement
TeeKumUITests/
└── CriticalJourneyTests.swift                // Pairing, map, meeting point and SOS user interactions

docs/
├── TechnicalRequirements.md                 // Product intent, architecture, ownership, verification plan and open decisions
├── agent.md                                 // Developer/agent working rules and documentation handoff convention
├── NETWORKING.md                            // Draft discovery, transport, queues and diagnostics reference
├── PAYLOAD_GUIDE.md                         // Draft payload fields and worked encoding examples
└── PROTOCOL_SPECIFICATION.md                // Draft cryptography, nonce, AAD and validation reference
```

#### Model & Enum Placement Convention

- Put a payload-free enum representing a category or simple choice in `Models/Enums/` under its owner. Examples: `Core/Models/Enums/Status.swift`, `Features/Pairing/Models/Enums/PairingMode.swift`, and `Core/Transport/Models/Enums/TransportState.swift`.
- “Payload-free” means its cases have no associated values. A raw value such as `Status: UInt8` is still allowed; it is a code/category, not a separate data record. Computed labels do not change this placement.
- Keep structured data in `Models/`: coordinates, identifiers, timestamps, recipient details and error context belong to a struct/model. For example, `SOSDeliveryState` contains delivery phases; `SOSEvent` holds event/recipient data.
- An enum with associated values represents richer data/state, so keep it directly in the owning `Models/` folder. Do not flatten a useful state machine just to fit `Models/Enums/`, and do not create an enum without cases to represent a status.
- Ownership takes precedence over global grouping: feature-only enums remain in that feature; shared domain enums live in `Core/Models/Enums/`; transport/wire-specific enums remain under their subsystem's `Models/Enums/`. Avoid duplicate `Status` definitions per feature.
- One principal type per file; file name matches its type. Do not put views, ViewModels, services or codecs in `Models/Enums/`.

The widget must not create a second SessionRuntime or hold group encryption keys. `Core/LiveActivity/SessionActivityAttributes.swift` is one shared source file with app/widget target membership, not two copied definitions. Share only the minimum display data required, with App Group configuration decided during implementation.

### 3.4 Feature Boundaries & Data Flow

| Capability | UI owner | Shared behavior / source of truth |
| :--- | :--- | :--- |
| Create/join/leave group, QR/link | Pairing | SessionRuntime owns lifecycle, Security owns keys; SessionStore owns active membership. |
| Map, member detail, status, sharing toggle | Map | Core/Location owns samples and publisher; session commands change sharing/status. |
| Propose/accept meeting point | MeetingPoint | SessionRuntime applies updates; SessionStore owns one active point. Concurrent proposal resolution remains an open protocol decision. |
| Hold SOS and show delivery | SOS | Core/Messaging owns urgent dispatch, retry and recipient ACK processing; SessionStore owns accepted emergency/delivery state. |
| Compass/UWB and beacon | Finder | Core supplies target location; feature service owns NearbyInteraction lifecycle and capability fallback. |
| Debug HUD | Diagnostics | Reads transport/location/session snapshots; cannot infer a hardware state from a static label. |

**Outbound example:** Map action -> MapViewModel -> session command -> publishing/codec/security/outbox -> transport. Toggle intent and actual publishing availability are separate states.

**Inbound example:** transport -> SessionRuntime -> validation/decryption/replay checks -> accepted state update -> SessionStore -> observing feature ViewModels/Views. A fresh network receipt must not reset the age of an old location sample. Exact validation order and packet fields await protocol reconciliation.

**Deep link:** AppRootView hands validated invite input to Pairing; the session starts only after the required consent flow completes. Invites and raw keys must not enter diagnostics or logs.

**Leave/expiry:** stop publishers, close transport, cancel tasks, end Live Activity if present, clear UI/session state and delete session secrets/recovery data. Verify that late callbacks from the previous session cannot repopulate a new one.

### 3.5 Four-Developer Collaboration Baseline

This is a proposed responsibility split; assign names with the team. Each developer owns feature UI, behavior, and relevant tests, with one reviewer for shared interfaces.

| Role | Primary scope | Shared ownership requiring review |
| :--- | :--- | :--- |
| Developer A | Pairing, invite validation, session lifecycle, recovery | Core/Session, Core/Security, Core/Persistence, App composition |
| Developer B | Transport, packet codec/validation, delivery pipeline; Diagnostics UI | Core/Transport, Core/Messaging; A reviews security/session changes |
| Developer C | Map/status/sharing, location, battery; Live Activity if selected | Core/Location, Core/Power, app-side Live Activity; A reviews lifecycle |
| Developer D | MeetingPoint, SOS UI/hold interaction, Finder | B reviews SOS/meeting wire contracts; C reviews location/finder integration |

Agree on session commands/state snapshots, transport events, location samples, diagnostics fields, and SOS delivery semantics before parallel feature work. Define test seams at platform boundaries; do not create a protocol for every class. Use fakes while implementation proceeds. Each PR includes its relevant tests and a reviewer; shared schema or App composition changes need the responsible owner. Review workload at each milestone, especially transport/security and UWB.

### 3.6 Mapping & Migration Sequence

| Legacy design path/name | Target destination |
| :--- | :--- |
| `Views/`, `ViewModels/` | Corresponding `Features/<Feature>/Views` and `ViewModels` |
| `GroupSessionViewModel` | Pairing UI -> PairingViewModel; accepted state -> SessionStore; session tasks -> SessionRuntime |
| `Models/Packet.swift`, initials/wire codecs | `Core/Messaging/` |
| Shared `Member`, location, group, meeting and SOS event records | `Core/Models/` |
| Payload-free `Status`, `SOSDeliveryState` and other shared category enums | `Core/Models/Enums/` |
| Feature/subsystem-only payload-free enums | Owning `Features/<Feature>/Models/Enums/` or `Core/<Subsystem>/Models/Enums/` |
| `PeerTransport*`, `StreamMessageFramer` | `Core/Transport/` |
| `PriorityOutboxQueue` | `Core/Messaging/` |
| `CryptoService*`, Keychain | `Core/Security/` |
| `LocationService*`, `LocationPublisher` | `Core/Location/` |
| `SessionStorage*` | `Core/Persistence/` |
| QR generator/scanner, meeting sheet, agreement view | Owning feature, rather than generic `Views/Components/` |

1. Treat the current Hello-world repository as the migration destination. Capture accessible prototype source/build/screenshots and characterize each feature before migrating it. Agree preserve/correct/defer/remove decisions; where source is unavailable, explicitly approve behavior reconstruction. Establish the destination build baseline and add meaningful fixtures/tests alongside the migrated behavior.
2. Confirm contracts and resolve protocol/security blockers in [Section 7 — Open Team Decisions](#7-open-team-decisions) before implementing transport or cryptography from these docs.
3. Move feature files in small PRs, fixing Xcode target membership and references. Separate mechanical moves from behavior changes.
4. Extract shared session ownership and dependency composition incrementally. Preserve teardown, permission/error behavior, publishing policy and honest SOS delivery states.
5. Verify automated state/codec/security checks and physical-device flows. Include locked screen, sharing OFF, stale GPS, loss/reconnect, Low Power Mode, and leave/rejoin. A folder refactor alone cannot establish runtime correctness.

---

## 4. Verification Plan

This is planned coverage, not a record of tests already implemented or passed. The current starter has no test target. Each owner adds the tests and device evidence required for their delivered behavior; exact commands and destinations must match the actual project at that time.

### 4.1 Owner-Based Verification

| Scope | Owner | Minimum coverage to add with implementation |
| :--- | :--- | :--- |
| Pairing, session, keys and recovery | Developer A | Invalid invites, consent, join/leave/rejoin, key lifecycle, recovery expiry and rejection of late callbacks. |
| Messaging, security validation and transport | Developer B; A reviews security/session behavior | Agreed wire fixtures, bounds, AEAD tampering, nonce uniqueness/restarts, replay rejection, framing for selected transport, queue bounds and reconnect. |
| Map, location, sharing and power | Developer C | Sharing OFF, permission denial, stale/invalid samples, original measurement timestamps, cadence/cancellation and agreed power thresholds. |
| Meeting point, SOS and Finder | Developer D; B/C review integration | Meeting conflict resolution, hold cancellation, urgent dispatch and recipient ACKs, duplicate alerts, unsupported/interrupted precision finding and fallback. |

### 4.2 Verification Evidence

- Add executable unit/integration targets when the first testable behavior is introduced; use controllable transport, location and clock inputs where appropriate.
- A successful `xcodegen generate` or app build is not a test run.
- Record the actual build/test command, revision, destination, result and limitations in the feature PR. Do not copy historical pass counts into new work.
- Shared protocol changes require agreed fixtures and review before dependent features adopt them.

### 4.3 Physical-Device Verification

When radio/location features are implemented, the responsible owner documents reproducible steps and results for two iPhones running iOS 27+ without cellular data or an infrastructure Wi-Fi connection. Cover discovery, state exchange, disconnect/reconnect, stale GPS, permissions, sharing OFF, locked-screen behavior, Low Power Mode, session teardown and SOS recipient confirmation.

Simulator results cannot establish radio range, background reliability, location accuracy or battery life. Record device models, OS versions, conditions and observed limits in the owner's feature documentation when that work is performed.

---

## 5. Git Workflow

Development is restricted to **four branch types**: `main`, `develop`, `prod`, and `feat/*`.

### 5.1 Branches

| Branch | Purpose | Who can push directly? | Protected? |
| :--- | :--- | :--- | :--- |
| `main` | Stable release candidate, fully integrated and tested. | None (PR only). | Protected. |
| `develop` | Active integration branch for combining and testing features. | None (PR only). | Protected. |
| `prod` | Final production release code tagged for distribution. | Designated Release PIC. | Protected. |
| `feat/*` | Feature development branch branched off `develop`. | Feature developer. | Unprotected. |

### 5.2 Branch Diagram

```text
develop → feat/feature-name → PR to develop → PR to main → PR to prod
```

### 5.3 Merging Rules

| Merge | When does it happen? | Who does it? | What must be true first? |
| :--- | :--- | :--- | :--- |
| `feat/*` → `develop` | Feature is complete and verified locally. | PR owner. | Code review approved and local tests pass without errors. |
| `develop` → `main` | Milestone features are verified as a stable release candidate. | Integration PIC. | Full offline peer-to-peer verification succeeds on physical devices. |
| `main` → `prod` | Final build is verified for release. | Release PIC. | Release certificates signed and final acceptance criteria met. |

### 5.4 Step by Step: How One Feature Moves Through Our Workflow

1. Developer creates a branch `feat/feature-name` from the latest `develop`.
2. Implements focused, modular changes.
3. Opens a Pull Request (PR) to `develop` detailing changes and verification evidence.
4. Reviewer reviews code; developer addresses feedback before merging.
5. Stable features are promoted from `develop` to `main` via PRs.
6. Release-ready builds from `main` are merged into `prod`.

### 5.5 Naming and Commit Conventions

**Branch naming:** `feat/feature-name`, lowercase with hyphens (*kebab-case*).  
**Commit message format:** `type: short description` or `type(scope): short description`.  

| Type | Usage | Example |
| :--- | :--- | :--- |
| `feat:` | New application feature or behavior. | `feat(radio): add network.framework p2p transport` |
| `fix:` | Bug fix or corrected behavior. | `fix(packet): correct int32 coordinate quantization` |
| `docs:` | Documentation updates. | `docs: update technical requirements wire protocol` |
| `refactor:`| Code restructuring without visual or functional changes. | `refactor(crypto): isolate keychain storage actor` |
| `chore:` | Repository maintenance, build settings, or `.gitignore`. | `chore: update xcode build settings` |
| `test:` | Adding or improving tests. | `test(packet): add 54-byte codec roundtrip tests` |

---

## 6. Team Starting Point

- The repository contains a single SwiftUI Hello-world app and an XcodeGen configuration targeting iOS 27.0.
- MVVM Feature-Driven foldering, file responsibilities and `Models/Enums/` placement are defined in Section 3; the feature source has not been created yet.
- Developer A–D in Section 3.5 are responsibility slots, not assigned names. Agree names and reviewers before parallel implementation.
- The delivery approach is migration from the existing vibe-coded product/behavior reference, not an assumption that feature requirements start from zero. Use [MIGRATION_BACKLOG.md](MIGRATION_BACKLOG.md) to capture the baseline, assign owners/reviewers, resolve the decisions below and deliver reviewed feature changes with evidence.
- Developers document their own implemented scope using the convention in [agent.md](agent.md#4-documentation-and-handoff). There is no shared chronological development-log requirement and no requirement to create completion reports before implementation.

## 7. Open Team Decisions

The retained networking/payload/security documents are draft design inputs. Resolve these items in the relevant document through owner/reviewer PRs before dependent implementation; do not infer approval from older wording inside examples.

| Topic | Decision needed before implementation | Owner / reviewer |
| :--- | :--- | :--- |
| Wire version and size | Reconcile the 54-byte / 16-bit-session proposal with the 56-byte / 32-bit-session layout in PROTOCOL_SPECIFICATION. Agree version, byte offsets, compatibility and golden fixtures. | B / A |
| Transport | Select TCP or UDP, matching Bonjour service type, receive semantics and framing. References currently differ. | B / A |
| Member identity and initials | Agree unique member identity, sender/slot allocation, initials radix, collisions and rejoin behavior. Initials are display labels, not unique identity. | A + B |
| Crypto and replay | Agree cipher, nonce/AAD construction, counter/restart/key lifecycle and deduplication identity. Review before freezing the wire layout. | A + B |
| Relay consent and scope | Decide whether stranger relaying is optional or required, and keep Phase 2 behavior separate from Phase 1 UI promises. | A / team |
| Background and Live Activity | Define supported runtime states and fallback. A visible indicator or Live Activity is not acceptance evidence for continuous relay or suspended-app SOS receipt. | C / A |
| Battery policy | Agree cutoff boundary, unknown battery state, Low Power Mode precedence and recovery behavior; remove guarantees until measured. | C / B |
| Meeting synchronization | Agree how simultaneous proposals and attendance reconcile after disconnection. | D / B |
| Finder and offline map | Verify map availability without internet, device capabilities, proximity-token exchange and fallback; do not freeze UWB transition distances without evidence. | D + C |
| Diagnostics and honest state | Separate discovered/connected/authenticated peers, measurement age, accuracy and publishing availability. Do not manufacture radio metrics or refresh stale coordinates on packet receipt. | B + C / D |
| Phase 2 security | Review mutable hop metadata, relay abuse budgets, deduplication limits and loop/storm handling before multi-hop work. | B / A |

Custom venue overlays and an Apple Watch companion remain later-phase proposals. They are not prerequisites for onboarding or the direct offline MVP.
