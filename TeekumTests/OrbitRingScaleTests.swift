//
//  OrbitRingScaleTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 16/11/26.
//

import XCTest
@testable import Teekum

final class OrbitRingScaleTests: XCTestCase {
    func testInitialRingsMatchTheFiveMeterDesign() {
        let scale = OrbitRingScale(range: OrbitRingScale.defaultRange, radius: 300)
        XCTAssertEqual(scale.distances, [5, 10, 15])
        XCTAssertEqual(scale.interval, 5)
        XCTAssertEqual(scale.outerRadius, 300)
    }

    func testRingsExpandAndContractContinuouslyWithZoom() {
        let initial = OrbitRingScale(range: 15, radius: 300)
        let zoomedIn = OrbitRingScale(range: 12, radius: 300)
        let zoomedOut = OrbitRingScale(range: 18, radius: 300)
        XCTAssertEqual(initial.interval, zoomedIn.interval)
        XCTAssertEqual(initial.interval, zoomedOut.interval)
        XCTAssertGreaterThan(zoomedIn.radius(for: 5), initial.radius(for: 5))
        XCTAssertLessThan(zoomedOut.radius(for: 5), initial.radius(for: 5))
    }

    func testZoomingOutKeepsAtMostFourRings() {
        for range in [5.0, 10, 15, 15.01, 20, 20.01, 40, 60, 80, 120, 1_000] {
            let scale = OrbitRingScale(range: range, radius: 300)
            XCTAssertGreaterThan(scale.distances.count, 0)
            XCTAssertLessThanOrEqual(scale.distances.count, 4)
            XCTAssertGreaterThanOrEqual(scale.interval, 5)
            XCTAssertGreaterThanOrEqual(scale.outerDistance, range)
        }
        XCTAssertEqual(OrbitRingScale(range: 60, radius: 300).interval, 20)
        XCTAssertEqual(OrbitRingScale(range: 120, radius: 300).interval, 50)
    }

    func testMarkersUseTheSameMeterScaleAsTheRings() {
        let scale = OrbitRingScale(range: 18, radius: 300)
        for distance in scale.distances {
            let projection = OrbitProjection(distance: distance, bearing: 90, heading: 0,
                radius: scale.outerRadius, range: scale.outerDistance)
            XCTAssertEqual(projection.x, scale.radius(for: distance), accuracy: 0.000001)
        }
    }
}
