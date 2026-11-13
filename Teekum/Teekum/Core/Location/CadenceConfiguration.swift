//
//  CadenceConfiguration.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
/// Configurable target intervals for the adaptive publishing engine.
///
/// Note: Target intervals represent requested scheduling intervals subject to iOS runloop,
/// system power management, and radio baseband scheduling.
nonisolated public struct CadenceConfiguration: Equatable, Sendable {
    /// Publishing interval while actively moving (recommended: 3–5 seconds).
    public var movingInterval: TimeInterval
    
    /// Publishing interval while stationary (recommended: 15–30 seconds).
    public var stationaryInterval: TimeInterval
    
    /// Accelerated publishing interval when one or more peers are distant or signal is weak (recommended: 2.0s).
    public var distantPeerInterval: TimeInterval
    
    /// Throttled publishing interval in survival mode (<20% battery).
    public var survivalInterval: TimeInterval
    
    /// Duration after which a location fix is marked stale for the UI.
    public var staleThreshold: TimeInterval
    
    /// Threshold after which a peer is considered stale (recommended: 30.0s).
    public var stalePeerThreshold: TimeInterval
    
    /// Accelerated publishing interval while probing for stale peers (recommended: 2.0s).
    public var staleRecoveryInterval: TimeInterval
    
    /// Additional staleness delay before triggering Stage 2 route discovery (recommended: 15.0s).
    public var staleRouteReqDelay: TimeInterval
    
    /// Maximum active recovery probe window duration before falling back to normal cadence (recommended: 60.0s).
    public var staleRecoveryTimeout: TimeInterval
    
    public init(
        movingInterval: TimeInterval = MeepoConfiguration.Timing.locationMovingInterval,
        stationaryInterval: TimeInterval = MeepoConfiguration.Timing.locationStationaryInterval,
        distantPeerInterval: TimeInterval = MeepoConfiguration.Timing.distantPeerInterval,
        survivalInterval: TimeInterval = MeepoConfiguration.Timing.survivalInterval,
        staleThreshold: TimeInterval = MeepoConfiguration.Timing.stalePeerThreshold,
        stalePeerThreshold: TimeInterval = MeepoConfiguration.Timing.stalePeerThreshold,
        staleRecoveryInterval: TimeInterval = 2.0,
        staleRouteReqDelay: TimeInterval = 15.0,
        staleRecoveryTimeout: TimeInterval = 60.0
    ) {
        self.movingInterval = movingInterval
        self.stationaryInterval = stationaryInterval
        self.distantPeerInterval = distantPeerInterval
        self.survivalInterval = survivalInterval
        self.staleThreshold = staleThreshold
        self.stalePeerThreshold = stalePeerThreshold
        self.staleRecoveryInterval = staleRecoveryInterval
        self.staleRouteReqDelay = staleRouteReqDelay
        self.staleRecoveryTimeout = staleRecoveryTimeout
    }
}
