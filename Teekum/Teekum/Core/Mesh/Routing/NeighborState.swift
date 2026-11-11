//
//  NeighborState.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public enum NeighborState: Sendable, Equatable {
    case connecting
    case connected
    case degraded(packetLossRatio: Double)
    case stale
}
