//
//  RelayTelemetry.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public struct RelayTelemetry: Sendable, Equatable {
    public let totalPacketsForwarded: Int
    public let totalSOSForwarded: Int
    public let packetsDroppedRateLimit: Int
    public let packetsDroppedHopLimit: Int
    public let duplicatePacketsSuppressed: Int
    public let packetsDroppedPolicy: Int
    public let packetsDroppedBattery: Int
    public let activeRoutesCount: Int
    public let activeNeighborsCount: Int
    public let currentForwardingRatePerSec: Double
    public let isFestivalSurvivalActive: Bool
    
    public init(
        totalPacketsForwarded: Int = 0,
        totalSOSForwarded: Int = 0,
        packetsDroppedRateLimit: Int = 0,
        packetsDroppedHopLimit: Int = 0,
        duplicatePacketsSuppressed: Int = 0,
        packetsDroppedPolicy: Int = 0,
        packetsDroppedBattery: Int = 0,
        activeRoutesCount: Int = 0,
        activeNeighborsCount: Int = 0,
        currentForwardingRatePerSec: Double = 0.0,
        isFestivalSurvivalActive: Bool = false
    ) {
        self.totalPacketsForwarded = totalPacketsForwarded
        self.totalSOSForwarded = totalSOSForwarded
        self.packetsDroppedRateLimit = packetsDroppedRateLimit
        self.packetsDroppedHopLimit = packetsDroppedHopLimit
        self.duplicatePacketsSuppressed = duplicatePacketsSuppressed
        self.packetsDroppedPolicy = packetsDroppedPolicy
        self.packetsDroppedBattery = packetsDroppedBattery
        self.activeRoutesCount = activeRoutesCount
        self.activeNeighborsCount = activeNeighborsCount
        self.currentForwardingRatePerSec = currentForwardingRatePerSec
        self.isFestivalSurvivalActive = isFestivalSurvivalActive
    }
}
