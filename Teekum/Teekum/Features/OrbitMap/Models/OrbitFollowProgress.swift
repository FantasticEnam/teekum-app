//
//  OrbitFollowProgress.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

struct OrbitFollowProgress {
    private var startingDistance: Double?

    mutating func record(_ distance: Double?) {
        guard startingDistance == nil, let distance, distance.isFinite, distance >= 0 else { return }
        startingDistance = distance
    }

    func fraction(remaining distance: Double) -> Double {
        guard distance.isFinite, distance >= 0 else { return 0 }
        if distance == 0 { return 1 }
        guard let startingDistance, startingDistance > 0 else { return 0 }
        return max(0, 1 - distance / startingDistance)
    }
}
