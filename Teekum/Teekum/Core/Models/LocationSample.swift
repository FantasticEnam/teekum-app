//
//  LocationSample.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CoreLocation

/// Coordinate, hardware measurement time and horizontal accuracy.
/// Never overwrite `timestamp` with packet receipt time.
public struct LocationSample: Equatable, Hashable, Codable, Sendable {
    public static let liveThresholdSeconds: TimeInterval = 30
    public static let staleThresholdSeconds: TimeInterval = 300

    public let latitude: CLLocationDegrees
    public let longitude: CLLocationDegrees

    /// Horizontal uncertainty radius in meters reported by CoreLocation.
    public let horizontalAccuracy: CLLocationAccuracy

    /// Original UTC timestamp when the GPS hardware measured this fix.
    public let timestamp: Date

    /// Optional magnetic compass heading in degrees (0..<360).
    public let heading: CLLocationDirection?

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(
        coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy,
        timestamp: Date = .now,
        heading: CLLocationDirection? = nil
    ) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
        self.heading = heading
    }

    public init(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        horizontalAccuracy: CLLocationAccuracy,
        timestamp: Date = .now,
        heading: CLLocationDirection? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
        self.heading = heading
    }

    /// Age in seconds relative to a reference date (defaults to `.now`).
    public func age(relativeTo referenceDate: Date = .now) -> TimeInterval {
        max(0, referenceDate.timeIntervalSince(timestamp))
    }

    /// Evaluates sample freshness honestly based on hardware measurement time.
    public func freshness(relativeTo referenceDate: Date = .now) -> LocationFreshness {
        guard horizontalAccuracy >= 0 else { return .unavailable }
        let sampleAge = age(relativeTo: referenceDate)
        if sampleAge <= Self.liveThresholdSeconds {
            return .live
        } else if sampleAge <= Self.staleThresholdSeconds {
            return .stale
        } else {
            return .expired
        }
    }

    /// Straight-line distance in meters to another coordinate.
    public func distance(to target: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: latitude, longitude: longitude)
        let toLocation = CLLocation(latitude: target.latitude, longitude: target.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// Forward azimuth bearing in degrees (0..<360) toward a target coordinate.
    public func bearing(to target: CLLocationCoordinate2D) -> Double {
        let lat1 = latitude * .pi / 180.0
        let lon1 = longitude * .pi / 180.0
        let lat2 = target.latitude * .pi / 180.0
        let lon2 = target.longitude * .pi / 180.0

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)

        let degrees = radiansBearing * 180.0 / .pi
        return (degrees + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
}
