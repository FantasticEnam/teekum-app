//
//  LocationServiceTesting.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CoreLocation

// MARK: - Simulation & Testing Hooks

extension LocationService {
    
    /// Simulates a location update for deterministic unit testing.
    public func simulateLocation(
        coordinate: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy = 5.0,
        timestamp: Date? = nil,
        speed: CLLocationSpeed = -1.0
    ) {
        let ts = timestamp ?? dateProvider()
        let location = CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: accuracy,
            course: 0,
            speed: speed,
            timestamp: ts
        )
        applyLocationMeasurement(location)
    }
    
    /// Simulates heading update for deterministic testing.
    public func simulateHeading(_ heading: CLLocationDirection) {
        self.currentHeading = heading
        if let current = currentLocation {
            self.currentLocation = LocationPin(
                coordinate: current.coordinate,
                horizontalAccuracy: current.horizontalAccuracy,
                timestamp: current.timestamp,
                heading: heading
            )
        }
    }
    
    /// Simulates stationary motion state for testing adaptive cadence selection.
    public func simulateMotionActivity(stationary: Bool) {
        setStationaryState(stationary)
    }
    
    /// Simulates authorization status change for testing permission handling.
    public func simulateAuthorizationStatus(_ status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        switch status {
        #if os(iOS)
        case .authorizedWhenInUse, .authorizedAlways:
            self.isGPSAvailable = true
        #else
        case .authorizedAlways:
            self.isGPSAvailable = true
        #endif
        case .denied, .restricted:
            self.isGPSAvailable = false
        case .notDetermined:
            break
        @unknown default:
            self.isGPSAvailable = false
        }
    }
    
    /// Triggers an immediate publish for testing publisher logic synchronously.
    public func triggerImmediatePublish() {
        publishCurrentState()
    }
}
