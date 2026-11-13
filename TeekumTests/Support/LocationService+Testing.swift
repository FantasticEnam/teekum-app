//
//  LocationService+Testing.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CoreLocation
@testable import Teekum

// MARK: - Simulation & Testing Hooks

extension LocationService {
    /// Simulates a location update for deterministic unit testing.
    func simulateLocation(
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
}
