//
//  OrbitProjection.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CoreLocation

struct OrbitProjection {
    let x: Double
    let y: Double
    let distance: CLLocationDistance
    let isClamped: Bool
    let isNearby: Bool

    init?(member: Member, nearby: NearbyOrbitPosition?, from location: LocationPin?, heading: Double,
          radius: Double, range: Double, at now: ContinuousClock.Instant) {
        if let measured = nearby?.projection(at: now, radius: radius, range: range) {
            self = measured
        } else if let location, let coordinate = member.coordinate {
            self.init(from: location, to: coordinate, heading: heading, radius: radius, range: range, overflowMargin: 20)
        } else {
            return nil
        }
    }

    init(from location: LocationPin, to coordinate: CLLocationCoordinate2D, heading: Double, radius: Double,
         range: Double = MeepoConfiguration.Navigation.tacticalRadarRangeMeters, overflowMargin: Double = 0) {
        self.init(distance: location.distance(to: coordinate), bearing: location.bearing(to: coordinate),
            heading: heading, radius: radius, range: range, overflowMargin: overflowMargin)
    }

    init(distance: Double, bearing: Double, heading: Double, radius: Double,
         range: Double = MeepoConfiguration.Navigation.tacticalRadarRangeMeters, overflowMargin: Double = 0,
         isNearby: Bool = false) {
        let angle = (bearing - heading) * .pi / 180
        let length = min(max(0, distance) * Self.screenPointsPerMeter(radius: radius, range: range), radius + overflowMargin)
        x = sin(angle) * length
        y = -cos(angle) * length
        self.distance = distance
        isClamped = distance > range
        self.isNearby = isNearby
    }

    static func screenPointsPerMeter(radius: Double, range: Double) -> Double {
        radius / range
    }
}
