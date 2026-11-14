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

    init(from location: LocationPin, to coordinate: CLLocationCoordinate2D, heading: Double, radius: Double,
         range: Double = MeepoConfiguration.Navigation.tacticalRadarRangeMeters) {
        self.init(distance: location.distance(to: coordinate), bearing: location.bearing(to: coordinate),
            heading: heading, radius: radius, range: range)
    }

    init(distance: Double, bearing: Double, heading: Double, radius: Double,
         range: Double = MeepoConfiguration.Navigation.tacticalRadarRangeMeters) {
        let angle = (bearing - heading) * .pi / 180
        let length = min(max(0, distance) / range, 1) * radius
        x = sin(angle) * length
        y = -cos(angle) * length
        self.distance = distance
        isClamped = distance > range
    }
}
