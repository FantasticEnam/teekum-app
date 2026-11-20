//
//  NearbyOrbitPosition.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

import Foundation

struct NearbyOrbitPosition {
    let distance: Double
    let bearing: Double?
    let measuredAt: ContinuousClock.Instant

    func isFresh(at now: ContinuousClock.Instant) -> Bool {
        now >= measuredAt && measuredAt.duration(to: now) <= .seconds(2)
    }

    func projection(at now: ContinuousClock.Instant, radius: Double, range: Double) -> OrbitProjection? {
        guard let bearing, isFresh(at: now) else { return nil }
        return OrbitProjection(distance: distance, bearing: bearing, heading: 0, radius: radius,
            range: range, overflowMargin: 20, isNearby: true)
    }
}
