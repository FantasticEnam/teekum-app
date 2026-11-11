//
//  RouteDiscoveryDiagnostics.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

nonisolated public struct RouteDiscoveryDiagnostics: Sendable, Equatable {
    public let activeInFlightDiscoveries: Int
    public let totalDiscoveriesInitiated: Int
    public let totalDiscoveriesSucceeded: Int
    public let totalDiscoveriesFailed: Int
    public let totalRReqSent: Int
    public let totalRReqReceived: Int
    public let totalRRespSent: Int
    public let totalRRespReceived: Int
    public let totalRoutesInvalidated: Int
    public let activeRoutesCount: Int
    
    public init(
        activeInFlightDiscoveries: Int = 0,
        totalDiscoveriesInitiated: Int = 0,
        totalDiscoveriesSucceeded: Int = 0,
        totalDiscoveriesFailed: Int = 0,
        totalRReqSent: Int = 0,
        totalRReqReceived: Int = 0,
        totalRRespSent: Int = 0,
        totalRRespReceived: Int = 0,
        totalRoutesInvalidated: Int = 0,
        activeRoutesCount: Int = 0
    ) {
        self.activeInFlightDiscoveries = activeInFlightDiscoveries
        self.totalDiscoveriesInitiated = totalDiscoveriesInitiated
        self.totalDiscoveriesSucceeded = totalDiscoveriesSucceeded
        self.totalDiscoveriesFailed = totalDiscoveriesFailed
        self.totalRReqSent = totalRReqSent
        self.totalRReqReceived = totalRReqReceived
        self.totalRRespSent = totalRRespSent
        self.totalRRespReceived = totalRRespReceived
        self.totalRoutesInvalidated = totalRoutesInvalidated
        self.activeRoutesCount = activeRoutesCount
    }
}
