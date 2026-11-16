//
//  OrbitRulerScaleTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 16/11/26.
//

import XCTest
@testable import Teekum

final class OrbitRulerScaleTests: XCTestCase {
    func testRulerExtendsWhenZoomingInAndRetractsWhenZoomingOut() {
        let initial = OrbitRulerScale(pointsPerMeter: 4, maximumWidth: 120)
        let zoomedIn = OrbitRulerScale(pointsPerMeter: 5, maximumWidth: 120)
        let zoomedOut = OrbitRulerScale(pointsPerMeter: 3, maximumWidth: 120)

        XCTAssertEqual(initial.distance, 20)
        XCTAssertEqual(zoomedIn.distance, initial.distance)
        XCTAssertEqual(zoomedOut.distance, initial.distance)
        XCTAssertGreaterThan(zoomedIn.width, initial.width)
        XCTAssertLessThan(zoomedOut.width, initial.width)
    }

    func testDistanceStepsKeepTheRulerWithinItsAvailableWidth() {
        for (pointsPerMeter, expectedDistance) in [(2.0, 50.0), (3, 20), (8, 10), (16, 5), (32, 2)] {
            let scale = OrbitRulerScale(pointsPerMeter: pointsPerMeter, maximumWidth: 120)

            XCTAssertEqual(scale.distance, expectedDistance)
            XCTAssertEqual(scale.width / pointsPerMeter, scale.distance, accuracy: 0.000001)
            XCTAssertGreaterThan(scale.width, 0)
            XCTAssertLessThanOrEqual(scale.width, 120)
        }
    }
}
