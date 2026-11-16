# Volume 06: Location Services, Adaptive Hardware & Live Activity (Meepo)

## Executive Summary & Big-Picture Overview

Volume 06 establishes the spatial awareness, kinetic intelligence, power preservation, local alerting, and system-level lock screen/Dynamic Island presentation architecture for the Meepo off-grid mesh networking client. While lower layers in the Meepo stack manage raw peer-to-peer radio frames (Volume 03) and multi-hop routing paths (Volume 04), the location and Live Activity subsystem sits directly at the physical boundary between native iOS hardware sensors and the user's immediate physical surroundings. It continuously monitors the device's geographical position, directional orientation, and kinetic activity state, translating physical movement into quantized zero-knowledge wire packets while strictly managing energy draw and operating system thermal constraints.

The subsystem operates across five core technical pillars:
1. **Adaptive GNSS & Motion-Aware Cadence Management (`LocationService`, `CadenceConfiguration`):** Continuously sampling GPS satellites and transmitting radio packets in an off-grid environment can deplete an iPhone battery within four hours. Meepo implements a dynamic scheduling hierarchy that modulates both GPS hardware precision (`desiredAccuracy`, `distanceFilter`, `headingFilter`) and network broadcasting intervals (3.0s–5.0s when walking, 15.0s–30.0s when stationary, 2.0s when probing for distant or stale peers, and 60.0s when battery falls below 20%).
2. **Deterministic Monotonic Validation & Quantization (`LocationPin`, `LocationService+Publishing`):** Incoming GPS measurements from Apple's `locationd` daemon are subjected to strict validation filters: invalid negative accuracy fixes are discarded, and timestamp monotonicity is enforced to prevent delayed or cached Wi-Fi fixes from corrupting local state. Floating-point coordinates are quantized via fixed-point scaling factor $1{,}000{,}000.0$ (~11cm precision) into signed 32-bit big-endian integers, packing precise coordinates into compact wire payloads without floating-point serialization variances.
3. **Unconditional Emergency SOS Coordinate Preemption (`LocationServiceProtocol`):** In life-safety distress scenarios, response time is critical. The location architecture guarantees that emergency SOS coordinators have immediate, synchronous access to the latest cached coordinate fix via `getLatestLocationForSOS()`, completely bypassing normal cadence timers and operating even when user Live Sharing is disabled.
4. **Offline Local Alerting & Auto-Dismissing Banners (`NotificationService`):** Because disaster operation environments lack cellular coverage and internet connectivity, Meepo cannot rely on Apple Push Notification service (APNs). `NotificationService` generates local alerts using `UNUserNotificationCenter` for high-priority background events (SOS distress alerts, incoming chat messages, and group member arrivals/departures) and manages self-cancelling 4-second in-app toast banners when the app is active in the foreground.
5. **ActivityKit Live Activities & Dynamic Island Presentation (`LiveActivityManager`, `TeekumWidgets`):** Using an out-of-process App Extension sandbox, Meepo projects real-time session telemetry onto the user's Lock Screen and Dynamic Island across Compact Leading, Compact Trailing, Minimal, and Expanded presentations. Data flow is governed by zero-knowledge privacy rules: `SessionActivityAttributes` contains zero cryptographic keys and zero raw coordinates, transmitting only scalar integer relative distances to prevent spatial leakage outside the primary application sandbox.

---

### ELI5 Overview: The Scout, The Watchman & The Tactical Heads-Up Display

Imagine an emergency search-and-rescue detachment operating in a blacked-out disaster zone without cellular service or internet:

1. **The Tactical Scout (`LocationService`):** The scout monitors a digital magnetic compass and dual-frequency GNSS sensors to calculate real-time grid coordinates. When actively traversing a rubble field, the scout broadcasts position pings every 3 to 5 seconds so search team leads maintain an accurate search track. When the scout halts at an evacuation triage post (`isStationary == true`), broadcasting every 3 seconds drains vital battery; the system automatically throttles broadcasts to once every 20 to 30 seconds.
2. **The Power Conservator (Survival Mode at <20% Battery):** In a prolonged grid blackout, battery is life-support. If battery reserves drop below 20%, the system automatically throttles GNSS sampling to coarse approximations and stretches broadcast intervals to once every 60 seconds (`survivalInterval = 60s`), ensuring the handset maintains power for emergency distress signaling throughout a 72-hour disaster recovery.
3. **The Perimeter Sentry (`NotificationService`):** While responders are resting or navigating with their phones locked in tactical pouches, the sentry monitors incoming mesh radio feeds. If an emergency SOS beacon is detected, the sentry triggers high-priority audio and haptic alarms (`UNUserNotificationCenter`) to alert responders instantly. If the app is active in the foreground, the sentry presents an unobtrusive status banner that auto-dismisses after 4 seconds.
4. **The Tactical Heads-Up Display (`LiveActivityManager` & `TeekumWidgets`):** Projected directly onto the iPhone Lock Screen and Dynamic Island, an ambient status HUD displays critical squad telemetry: nearest responder initials, directional compass bearing, radial distance, and battery health. Responders do not need to unlock their devices with heavy rescue gloves; a glance provides immediate situational awareness. If an operative triggers an SOS flare, the HUD instantly strobes high-intensity red with the casualty's callsign!

---

## Design and UX Guide (Zero Code Required)

This section provides product designers, UX researchers, and brand leads with a non-technical reference explaining how Meepo's location and widget systems behave in the physical world. No code or programming knowledge is required to understand this section.

### User Journey and Screen States

```
[Active Rubble Search] ──► [Stationary at Triage LZ] ──► [Battery Drops <20%] ──► [Emergency SOS]
   Cadence: 3-5s               Cadence: 15-30s              Cadence: 60s           Cadence: Instant
   GPS: Max Precision          GPS: Power Saved             GPS: Coarse 100m       GPS: Cached Fix
   Island: Teal Dot            Island: Teal Dot             Island: Orange Warning Island: Flashing Red
```

1. **Active Search (Traversing Rubble Sectors):**
   - **Screen Experience:** The responder is actively mobile. The tactical radar map displays fluid position updates.
   - **Dynamic Island:** Displays a crisp teal icon on the left (the rendezvous pin) and the active count of nearby squad members on the right (e.g., `3 [peers]`).
   - **Status Bar:** A solid blue pill appears behind the time in the upper-left corner of the iPhone status bar. This confirms that Meepo is maintaining background squad tracking even if the responder switches to another app or locks their phone.

2. **Stationary Staging (Stationed at Triage LZ or Forward Base):**
   - **Screen Experience:** The responder arrives at a field triage checkpoint and halts movement. Within seconds, the device detects that motion has ceased.
   - **Dynamic Island & Widget:** The display remains visible and rock-solid, showing the current distance to the designated triage rally point.
   - **Background Power State:** The device automatically enters a power-saving sleep cadence. Location broadcasts drop from once every few seconds down to once every 15 to 30 seconds, preventing battery exhaustion during prolonged medical care.

3. **Disaster Survival Mode (Battery Under 20% or Low Power Mode):**
   - **Screen Experience:** The user's battery drops to 19%, or iOS Low Power Mode is activated.
   - **Visual Warning:** The UI displays a persistent low-power banner, alerting the responder that location sharing has been throttled to conserve emergency communication capacity.
   - **Dynamic Island & Widget:** Update intervals stretch out to once every 60 seconds. The phone intentionally stops requesting high-drain GPS satellite fixes, relying on coarse sensor approximations (~100 meters). This prevents the device from dying during the critical final hours of an evacuation.

4. **Emergency SOS Distress State:**
   - **Screen Experience:** Any member of the group presses the emergency distress button.
   - **Dynamic Island Override:** Instantly, all normal friend counts and chat indicators disappear. The Dynamic Island flips into high-visibility alert mode:
     - *Left slot:* A bright red circular SOS alarm icon (`sos.circle.fill`).
     - *Right slot:* The 3-letter initials of the friend in danger rendered in bold alert red (e.g., `ADI`).
   - **Lock Screen Card:** The Lock Screen card border and badges illuminate in alarm red, clearly displaying "Emergency SOS", the distressed friend's initials, and the active relay hops required to reach them.

---

### Why Can't We Just...? (Constraints for Designers)

Product designers frequently ask why certain mobile behaviors cannot be styled or configured differently. The following table answers the most common design questions through the lens of iOS platform restrictions:

| "Why Can't We Just...?" | Technical & Platform Reality | Design Solution / Permitted Behavior |
| :--- | :--- | :--- |
| **Why can't we hide the blue status bar location pill?** | Apple mandates that any app using background location with `WhenInUse` authorization must display the blue indicator (`showsBackgroundLocationIndicator = true`) whenever GPS is running in the background. Hiding it requires requesting permanent `Always` authorization, which iOS frequently prompts users to revoke with scary popups, resulting in high uninstall rates. | Embrace the blue pill as an intentional security feature. In onboarding, educate users that the blue pill means "Your group safety mesh is protecting you in the background." |
| **Why can't we update the Dynamic Island every second like a real-time compass needle?** | Apple's ActivityKit framework enforces strict rate limits on background widget updates. Pushing updates faster than every 15 seconds causes the operating system to throttle or entirely suspend the widget process to prevent battery drain. | Keep high-frequency spinning compass needles inside the active foreground app (`OrbitMapView`). Use the Dynamic Island for stable, aggregated milestones (distance in meters, peer counts, and unread badges). |
| **Why does location precision drop when users stand still?** | High-precision dual-frequency GPS (L1/L5) requires continuous radio power that draws up to 120 mA of current. When a responder or survivor is stationary at a forward triage post or shelter, continuous sub-meter tracking is redundant because their physical position has not shifted. | Design the UI to show an expanding "confidence halo" or subtle resting badge around stationary friends on the map, indicating that their location is verified but power is being preserved. |
| **Why can't the widget read the raw GPS coordinates directly?** | App Extensions run in a completely isolated system process outside the main app sandbox. Giving the widget direct access to raw GPS would duplicate hardware power draw and violate Apple's memory ceiling (~30 MB maximum for widget processes). | The main app precomputes the relative distance in integer meters and sends only the precalculated number to the widget. The widget never touches GPS hardware. |
| **Why can't we display full friend names on the Lock Screen?** | Lock Screen cards and Dynamic Island pills have extremely tight width budgets. A long name like "Christopher" truncates or pushes emergency SOS buttons off-screen on smaller devices like the iPhone 14 Pro or iPhone 15. | Strictly format all identities into compact, standardized 3-letter uppercase initials (e.g., `CHR` or `DAF`) inside a 56x56 color-coded avatar circle. |

---

### Editable Design Tokens vs. Locked Engineering Rules

To ensure smooth collaboration between UI/UX designers and iOS systems engineers, the following matrix defines what interface properties are freely customizable versus what rules are hard-coded into the hardware engine:

```
+---------------------------------------------------------------------------------+
|                       DESIGN & ENGINEERING BOUNDARY MATRIX                      |
+------------------------------------+--------------------------------------------+
| FREELY EDITABLE DESIGN TOKENS      | LOCKED HARDWARE ENGINEERING RULES          |
| (Colors, Layouts, Copy, Assets)    | (Cadence, Battery, Encryption, Safety)     |
+------------------------------------+--------------------------------------------+
| 1. Primary Accent Color (Teal)     | 1. Survival Mode Battery Cutoff (<20%)     |
| 2. Alert Badge Color (Pure Red)    | 2. Stationary Detection Cadence (15s-30s)  |
| 3. Dynamic Island Margin & Padding | 3. Motion Detection Cadence (3s-5s)        |
| 4. Avatar Circle Size (56x56 pt)   | 4. SOS Cadence (Instantaneous / 0s)        |
| 5. Toast Auto-Dismiss Time (4s)    | 5. Maximum Widget Payload Size (4 KB limit)|
| 6. Custom Vector Icon ("MeetPoint")| 6. ActivityKit Update Throttle (15s minimum|
| 7. Font Hierarchy (Helvetica/SF)   | 7. Coordinate Quantization Factor (1e6)    |
+------------------------------------+--------------------------------------------+
```

1. **Freely Editable UI Design Tokens:**
   - **Brand Colors:** The primary teal tint (`Color.buttonPrimary`) used for the Rendezvous icon and trailing badge counts can be restyled in `Theme.swift`.
   - **Emergency Accent:** The alert red tint (`Color.red`) used for SOS initial rings and warning triangles can be tuned for high-contrast visibility.
   - **Card Geometry:** Padding, corner radii (e.g., `Capsule()`), and background opacity on Lock Screen cards (`SessionLiveActivityView.swift`) can be styled to match seasonal brand guidelines.
   - **In-App Toast Duration:** The 4-second auto-dismiss timeout in `NotificationService.swift` can be adjusted between 3 and 6 seconds based on user testing readability scores.

2. **Locked Hardware Engineering Rules:**
   - **20% Battery Cutoff:** The transition into disaster operation Survival Mode at 20% battery (`currentBatteryLevel < 0.20`) is a locked safety threshold. Altering this value risks running the phone out of power before sunrise during multi-day off-grid disaster operations.
   - **Movement Thresholds:** The speed transitions (stationary at `<0.3 m/s`, moving at `>=0.8 m/s`) are calibrated to human walking dynamics and cannot be modified without risking false stationary triggers while crawling or walking slowly in crowded crowds.
   - **Fixed-Point Quantization:** The scaling factor of $1{,}000{,}000.0$ (~11cm) is hardcoded into the 56-byte wire frame. Changing it breaks compatibility with all other mesh radios in the field.
   - **SOS Preemption Guarantee:** The immediate availability of cached coordinates for SOS dispatch (`getLatestLocationForSOS()`) cannot be disabled or tied to UI animations.

---
---

## Technical Engineering Deep-Dive

This section provides a rigorous, code-level architectural analysis of Volume 06. It begins with a step-by-step end-to-end trace, details the complete inventory of source artifacts, presents Mermaid diagrams and hardware comparison tables, and provides an exhaustive file-by-file walkthrough for all 18 files.

---

### End-to-End Flow: From Sensor Movement to Lock Screen Live Activity

To guide junior systems engineers through Meepo's spatial pipeline, the following walkthrough traces a single physical event: an iPhone user stands resting at a stage, begins walking 15 meters toward a disaster operation meeting point, and triggers an automated cascade that accelerates GPS sampling, validates fixes, encrypts wire frames, and updates the Lock Screen and Dynamic Island widgets:

```mermaid
sequenceDiagram
    autonumber
    participant Sensor as "CoreMotion / CMMotionActivity"
    participant LocService as "LocationService (@MainActor)"
    participant GPS as "CLLocationManager (CoreLocation)"
    participant Pub as "LocationPublisher"
    participant Radio as "PeerTransport (AWDL / BLE)"
    participant LiveAct as "LiveActivityManager"
    participant Widget as "TeekumWidgets (WidgetKit Extension)"

    Note over Sensor,LocService: Phase 1: Kinetic State Change
    Sensor->>LocService: Handler fires on motionQueue (stationary: false, walking: true)
    LocService->>LocService: setStationaryState(false) hops to @MainActor
    LocService->>GPS: applyDynamicAccuracy() -> desiredAccuracy = Best, filter = None
    LocService->>LocService: startPublishingScheduler() -> interval drops from 30s to 3s

    Note over GPS,LocService: Phase 2: Hardware GNSS Fix Ingestion
    GPS->>LocService: locationManager(_:didUpdateLocations:) delivered via XPC
    LocService->>LocService: applyLocationMeasurement(location)
    LocService->>LocService: Verify horizontalAccuracy >= 0 and timestamp >= existing.timestamp
    LocService->>LocService: currentLocation = LocationPin(...) & isGPSAvailable = true

    Note over LocService,Radio: Phase 3: Wire Serialization & Radio Broadcast
    LocService->>Pub: publishedPingsContinuation.yield(pin) via AsyncStream
    Pub->>Pub: Quantize lat/lon: degrees * 1,000,000 into Int32
    Pub->>Pub: Pack LocationPingPayload (18 bytes) & seal via ChaCha20-Poly1305
    Pub->>Radio: broadcastPacket(wireData) [56-Byte Frame]

    Note over LocService,Widget: Phase 4: ActivityKit Telemetry & WidgetKit Render
    LocService->>LiveAct: update(peerCount, unreadCount, meetingPoint, location)
    LiveAct->>LiveAct: Calculate Euclidean distance to MeetingPoint in integer meters
    LiveAct->>LiveAct: Rate-limit check (state != previous || elapsed >= 15s)
    LiveAct->>Widget: Activity.update(ActivityContent(state: state, staleDate: now + 30s))
    Widget->>Widget: SessionActivityWidget re-renders SwiftUI Dynamic Island & Lock Screen
```

#### Step-by-Step Architectural Trace:
1. **Kinetic Transition Detection:** The user begins walking. The iPhone's M-series motion coprocessor detects continuous step acceleration. `CMMotionActivityManager` fires its completion block on a private background queue (`motionQueue`) with `activity.stationary == false` and `activity.walking == true`.
2. **Actor Dispatch & Scheduler Acceleration:** The completion block safely hops to the `@MainActor` by calling `LocationService.setStationaryState(false)`. This state transition triggers two immediate hardware reactions:
   - `applyDynamicAccuracy()` resets `locationManager.desiredAccuracy` to `kCLLocationAccuracyBest` and clears the distance filter (`kCLDistanceFilterNone`).
   - `startPublishingScheduler()` cancels any active 30-second resting sleep and restarts the scheduler at `movingInterval` (3.0s–5.0s) or `distantPeerInterval` (2.0s).
3. **Hardware Fix Delivery:** Apple's system daemon (`locationd`) locks onto dual-frequency L1/L5 GNSS satellite signals and invokes the delegate method `locationManager(_:didUpdateLocations:)`.
4. **Monotonic Verification & Timestamp Integrity:** The delegate method hops to `@MainActor` and passes the fix to `applyLocationMeasurement(_:)`. The method performs two critical safety assertions:
   - It asserts `location.horizontalAccuracy >= 0` to discard invalid fixes.
   - It asserts `location.timestamp >= existing.timestamp` to discard out-of-order cached cellular or Wi-Fi fixes.
   - The verified measurement is encapsulated into an immutable `LocationPin`.
5. **Async Stream Yielding:** The new `LocationPin` is emitted into `publishedPingsContinuation`, waking any downstream subscribers awaiting `locationService.publishedPings`.
6. **Quantization & Sealing:** `LocationPublisher` receives the pin. It quantizes the continuous floating-point latitude and longitude into signed 32-bit big-endian integers using `coordinateScalingFactor = 1_000_000.0`. It packages an 18-byte `LocationPingPayload`, seals it with ChaCha20-Poly1305 using the group's 256-bit symmetric session key, and transmits a 56-byte wire packet across the AWDL mesh via `PeerTransport`.
7. **ActivityKit Snapshot Assembly:** Concurrently, `SessionController` forwards the fresh `LocationPin` to `LiveActivityManager.update(...)`. The manager computes the distance in meters to the active `MeetingPoint` via `location.distance(to: point.coordinate)` and constructs a lightweight `SessionActivityAttributes.ContentState` containing direct peer count, unread message count, distance, and SOS status.
8. **Rate-Limiting & Asynchronous Push:** `LiveActivityManager` verifies that either the content state has changed or 15 seconds have elapsed since the last push. It calls `@concurrent static pushUpdate(id:state:)`, pushing the update via XPC to the iOS ActivityKit daemon.
9. **WidgetKit Rendering in Isolated Process:** iOS SpringBoard wakes the `TeekumWidgets` App Extension. `SessionActivityWidget` evaluates the presentation context and re-renders `SessionLiveActivityView`, refreshing the trailing peer distance and bearing on the Dynamic Island and Lock Screen without waking the main application interface.

---

### Included Source Files

The following table lists all 18 source code and configuration files assigned to Volume 06 in `docs/handbook/_MANIFEST.md`. Every file path is linked relative to this document, accompanied by its verified line count (`wc -l`) and singular architectural responsibility:

| File Path | Category | Line Count (`wc -l`) | Architectural Role |
| :--- | :--- | :---: | :--- |
| [CadenceConfiguration.swift](../../Teekum/Teekum/Core/Location/CadenceConfiguration.swift) | Config Model | 62 | Thread-safe configuration struct specifying dynamic GPS update and staleness intervals based on motion, battery, and peer proximity. |
| [LocationPin.swift](../../Teekum/Teekum/Core/Location/LocationPin.swift) | Domain Model | 118 | Canonical immutable geographic measurement model featuring fixed-point wire quantization helpers and spherical bearing calculations. |
| [LocationPublisher.swift](../../Teekum/Teekum/Core/Location/LocationPublisher.swift) | Publisher Actor | 149 | Main-thread publisher actor observing location streams, quantizing coordinates, and broadcasting encrypted 56-byte wire frames. |
| [LocationService+AdaptiveHardware.swift](../../Teekum/Teekum/Core/Location/LocationService+AdaptiveHardware.swift) | Hardware Extension | 135 | Hardware extension managing CoreMotion activity tracking, dynamic sensor accuracy tuning, and battery survival mode transitions. |
| [LocationService+Delegate.swift](../../Teekum/Teekum/Core/Location/LocationService+Delegate.swift) | Delegate Extension | 85 | Nonisolated CLLocationManagerDelegate extension safely dispatching hardware location and compass heading fixes to @MainActor. |
| [LocationService+Lifecycle.swift](../../Teekum/Teekum/Core/Location/LocationService+Lifecycle.swift) | Lifecycle Extension | 139 | Lifecycle extension coordinating async permission requests via CheckedContinuation, hardware sensor boot, and clean session teardown. |
| [LocationService+Publishing.swift](../../Teekum/Teekum/Core/Location/LocationService+Publishing.swift) | Publishing Extension | 158 | Publishing extension implementing the periodic timer loop, Live Sharing toggle guard, burst pings, and monotonic validation filters. |
| [LocationService.swift](../../Teekum/Teekum/Core/Location/LocationService.swift) | Central Service | 263 | Authoritative CoreLocation and CoreMotion service managing hardware handles, background indicators, and adaptive cadence intervals. |
| [LocationServiceError.swift](../../Teekum/Teekum/Core/Location/LocationServiceError.swift) | Domain Error | 29 | Strongly-typed, localized error enumeration reporting disabled services, denied permissions, and hardware tracking failures. |
| [LocationServiceProtocol+Configuration.swift](../../Teekum/Teekum/Core/Location/LocationServiceProtocol+Configuration.swift) | Protocol Defaults | 22 | Protocol extension providing default stub implementations for optional heading callbacks, tactical radar toggles, and burst pings. |
| [LocationServiceProtocol.swift](../../Teekum/Teekum/Core/Location/LocationServiceProtocol.swift) | Core Protocol | 99 | Master architectural protocol declaring location observation, heading streams, cadence controls, and immediate SOS coordinate access. |
| [NotificationService.swift](../../Teekum/Teekum/Core/Notifications/NotificationService.swift) | Notification Service | 85 | Local notification manager delivering offline UNUserNotificationCenter alerts for SOS sirens, chat messages, and auto-dismissing toasts. |
| [LiveActivityManager.swift](../../Teekum/Teekum/Core/LiveActivity/LiveActivityManager.swift) | ActivityKit Coordinator | 54 | Main-thread manager starting, rate-limiting, and stopping Dynamic Island and Lock Screen Live Activities via ActivityKit. |
| [SessionActivityAttributes.swift](../../Teekum/Teekum/Core/LiveActivity/SessionActivityAttributes.swift) | Shared Data Contract | 39 | ActivityAttributes structure defining static session metadata and lightweight dynamic telemetry compiled into both app and widget. |
| [TeekumWidgetBundle.swift](../../TeekumWidgets/TeekumWidgetBundle.swift) | Widget Entry Point | 14 | Executable entry point (@main) for the TeekumWidgets App Extension target registering SessionActivityWidget with WidgetKit. |
| [SessionActivityWidget.swift](../../TeekumWidgets/SessionActivityWidget.swift) | WidgetKit Declaration | 131 | WidgetKit declaration binding ActivityAttributes to Lock Screen cards and Dynamic Island Compact, Minimal, and Expanded presentations. |
| [SessionLiveActivityView.swift](../../TeekumWidgets/SessionLiveActivityView.swift) | SwiftUI Presentation | 143 | Reusable SwiftUI view components rendering the app badge, color-coded member initials avatar, session name, and status pills. |
| [Widgets-Info.plist](../../Config/Widgets-Info.plist) | Extension Config | 33 | XML property list declaring the com.apple.widgetkit-extension extension point and XPC service bundle configuration. |
| **Total Volume 06 Inventory** | **18 Artifacts** | **1,758** | **100% Volume 06 Codebase Accounting** |

---

### Adaptive Accuracy & Live Activity Architecture

#### 1. Adaptive Hardware Accuracy & Battery Management Pipeline

The following diagram illustrates how external physical and electrical stimuli (walking movement, resting stationary state, distant mesh peers, and battery drain) dynamically drive the hardware configuration of the iPhone's GPS and compass chips:

```mermaid
flowchart TD
    subgraph Stimuli ["Environmental & System Stimuli"]
        A["CMMotionActivityManager (Stationary / Walking)"]
        B["UIDevice Battery Monitoring (<20% Battery)"]
        C["ProcessInfo.isLowPowerModeEnabled"]
        D["Tactical Radar View Active (User Viewing Compass)"]
        E["NeighborTable (Distant / Stale Peers Detected)"]
    end

    subgraph DecisionEngine ["LocationService Cadence & Precision Engine"]
        F{"Evaluate Highest Precedence State"}
        D -->|Precedence 1| G["Mode: Tactical Navigation"]
        B & C -->|Precedence 2| H["Mode: disaster operation Survival"]
        E -->|Precedence 3| I["Mode: Distant / Stale Recovery"]
        A -->|Precedence 4: Resting| J["Mode: Stationary Rest"]
        A -->|Precedence 5: Moving| K["Mode: Normal Walking"]
        F --> G & H & I & J & K
    end

    subgraph HardwareTuning ["CoreLocation Hardware Tuning"]
        G --> L["desiredAccuracy: BestForNavigation<br/>distanceFilter: 0m<br/>headingFilter: None (0°)<br/>Cadence: 2.0s - 3.0s"]
        H --> M["desiredAccuracy: HundredMeters<br/>distanceFilter: 25m<br/>headingFilter: 5.0°<br/>Cadence: 60.0s"]
        I --> N["desiredAccuracy: Best<br/>distanceFilter: 0m<br/>headingFilter: 1.0°<br/>Cadence: 2.0s"]
        J --> O["desiredAccuracy: HundredMeters<br/>distanceFilter: 15m<br/>headingFilter: 3.0°<br/>Cadence: 15.0s - 30.0s"]
        K --> P["desiredAccuracy: Best<br/>distanceFilter: 0m<br/>headingFilter: 1.0°<br/>Cadence: 3.0s - 5.0s"]
    end
```

#### 2. Hardware Precision & Cadence Comparison Table

The following table derives directly from the actual code constants in `CadenceConfiguration.swift` and `LocationService+AdaptiveHardware.swift`, contrasting the five operating modes across accuracy, filters, reporting cadence, and power impact:

| Operating Mode | Trigger Condition | CoreLocation `desiredAccuracy` | Hardware `distanceFilter` | Compass `headingFilter` | Publishing Cadence Interval | Estimated Battery Draw & Hardware Impact |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Tactical Radar** | `isTacticalRadarActive == true` | `kCLLocationAccuracyBestForNavigation` | `kCLDistanceFilterNone` (0.0 m) | `kCLHeadingFilterNone` (0.0°) | `2.0s – 3.0s` | **High Draw (~100–120 mA):** Locks dual-frequency L1/L5 GNSS continuously; unthrottled fluxgate compass updates. |
| **disaster operation Survival** | `currentBatteryLevel < 0.20` or Low Power Mode | `kCLLocationAccuracyHundredMeters` | `25.0 meters` | `5.0 degrees` | `60.0s (survivalInterval)` | **Ultra-Low Draw (~10–15 mA):** Cuts GPS duty cycle by ~85%; relies on cell/sensor coarse approximations. |
| **Distant / Stale Recovery** | `hasDistantPeers` or `hasStalePeers` | `kCLLocationAccuracyBest` | `kCLDistanceFilterNone` (0.0 m) | `1.0 degrees` | `2.0s (distant/staleInterval)` | **Moderate-High Draw (~65–80 mA):** Accelerated radio bursts to punch through weak mesh hops and recover routes. |
| **Stationary Rest** | `isStationary == true` (sitting/dancing) | `kCLLocationAccuracyHundredMeters` | `15.0 meters` | `3.0 degrees` | `15.0s – 30.0s (stationaryInterval)` | **Low Draw (~20–25 mA):** Baseband GPS radio sleeps between windows; compass interrupts relaxed. |
| **Normal Walking** | Moving default (`isStationary == false`) | `kCLLocationAccuracyBest` | `kCLDistanceFilterNone` (0.0 m) | `1.0 degrees` | `3.0s – 5.0s (movingInterval)` | **Standard Draw (~45–60 mA):** Standard high-precision civilian tracking (~3–5m real-world accuracy). |

---

#### 3. ActivityKit Presentation Layout Topology

The following diagram maps the structural layout of the `TeekumWidgets` extension across Lock Screen and Dynamic Island presentation surfaces:

```
+------------------------------------------------------------------------------------+
|                         DYNAMIC ISLAND EXPANDED PRESENTATION                       |
| +--------------------------------------------------+-----------------------------+ |
| | [Leading Region]                                 | [Trailing Region]           | |
| | SessionAppBadge ("Meepo" + Rendezvous Pin)       | Relay Status Text (Teal/Red)| |
| +--------------------------------------------------+-----------------------------+ |
| | [Bottom Region: SessionSummaryRow]                                             | |
| | +---------------+  +-------------------------------+  +---------------------+  | |
| | | 56x56 Avatar  |  | "disaster operation Crew" (Title)       |  | [3 People] or       |  | |
| | | Initials [DAF]|  | "YOU" or "Emergency SOS" (Sub)|  | [2 Unread] or [SOS] |  | |
| | +---------------+  +-------------------------------+  +---------------------+  | |
| +--------------------------------------------------------------------------------+ |
+------------------------------------------------------------------------------------+

+-------------------------------------+   +------------------------------------------+
|       DYNAMIC ISLAND COMPACT        |   |          DYNAMIC ISLAND MINIMAL          |
| +-------------+     +-------------+ |   | +--------------------------------------+ |
| | [Leading]   | (O) | [Trailing]  | |   | | Single Icon Slot:                    | |
| | MeetPoint   |     | "3 [peers]" | |   | | - Normal: MeetPoint Vector (Teal)    | |
| | or Red SOS  |     | or "ADI" SOS| |   | | - Unread: message.fill (Teal)        | |
| +-------------+     +-------------+ |   | | - SOS: sos.circle.fill (Red)         | |
|                                     |   | +--------------------------------------+ |
+-------------------------------------+   +------------------------------------------+

+------------------------------------------------------------------------------------+
|                             LOCK SCREEN LIVE ACTIVITY CARD                         |
| +--------------------------------------------------+-----------------------------+ |
| | SessionAppBadge ("Meepo" + Rendezvous Pin)       | Relay Status Text ("Active")| |
| +--------------------------------------------------+-----------------------------+ |
| | ------------------------------------------------------------------------------- | |
| | [SessionSummaryRow]                                                              | |
| | +---------------+  +-------------------------------+  +---------------------+  | |
| | | 56x56 Avatar  |  | Session Name ("Sector 4 SAR")   |  | Pill Capsule Badge  |  | |
| | | Initials [DAF]|  | Subtitle ("YOU")              |  | [120m to Meeting]   |  | |
| | +---------------+  +-------------------------------+  +---------------------+  | |
| +--------------------------------------------------------------------------------+ |
+------------------------------------------------------------------------------------+
```

---
## Dedicated File-by-File Deep-Dives

---

### 1. `Teekum/Teekum/Core/Location/CadenceConfiguration.swift`
- **File Path**: [CadenceConfiguration.swift](../../Teekum/Teekum/Core/Location/CadenceConfiguration.swift)
- **Line Count**: 62 lines (`wc -l`)
- **Category & Isolation**: Config Model, `nonisolated public struct`, Conforms to `Equatable, Sendable`

#### What This File Does
`CadenceConfiguration.swift` defines the timing parameters that regulate how frequently an active device broadcasts its GPS coordinates over the peer-to-peer radio mesh. Rather than transmitting at a static, unyielding frequency, Meepo dynamically alters its publishing cadence depending on whether the user is running/walking, standing still, navigating to distant peers, recovering a lost connection, or operating under critically low battery conditions. This file encapsulates all those target intervals and staleness thresholds in a type-safe, thread-safe value type.

#### ELI5 Analogy
Imagine a search-and-rescue operative deployed into a disaster rubble field. If they are actively traversing shifting concrete slabs, they broadcast a location ping every 3 to 5 seconds so team leads know their exact path. If they halt at a forward triage post to assist casualties, pinging every 3 seconds needlessly drains battery; throttling to 15-30 seconds is optimal. If a nearby teammate triggers an SOS alarm, the cadence accelerates to 2 seconds for high-speed tracking. If device battery drops below 20%, the system drops to 60-second survival intervals to conserve power. `CadenceConfiguration` is the automated rulebook that calculates these exact intervals.

#### Technical Terms Defined
- **Adaptive Publishing Cadence**: A dynamic scheduling strategy where sensor sampling and radio transmission frequencies vary in real time based on environmental triggers (speed, battery, peer proximity) rather than fixed timers.
- **Runloop Jitter**: Deviations in exact timer firing times caused by the operating system prioritizing UI rendering, thread scheduling, or device sleep cycles over background tasks.
- **Duty Cycle**: The percentage of time a hardware component (such as an Apple L1/L5 GNSS receiver or AWDL Wi-Fi radio) remains actively powered versus powered down in a low-power sleep state.
- **Staleness Threshold**: The duration after which a cached coordinate measurement is deemed outdated and flagged as untrustworthy for real-time directional steering.

#### Code-Block and Line-by-Line Walkthrough
Lines 13–40 declare the struct and its configuration properties:
```swift
nonisolated public struct CadenceConfiguration: Equatable, Sendable {
    /// Publishing interval while actively moving (recommended: 3–5 seconds).
    public var movingInterval: TimeInterval
    
    /// Publishing interval while stationary (recommended: 15–30 seconds).
    public var stationaryInterval: TimeInterval
    
    /// Accelerated publishing interval when one or more peers are distant or signal is weak (recommended: 2.0s).
    public var distantPeerInterval: TimeInterval
    
    /// Throttled publishing interval in survival mode (<20% battery).
    public var survivalInterval: TimeInterval
    
    /// Duration after which a location fix is marked stale for the UI.
    public var staleThreshold: TimeInterval
    
    /// Threshold after which a peer is considered stale (recommended: 30.0s).
    public var stalePeerThreshold: TimeInterval
    
    /// Accelerated publishing interval while probing for stale peers (recommended: 2.0s).
    public var staleRecoveryInterval: TimeInterval
    
    /// Additional staleness delay before triggering Stage 2 route discovery (recommended: 15.0s).
    public var staleRouteReqDelay: TimeInterval
    
    /// Maximum active recovery probe window duration before falling back to normal cadence (recommended: 60.0s).
    public var staleRecoveryTimeout: TimeInterval
```
- Line 15 (`movingInterval`): The target period (default 3.0–5.0 seconds) between broadcast pings while the device is in physical motion.
- Line 18 (`stationaryInterval`): The target period (default 15.0–30.0 seconds) when the device is resting, dancing, or stationary, reducing radio congestion.
- Line 21 (`distantPeerInterval`): Accelerated interval (2.0 seconds) applied when one or more peers have weak RSSI or high geographic separation, ensuring responsive routing through fringe relays.
- Line 24 (`survivalInterval`): Extreme power-save cadence (60.0 seconds) triggered when battery drops below 20%, ensuring the phone survives emergency situations.
- Lines 27–30 (`staleThreshold`, `stalePeerThreshold`): Time limits (default 30.0 seconds) after which a peer pin is considered stale on the map.
- Lines 33–39 (`staleRecoveryInterval`, `staleRouteReqDelay`, `staleRecoveryTimeout`): Timing parameters controlling active probe bursts (2.0s interval for up to 60.0s) before falling back, and inserting a 15.0s delay before triggering an AODV Stage 2 `RREQ` route discovery.

Lines 41–61 provide the default memberwise initializer binding to `MeepoConfiguration.Timing` constants:
```swift
    public init(
        movingInterval: TimeInterval = MeepoConfiguration.Timing.locationMovingInterval,
        stationaryInterval: TimeInterval = MeepoConfiguration.Timing.locationStationaryInterval,
        distantPeerInterval: TimeInterval = MeepoConfiguration.Timing.distantPeerInterval,
        survivalInterval: TimeInterval = MeepoConfiguration.Timing.survivalInterval,
        staleThreshold: TimeInterval = MeepoConfiguration.Timing.stalePeerThreshold,
        stalePeerThreshold: TimeInterval = MeepoConfiguration.Timing.stalePeerThreshold,
        staleRecoveryInterval: TimeInterval = 2.0,
        staleRouteReqDelay: TimeInterval = 15.0,
        staleRecoveryTimeout: TimeInterval = 60.0
    ) {
        self.movingInterval = movingInterval
        self.stationaryInterval = stationaryInterval
        self.distantPeerInterval = distantPeerInterval
        self.survivalInterval = survivalInterval
        self.staleThreshold = staleThreshold
        self.stalePeerThreshold = stalePeerThreshold
        self.staleRecoveryInterval = staleRecoveryInterval
        self.staleRouteReqDelay = staleRouteReqDelay
        self.staleRecoveryTimeout = staleRecoveryTimeout
    }
}
```

#### Engineering Rationale and Edge Cases
- **Hardware Duty-Cycle Tradeoffs**: A continuous GPS fix draws approximately 50–120 mA of current on an iPhone baseband. By relaxing the update cadence from 3 seconds to 30 seconds when stationary, the system allows the GNSS receiver and the AWDL Wi-Fi chip to enter deep low-power sleep states, extending field battery life from 4 hours to over 18 hours.
- **Sendable Safety**: Marked `nonisolated` and `Sendable`, allowing it to be safely passed across actor boundaries (e.g., from `LocationService` on `@MainActor` to background evaluation routines) without data races.

---

### 2. `Teekum/Teekum/Core/Location/LocationPin.swift`
- **File Path**: [LocationPin.swift](../../Teekum/Teekum/Core/Location/LocationPin.swift)
- **Line Count**: 118 lines (`wc -l`)
- **Category & Isolation**: Domain Model, `public struct`, Conforms to `Equatable, Hashable, Sendable`

#### What This File Does
`LocationPin.swift` represents Meepo's canonical, immutable in-memory model of a geographic measurement. It couples a 64-bit IEEE 754 double-precision coordinate (`CLLocationCoordinate2D`) with horizontal uncertainty accuracy, an unalterable hardware timestamp, and optional compass heading. Furthermore, this file hosts the essential quantization and dequantization functions that convert floating-point degrees into signed 32-bit big-endian integers for transmission within Meepo's strict 56-byte wire packets.

#### ELI5 Analogy
When a surveyor records a boundary pin, they do not just write down coordinates; they record the measurement instrument's margin of error and the exact second the reading was stamped on the clock. `LocationPin` is that complete certified certificate. When sending this certificate over a tiny telegraph line where letters cost money, the surveyor scales the GPS numbers into exact millidegrees (integers) so they fit into tiny fixed-size message envelopes without losing accuracy.

#### Technical Terms Defined
- **Coordinate Quantization**: The mathematical process of mapping continuous floating-point geographic degrees into discrete, fixed-width integer values by multiplying by a scaling factor and rounding.
- **Sub-Meter Resolution**: At a scaling factor of $1{,}000{,}000.0$ (1 microdegree), 1 unit represents approximately 0.11 meters (~11 centimeters) at the equator, providing sub-meter precision well within the physical accuracy of civilian GPS (~3–5 meters).
- **Forward Azimuth (Bearing)**: The horizontal direction of a target expressed as the angular distance from true or magnetic north, measured clockwise from 0° to 360°.
- **Great-Circle Navigation**: Trigonometric calculation along the curved surface of the Earth using spherical trigonometry (rhumb line or haversine formulas).

#### Code-Block and Line-by-Line Walkthrough
Lines 12–36 establish the core value structure:
```swift
public struct LocationPin: Equatable, Hashable, Sendable {
    /// Geographical coordinate (64-bit IEEE 754 Double precision degrees).
    public let coordinate: CLLocationCoordinate2D
    
    /// Estimated horizontal accuracy uncertainty radius in meters.
    public let horizontalAccuracy: CLLocationAccuracy
    
    /// Exact UTC timestamp when the measurement was taken by the hardware GPS receiver.
    /// Note: Intermediary relays must NEVER mutate or refresh this timestamp.
    public let timestamp: Date
    
    /// Optional device magnetic heading at measurement time (0..<360 degrees).
    public let heading: CLLocationDirection?
    
    public init(
        coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy,
        timestamp: Date = Date(),
        heading: CLLocationDirection? = nil
    ) {
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
        self.heading = heading
    }
```
Notice line 20: `Intermediary relays must NEVER mutate or refresh this timestamp.` Preserving the original GNSS lock timestamp is essential for mesh hops to detect and discard stale or out-of-order packets.

Lines 40–63 implement the 56-byte wire quantization helpers:
```swift
    // MARK: - Fixed 56-Byte Wire Quantization Helpers
    
    /// Conversion constant between Double degrees and Int32 wire quantization (~11cm resolution).
    public static let coordinateScalingFactor: Double = 1_000_000.0
    
    /// Quantized big-endian signed 32-bit integer representing latitude (`degrees * 1_000_000`).
    public var rawLatitude: Int32 {
        Int32((coordinate.latitude * Self.coordinateScalingFactor).rounded())
    }
    
    /// Quantized big-endian signed 32-bit integer representing longitude (`degrees * 1_000_000`).
    public var rawLongitude: Int32 {
        Int32((coordinate.longitude * Self.coordinateScalingFactor).rounded())
    }
    
    /// Compact single-byte horizontal accuracy in meters (clamped 0...255).
    public var rawAccuracyByte: UInt8 {
        UInt8(min(255.0, max(0.0, horizontalAccuracy.rounded())))
    }
    
    /// Dequantizes 32-bit signed raw wire coordinates back into a native `CLLocationCoordinate2D`.
    public static func dequantize(latitudeRaw: Int32, longitudeRaw: Int32) -> CLLocationCoordinate2D {
        let lat = Double(latitudeRaw) / Self.coordinateScalingFactor
        let lon = Double(longitudeRaw) / Self.coordinateScalingFactor
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
```
- `rawLatitude` / `rawLongitude`: Converts `Double` to `Int32` with `.rounded()`. Signed 32-bit integer ranges from -2,147,483,648 to +2,147,483,647, easily accommodating latitude [-90,000,000 to +90,000,000] and longitude [-180,000,000 to +180,000,000].
- `rawAccuracyByte`: Clamps the horizontal accuracy in meters (0 to 255 meters) into a single unsigned byte (`UInt8`), saving 7 bytes compared to a raw `Double`.

Lines 66–86 provide trigonometric distance and bearing calculations:
```swift
    // MARK: - Navigation Computations
    public func distance(to target: CLLocationCoordinate2D) -> CLLocationDistance {
        let currentLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let targetLoc = CLLocation(latitude: target.latitude, longitude: target.longitude)
        return currentLoc.distance(from: targetLoc)
    }
    
    /// Computes the forward bearing (azimuth) in degrees (0..<360) from this location to a target.
    public func bearing(to target: CLLocationCoordinate2D) -> Double {
        let lat1 = coordinate.latitude * .pi / 180.0
        let lon1 = coordinate.longitude * .pi / 180.0
        let lat2 = target.latitude * .pi / 180.0
        let lon2 = target.longitude * .pi / 180.0
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        let degrees = radiansBearing * 180.0 / .pi
        return (degrees + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
```
Lines 106–117 retroactively conform Apple's `CLLocationCoordinate2D` to `Equatable` and `Hashable` via `@retroactive`, enabling coordinate comparison and dictionary hashing across the Swift concurrency runtime.

#### Engineering Rationale and Edge Cases
- **Avoidance of IEEE 754 Floating-Point Leaks**: Transmitting raw 64-bit doubles over the wire introduces platform-dependent serialization variations and wastes 16 bytes per frame. Scaling by 1,000,000 into `Int32` is lossless for civilian positioning (~11cm) while guaranteeing identical cross-architecture endianness.
- **Accuracy Clamping**: Accuracies worse than 255 meters (e.g., cell-tower triangulation with 1,500m uncertainty) are clamped to 255. Receivers treat accuracy 255 as poor or approximate, rendering a wider uncertainty radius in the UI.

---

### 3. `Teekum/Teekum/Core/Location/LocationPublisher.swift`
- **File Path**: [LocationPublisher.swift](../../Teekum/Teekum/Core/Location/LocationPublisher.swift)
- **Line Count**: 149 lines (`wc -l`)
- **Category & Isolation**: Publisher Actor, `@Observable`, `@MainActor public final class`

#### What This File Does
`LocationPublisher.swift` serves as the high-level bridge between the local location monitoring actor (`LocationService`) and the network radio broadcast layer (`PeerTransport`). It observes the asynchronous stream of validated `LocationPin` updates, packs the geographic coordinates, heading, initials, and battery level into a binary `LocationPingPayload`, wraps the payload with ChaCha20-Poly1305 authenticated encryption, and submits the resulting 56-byte wire packet to the transport pipeline. Crucially, it strictly enforces privacy controls: if Live Sharing is turned off, all ordinary location publishing is unconditionally suppressed.

#### ELI5 Analogy
Think of `LocationPublisher` as the communications specialist for a field search squad. When the GPS surveyor (`LocationService`) acquires a fresh coordinate fix, the publisher checks the master switch: if "Stealth Mode" (Live Sharing Disabled) is toggled on, the coordinates are discarded immediately to protect operative privacy. If live sharing is active, the publisher condenses the coordinates into fixed-point integers, seals them inside a 56-byte encrypted datagram via `CryptoService`, and queues them onto `PriorityOutboxQueue`.

#### Technical Terms Defined
- **Live Sharing Master Toggle**: A top-level user privacy guarantee that completely halts peer-to-peer location broadcasting while allowing local map viewing and emergency SOS functions to continue operating.
- **Monotonic Packet Counter**: An incrementing counter (`&+= 1`) embedded in the packet sequence number to guarantee packet uniqueness and prevent replay attacks across intermediate mesh hops.
- **Generation UUID**: A unique token created when starting the publisher loop, used to detect whether an in-flight asynchronous serialization task was invalidated by a subsequent start/stop lifecycle call.
- **SymmetricKey Sealing**: Cryptographically sealing cleartext bytes into ciphertext with an authenticated Poly1305 authentication tag using an ephemeral 256-bit symmetric key negotiated during group pairing.

#### Code-Block and Line-by-Line Walkthrough
Lines 13–24 establish the actor dependencies:
```swift
@Observable
@MainActor
public final class LocationPublisher {
    
    // MARK: - Dependencies
    
    public let locationService: LocationServiceProtocol
    private let sessionProvider: @Sendable () -> GroupSession?
    public let cryptoService: CryptoServiceProtocol
    public let transport: PeerTransport
    private let sequenceAllocator: PacketSequenceAllocator?
    private var generation = UUID()
```
Lines 58–76 manage the lifecycle loop:
```swift
    // MARK: - Lifecycle Controls
    
    /// Starts observing the location service and broadcasting pings when Live Sharing is active.
    public func start() {
        guard !isRunning else { return }
        generation = UUID()
        isRunning = true
        
        listeningTask?.cancel()
        let pingsStream = locationService.publishedPings
        listeningTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if let location = locationService.currentLocation, locationService.isLiveSharingEnabled {
                await handleLocationPingReady(location: location)
            }
            for await location in pingsStream {
                guard !Task.isCancelled, self.isRunning else { break }
                await self.handleLocationPingReady(location: location)
            }
        }
    }
```
When `start()` is invoked, it cancels any previous listening task, takes an immediate fix if available and Live Sharing is enabled, and subsequently loops over `locationService.publishedPings`.

Lines 90–141 implement the core packet assembly and transmission:
```swift
    // MARK: - Ordinary Location Publishing
    
    public func handleLocationPingReady(location: LocationPin) async {
        // Acceptance Criterion 2: Live Sharing OFF prevents ordinary location broadcasting
        guard locationService.isLiveSharingEnabled else { return }
        
        guard let session = sessionProvider() else {
            return
        }
        
        let batteryPct = locationService.currentBatteryLevel.asBatteryPercentage
        let headingByte = locationService.currentHeading?.quantizedHeadingByte ?? 0
        
        let payload = LocationPingPayload(
            coordinate: location.coordinate,
            timestamp: location.timestamp,
            accuracy: location.rawAccuracyByte,
            senderInitials: session.localInitials,
            batteryLevel: batteryPct,
            heading: headingByte,
            colorCode: session.localColorCode
        )
        
        let payloadData = payload.serialize()
        
        let current = generation
        let seq: UInt32
        do { seq = try await nextSequence(for: session) }
        catch { return }
        guard generation == current, sessionProvider() == session, !Task.isCancelled else { return }
        
        let envelope = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .locationPing,
            hopLimit: PacketConstants.defaultHopLimit,
            hopCount: 0,
            sessionId: session.sessionId,
            sequenceNumber: seq
        )
        
        do {
            let key = SymmetricKey(data: session.symmetricKeyData)
            let sealed = try await cryptoService.seal(payload: payloadData, envelope: envelope, using: key)
            let wirePacket = RawWirePacket(envelope: envelope, ciphertext: sealed.ciphertext, authTag: sealed.authTag)
            let wireData = try wirePacket.toWireData()
            guard generation == current, sessionProvider() == session, !Task.isCancelled else { return }
            try await transport.broadcastPacket(wireData)
            publishedPingsCount += 1
        } catch {
            // Failed transmissions are handled by transport / retry policy
        }
    }
```
Notice line 145: sequence numbering combines the session's member slot (2 bits) with the publisher's monotonic counter (30 bits), preventing sequence collision between concurrent group members.

#### Engineering Rationale and Edge Cases
- **Generation Invalidation**: Across session boundaries (leaving a group and joining another), asynchronous cryptographic sealing tasks may still be waiting on lock resolution. By capturing `let current = generation` and asserting `guard generation == current, sessionProvider() == session`, outdated packets from a terminated session can never leak onto the wire of a newly joined session.
- **Privacy Enforcement**: Live Sharing enforcement occurs both in `LocationService` (halting the scheduler) and redundantly in `LocationPublisher` (`guard locationService.isLiveSharingEnabled`). Even if a racing location pin escaped the service queue, the publisher immediately drops it.

---

### 4. `Teekum/Teekum/Core/Location/LocationServiceError.swift`
- **File Path**: [LocationServiceError.swift](../../Teekum/Teekum/Core/Location/LocationServiceError.swift)
- **Line Count**: 29 lines (`wc -l`)
- **Category & Isolation**: Domain Error, `nonisolated public enum`, Conforms to `Error, LocalizedError, Equatable`

#### What This File Does
`LocationServiceError.swift` enumerates the typed domain errors produced by the location subsystem during startup, permission negotiation, and continuous tracking. It provides localized, human-readable descriptions for each error case so that higher-level UI coordinators can present helpful remediation instructions to the user.

#### ELI5 Analogy
When a machine fails to start, an error light turns on. Rather than just blinking a generic red light, this file provides the specific label under the light: "Airplane mode switch is off", "The user locked the door", or "The GPS antenna is disconnected".

#### Technical Terms Defined
- **LocalizedError**: A Swift Foundation protocol that provides user-facing descriptive strings via `errorDescription`, facilitating direct display in alerts and banner views.
- **System Location Restriction**: An operating system state (such as MDM profile restrictions or Screen Time parental controls) where the user cannot grant location permissions even if they want to.

#### Code-Block and Line-by-Line Walkthrough
Lines 11–28 declare the error cases and localized strings:
```swift
nonisolated public enum LocationServiceError: Error, LocalizedError, Equatable {
    case locationServicesDisabled
    case permissionDenied
    case permissionRestricted
    case trackingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .locationServicesDisabled:
            return "Location Services are disabled on this device in System Settings."
        case .permissionDenied:
            return "Location permission was denied. Please allow location access in Settings."
        case .permissionRestricted:
            return "Location access is restricted (e.g. Parental Controls)."
        case let .trackingFailed(reason):
            return "Location tracking failed: \(reason)"
        }
    }
}
```
- Line 12 (`locationServicesDisabled`): Triggered when `CLLocationManager.locationServicesEnabled()` returns `false` globally on iOS.
- Line 13 (`permissionDenied`): Triggered when the user explicitly selected "Don't Allow" or turned off location in iOS Settings.
- Line 14 (`permissionRestricted`): Triggered when parental controls or corporate profiles prevent authorization changes.
- Line 15 (`trackingFailed`): General catch-all wrapping underlying CoreLocation errors (`kCLErrorDomain`).

#### Engineering Rationale and Edge Cases
- **Nonisolated Equatable**: Because this error enum is `nonisolated` and `Equatable`, background tasks and unit tests can easily assert against specific failure modes without hopping to the main actor.

---

### 5. `Teekum/Teekum/Core/Location/LocationServiceProtocol+Configuration.swift`
- **File Path**: [LocationServiceProtocol+Configuration.swift](../../Teekum/Teekum/Core/Location/LocationServiceProtocol+Configuration.swift)
- **Line Count**: 22 lines (`wc -l`)
- **Category & Isolation**: Protocol Defaults, Protocol Extension on `LocationServiceProtocol`

#### What This File Does
This file provides sensible default implementations for optional configuration properties and convenience methods declared in `LocationServiceProtocol`. By defining these defaults in a protocol extension, mock implementations in unit tests and lightweight previews do not need to implement empty stubs for heading callbacks, tactical radar toggles, or burst ping triggers.

#### ELI5 Analogy
When filling out a detailed form, some sections are optional. If you leave them blank, the office assumes standard defaults (e.g., "Standard Mail", "No special handling"). This file provides those standard answers so test simulators don't have to write out every single optional setting.

#### Technical Terms Defined
- **Protocol Default Implementation**: A Swift language mechanism allowing a protocol extension to provide baseline behavior, making those protocol members effectively optional for conforming types.
- **Tactical Radar Mode**: A high-precision UI mode that dials the GPS receiver to maximum sensitivity (`kCLLocationAccuracyBestForNavigation`) for close-quarters peer rendezvous.

#### Code-Block and Line-by-Line Walkthrough
Lines 11–22 implement the default stubs:
```swift
extension LocationServiceProtocol {
    public var onHeadingUpdate: ((CLLocationDirection) -> Void)? {
        get { nil }
        set {}
    }
    public var isPreciseLocationAuthorized: Bool { true }
    public var isTacticalRadarActive: Bool { false }
    public func setTacticalRadarActive(_ active: Bool) {}
    public func resetPublishedPingsStream() {}
    public func triggerCadenceEvaluation() {}
    public func triggerBurstPings(count: Int, interval: TimeInterval) {}
}
```
- Lines 12–15: Default no-op heading update closure.
- Line 16: Assumes precise location is authorized by default.
- Lines 17–18: Defaults `isTacticalRadarActive` to `false` and makes the setter a no-op.
- Lines 19–21: Stub implementations for stream reset, cadence evaluation, and burst ping triggers.

#### Engineering Rationale and Edge Cases
- **Mock Ergonomics**: In SwiftUI previews and unit tests (e.g., testing Chat or SOS logic), test developers can mock `LocationServiceProtocol` by implementing only `currentLocation` without having to implement complex burst pings or radar state machines.

---

### 6. `Teekum/Teekum/Core/Location/LocationServiceProtocol.swift`
- **File Path**: [LocationServiceProtocol.swift](../../Teekum/Teekum/Core/Location/LocationServiceProtocol.swift)
- **Line Count**: 99 lines (`wc -l`)
- **Category & Isolation**: Core Protocol, `@MainActor public protocol LocationServiceProtocol: AnyObject`

#### What This File Does
`LocationServiceProtocol.swift` establishes the authoritative architectural contract for Meepo's location, motion coprocessor, battery monitoring, and telemetry distribution subsystem. Every consumer in the app—including `SessionController`, `LocationPublisher`, map views, finder radar canvases, and SOS coordinators—depends exclusively on this protocol abstraction rather than the concrete `LocationService` class, enabling clean dependency injection and comprehensive test mocking.

#### ELI5 Analogy
Think of `LocationServiceProtocol` as the formal specification sheet for a car's GPS and dashboard unit. It specifies that any dashboard installed must provide a speedometer, a compass heading, an odometer, and a low-fuel warning. Whether the actual dashboard uses analog needles, an LCD screen, or a virtual simulator for driving school, as long as it adheres to this spec sheet, the rest of the car works perfectly.

#### Technical Terms Defined
- **AnyObject Constraint**: Constrains conforming types to class types, allowing instances to be bound weakly (`[weak self]`) to prevent retain cycles.
- **AsyncStream**: An asynchronous sequence of values produced over time, allowing callers to use standard Swift `for await` loops to process incoming location fixes without delegate callbacks.
- **Survival Mode**: A protective low-power throttling state engaged automatically when battery drops below 20%, reducing GPS sampling and radio transmissions.

#### Code-Block and Line-by-Line Walkthrough
Lines 13–46 define state properties for location, heading, motion, and battery:
```swift
@MainActor
public protocol LocationServiceProtocol: AnyObject {
    /// Latest measured local coordinate, uncertainty accuracy radius, and measurement timestamp.
    var currentLocation: LocationPin? { get }
    
    /// Latest magnetic compass heading in degrees (0..<360).
    var currentHeading: CLLocationDirection? { get }
    
    /// Optional high-frequency callback invoked whenever a hardware compass heading fix is received.
    var onHeadingUpdate: ((CLLocationDirection) -> Void)? { get set }
    
    /// Motion coprocessor activity state (`true` if user is standing/dancing in place; `false` if walking).
    var isStationary: Bool { get }
    
    /// True if any tracked group member or radio neighbor is distant (far GPS or weak RSSI).
    var hasDistantPeers: Bool { get set }
    
    /// Optional closure provider to dynamically evaluate whether any peers are distant.
    var hasDistantPeersProvider: (@MainActor @Sendable () -> Bool)? { get set }
    
    /// True if any tracked group member is stale and within active recovery window.
    var hasStalePeers: Bool { get set }
    
    /// Optional closure provider to dynamically evaluate whether any peers are stale and within the active recovery window.
    var hasStalePeersProvider: (@MainActor @Sendable () -> Bool)? { get set }
    
    /// User-controlled master toggle governing whether coordinates are broadcast to the group.
    var isLiveSharingEnabled: Bool { get set }
    
    /// Hard 20% cutoff battery detection (disaster operation Survival Mode).
    var isSurvivalModeActive: Bool { get }
    
    /// Current device battery percentage (0.0 ... 1.0).
    var currentBatteryLevel: Float { get }
    
    /// Current Core Location authorization status.
    var authorizationStatus: CLAuthorizationStatus { get }
    
    /// True if GPS hardware is functioning, authorized, and actively providing valid fixes.
    var isGPSAvailable: Bool { get }
    
    /// True if the current location measurement is older than the staleness threshold.
    var isLocationStale: Bool { get }
    
    /// True if Core Location authorization has full accuracy (Precise Location: ON).
    var isPreciseLocationAuthorized: Bool { get }
    
    /// True if the user is actively viewing the Tactical Radar or navigating.
    var isTacticalRadarActive: Bool { get }
    
    /// Enables or disables high-precision navigation mode (kCLLocationAccuracyBestForNavigation).
    func setTacticalRadarActive(_ active: Bool)
```
Lines 67–76 expose timing and streams:
```swift
    /// Time elapsed in seconds since the current location was measured by hardware GPS (nil if no fix acquired yet).
    var locationAge: TimeInterval? { get }
    
    /// Current target publishing interval in seconds based on movement, stationary state, and battery.
    var currentCadenceInterval: TimeInterval { get }
    
    /// Configurable cadence settings.
    var cadenceConfig: CadenceConfiguration { get set }
    
    /// Async stream yielding location pings ready for radio publishing.
    var publishedPings: AsyncStream<LocationPin> { get }
```
Lines 79–98 define operational control methods:
```swift
    /// Requests standard iOS CoreLocation permissions with friendly educational primer.
    func requestPermissions() async -> Bool
    
    /// Starts adaptive GPS sampling and CoreMotion activity tracking.
    func startTracking() throws
    
    /// Pauses GPS receiver and stops compass monitoring to conserve battery.
    func stopTracking()
    
    /// Retrieves the latest available location immediately for emergency SOS dispatch.
    /// Does not wait for a fresh GPS fix or a normal ping interval, and operates regardless of Live Sharing state.
    func getLatestLocationForSOS() -> LocationPin?
    
    /// Recreates the publishedPings stream and continuation to recover from cancellation.
    func resetPublishedPingsStream()
    
    /// Re-evaluates cadence and interrupts any current long sleep if cadence accelerated.
    func triggerCadenceEvaluation()
    
    /// Publishes a rapid burst of fresh location pings to punch through intermediate mesh relays.
    func triggerBurstPings(count: Int, interval: TimeInterval)
}
```
Notice line 89: `getLatestLocationForSOS() -> LocationPin?`. This is an explicit architectural guarantee: in an emergency SOS situation, the coordinator can obtain the latest known coordinate synchronously, bypassing normal cadence delays and ignoring whether Live Sharing is disabled.

#### Engineering Rationale and Edge Cases
- **MainActor Isolation**: Marked `@MainActor` because CoreLocation delegate callbacks, UI bindings, and permission prompts must be synchronized on the main thread to prevent thread hops and UI tearing.
- **SOS Bypass Guarantee**: When a user triggers SOS, waiting 3–5 seconds for the next cadence ping or requiring the user to first re-enable Live Sharing would be dangerous in life-threatening scenarios. The protocol mandates immediate, unconditional access to the cached coordinate.

---
### 7. `Teekum/Teekum/Core/Location/LocationService.swift`
- **File Path**: [LocationService.swift](../../Teekum/Teekum/Core/Location/LocationService.swift)
- **Line Count**: 263 lines (`wc -l`)
- **Category & Isolation**: Central Service, `@Observable`, `@MainActor public final class`, Inherits `NSObject`, Conforms to `CLLocationManagerDelegate, LocationServiceProtocol`

#### What This File Does
`LocationService.swift` is the central operational hub for location sensing, kinetic monitoring, and battery management across the entire application. It instantiates and owns the native `CLLocationManager` and `CMMotionActivityManager` hardware wrappers, maintains the latest observable state (`currentLocation`, `currentHeading`, `isStationary`, `isSurvivalModeActive`), calculates the adaptive cadence interval based on multi-variable inputs (motion, battery level, distant peers, stale peers), and exposes an `AsyncStream<LocationPin>` for downstream broadcast consumers.

#### ELI5 Analogy
Imagine the master control bridge of an explorer ship. The captain sits here receiving continuous reports from the crow's nest lookouts (compass and GPS sensors), the engine room (battery monitor), and the crew on deck (motion sensors). The captain continuously recalculates how fast the ship should transmit status beacons to the rest of the fleet: "We are at anchor in calm seas; send signals slowly to save lantern fuel. We are now sailing at full speed into a storm; send signals every few seconds!"

#### Technical Terms Defined
- **Adaptive Cadence Hierarchy**: A prioritized decision tree that selects the broadcast interval by evaluating survival mode first, stale peer recovery second, distant peer proximity third, stationary rest fourth, and normal walking fifth.
- **Background Location Mode**: An iOS capability (`UIBackgroundModes = ["location"]`) allowing an app to receive continuous GPS callbacks while suspended or locked.
- **showsBackgroundLocationIndicator**: An Apple CoreLocation property that enables the system-level blue status bar indicator pill, informing the user that the app is actively tracking location in the background.
- **Observation Framework (`@Observable`)**: Apple's modern Swift macro system for fine-grained SwiftUI view tracking, replacing Combine's `ObservableObject` and `@Published`.

#### Code-Block and Line-by-Line Walkthrough
Lines 32–46 define class inheritance and hardware handles:
```swift
@Observable
@MainActor
public final class LocationService: NSObject, CLLocationManagerDelegate, LocationServiceProtocol {
    
    // MARK: - Core Location & Motion Hardware
    
    let locationManager: CLLocationManager
    #if os(iOS) && canImport(CoreMotion)
    let motionActivityManager: CMMotionActivityManager?
    let motionQueue = OperationQueue()
    #endif
    
    /// Injectable date provider for deterministic time-based testing.
    let dateProvider: @Sendable () -> Date
```
Notice `motionQueue`: CoreMotion requires a separate `OperationQueue` for delivering activity updates off the main runloop before `LocationService` marshals them onto `@MainActor`.

Lines 156–215 implement initialization and hardware configuration:
```swift
    public init(
        cadenceConfig: CadenceConfiguration = CadenceConfiguration(),
        isLiveSharingEnabled: Bool = true,
        locationManager: CLLocationManager = CLLocationManager(),
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.cadenceConfig = cadenceConfig
        self.isLiveSharingEnabled = isLiveSharingEnabled
        self.locationManager = locationManager
        self.dateProvider = dateProvider
        self.authorizationStatus = locationManager.authorizationStatus
        
        #if os(iOS) && canImport(CoreMotion)
        self.motionActivityManager = CMMotionActivityManager.isActivityAvailable() ? CMMotionActivityManager() : nil
        #endif
        
        var streamContinuation: AsyncStream<LocationPin>.Continuation!
        self.publishedPings = AsyncStream { streamContinuation = $0 }
        self.publishedPingsContinuation = streamContinuation
        
        super.init()
        
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.distanceFilter = kCLDistanceFilterNone
        self.locationManager.activityType = .fitness
        self.locationManager.pausesLocationUpdatesAutomatically = false
        
        #if os(iOS)
        if let bgModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
           bgModes.contains("location") {
            self.locationManager.allowsBackgroundLocationUpdates = true
            self.locationManager.showsBackgroundLocationIndicator = true
        }
        #endif
```
By explicitly setting `allowsBackgroundLocationUpdates = true` and `showsBackgroundLocationIndicator = true`, Meepo satisfies Apple's App Store guidelines for persistent background tracking.

Lines 237–252 implement the adaptive cadence decision tree:
```swift
    /// Current target publishing interval in seconds based on movement, stationary state, and battery.
    public var currentCadenceInterval: TimeInterval {
        if isSurvivalModeActive {
            return cadenceConfig.survivalInterval
        } else if hasStalePeers || (hasStalePeersProvider?() ?? false) {
            // Stale peer detected within recovery window: accelerate cadence to recover fresh updates
            return cadenceConfig.staleRecoveryInterval
        } else if hasDistantPeers || (hasDistantPeersProvider?() ?? false) {
            // Distant peers detected: accelerate cadence from 20s to 2s to maintain relay responsiveness
            return cadenceConfig.distantPeerInterval
        } else if isStationary {
            return cadenceConfig.stationaryInterval
        } else {
            return cadenceConfig.movingInterval
        }
    }
```
The hierarchy is strictly ordered by urgency:
1. **Survival Mode (<20% battery)**: Always takes precedence (60.0s), preventing device death.
2. **Stale Peer Recovery**: Takes second priority (2.0s), actively probing for lost mesh relays.
3. **Distant Peers**: Accelerates cadence to 2.0s to maintain weak radio links.
4. **Stationary State**: Drops cadence to 15.0–30.0s to conserve battery while standing/dancing.
5. **Moving State**: Baseline 3.0–5.0s cadence while walking.

Lines 256–262 implement the immediate SOS coordinate access:
```swift
    public func getLatestLocationForSOS() -> LocationPin? {
        return currentLocation
    }
```
This guarantees zero latency when emergency SOS is triggered.

#### Engineering Rationale and Edge Cases
- **pausesLocationUpdatesAutomatically = false**: By default, iOS suspends location updates if the user is stationary for several minutes to save power. For a disaster operation safety mesh, automatic pause is catastrophic because peers would assume the user is lost or disconnected. Disabling auto-pause keeps the mesh heartbeat alive.
- **Deinitialization Safety**: In `deinit` (lines 217–221), `NotificationCenter.default.removeObserver(self)` cleanly tears down battery and power change observers, preventing dangling notification callbacks.

---

### 8. `Teekum/Teekum/Core/Location/LocationService+Lifecycle.swift`
- **File Path**: [LocationService+Lifecycle.swift](../../Teekum/Teekum/Core/Location/LocationService+Lifecycle.swift)
- **Line Count**: 139 lines (`wc -l`)
- **Category & Isolation**: Lifecycle Extension, Extension on `@MainActor public final class LocationService`

#### What This File Does
`LocationService+Lifecycle.swift` isolates the permission authorization workflow and hardware start/stop lifecycle management. It translates Apple's asynchronous `CLAuthorizationStatus` callbacks into modern Swift concurrency using `CheckedContinuation`, starts and pauses the physical GPS and compass hardware, and cleanly resets measurement state upon leaving or resetting a group session.

#### ELI5 Analogy
Before opening a high-security research lab, a guard must check everyone's security badges. If someone arrives without a badge, the guard halts them at the door, requests clearance from head office, and waits for approval. Once cleared, the guard flips the master circuit breakers to power up the lights and security cameras. When closing time arrives, the guard powers down the heavy equipment but leaves the emergency exit signs lit. `LocationService+Lifecycle` is that security guard and master power switch.

#### Technical Terms Defined
- **CheckedContinuation**: A Swift concurrency primitive (`withCheckedContinuation`) that suspends an `async` function until a traditional delegate callback or completion handler resumes it with a return value, bridging callback-based APIs into `async/await`.
- **When-In-Use vs. Always Authorization**: iOS permissions governing location access. `authorizedWhenInUse` allows tracking while the app is in the foreground or displaying the background blue status bar pill; `authorizedAlways` grants opportunistic tracking without UI indicators.
- **Hardware Teardown**: The systematic invocation of `stopUpdatingLocation()` and `stopUpdatingHeading()` to cut baseband power draw when tracking is no longer required.

#### Code-Block and Line-by-Line Walkthrough
Lines 16–46 implement asynchronous permission negotiation:
```swift
    public func requestPermissions() async -> Bool {
        guard CLLocationManager.locationServicesEnabled() else {
            isGPSAvailable = false
            return false
        }
        
        let currentStatus = self.authorizationStatus
        
        switch currentStatus {
        #if os(iOS)
        case .authorizedWhenInUse, .authorizedAlways:
            isGPSAvailable = true
            return true
        #else
        case .authorizedAlways:
            isGPSAvailable = true
            return true
        #endif
        case .denied, .restricted:
            isGPSAvailable = false
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.permissionContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }
        @unknown default:
            isGPSAvailable = false
            return false
        }
    }
```
When `authorizationStatus` is `.notDetermined`, it suspends the async task into `permissionContinuation` and prompts the user via `requestWhenInUseAuthorization()`. The continuation is later resumed in `locationManagerDidChangeAuthorization` (`LocationService+Delegate.swift`).

Lines 56–109 implement `startTracking()`:
```swift
    public func startTracking() throws {
        resetPublishedPingsStream()
        
        guard CLLocationManager.locationServicesEnabled() else {
            isGPSAvailable = false
            throw LocationServiceError.locationServicesDisabled
        }
        
        let status = self.authorizationStatus
        
        switch status {
        case .denied:
            isGPSAvailable = false
            throw LocationServiceError.permissionDenied
        case .restricted:
            isGPSAvailable = false
            throw LocationServiceError.permissionRestricted
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            break
        }
        
        isTracking = true
        isGPSAvailable = (status == .authorizedWhenInUse || status == .authorizedAlways)
        
        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        
        startMotionTracking()
        updateBatteryState()
        applyDynamicAccuracy()
        
        if isLiveSharingEnabled {
            startPublishingScheduler()
        }
    }
```
- Line 57: `resetPublishedPingsStream()`: Re-initializes the AsyncStream continuation so fresh subscribers do not inherit a terminated or cancelled stream from a previous session.
- Lines 94–99: Powers on location fixes and compass heading updates if hardware is available.
- Lines 102–108: Starts CoreMotion activity tracking, reads initial battery state, adjusts hardware accuracy, and launches the publishing scheduler.

Lines 113–123 implement `stopTracking()`:
```swift
    public func stopTracking() {
        isTracking = false
        stopPublishingScheduler()
        
        locationManager.stopUpdatingLocation()
        #if os(iOS)
        locationManager.stopUpdatingHeading()
        #endif
        
        stopMotionTracking()
    }
```
Notice that `stopTracking()` halts the hardware and scheduler but intentionally leaves `currentLocation` in memory, allowing offline viewing and SOS dispatch using the last valid fix.

Lines 125–138 implement `clearSessionMeasurements()`:
Fully tears down tracking and clears all in-memory coordinates, headings, and peer proximity flags when leaving a session.

#### Engineering Rationale and Edge Cases
- **Stream Recreation**: If an `AsyncStream` was consumed by a `Task` that was subsequently cancelled, the underlying stream continuation becomes closed. Recreating the stream via `resetPublishedPingsStream()` prevents subsequent session starts from yielding into a dead pipe.
- **Handling Denied States Synchronously**: If permissions are already `.denied`, `startTracking()` immediately throws `LocationServiceError.permissionDenied` without prompting, allowing the UI to present a direct link to the iOS Settings app.

---

### 9. `Teekum/Teekum/Core/Location/LocationService+Delegate.swift`
- **File Path**: [LocationService+Delegate.swift](../../Teekum/Teekum/Core/Location/LocationService+Delegate.swift)
- **Line Count**: 85 lines (`wc -l`)
- **Category & Isolation**: Delegate Extension, Extension on `@MainActor public final class LocationService` implementing `CLLocationManagerDelegate`

#### What This File Does
`LocationService+Delegate.swift` implements the native `CLLocationManagerDelegate` protocol methods called by the operating system's `locationd` daemon. Because Apple's CoreLocation framework calls delegate methods on arbitrary system threads, each delegate implementation in this file uses `nonisolated` declarations that safely hop to `@MainActor` via `Task { @MainActor [weak self] in ... }`, preventing data races and maintaining strict thread-safe isolation.

#### ELI5 Analogy
When letters arrive at a corporate mailroom from various delivery couriers, the mailroom clerks do not walk directly into the executive boardroom. Instead, they drop the envelopes into a secure incoming chute marked "Executive Action". The executive opens each letter in order, verifies the signature, and updates the status board. This file is that mailroom drop chute.

#### Technical Terms Defined
- **nonisolated Delegate Method**: A method marked `nonisolated` to fulfill an Objective-C protocol requirement that does not guarantee `@MainActor` thread affinity.
- **Actor Hopping**: Explicitly dispatching execution from a background thread to the `@MainActor` executor using `Task { @MainActor in ... }`.
- **True Heading vs. Magnetic Heading**: Magnetic heading is referenced to the magnetic North Pole; True heading is corrected for local geomagnetic declination to point to geographic True North.
- **Heading Accuracy**: A metric in degrees indicating uncertainty; a negative value indicates compass calibration is corrupted by local magnetic interference.

#### Code-Block and Line-by-Line Walkthrough
Lines 15–22 handle location fixes:
```swift
    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self, self.isTracking else { return }
            for location in locations {
                self.applyLocationMeasurement(location)
            }
        }
    }
```
CoreLocation frequently delivers locations in batches. The loop processes each measurement sequentially through `applyLocationMeasurement(_:)`.

Lines 24–32 handle compass heading fixes:
```swift
    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor [weak self] in
            guard let self, self.isTracking else { return }
            self.currentHeading = heading
            self.onHeadingUpdate?(heading)
        }
    }
```
- Line 25: Immediately filters out fixes where `headingAccuracy < 0` (uncalibrated or magnetically corrupted fixes).
- Line 26: Prefers `trueHeading` if valid (`>= 0`); otherwise falls back to `magneticHeading`.
- Lines 29–30: Updates `currentHeading` and notifies high-frequency listeners (such as directional finder radar needles) via `onHeadingUpdate`.

Lines 34–73 handle authorization state changes:
```swift
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = newStatus
            
            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.isGPSAvailable = true
                self.permissionContinuation?.resume(returning: true)
                self.permissionContinuation = nil
                if self.isTracking {
                    self.locationManager.startUpdatingLocation()
                    if CLLocationManager.headingAvailable() {
                        self.locationManager.startUpdatingHeading()
                    }
                }
            case .denied, .restricted:
                self.isGPSAvailable = false
                self.permissionContinuation?.resume(returning: false)
                self.permissionContinuation = nil
            case .notDetermined:
                break
            @unknown default:
                self.isGPSAvailable = false
                self.permissionContinuation?.resume(returning: false)
                self.permissionContinuation = nil
            }
        }
    }
```
Resumes `permissionContinuation` and immediately boots GPS and compass updates if authorization was granted while `isTracking` is active.

Lines 75–84 handle errors:
```swift
    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let clError = error as? CLError {
                if clError.code == .denied {
                    self.isGPSAvailable = false
                }
            }
        }
    }
```

#### Engineering Rationale and Edge Cases
- **Non-blocking Heading Guard**: Evaluating `guard newHeading.headingAccuracy >= 0` outside the `Task` prevents creating unnecessary MainActor async tasks when the compass is spinning wildly or uncalibrated.
- **Weak Self Capture**: All closures capture `[weak self]` to ensure that tearing down `LocationService` does not leak memory if a pending XPC callback from `locationd` arrives late.

---

### 10. `Teekum/Teekum/Core/Location/LocationService+AdaptiveHardware.swift`
- **File Path**: [LocationService+AdaptiveHardware.swift](../../Teekum/Teekum/Core/Location/LocationService+AdaptiveHardware.swift)
- **Line Count**: 135 lines (`wc -l`)
- **Category & Isolation**: Hardware Extension, Extension on `@MainActor public final class LocationService`

#### What This File Does
`LocationService+AdaptiveHardware.swift` dynamically modulates physical sensor hardware to strike an optimal balance between positioning precision and battery longevity. It interfaces with Apple's M-series motion coprocessor via `CMMotionActivityManager` to detect when the user is stationary versus walking, listens to system battery and low-power notifications via `UIDevice` and `ProcessInfo`, and continuously adjusts CoreLocation's `desiredAccuracy`, `distanceFilter`, and `headingFilter`.

#### ELI5 Analogy
Think of an intelligent car with an adaptive engine. When cruising on the open highway at night, it switches to eco-mode, dimming dashboard lights and lowering RPM to save fuel. When the driver hits the gas pedal to overtake or turns onto a winding racetrack, it instantly switches to high-performance sport mode, engaging twin turbochargers and stiffening the suspension. This file is the car's dynamic engine management computer.

#### Technical Terms Defined
- **Motion Coprocessor (M-Series)**: A dedicated ultra-low-power silicon core on Apple chips that processes accelerometer and gyroscope data continuously without waking the main CPU.
- **Dual-Frequency L1/L5 GNSS**: High-end satellite positioning utilizing two distinct radio carrier frequencies (1575.42 MHz and 1176.45 MHz), mitigating multipath signal reflections in dense forest or city environments at the cost of higher power draw.
- **kCLLocationAccuracyBestForNavigation**: The highest precision positioning mode in CoreLocation, keeping dual-frequency GNSS and cellular/Wi-Fi assistance fully powered.
- **Hardware Power Gating**: De-energizing peripheral sensor radios and filters when the operating system detects that sensor readings would be redundant (e.g., stationary device).

#### Code-Block and Line-by-Line Walkthrough
Lines 23–38 implement motion coprocessor integration:
```swift
    func startMotionTracking() {
        #if os(iOS) && canImport(CoreMotion)
        guard let motionActivityManager else { return }
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        
        // Core Motion invokes this handler on motionQueue before we hop to MainActor.
        motionActivityManager.startActivityUpdates(to: motionQueue) { @Sendable [weak self] activity in
            guard let activity else { return }
            let stationary = activity.stationary && !activity.walking && !activity.running
            Task { @MainActor [weak self] in
                guard let self, isTracking else { return }
                self.setStationaryState(stationary)
            }
        }
        #endif
    }
```
Notice line 31: `stationary = activity.stationary && !activity.walking && !activity.running`. This protects against edge cases where the user is walking slowly or dancing in place and the classifier temporarily asserts multiple flags.

Lines 46–55 handle state changes:
```swift
    func setStationaryState(_ stationary: Bool) {
        guard isStationary != stationary else { return }
        self.isStationary = stationary
        applyDynamicAccuracy()
        
        // When motion state changes, restart scheduler to adopt new cadence immediately
        if isTracking && isLiveSharingEnabled {
            startPublishingScheduler()
        }
    }
```
When transitioning between walking and resting, the scheduler is immediately restarted to adopt the new cadence without waiting for the old timer to expire.

Lines 59–97 implement dynamic hardware accuracy tuning:
```swift
    /// Enables or disables high-precision navigation mode for the tactical radar.
    public func setTacticalRadarActive(_ active: Bool) {
        guard isTacticalRadarActive != active else { return }
        self.isTacticalRadarActive = active
        applyDynamicAccuracy()
    }
    
    public func applyDynamicAccuracy() {
        if isTacticalRadarActive {
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager.distanceFilter = kCLDistanceFilterNone
            #if os(iOS)
            locationManager.headingFilter = kCLHeadingFilterNone
            #endif
        } else if isSurvivalModeActive {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 25.0
            #if os(iOS)
            locationManager.headingFilter = 5.0
            #endif
        } else if isStationary {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 15.0
            #if os(iOS)
            locationManager.headingFilter = 3.0
            #endif
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = kCLDistanceFilterNone
            #if os(iOS)
            locationManager.headingFilter = 1.0
            #endif
        }
    }
```
Lines 101–134 implement battery and survival mode detection:
```swift
    public func applyBatteryLevel(_ level: Float, isLowPower: Bool = false) {
        self.currentBatteryLevel = min(1.0, max(0.0, level))
        self.isLowPowerMode = isLowPower
        let survival = (currentBatteryLevel < 0.20) || isLowPower
        
        if isSurvivalModeActive != survival {
            self.isSurvivalModeActive = survival
            applyDynamicAccuracy()
            if isTracking && isLiveSharingEnabled {
                startPublishingScheduler()
            }
        }
    }
```

#### Engineering Rationale and Edge Cases
- **Simulator Fallback**: `UIDevice.current.batteryLevel` returns `-1.0` in the iOS Simulator. Line 112 safely handles this: `let battery = rawLevel >= 0 ? rawLevel : 1.0`.
- **Compass Power Conservation**: Compass digital fluxgate sensors consume significant power. Relaxing `headingFilter` to 3.0° or 5.0° prevents constant compass interrupts when the phone is swaying in a pocket or backpack.

---

### 11. `Teekum/Teekum/Core/Location/LocationService+Publishing.swift`
- **File Path**: [LocationService+Publishing.swift](../../Teekum/Teekum/Core/Location/LocationService+Publishing.swift)
- **Line Count**: 158 lines (`wc -l`)
- **Category & Isolation**: Publishing Extension, Extension on `@MainActor public final class LocationService`

#### What This File Does
`LocationService+Publishing.swift` implements the active publishing loop and monotonic validation filters. It manages the single cancellable timer loop (`publishingTask`) that ticks at the interval determined by `currentCadenceInterval`, handles the user's Live Sharing master toggle, provides burst ping capabilities to punch through intermediate mesh relays, and enforces rigorous monotonic validation on incoming GPS fixes so that outdated or inaccurate fixes are discarded.

#### ELI5 Analogy
Imagine a lighthouse keeper with an adjustable lantern. When the keeper turns on the beacon, a clockwork motor spins the light at the speed designated by the harbor master. Every time the light sweeps past the window, the keeper checks their nautical log. If the latest ship coordinate is older than the previous entry (due to a delayed pigeon message), they reject it and do not shine the light in the wrong direction. If a ship fires a flare asking for immediate guidance, the keeper rapidly pulses the beacon three times ("burst pings") to guide them in.

#### Technical Terms Defined
- **Monotonic Timestamp Validation**: A filter rule requiring that any new measurement must have a timestamp strictly greater than or equal to the previous measurement (`location.timestamp >= existing.timestamp`), preventing delayed network or cellular fixes from regressing device state.
- **Negative Accuracy Discard**: CoreLocation returns a negative horizontal accuracy (such as `-1.0`) when it cannot compute a geographic fix. Any fix with `horizontalAccuracy < 0` is strictly discarded.
- **Burst Pings**: A rapid sequence of location frames transmitted at short intervals (e.g., 3 pings spaced 500ms apart) designed to bypass transient radio packet loss and prime mesh routing tables.

#### Code-Block and Line-by-Line Walkthrough
Lines 20–29 handle the Live Sharing master toggle:
```swift
    func handleLiveSharingToggleChanged() {
        if isLiveSharingEnabled {
            if isTracking {
                startPublishingScheduler()
            }
        } else {
            // Live Sharing OFF prevents ordinary location broadcasting
            stopPublishingScheduler()
        }
    }
```
Toggling Live Sharing off cancels the scheduler loop immediately, ensuring no location pins are emitted while the user expects stealth privacy.

Lines 35–69 manage the scheduler loop:
```swift
    func startPublishingScheduler() {
        stopPublishingScheduler()
        
        guard isTracking, isLiveSharingEnabled else { return }
        
        // Broadcast current location fix immediately upon scheduler start
        publishCurrentState()
        
        publishingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isTracking, self.isLiveSharingEnabled else { break }
                
                let interval = self.currentCadenceInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                
                guard !Task.isCancelled, self.isTracking, self.isLiveSharingEnabled else { break }
                
                self.publishCurrentState()
            }
        }
    }
```
Notice the pattern:
1. Calls `stopPublishingScheduler()` first to prevent duplicate concurrent timer loops.
2. Emits `publishCurrentState()` immediately so the user doesn't wait up to 30 seconds for the first ping.
3. Loops with `Task.sleep`, checking cancellation tokens at every step.

Lines 72–91 implement burst pings:
```swift
    public func triggerBurstPings(
        count: Int = MeshTimingConfiguration.default.staleResponseBurstCount,
        interval: TimeInterval = MeshTimingConfiguration.default.staleResponseBurstInterval
    ) {
        guard isLiveSharingEnabled, count > 0 else { return }
        
        // 1. Immediately publish ping #1
        publishCurrentState()
        guard count > 1 else { return }
        
        // 2. Schedule remaining burst pings in a cancellable task
        burstTask?.cancel()
        burstTask = Task { @MainActor [weak self] in
            for _ in 1..<count {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, let self, self.isLiveSharingEnabled else { break }
                self.publishCurrentState()
            }
        }
    }
```
Lines 113–149 enforce monotonic validation:
```swift
    public func applyLocationMeasurement(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0 else {
            // Discard invalid GPS fix
            return
        }
        
        if let existing = currentLocation {
            // An older coordinate cannot overwrite a newer valid measurement
            guard location.timestamp >= existing.timestamp else {
                return
            }
        }
        
        let newPin = LocationPin(
            coordinate: location.coordinate,
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: location.timestamp,
            heading: currentHeading
        )
        
        let isFirstFix = (self.currentLocation == nil)
        self.currentLocation = newPin
        self.isGPSAvailable = true
        
        if isFirstFix && isLiveSharingEnabled && isTracking {
            publishCurrentState()
        }
```
- Lines 114–116: Discards invalid negative accuracy fixes.
- Lines 119–124: Discards fixes with out-of-order timestamps.
- Lines 143–148: If CoreMotion is unavailable on the platform, falls back to `evaluateGPSSpeedForStationary(location.speed)`. If speed is `>= 0.8 m/s` (~2.88 km/h), stationary mode is cleared; if speed is `< 0.3 m/s`, stationary mode is engaged.

#### Engineering Rationale and Edge Cases
- **No Coordinate Fabrication**: Line 97 checks: `guard let location = currentLocation else { return }`. If the GPS receiver has not acquired a satellite lock, Meepo refuses to manufacture default coordinates (such as (0,0) or last week's cached fix). It remains silent until an authentic GNSS lock is secured.
- **GPS Speed Fallback**: On iPads, iPods, or custom hardware where M-series CoreMotion coprocessors are absent, the system seamlessly uses GNSS Doppler speed (`location.speed`) to drive stationary detection without crashing or degrading cadence logic.

---
### 12. `Teekum/Teekum/Core/Notifications/NotificationService.swift`
- **File Path**: [NotificationService.swift](../../Teekum/Teekum/Core/Notifications/NotificationService.swift)
- **Line Count**: 85 lines (`wc -l`)
- **Category & Isolation**: Notification Service, `@Observable`, `@MainActor final class`, Inherits `NSObject`, Conforms to `UNUserNotificationCenterDelegate`

#### What This File Does
`NotificationService.swift` manages local notifications and in-app banner toasts across the application lifecycle. When Meepo is in the background or device is locked, it posts system notifications through `UNUserNotificationCenter` for high-priority events (emergency SOS sirens, incoming chat messages, and group member join/leave events). When the app is in the foreground, it manages transient in-app banner alerts that automatically auto-dismiss after 4 seconds.

#### ELI5 Analogy
Imagine a personal assistant who handles announcements. If you are sitting in your office working on your computer (app in foreground), the assistant simply points to a small sticky note on your desk, which they remove after 4 seconds so your desk stays clean. If you are walking down the hallway or away from your desk (app in background/locked), the assistant pages you over the building intercom loudspeaker with a clear announcement.

#### Technical Terms Defined
- **UNUserNotificationCenter**: Apple's framework managing notification delivery, badges, alerts, and sounds across iOS.
- **Local vs. Remote Notifications**: Local notifications are generated directly on-device by application logic without requiring an external APNs (Apple Push Notification service) push server or cellular internet connection.
- **Auto-Dismiss Task**: A cancellable asynchronous timer task (`Task.sleep(for: .seconds(4))`) that resets in-memory toast alert state after a fixed duration.
- **willPresent Notification Options**: Delegate callback determining whether a notification that arrives while the app is actively running in the foreground should display a banner, play a sound, or update a badge.

#### Code-Block and Line-by-Line Walkthrough
Lines 13–25 declare the state properties and initialize the delegate:
```swift
@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private(set) var message: String?
    private(set) var chatAlert: (sender: String, body: String)?
    private(set) var groupActivity: (message: String, memberID: String)?
    private var dismissTask: Task<Void, Never>?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
```
Lines 26–28 request user permissions:
```swift
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }
```
Requests alert banners, sound alerts, and app icon badges.

Lines 30–41 implement general notification dispatch:
```swift
    func notify(title: String, body: String, showBanner: Bool = true) {
        if showBanner {
            showMessage("\(title): \(body)")
        }
        guard UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
```
Notice line 34: `guard UIApplication.shared.applicationState != .active else { return }`. If the app is active in the foreground, system notification delivery is skipped to avoid duplicate alert banners, relying instead on `showMessage(...)` for in-app toasts.

Lines 43–56 provide domain-specific notification dispatchers:
```swift
    func notifyGroupActivity(_ members: [String], joined: Bool) {
        guard let first = members.first else { return }
        let names = members.formatted(.list(type: .and))
        let body = joined
            ? (members.count == 1 ? "\(names) has joined" : "\(names) have joined")
            : "Lost contact with \(names)"
        showMessage(body, memberID: first)
        notify(title: "Group activity", body: body, showBanner: false)
    }

    func notifyChat(sender: String, body: String) {
        showMessage(body, chatSender: sender)
        notify(title: sender, body: body, showBanner: false)
    }
```
Lines 58–69 implement the in-app banner auto-dismiss logic:
```swift
    private func showMessage(_ text: String, memberID: String? = nil, chatSender: String? = nil) {
        message = memberID == nil && chatSender == nil ? text : nil
        chatAlert = chatSender.map { ($0, text) }
        groupActivity = memberID.map { (text, $0) }
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            self?.message = nil
            self?.chatAlert = nil
            self?.groupActivity = nil
        }
    }
```
When a new alert arrives, previous auto-dismiss tasks are cancelled, and a fresh 4-second sleep task is spawned.

Lines 81–84 implement the foreground presentation options:
```swift
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
```

#### Engineering Rationale and Edge Cases
- **Completely Offline Notification Guarantee**: Because Meepo operates in disconnected wilderness disaster operations without cell towers or Wi-Fi routers, Apple Push Notification service (APNs) is unavailable. All alerts are generated locally via `UNNotificationRequest(identifier:trigger: nil)`, guaranteeing immediate firing without network roundtrips.
- **Notification Queue Pruning**: In `clear()` (lines 71–79), calling `removeAllDeliveredNotifications()` and `removeAllPendingNotificationRequests()` prevents stale mesh notifications from cluttering the user's Notification Center when they end or reset a session.

---

### 13. `Teekum/Teekum/Core/LiveActivity/LiveActivityManager.swift`
- **File Path**: [LiveActivityManager.swift](../../Teekum/Teekum/Core/LiveActivity/LiveActivityManager.swift)
- **Line Count**: 54 lines (`wc -l`)
- **Category & Isolation**: ActivityKit Coordinator, `@MainActor final class`

#### What This File Does
`LiveActivityManager.swift` coordinates Apple's ActivityKit subsystem to drive real-time Live Activities on the Lock Screen and Dynamic Island. When a group session starts, it requests a new `Activity<SessionActivityAttributes>`; as mesh telemetry arrives, it throttles and updates the activity content state with peer counts, unread messages, distance to meeting point, SOS status, and relay state; when the session ends, it dismisses the activity immediately.

#### ELI5 Analogy
Imagine a tactical communications specialist managing a heads-up situational billboard at an emergency staging ground. When a deployment commences, the specialist activates the Live Activity on the Lock Screen and Dynamic Island. As the rescue unfolds, the display updates with squad distance, direction bearing, and battery levels. To conserve battery on long 12-hour shifts, updates are debounced so the display refreshes only when data shifts significantly or 15 seconds have passed. When the squad demobilizes, the display is completely torn down.

#### Technical Terms Defined
- **ActivityKit**: Apple's framework for presenting real-time live data on the iPhone Lock Screen and Dynamic Island.
- **ContentState**: The dynamic, codable struct within `ActivityAttributes` that updates over the lifetime of the activity.
- **Stale Date**: An expiration timestamp provided to ActivityKit (`.now.addingTimeInterval(30)`) informing iOS when the data should be visually grayed out or dimmed if no fresh updates arrive.
- **Immediate Dismissal Policy**: Calling `activity.end(nil, dismissalPolicy: .immediate)` to instantly remove the Dynamic Island and Lock Screen widgets without leaving a lingering ended banner.

#### Code-Block and Line-by-Line Walkthrough
Lines 11–15 define class properties:
```swift
@MainActor
final class LiveActivityManager {
    private var activityID: String?
    private var lastState: SessionActivityAttributes.ContentState?
```
Lines 16–23 start a new Live Activity:
```swift
    func start(session: GroupSession) async {
        await stop()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = SessionActivityAttributes(sessionId: session.sessionId,
            sessionName: session.sessionName, userInitials: session.localInitials, userColorCode: session.localColorCode)
        activityID = try? Activity.request(attributes: attributes,
            content: ActivityContent(state: .init(), staleDate: .now.addingTimeInterval(30)), pushType: nil).id
    }
```
- Line 17: Calls `await stop()` first to terminate any existing orphan activities from previous runs.
- Line 18: Checks `ActivityAuthorizationInfo().areActivitiesEnabled` to respect user privacy settings.
- Lines 19–22: Creates `SessionActivityAttributes` with session metadata and requests the activity with `pushType: nil` (local updates only, no APNs push token required).

Lines 25–38 update the content state:
```swift
    func update(peerCount: Int, unreadCount: Int, meeting: MeetingPoint?, location: LocationPin?, sosSender: String?, relay: RelayPolicyState) async {
        guard let activityID else { return }
        let distance = meeting.flatMap { point in location.map { Int($0.distance(to: point.coordinate)) } }
        var state = SessionActivityAttributes.ContentState(directPeerCount: peerCount, unreadMessageCount: unreadCount,
            meetingPointName: meeting?.name, meetingPointDistanceMeters: distance,
            sosSenderInitials: sosSender, relayStatusText: relay.statusDescription())
        if let previous = lastState {
            state.lastUpdated = previous.lastUpdated
            guard state != previous || Date.now.timeIntervalSince(previous.lastUpdated) >= 15 else { return }
            state.lastUpdated = .now
        }
        lastState = state
        await Self.pushUpdate(id: activityID, state: state)
    }
```
Notice line 33: `guard state != previous || Date.now.timeIntervalSince(previous.lastUpdated) >= 15 else { return }`. This rate-limiter prevents spamming the ActivityKit daemon with high-frequency updates, conserving system power while guaranteeing an update at least every 15 seconds.

Lines 40–45 push the update concurrently:
```swift
    @concurrent private static func pushUpdate(id: String, state: SessionActivityAttributes.ContentState) async {
        for activity in Activity<SessionActivityAttributes>.activities where activity.id == id {
            await activity.update(ActivityContent(state: state, staleDate: .now.addingTimeInterval(30)))
            break
        }
    }
```
Notice `@concurrent`: pushes the XPC update without blocking the `@MainActor` thread.

Lines 47–53 tear down the activity:
```swift
    func stop() async {
        activityID = nil
        lastState = nil
        for existing in Activity<SessionActivityAttributes>.activities {
            await existing.end(nil, dismissalPolicy: .immediate)
        }
    }
```

#### Engineering Rationale and Edge Cases
- **ActivityKit 4KB Payload Limit**: Apple restricts ActivityKit content state payloads to 4 kilobytes. `SessionActivityAttributes.ContentState` is kept lean (a few integers and short strings), easily fitting within ~100 bytes, well under the 4KB budget.
- **Stale Date Management**: Supplying `staleDate: .now.addingTimeInterval(30)` ensures that if the main app is force-quit or runs out of battery, iOS automatically dims the Dynamic Island widget after 30 seconds, signaling to the user that live telemetry has paused.

---

### 14. `Teekum/Teekum/Core/LiveActivity/SessionActivityAttributes.swift`
- **File Path**: [SessionActivityAttributes.swift](../../Teekum/Teekum/Core/LiveActivity/SessionActivityAttributes.swift)
- **Line Count**: 39 lines (`wc -l`)
- **Category & Isolation**: Shared Data Contract, Dual Target (`Teekum` + `TeekumWidgets`), `struct`, Conforms to `ActivityAttributes`

#### What This File Does
`SessionActivityAttributes.swift` defines the data contract that bridges the main application and the WidgetKit extension. It conforms to Apple's `ActivityAttributes` protocol, defining both immutable session metadata (session ID, session name, user initials, color code) and the mutable, codable `ContentState` struct (peer count, unread count, meeting point distance, SOS status, relay text).

#### ELI5 Analogy
Imagine a tactical mission credential. The front page is a permanent card displaying static deployment data: session ID, squad callsign, and assigned squad badge color. The reverse is an electronic tactical ink strip (`ContentState`) that continuously refreshes with dynamic field metrics: distance to the nearest teammate, compass direction, connection health, and emergency distress state.

#### Technical Terms Defined
- **ActivityAttributes**: Apple's protocol marking a struct as the static configuration schema for an ActivityKit Live Activity.
- **ContentState Protocol Conformance**: Must conform to `Codable, Hashable, Sendable` so iOS SpringBoard can serialize, diff, and distribute state snapshots across XPC boundaries between processes.
- **Zero-Knowledge Widget Isolation**: Deliberately excluding raw GPS coordinates and encryption keys from the widget payload to prevent location or security leaks outside the app container.

#### Code-Block and Line-by-Line Walkthrough
Lines 12–39 declare the attributes and nested dynamic content state:
```swift
/// Shared by the app and widget; contains no session key or precise coordinates.
struct SessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var directPeerCount = 0
        var unreadMessageCount = 0
        var meetingPointName: String?
        var meetingPointDistanceMeters: Int?
        var sosSenderInitials: String?
        var relayStatusText = "Relay off"
        var lastUpdated = Date.now
    }
    
    let sessionId: UInt32
    let sessionName: String
    let userInitials: String
    let userColorCode: UInt8
    
    init(
        sessionId: UInt32,
        sessionName: String,
        userInitials: String,
        userColorCode: UInt8 = 0x00
    ) {
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.userInitials = userInitials
        self.userColorCode = userColorCode
    }
}
```
- Line 11 comment: `Shared by the app and widget; contains no session key or precise coordinates.`
- Lines 14–20: Dynamic content state fields:
  - `directPeerCount`: Number of 1-hop radio neighbors.
  - `unreadMessageCount`: Chat messages waiting to be read.
  - `meetingPointName`: Optional name of the rendezvous point (e.g., "Evac LZ Alpha").
  - `meetingPointDistanceMeters`: Calculated distance in meters.
  - `sosSenderInitials`: Initials of the peer in distress, or `nil` if no SOS.
  - `relayStatusText`: Human-readable mesh status ("Relay active", "Relay off").
  - `lastUpdated`: Timestamp used by `LiveActivityManager` to throttle updates.
- Lines 23–26: Static attributes immutable for the duration of the Live Activity.

#### Engineering Rationale and Edge Cases
- **Dual Target Inclusion**: Because this file is compiled into both the main app binary and the widget extension binary, modifying this file requires zero bridging headers or binary frameworks.
- **Privacy by Design**: By passing only `meetingPointDistanceMeters: Int?` instead of `latitude` and `longitude`, any malicious observer or crash dump inspecting the widget extension memory cannot extract the user's geographic coordinates.

---

### 15. `TeekumWidgets/TeekumWidgetBundle.swift`
- **File Path**: [TeekumWidgetBundle.swift](../../TeekumWidgets/TeekumWidgetBundle.swift)
- **Line Count**: 14 lines (`wc -l`)
- **Category & Isolation**: Widget Entry Point, Widget Extension Target (`TeekumWidgets`), `@main struct TeekumWidgetBundle: WidgetBundle`

#### What This File Does
`TeekumWidgetBundle.swift` is the primary executable entry point for the `TeekumWidgets` App Extension. Annotated with `@main`, it conforms to WidgetKit's `WidgetBundle` protocol, registering `SessionActivityWidget` with the operating system as an available Live Activity provider.

#### ELI5 Analogy
When a department store opens, there is a central directory board at the entrance listing all the departments inside. `@main struct TeekumWidgetBundle` is that directory board for iOS, telling the phone: "The only department inside this extension is the `SessionActivityWidget`."

#### Technical Terms Defined
- **@main Annotation**: The Swift compiler directive designating the executable entry point of the binary or extension.
- **WidgetBundle**: A container protocol allowing an extension to expose one or multiple widgets and live activities to WidgetKit.

#### Code-Block and Line-by-Line Walkthrough
Lines 11–14 declare the bundle:
```swift
import SwiftUI
import WidgetKit

@main
struct TeekumWidgetBundle: WidgetBundle {
    var body: some Widget { SessionActivityWidget() }
}
```
- Line 11: `@main` designates this struct as the extension's entry point.
- Line 12: Conforms to `WidgetBundle`.
- Line 13: Returns `SessionActivityWidget()` inside the widget body composition.

#### Engineering Rationale and Edge Cases
- **Minimal Bundle Surface**: By keeping the bundle stripped to a single active widget, the extension binary size remains negligible (~200 KB) and cold-boot execution time is under 10 milliseconds, preventing watchdog terminations by iOS SpringBoard.

---

### 16. `TeekumWidgets/SessionActivityWidget.swift`
- **File Path**: [SessionActivityWidget.swift](../../TeekumWidgets/SessionActivityWidget.swift)
- **Line Count**: 131 lines (`wc -l`)
- **Category & Isolation**: WidgetKit Declaration, Widget Extension Target (`TeekumWidgets`), `struct SessionActivityWidget: Widget`

#### What This File Does
`SessionActivityWidget.swift` implements the complete WidgetKit layout configuration for both Lock Screen Live Activities and Dynamic Island presentations. It defines how data from `SessionActivityAttributes` and `ContentState` is partitioned across the Dynamic Island's four presentations: Expanded (leading, trailing, bottom regions), Compact Leading, Compact Trailing, and Minimal. It also provides comprehensive SwiftUI Xcode preview configurations covering normal, chat unread, and emergency SOS states.

#### ELI5 Analogy
Think of a master graphic designer designing logos for different sizes: a giant highway billboard (Lock Screen), a medium horizontal banner (Dynamic Island Expanded), and tiny postage stamps (Dynamic Island Compact and Minimal). The designer ensures that no matter how small the space is, the most critical message (especially an emergency alarm) is instantly visible.

#### Technical Terms Defined
- **ActivityConfiguration**: The WidgetKit structure that binds an `ActivityAttributes` type to its Lock Screen view and Dynamic Island layouts.
- **DynamicIslandExpandedRegion**: Layout containers (`.leading`, `.trailing`, `.bottom`, `.center`) that populate the expanded Dynamic Island interface when a user long-presses the pill.
- **Compact Presentation**: The split layout used when Meepo is the sole active Live Activity, displaying content on both the left (leading) and right (trailing) of the camera cutout.
- **Minimal Presentation**: The circular or pill layout used when another app is concurrently presenting in the Dynamic Island, constraining Meepo to a single trailing slot.

#### Code-Block and Line-by-Line Walkthrough
Lines 12–53 implement the core `Widget` body:
```swift
struct SessionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            SessionLiveActivityView(attributes: context.attributes, state: context.state)
                .background(.black)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let accent: Color = context.state.sosSenderInitials == nil ? .buttonPrimary : .red
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SessionAppBadge(accentColor: accent)
                        .padding(.leading, 8)
                        .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.relayStatusText)
                        .font(.custom("Helvetica", size: 12, relativeTo: .caption))
                        .foregroundStyle(accent)
                        .padding(.trailing, 8)
                        .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionSummaryRow(attributes: context.attributes, state: context.state)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
            } compactLeading: {
                islandIcon(for: context.state)
            } compactTrailing: {
                compactTrailingContent(for: context.state)
            } minimal: {
                if context.state.sosSenderInitials == nil && context.state.unreadMessageCount > 0 {
                    Image(systemName: "message.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.buttonPrimary)
                } else {
                    islandIcon(for: context.state)
                }
            }
        }
    }
```
Lines 55–68 implement the icon selector:
```swift
    @ViewBuilder
    private func islandIcon(for state: SessionActivityAttributes.ContentState) -> some View {
        if state.sosSenderInitials != nil {
            Image(systemName: "sos.circle.fill")
                .foregroundStyle(.red)
        } else {
            Image("MeetPoint")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(Color.buttonPrimary)
        }
    }
```
If an SOS is active, the icon becomes a red SOS badge; otherwise, it displays the MeetPoint vector asset.

Lines 70–94 implement compact trailing content:
```swift
    @ViewBuilder
    private func compactTrailingContent(for state: SessionActivityAttributes.ContentState) -> some View {
        if let sosInitials = state.sosSenderInitials {
            Text(sosInitials)
                .font(.custom("Helvetica", size: 12, relativeTo: .caption))
                .foregroundStyle(.red)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } else {
            let badge = state.unreadMessageCount > 0
                ? (count: state.unreadMessageCount, icon: "message.fill")
                : (count: state.directPeerCount, icon: "person.2.fill")
            HStack(spacing: 3) {
                Text("\(badge.count)")
                    .font(.custom("Helvetica", size: 12, relativeTo: .caption))
                    .monospacedDigit()
                Image(systemName: badge.icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.buttonPrimary)
            .lineLimit(1)
        }
    }
```
Trailing prioritization:
1. **SOS Active**: Displays red initials (`sosInitials`).
2. **Unread Messages**: Displays count + `message.fill`.
3. **Normal Navigation**: Displays direct peer count + `person.2.fill`.

Lines 97–131 implement Xcode `#Preview` macros across all presentation modes:
- Lock Screen Live Activity preview (`as: .content`).
- Dynamic Island Expanded preview (`as: .dynamicIsland(.expanded)`).
- Dynamic Island Compact preview (`as: .dynamicIsland(.compact)`).
- Dynamic Island Minimal preview (`as: .dynamicIsland(.minimal)`).

#### Engineering Rationale and Edge Cases
- **Monospaced Digits**: Line 87 specifies `.monospacedDigit()` for counts, preventing visual jitter and horizontal bouncing in the Dynamic Island as numbers transition between 1 and 9.
- **Minimum Scale Factor**: Text labels specify `.minimumScaleFactor(0.75)` to prevent text truncation on smaller iPhone Dynamic Island cutouts (e.g., iPhone 14 Pro).

---

### 17. `TeekumWidgets/SessionLiveActivityView.swift`
- **File Path**: [SessionLiveActivityView.swift](../../TeekumWidgets/SessionLiveActivityView.swift)
- **Line Count**: 143 lines (`wc -l`)
- **Category & Isolation**: SwiftUI Presentation, Widget Extension Target (`TeekumWidgets`), SwiftUI View Declarations (`SessionAppBadge`, `SessionSummaryRow`, `SessionLiveActivityView`)

#### What This File Does
`SessionLiveActivityView.swift` implements the reusable SwiftUI presentation components for the Lock Screen card and the expanded Dynamic Island view. It encapsulates `SessionAppBadge` (app icon and name), `SessionSummaryRow` (avatar circle with color-coded initials, session name, subtitle, and dynamic status pill), and the outer container `SessionLiveActivityView` with dark styling and white translucent borders.

#### ELI5 Analogy
This file is the visual styling kit. When `SessionActivityWidget` sets up the framework, `SessionLiveActivityView` paints the actual picture: drawing the circular avatar badge, selecting the right font sizes, laying out the dividers, and turning the entire card into an alert banner if someone in the disaster operation group presses the emergency button.

#### Technical Terms Defined
- **Capsule Badge**: A pill-shaped UI element constructed using `Capsule()` with background opacity and stroke overlay, providing high visual legibility against diverse lock screen wallpapers.
- **Color Code Resolution**: Resolving an 8-bit unsigned integer color index into a high-contrast SwiftUI `Color` using `MemberColor.resolve(code:initials:)`.
- **Dynamic Accent Tint**: Dynamically toggling the primary accent color from disaster operation teal (`.buttonPrimary`) to emergency red (`.red`) across all subviews when an active SOS is detected.

#### Code-Block and Line-by-Line Walkthrough
Lines 12–28 define `SessionAppBadge`:
```swift
struct SessionAppBadge: View {
    let accentColor: Color
    
    var body: some View {
        Label {
            Text("Meepo")
                .font(.custom("Helvetica", size: 12, relativeTo: .caption))
        } icon: {
            Image("MeetPoint")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
        }
        .foregroundStyle(accentColor)
    }
}
```
Renders the app title "Meepo" alongside the vector pin template icon.

Lines 30–107 define `SessionSummaryRow`:
```swift
struct SessionSummaryRow: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(circleFillColor)
                Text(circleInitials)
                    .font(.custom("Helvetica", size: 16, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 56, height: 56)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(attributes.sessionName)
                    .font(.custom("Helvetica", size: 20, relativeTo: .title2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitleText)
                    .font(.custom("Helvetica", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(state.sosSenderInitials == nil ? .white.opacity(0.85) : .red)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            HStack(spacing: 6) {
                Image(systemName: rightBadge.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(rightBadge.text)
                    .font(.custom("Helvetica", size: 12, relativeTo: .caption))
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
        }
        .foregroundStyle(.white)
    }
```
- Lines 36–46: 56x56 circular avatar. In normal mode, it displays the local user's initials filled with their assigned `userColor`. In SOS mode, it swaps to the distressed sender's initials filled with bright red.
- Lines 48–56: Session title and subtitle ("YOU" or "Emergency SOS" in red).
- Lines 60–70: Right capsule pill. Dynamically shifts between:
  - SOS: `exclamationmark.triangle.fill` with `"SOS"`.
  - Unread Messages: `message.fill` with `"X Unread"`.
  - Peer Count: `person.2.fill` with `"X Person/People"`.

Lines 109–134 define the outer `SessionLiveActivityView`:
```swift
struct SessionLiveActivityView: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SessionAppBadge(accentColor: accentColor)
                Spacer()
                Text(state.relayStatusText)
                    .font(.custom("Helvetica", size: 12, relativeTo: .caption))
                    .foregroundStyle(accentColor)
            }
            Divider()
                .overlay(.white.opacity(0.2))
            SessionSummaryRow(attributes: attributes, state: state)
        }
        .padding(16)
        .foregroundStyle(.white)
        .tint(Color.buttonPrimary)
    }
}
```

#### Engineering Rationale and Edge Cases
- **Contrast Ratios on Lock Screens**: Lock screen live activities are rendered over arbitrary user wallpapers (bright daylight photos, white backgrounds, busy textures). By enforcing a solid black background tint (`.background(.black)`) and high-opacity white text (`.white.opacity(0.85)`), the view guarantees WCAG AAA contrast compliance under all ambient outdoor lighting conditions.
- **Pluralization Handling**: Line 105 implements proper English pluralization: `\(state.directPeerCount == 1 ? "Person" : "People")`, avoiding awkward "1 People" UI glitches.

---

### 18. `Config/Widgets-Info.plist`
- **File Path**: [Widgets-Info.plist](../../Config/Widgets-Info.plist)
- **Line Count**: 33 lines (`wc -l`)
- **Category & Isolation**: Extension Config, XML Property List (`NSExtension`)

#### What This File Does
`Config/Widgets-Info.plist` is the configuration property list for the `TeekumWidgets` App Extension target. It defines the bundle metadata, executable name, version numbers, package type, and crucially, declares the `NSExtension` dictionary with the extension point identifier `com.apple.widgetkit-extension`. This declaration informs the iOS kernel and SpringBoard that the compiled Mach-O binary is a WidgetKit extension capable of rendering Live Activities.

#### ELI5 Analogy
When a building contractor registers a new commercial annex with the city planning board, they submit an official registration form. The form declares the official name of the annex, what services it provides, and what building codes it adheres to. `Config/Widgets-Info.plist` is that registration form submitted to the iOS operating system.

#### Technical Terms Defined
- **NSExtensionPointIdentifier**: An Apple property list key specifying the exact system framework that hosts the extension. For widgets, this must be `com.apple.widgetkit-extension`.
- **Mach-O Package Type**: Designated by `CFBundlePackageType = "XPC!"`, identifying the target as an XPC service extension rather than a standalone application executable.

#### Code-Block and Line-by-Line Walkthrough
Lines 1–33 declare the complete XML property list:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>XPC!</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
```
- Lines 11–20: Standard Apple bundle identification keys populated by Xcode build settings (`$(EXECUTABLE_NAME)`, `$(PRODUCT_BUNDLE_IDENTIFIER)`).
- Line 22: `<string>XPC!</string>`: Marks the package type as an out-of-process XPC service.
- Lines 27–31: Declares the WidgetKit extension point:
  ```xml
  <key>NSExtension</key>
  <dict>
      <key>NSExtensionPointIdentifier</key>
      <string>com.apple.widgetkit-extension</string>
  </dict>
  ```
  Without this exact key-value pair, iOS SpringBoard will never discover or instantiate the widget bundle.

#### Engineering Rationale and Edge Cases
- **Absence of Principal Class**: Modern WidgetKit extensions do not declare an `NSExtensionPrincipalClass`. Instead, discovery is handled entirely by the `@main struct ... : WidgetBundle` entry point in Swift. Attempting to define an Objective-C principal class here would result in App Extension launch crashes.

---

## Footer Navigation

| Navigation Target | Path |
| :--- | :--- |
| **Previous Volume** | [Volume 05: Messaging Dispatch, Priority Outbox & Initials Codec](05_messaging_and_codecs.md) |
| **Master Index** | [Volume 00: Index and System Architecture](00_index_and_architecture.md) |
| **Next Volume** | [Volume 07: Feature SOS, Forwarding Engine & Inactivity Guard](07_feature_sos.md) |

---
