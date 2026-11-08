//
//  PacketForwarder.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation
import CryptoKit

/// Thread-safe Ad-hoc Multi-Hop Mesh Packet Forwarder & Blind Relay Engine.
///
/// Implements Subsystem 3 of Phase 2 Multi-Hop Mesh Architecture:
/// - Enforces zero-knowledge blind relaying: intermediate phones forward opaque ciphertexts without group keys.
/// - Validates packet structure, version, and hop bounds before enqueuing (`PacketForwarder+Evaluation.swift`).
/// - Suppresses duplicate packets across hops via bounded 1,024-entry 5-minute LRU `SeenPacketCache`.
/// - Authenticates packets addressed to local group sessions with Poly1305 MAC tag and freshness filters.
/// - Enforces communal participation policies: opt-in requirement and hard 20% battery cutoff.
/// - Enforces rate limiting: 2 pkts/sec ordinary token bucket, 4 pkts/sec urgent SOS token bucket.
/// - Mutates only `hopCount` (Byte 2), preserving the sender's Poly1305 tag via AAD hop masking.
/// - Blind forwarding execution and flooding: `PacketForwarder+Dispatch.swift`.
/// - Supports injected `MeshClock` and actors for 100% deterministic test execution.
public actor PacketForwarder: PacketForwarding {
    
    // MARK: - Dependencies
    
    let routingTable: RoutingTableManaging
    let rateLimiter: ForwardingBudgetManaging
    let neighborTable: NeighborManaging
    let seenPacketCache: SeenPacketCache
    let clock: MeshClock
    let cryptoService: CryptoServiceProtocol?
    let sessionProvider: (@Sendable () -> GroupSession?)?
    let policyProvider: (@Sendable () -> RelayPolicyState)?
    let policyManager: RelayPolicyManaging?
    weak var transport: MeshTransport?
    
    // MARK: - Telemetry Counters
    
    var totalEvaluatedCount: Int = 0
    var totalLocallyDeliveredCount: Int = 0
    var totalForwardedCount: Int = 0
    var totalDroppedDuplicatesCount: Int = 0
    var totalDroppedHopLimitCount: Int = 0
    var totalDroppedRateLimitCount: Int = 0
    var totalDroppedPolicyCount: Int = 0
    var totalDroppedBatteryCount: Int = 0
    var totalDroppedMalformedCount: Int = 0
    var totalDroppedSecurityCount: Int = 0
    
    // MARK: - Initialization
    
    public init(
        routingTable: RoutingTableManaging,
        rateLimiter: ForwardingBudgetManaging,
        neighborTable: NeighborManaging,
        seenPacketCache: SeenPacketCache,
        clock: MeshClock = SystemMeshClock(),
        cryptoService: CryptoServiceProtocol? = nil,
        sessionProvider: (@Sendable () -> GroupSession?)? = nil,
        policyProvider: (@Sendable () -> RelayPolicyState)? = nil,
        policyManager: RelayPolicyManaging? = nil,
        transport: MeshTransport? = nil
    ) {
        self.routingTable = routingTable
        self.rateLimiter = rateLimiter
        self.neighborTable = neighborTable
        self.seenPacketCache = seenPacketCache
        self.clock = clock
        self.cryptoService = cryptoService
        self.sessionProvider = sessionProvider
        self.policyProvider = policyProvider
        self.policyManager = policyManager
        self.transport = transport
    }
    
    // MARK: - Telemetry & Diagnostic Snapshot
    
    public func telemetry() -> RelayTelemetry {
        RelayTelemetry(
            totalPacketsForwarded: totalForwardedCount,
            totalSOSForwarded: 0,
            packetsDroppedRateLimit: totalDroppedRateLimitCount,
            packetsDroppedHopLimit: totalDroppedHopLimitCount,
            duplicatePacketsSuppressed: totalDroppedDuplicatesCount,
            packetsDroppedPolicy: totalDroppedPolicyCount,
            packetsDroppedBattery: totalDroppedBatteryCount,
            activeRoutesCount: 0,
            activeNeighborsCount: 0,
            currentForwardingRatePerSec: 0.0,
            isFestivalSurvivalActive: false
        )
    }
}
