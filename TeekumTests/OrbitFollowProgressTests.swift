//
//  OrbitFollowProgressTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

import XCTest
@testable import Teekum

final class OrbitFollowProgressTests: XCTestCase {
    func testApproachingAndMovingAwayKeepTheOriginalStartingDistance() {
        var progress = OrbitFollowProgress()
        progress.record(nil)
        progress.record(.nan)
        progress.record(10)
        XCTAssertEqual(progress.fraction(remaining: 10), 0)

        progress.record(5)
        XCTAssertEqual(progress.fraction(remaining: 5), 0.5)
        XCTAssertEqual(progress.fraction(remaining: 8), 0.2, accuracy: 0.001)
        XCTAssertEqual(progress.fraction(remaining: 14), 0)
        XCTAssertEqual(progress.fraction(remaining: 0), 1)
    }

    func testStartingAtTheSamePositionDoesNotDivideByZero() {
        var progress = OrbitFollowProgress()
        progress.record(0)
        XCTAssertEqual(progress.fraction(remaining: 0), 1)
        XCTAssertEqual(progress.fraction(remaining: 2), 0)
    }
}
