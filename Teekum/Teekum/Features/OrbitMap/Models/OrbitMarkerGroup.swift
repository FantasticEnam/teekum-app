//
//  OrbitMarkerGroup.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 19/11/26.
//

import CoreGraphics

struct OrbitMarkerGroup: Identifiable {
    typealias Marker = (member: Member, projection: OrbitProjection)

    let id: Member.ID
    let markers: [Marker]

    var center: CGPoint {
        let count = Double(markers.count)
        return CGPoint(
            x: markers.reduce(0) { $0 + $1.projection.x } / count,
            y: markers.reduce(0) { $0 + $1.projection.y } / count
        )
    }

    func badgeOffset(clearingLocalMarkerBy clearance: CGFloat, above aboveClearance: CGFloat) -> CGPoint {
        let center = center
        let distance = hypot(center.x, center.y)
        // A group at the radar origin has no usable bearing.
        guard distance > 0.5 else { return CGPoint(x: 0, y: clearance) }
        let upward = max(0, -center.y / distance)
        let minimumDistance = clearance + max(0, aboveClearance - clearance) * upward * upward
        guard distance < minimumDistance else { return center }
        let scale = minimumDistance / distance
        return CGPoint(x: center.x * scale, y: center.y * scale)
    }

    static func make(from markers: [Marker], overlapDistance: CGFloat) -> [Self] {
        let sorted = markers.sorted { $0.member.id < $1.member.id }
        let nearby = sorted.filter { !$0.projection.isClamped }
        let overlapSquared = Double(overlapDistance * overlapDistance)
        var assigned: Set<Member.ID> = []
        var result: [Self] = []

        for marker in sorted where assigned.insert(marker.member.id).inserted {
            var group = [marker]
            if !marker.projection.isClamped {
                var index = 0
                while index < group.count {
                    let origin = group[index].projection
                    for candidate in nearby where !assigned.contains(candidate.member.id) {
                        let dx = candidate.projection.x - origin.x
                        let dy = candidate.projection.y - origin.y
                        if dx * dx + dy * dy < overlapSquared {
                            assigned.insert(candidate.member.id)
                            group.append(candidate)
                        }
                    }
                    index += 1
                }
            }
            result.append(Self(id: marker.member.id, markers: group))
        }
        return result
    }
}
