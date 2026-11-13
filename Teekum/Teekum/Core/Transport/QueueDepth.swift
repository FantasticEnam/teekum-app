//
//  QueueDepth.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Instantaneous queue depth across priority lanes.
nonisolated public struct QueueDepth: Sendable, Equatable {
    public let urgentCount: Int
    public let normalCount: Int
    public let relayCount: Int
    public let chatCount: Int
    
    public var total: Int { urgentCount + normalCount + relayCount + chatCount }
    
    public nonisolated init(
        urgentCount: Int = 0,
        normalCount: Int = 0,
        relayCount: Int = 0,
        chatCount: Int = 0
    ) {
        self.urgentCount = urgentCount
        self.normalCount = normalCount
        self.relayCount = relayCount
        self.chatCount = chatCount
    }
}
