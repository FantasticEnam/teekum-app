//
//  LocationService+Lifecycle.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CoreLocation

// MARK: - Permissions & Tracking Lifecycle

extension LocationService {
    
    /// Requests standard iOS CoreLocation permissions with explicit handling of denied/restricted states.
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
    
    /// Recreates the publishedPings stream and continuation to recover from task cancellation across sessions.
    public func resetPublishedPingsStream() {
        var streamContinuation: AsyncStream<LocationPin>.Continuation!
        self.publishedPings = AsyncStream { streamContinuation = $0 }
        self.publishedPingsContinuation = streamContinuation
    }
    
    /// Starts adaptive GPS sampling, CoreMotion activity tracking, and publishing scheduler.
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
            // Request and start
            locationManager.requestWhenInUseAuthorization()
        #if os(iOS)
        case .authorizedWhenInUse, .authorizedAlways:
            break
        #else
        case .authorizedAlways:
            break
        #endif
        @unknown default:
            break
        }
        
        isTracking = true
        #if os(iOS)
        isGPSAvailable = (status == .authorizedWhenInUse || status == .authorizedAlways)
        #else
        isGPSAvailable = (status == .authorizedAlways)
        #endif
        
        locationManager.startUpdatingLocation()
        
        #if os(iOS)
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        #endif
        
        startMotionTracking()
        updateBatteryState()
        applyDynamicAccuracy()
        
        if isLiveSharingEnabled {
            startPublishingScheduler()
        }
    }
    
    /// Pauses GPS receiver and stops compass and motion monitoring to conserve battery.
    /// Preserves the last known valid coordinate in memory so SOS and UI can continue to read it.
    public func stopTracking() {
        isTracking = false
        stopPublishingScheduler()
        
        locationManager.stopUpdatingLocation()
        #if os(iOS)
        locationManager.stopUpdatingHeading()
        #endif
        
        stopMotionTracking()
    }

    public func clearSessionMeasurements() {
        stopTracking()
        currentLocation = nil
        currentHeading = nil
        isGPSAvailable = false
        onHeadingUpdate = nil
        hasDistantPeers = false
        hasStalePeers = false
        hasDistantPeersProvider = nil
        hasStalePeersProvider = nil
        isTacticalRadarActive = false
        permissionContinuation?.resume(returning: false)
        permissionContinuation = nil
    }
}
