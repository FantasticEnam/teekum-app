//
//  OrbitRulerScale.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 16/11/26.
//

import Foundation

struct OrbitRulerScale {
    let distance: Double
    let width: Double

    init(pointsPerMeter: Double, maximumWidth: Double) {
        let maximumDistance = maximumWidth / pointsPerMeter
        let magnitude = pow(10, floor(log10(maximumDistance)))
        let step = [1.0, 2, 5].last { $0 * magnitude <= maximumDistance } ?? 1
        distance = step * magnitude
        width = distance * pointsPerMeter
    }
}
