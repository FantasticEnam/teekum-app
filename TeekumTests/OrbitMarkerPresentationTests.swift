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
}
