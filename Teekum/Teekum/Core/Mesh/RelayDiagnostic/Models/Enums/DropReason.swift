//
//  DropReason.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public enum DropReason: Sendable, Equatable {
    case duplicate
    case hopLimitExceeded
    case rateLimitExceeded
    case batteryThrottled
    case policyDisabled
    case queueSaturation
    case malformed
    case securityVerificationFailed
    case simulatedLoss
}
