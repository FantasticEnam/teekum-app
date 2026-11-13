//
//  NeighborEntry.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation

/// Internal mutable state record for a tracked 1-hop physical neighbor.
public struct NeighborEntry {
    var info: NeighborInfo
    var packetsSent: Int = 0
    var packetsFailed: Int = 0
    var lastPacketSentAt: Date? = nil
    
    var packetLossRatio: Double {
        let total = packetsSent + packetsFailed
        guard total > 0 else { return 0.0 }
        return Double(packetsFailed) / Double(total)
    }
}
