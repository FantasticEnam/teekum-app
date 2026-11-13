//
//  LocationServiceProtocol+Configuration.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CoreLocation

extension LocationServiceProtocol {
    public var onHeadingUpdate: ((CLLocationDirection) -> Void)? {
        get { nil }
        set {}
    }
    public var isPreciseLocationAuthorized: Bool { true }
    public var isTacticalRadarActive: Bool { false }
    public func setTacticalRadarActive(_ active: Bool) {}
    public func resetPublishedPingsStream() {}
    public func triggerCadenceEvaluation() {}
    public func triggerBurstPings(count: Int, interval: TimeInterval) {}
}
