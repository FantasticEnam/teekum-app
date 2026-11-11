//
//  LocationService+AdaptiveHardware.swift
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

// MARK: - Motion, Dynamic Accuracy & Battery Survival Control

extension LocationService {
    
    // MARK: - Motion Monitoring
    
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
    
    func stopMotionTracking() {
        #if os(iOS) && canImport(CoreMotion)
        motionActivityManager?.stopActivityUpdates()
        #endif
    }
    
    func setStationaryState(_ stationary: Bool) {
        guard isStationary != stationary else { return }
        self.isStationary = stationary
        applyDynamicAccuracy()
        
        // When motion state changes, restart scheduler to adopt new cadence immediately
        if isTracking && isLiveSharingEnabled {
            startPublishingScheduler()
        }
    }
    
    // MARK: - Tactical Radar & Dynamic Accuracy Control
    
    /// Enables or disables high-precision navigation mode for the tactical radar.
    public func setTacticalRadarActive(_ active: Bool) {
        guard isTacticalRadarActive != active else { return }
        self.isTacticalRadarActive = active
        applyDynamicAccuracy()
    }
    
    /// Dynamically tunes Core Location desiredAccuracy, distanceFilter, and headingFilter:
    /// - Tactical Radar active -> kCLLocationAccuracyBestForNavigation + 0° heading filter (Dual-frequency L1/L5 GPS).
    /// - Festival Survival Mode (<20% battery) -> kCLLocationAccuracyHundredMeters + 25m distanceFilter.
    /// - Stationary (standing/dancing at stage) -> kCLLocationAccuracyHundredMeters + 15m distanceFilter.
    /// - Moving (walking between stages) -> kCLLocationAccuracyBest + 1° headingFilter.
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
    
    // MARK: - Battery & Survival Mode Monitoring
    
    @objc nonisolated func handlePowerOrBatteryChange() {
        Task { @MainActor [weak self] in
            self?.updateBatteryState()
        }
    }
    
    public func updateBatteryState() {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let rawLevel = UIDevice.current.batteryLevel
        // UIDevice returns -1.0 if monitoring is unsupported (e.g. simulator)
        let battery = rawLevel >= 0 ? rawLevel : 1.0
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        let battery: Float = 1.0
        let isLowPower = false
        #endif
        
        applyBatteryLevel(battery, isLowPower: isLowPower)
    }
    
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
}
