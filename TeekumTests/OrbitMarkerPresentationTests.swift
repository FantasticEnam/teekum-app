//
//  OrbitMarkerPresentationTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 17/11/26.
//

import XCTest
@testable import Teekum

final class OrbitMarkerPresentationTests: XCTestCase {
    @MainActor
    func testBatteryIndicatorShowsOnlyTenPercentAndBelow() {
        XCTAssertEqual(OrbitBatteryIndicatorView.percentage(for: 0.1), "10%")
        XCTAssertEqual(OrbitBatteryIndicatorView.percentage(for: 0.05), "5%")
        XCTAssertEqual(OrbitBatteryIndicatorView.percentage(for: 0), "0%")
        XCTAssertNil(OrbitBatteryIndicatorView.percentage(for: 0.11))
        XCTAssertNil(OrbitBatteryIndicatorView.percentage(for: 0.2))
        XCTAssertNil(OrbitBatteryIndicatorView.percentage(for: nil))
        XCTAssertNil(OrbitBatteryIndicatorView.percentage(for: -1))
        XCTAssertNil(OrbitBatteryIndicatorView.percentage(for: .nan))
    }

    func testBloomBoundaryMatchesTheOuterRing() {
        let inside = OrbitProjection(distance: 59, bearing: 90, heading: 0,
            radius: 200, range: 60, overflowMargin: 20)
        let boundary = OrbitProjection(distance: 60, bearing: 90, heading: 0,
            radius: 200, range: 60, overflowMargin: 20)
        let outside = OrbitProjection(distance: 61, bearing: 90, heading: 0,
            radius: 200, range: 60, overflowMargin: 20)
        let distant = OrbitProjection(distance: 120, bearing: 90, heading: 0,
            radius: 200, range: 60, overflowMargin: 20)

        XCTAssertFalse(inside.isClamped)
        XCTAssertLessThan(inside.x, 200)
        XCTAssertFalse(boundary.isClamped)
        XCTAssertEqual(boundary.x, 200, accuracy: 0.000001)
        XCTAssertTrue(outside.isClamped)
        XCTAssertGreaterThan(outside.x, 200)
        XCTAssertTrue(distant.isClamped)
        XCTAssertEqual(distant.x, 220, accuracy: 0.000001)
        XCTAssertEqual(distant.distance, 120)
    }

    func testOverlapsRegroupAfterZoomingOutAndBackIn() throws {
        func groups(range: Double, heading: Double = 0) -> [OrbitMarkerGroup] {
            let scale = OrbitRingScale(range: range, radius: 294)
            let markers: [OrbitMarkerGroup.Marker] = [("DAF", 4.8), ("AYU", 1.3)].map { id, distance in
                let projection = OrbitProjection(distance: distance, bearing: 90, heading: heading,
                    radius: scale.outerRadius, range: scale.outerDistance)
                return (Member(id: id), projection)
            }
            return OrbitMarkerGroup.make(from: markers, overlapDistance: 36)
        }

        let start = groups(range: 10)
        XCTAssertEqual(start.map(\.id), ["AYU", "DAF"])
        let zoomedOut = try XCTUnwrap(groups(range: 38).first)
        XCTAssertEqual(zoomedOut.markers.map(\.member.id), ["AYU", "DAF"])
        XCTAssertEqual(zoomedOut.center.x, 3.05 * 294 / 38, accuracy: 0.000001)
        XCTAssertEqual(groups(range: 38, heading: 90).first?.markers.map(\.member.id), ["AYU", "DAF"])
        XCTAssertEqual(groups(range: 5).map(\.id), ["AYU", "DAF"])
        XCTAssertEqual(groups(range: 10).map(\.center), start.map(\.center))
    }

    func testBadgeFollowsTheSameBearingAcrossTheRadarCenterline() {
        func badgeOffset(heading: Double, distance: Double = 2) -> CGPoint {
            let projection = OrbitProjection(distance: distance, bearing: 0, heading: heading, radius: 100, range: 10)
            let group = OrbitMarkerGroup(id: "AYU", markers: [(Member(id: "AYU"), projection), (Member(id: "DAF"), projection)])
            return group.badgeOffset(clearingLocalMarkerBy: 40, above: 67)
        }

        let facingLeft = badgeOffset(heading: 1)
        let facingRight = badgeOffset(heading: 359)
        XCTAssertLessThan(facingLeft.x, 0)
        XCTAssertGreaterThan(facingRight.x, 0)
        XCTAssertEqual(facingLeft.y, facingRight.y, accuracy: 0.000001)
        XCTAssertLessThan(facingRight.x - facingLeft.x, 3)
        XCTAssertEqual(badgeOffset(heading: 0).y, -67, accuracy: 0.000001)
        XCTAssertEqual(badgeOffset(heading: 90).x, -40, accuracy: 0.000001)
        XCTAssertEqual(badgeOffset(heading: 0, distance: 8).y, -80, accuracy: 0.000001)
        XCTAssertEqual(badgeOffset(heading: 180, distance: 0), CGPoint(x: 0, y: 40))
    }

    func testChainOfOverlapsGroupsButClampedMarkersKeepTheirBloom() {
        let markers: [OrbitMarkerGroup.Marker] = [("ADI", 10.0), ("AYU", 40.0), ("NIC", 70.0), ("VAN", 105.0)]
            .map { id, distance in
                let projection = OrbitProjection(distance: distance, bearing: 90, heading: 0,
                    radius: 100, range: 100, overflowMargin: 20)
                return (Member(id: id), projection)
            }
        let groups = OrbitMarkerGroup.make(from: markers, overlapDistance: 44)

        XCTAssertEqual(groups.map(\.id), ["ADI", "VAN"])
        XCTAssertEqual(groups.map { $0.markers.count }, [3, 1])
        XCTAssertTrue(groups.last?.markers.first?.projection.isClamped == true)
    }

    func testOrbitUsesFreshNearbyDirectionWithoutGPSAndFallsBackWhenItExpires() throws {
        let now = ContinuousClock.now
        let member = Member(id: "AYU", coordinate: .init(latitude: 0, longitude: 0.0001))
        let pin = LocationPin(coordinate: .init(latitude: 0, longitude: 0), horizontalAccuracy: 12)
        let close = NearbyOrbitPosition(distance: 0.6, bearing: 90, measuredAt: now)
        let rangeOnly = NearbyOrbitPosition(distance: 0.6, bearing: nil, measuredAt: now)
        let direct = try XCTUnwrap(OrbitProjection(member: member, nearby: close, from: nil,
            heading: 180, radius: 150, range: 15, at: now))
        XCTAssertTrue(direct.isNearby)
        XCTAssertEqual(direct.distance, 0.6, accuracy: 0.000001)
        XCTAssertEqual(direct.x, 6, accuracy: 0.000001)
        XCTAssertNil(OrbitProjection(member: member, nearby: rangeOnly, from: nil,
            heading: 180, radius: 150, range: 15, at: now))
        let expired = try XCTUnwrap(OrbitProjection(member: member, nearby: close, from: pin,
            heading: 180, radius: 150, range: 15, at: now.advanced(by: .seconds(3))))
        XCTAssertFalse(expired.isNearby)
        XCTAssertGreaterThan(expired.distance, 10)
        XCTAssertLessThan(expired.x, 0)
    }
}
