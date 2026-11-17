//
//  OrbitRingScale.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 16/11/26.
//

import Foundation

struct OrbitRingScale {
    static let defaultRange = 15.0
    static let maximumRingCount = 4

    let interval: Double
    let distances: [Double]
    let pointsPerMeter: Double

    var outerDistance: Double { distances.last ?? interval }
    var outerRadius: Double { radius(for: outerDistance) }

    init(range: Double, radius: Double) {
        let minimumInterval = max(5, range / Double(Self.maximumRingCount))
        let magnitude = pow(10, floor(log10(minimumInterval)))
        let step = [1.0, 2, 5, 10].first { $0 * magnitude >= minimumInterval } ?? 10
        let interval = step * magnitude
        self.interval = interval
        let count = min(Self.maximumRingCount, max(1, Int(ceil(range / interval))))
        distances = (1...count).map { Double($0) * interval }
        pointsPerMeter = OrbitProjection.screenPointsPerMeter(radius: radius, range: range)
    }

    func radius(for distance: Double) -> Double {
        distance * pointsPerMeter
    }
}
