//
//  LocationService.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CoreLocation
#if canImport(CoreMotion)
import CoreMotion
#endif
#if canImport(UIKit)
import UIKit
#endif
import Observation

/// Authoritative Core Location & Core Motion service managing:
/// 1. Local location state (latest coordinate, accuracy, measurement timestamp).
/// 2. Motion-aware adaptive publishing cadence (3–5s moving, 15–30s stationary) (`LocationService+Publishing.swift`).
/// 3. Status coalescing into the next regular location update (no separate status packets).
/// 4. Live Sharing master toggle (stops broadcasting when disabled).
/// 5. Stale coordinate detection, GPS availability, and explicit permission state for the UI (`LocationService+Lifecycle.swift`).
/// 6. Independent immediate location access for emergency SOS dispatch.
/// 7. Core Location delegate ingestion (`LocationService+Delegate.swift`), adaptive hardware/battery tuning
///    (`LocationService+AdaptiveHardware.swift`), and deterministic simulation hooks (`LocationService+Testing.swift`).
///
/// Note on Platform Behavior:
/// Target intervals represent requested scheduling cadences subject to iOS runloop,
/// system power management, and radio baseband scheduling. Stationary intervals reduce
/// GPS and radio duty cycles without making rigid power or battery percentage guarantees.
@Observable
@MainActor
public final class LocationService: NSObject, CLLocationManagerDelegate, LocationServiceProvider {
    
    // MARK: - Core Location & Motion Hardware
    
    let locationManager: CLLocationManager
    #if os(iOS) && canImport(CoreMotion)
    let motionActivityManager: CMMotionActivityManager?
    let motionQueue = OperationQueue()
    #endif
    
    /// Injectable date provider for deterministic time-based testing.
    let dateProvider: @Sendable () -> Date
    
    // MARK: - State Properties
    
    /// Latest measured local coordinate, uncertainty accuracy radius, and measurement timestamp.
    public internal(set) var currentLocation: LocationPin?
    
    /// Latest magnetic compass heading in degrees (0..<360).
    public internal(set) var currentHeading: CLLocationDirection?
    
    /// Optional high-frequency callback invoked whenever a hardware compass heading fix is received.
    public var onHeadingUpdate: ((CLLocationDirection) -> Void)?
    
    /// Motion state (`true` if user is stationary/resting; `false` if walking/moving).
    public internal(set) var isStationary: Bool = false
    
    /// True when one or more peers are distant or signal is weak.
    public var hasDistantPeers: Bool = false
    
    /// Dynamic provider closure to evaluate whether any peers are distant.
    public var hasDistantPeersProvider: (@MainActor @Sendable () -> Bool)? = nil
    
    /// True when one or more peers are stale and within the active recovery window.
    public var hasStalePeers: Bool = false
    
    /// Dynamic provider closure to evaluate whether any peers are stale and within the active recovery window.
    public var hasStalePeersProvider: (@MainActor @Sendable () -> Bool)? = nil
    
    /// Master toggle governing whether coordinates are broadcast to the group.
    public var isLiveSharingEnabled: Bool {
        didSet {
            handleLiveSharingToggleChanged()
        }
    }
    
    /// True when device battery is <20% or in Low Power Mode (Festival Survival Mode).
    public internal(set) var isSurvivalModeActive: Bool = false
    
    /// True when device is in iOS Low Power Mode.
    public internal(set) var isLowPowerMode: Bool = false
    
    /// Current device battery percentage (0.0 ... 1.0).
    public internal(set) var currentBatteryLevel: Float = 1.0
    
    // MARK: - Dynamic Adaptive Accuracy (Option B)
    
    /// Tracks whether the user is actively viewing the Tactical Radar or navigating.
    public internal(set) var isTacticalRadarActive: Bool = false
    
    /// True if Core Location accuracy authorization is .fullAccuracy (Precise Location ON).
    public var isPreciseLocationAuthorized: Bool {
        #if os(iOS)
        return locationManager.accuracyAuthorization == .fullAccuracy
        #else
        return true
        #endif
    }
    
    /// Current CoreLocation desiredAccuracy value configured on the hardware manager.
    public var currentDesiredAccuracy: CLLocationAccuracy {
        locationManager.desiredAccuracy
    }
    
    /// Current CoreLocation distanceFilter value configured on the hardware manager.
    public var currentDistanceFilter: CLLocationDistance {
        locationManager.distanceFilter
    }
    
    /// Current CoreLocation headingFilter value configured on the hardware manager.
    public var currentHeadingFilter: CLLocationDegrees {
        #if os(iOS)
        return locationManager.headingFilter
        #else
        return 1.0
        #endif
    }
    
    /// Current Core Location authorization status.
    public internal(set) var authorizationStatus: CLAuthorizationStatus
    
    /// True if GPS hardware is functioning, authorized, and actively providing valid fixes.
    public internal(set) var isGPSAvailable: Bool = false
    
    /// Configurable cadence settings (moving, stationary, survival, stale threshold).
    public var cadenceConfig: CadenceConfiguration
    
    /// True if location updates and motion monitoring are currently running.
    public internal(set) var isTracking: Bool = false
    
    // MARK: - Single Cancellable Scheduler Loop
    
    /// Active publishing scheduler task. Strictly one task runs at a time.
    var publishingTask: Task<Void, Never>?
    
    /// Active response burst task.
    var burstTask: Task<Void, Never>?
    
    /// Continuation for async permission requests.
    var permissionContinuation: CheckedContinuation<Bool, Never>?
    
    // MARK: - Publication Callbacks & Streams
    
    /// Direct closure callback invoked when a location ping is ready to publish.
    public var onPublishLocationPing: ((LocationPin) -> Void)?
    
    /// Async stream yielding location pings for reactive consumers.
    public internal(set) var publishedPings: AsyncStream<LocationPin>
    var publishedPingsContinuation: AsyncStream<LocationPin>.Continuation!
    
    // MARK: - Initialization
    
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
        
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerOrBatteryChange),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerOrBatteryChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerOrBatteryChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        #endif
        
        updateBatteryState()
    }
    
    deinit {
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self)
        #endif
    }
    
    // MARK: - Computed Properties for UI
    
    /// Seconds elapsed since the current location was measured by hardware GPS (nil if no fix acquired).
    public var locationAge: TimeInterval? {
        guard let loc = currentLocation else { return nil }
        return max(0, dateProvider().timeIntervalSince(loc.timestamp))
    }
    
    /// True if the current location fix is older than the staleness threshold.
    public var isLocationStale: Bool {
        guard let age = locationAge else { return true }
        return age > cadenceConfig.staleThreshold
    }
    
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
    
    // MARK: - Emergency SOS Location Access (Acceptance Criteria 6)
    
    /// Retrieves the latest available location immediately for emergency SOS dispatch.
    /// Does not wait for a fresh GPS fix or a normal ping interval, and operates
    /// unconditionally even when Live Sharing is disabled.
    /// Preserves the exact hardware measurement timestamp without modification.
    public func getLatestLocationForSOS() -> LocationPin? {
        return currentLocation
    }
}
