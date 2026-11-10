//
//  LocationServicePublishing.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CoreLocation
#if canImport(CoreMotion)
import CoreMotion
#endif

// MARK: - Publishing Scheduler & Monotonic Location Validation

extension LocationService {
    
    // MARK: - Live Sharing Master Toggle (Acceptance Criteria 1 & 2)
    
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
    
    // MARK: - Publishing Scheduler Engine
    
    /// Starts the periodic publishing scheduler.
    /// Cancels any existing loop first to ensure duplicate timers or concurrent loops are never created.
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
    
    /// Cancels the publishing scheduler loop.
    func stopPublishingScheduler() {
        publishingTask?.cancel()
        publishingTask = nil
        burstTask?.cancel()
        burstTask = nil
    }
    
    /// Re-evaluates cadence immediately, restarting the scheduler loop with fresh cadence.
    public func triggerCadenceEvaluation() {
        guard isTracking, isLiveSharingEnabled else { return }
        startPublishingScheduler()
    }
    
    /// Publishes a rapid burst of fresh location pings to punch through intermediate mesh relays.
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
    
    /// Dispatches the latest useful location ping.
    /// If no valid location fix has been acquired yet, does not manufacture fake coordinates.
    public func publishCurrentState() {
        guard isLiveSharingEnabled else { return }
        guard let location = currentLocation else {
            // Do not manufacture new coordinates when GPS is unavailable
            return
        }
        
        onPublishLocationPing?(location)
        publishedPingsContinuation.yield(location)
    }
    
    // MARK: - Monotonic Location Updates & Validation (Acceptance Criteria 4)
    
    /// Evaluates and applies a location measurement.
    /// Enforces:
    /// 1. Positive horizontal accuracy (discards negative invalid fixes).
    /// 2. Monotonic timestamp ordering (older coordinates cannot overwrite newer measurements).
    /// 3. Preserves original measurement timestamp.
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
        
        // GPS speed fallback for motion detection if CoreMotion is unavailable
        #if os(iOS) && canImport(CoreMotion)
        if motionActivityManager == nil {
            evaluateGPSSpeedForStationary(location.speed)
        }
        #else
        evaluateGPSSpeedForStationary(location.speed)
        #endif
    }
    
    func evaluateGPSSpeedForStationary(_ speed: CLLocationSpeed) {
        if speed >= 0.8 {
            setStationaryState(false)
        } else if speed >= 0 && speed < 0.3 {
            setStationaryState(true)
        }
    }
}
