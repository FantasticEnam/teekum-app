//
//  LocationServiceProtocol.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CoreLocation


/// Authoritative contract for the location, motion, and battery monitoring subsystem.
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
    
    /// Hard 20% cutoff battery detection (Festival Survival Mode).
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
    
    /// Time elapsed in seconds since the current location was measured by hardware GPS (nil if no fix acquired yet).
    var locationAge: TimeInterval? { get }
    
    /// Current target publishing interval in seconds based on movement, stationary state, and battery.
    var currentCadenceInterval: TimeInterval { get }
    
    /// Configurable cadence settings.
    var cadenceConfig: CadenceConfiguration { get set }
    
    /// Async stream yielding location pings ready for radio publishing.
    var publishedPings: AsyncStream<LocationPin> { get }
    
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
