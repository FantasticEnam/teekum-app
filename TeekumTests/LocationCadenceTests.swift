//
//  LocationCadenceTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 17/11/26.
//

import XCTest
@testable import Teekum

final class LocationCadenceTests: XCTestCase {
    @MainActor
    func testLocationStreamKeepsTheNewestFixBeforeAndAfterSessionReset() async {
        let location = LocationService()
        let baseTime = Date(timeIntervalSince1970: 1_800_000_000)
        for session in 0..<2 {
            if session > 0 { location.resetPublishedPingsStream() }
            for sample in 0..<20 {
                location.simulateLocation(coordinate: .init(latitude: 0, longitude: Double(sample) / 100_000),
                    timestamp: baseTime.addingTimeInterval(Double(session * 100 + sample)))
                location.publishCurrentState()
            }
            var iterator = location.publishedPings.makeAsyncIterator()
            let next = await iterator.next()
            XCTAssertEqual(next?.timestamp, baseTime.addingTimeInterval(Double(session * 100 + 19)))
            XCTAssertEqual(next?.coordinate.longitude, 0.00019)
        }
    }

    @MainActor
    func testDefaultCadenceMatchesPrototypeAndPowerOverrides() {
        let location = LocationService()
        location.applyBatteryLevel(1)
        location.setStationaryState(false)
        XCTAssertEqual(location.currentCadenceInterval, 4)
        location.setStationaryState(true)
        XCTAssertEqual(location.currentCadenceInterval, 20)
        location.applyBatteryLevel(0.1)
        XCTAssertEqual(location.currentCadenceInterval, 60)
        location.applyBatteryLevel(1, isLowPower: true)
        XCTAssertEqual(location.currentCadenceInterval, 60)
    }

    @MainActor
    func testMotionStateChangeInterruptsStationaryWaitAndPublishesNewMeasurement() async {
        let location = LocationService()
        let firstTime = Date(timeIntervalSince1970: 1_800_000_000)
        let nextTime = firstTime.addingTimeInterval(4)
        location.simulateLocation(coordinate: .init(latitude: 0, longitude: 0), timestamp: firstTime)
        location.setStationaryState(true)
        location.isTracking = true
        defer { location.stopTracking() }
        let resumed = expectation(description: "Walking publishes the new GPS fix immediately")
        location.onPublishLocationPing = { pin in
            if pin.timestamp == nextTime { resumed.fulfill() }
        }
        location.startPublishingScheduler()

        location.simulateLocation(coordinate: .init(latitude: 0, longitude: 0.0001),
            timestamp: nextTime)
        location.setStationaryState(false)

        XCTAssertFalse(location.isStationary)
        XCTAssertEqual(location.currentCadenceInterval, 4)
        await fulfillment(of: [resumed], timeout: 1)
    }
}
