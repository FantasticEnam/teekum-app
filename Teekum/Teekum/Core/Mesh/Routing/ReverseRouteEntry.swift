//
//  ReverseRouteEntry.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

nonisolated public struct ReverseRouteEntry: Sendable, Equatable {
    public let discoveryKey: UInt32          // Discovery nonce or sequenceNumber
    public let incomingPeerId: String        // Node that forwarded the RREQ
    public let hopCount: UInt8               // Traversal hops observed
    public let expiresAt: Date               // Ephemeral TTL (typically 15s)
    
    public nonisolated init(
        discoveryKey: UInt32,
        incomingPeerId: String,
        hopCount: UInt8,
        expiresAt: Date
    ) {
        self.discoveryKey = discoveryKey
        self.incomingPeerId = incomingPeerId
        self.hopCount = hopCount
        self.expiresAt = expiresAt
    }
}
