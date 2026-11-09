//
//  RouteReqHandlingResult.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public enum RouteReqHandlingResult: Sendable, Equatable {
    case answeredWithRResp(targetInitials: String, nextHop: String)
    case forwarded(nextHops: [String], hopCount: UInt8)
    case droppedLoopDetected
    case droppedDuplicate
    case droppedHopLimitExceeded
    case droppedSecurityFailed
    case droppedFloodingThrottled
}
