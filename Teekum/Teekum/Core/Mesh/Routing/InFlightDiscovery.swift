//
//  InFlightDiscovery.swift
//  Teekum
//
//  Created by Nicho on 07/11/26.
//

import Foundation

struct InFlightDiscovery {
    let targetInitials: String
    let sessionId: UInt32
    let discoveryNonce: UInt32
    let sequenceNumber: UInt32
    let startedAt: Date
    let timeoutDeadline: Date
    var continuations: [CheckedContinuation<RouteEntry, Error>]
}
