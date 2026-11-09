//
//  RouteDiscoveryService.swift
//  Teekum
//
//  Created by Nicho on 07/11/26.
//

import Foundation
import CryptoKit

/// Thread-safe Ad-hoc On-Demand Distance Vector (AODV) Route Discovery Engine.
///
/// Implements Subsystem 2 Route Discovery for Phase 2 Multi-Hop Mesh Architecture:
/// - On-demand discovery of multi-hop paths between group members (`ROUTE_REQ` / `ROUTE_RESP`).
/// - Deduplicates route requests using `(originatorInitials, discoveryNonce)` and sequence identifiers.
/// - Rejects stale route responses, detects routing loops, and caps maximum hop count at 8.
/// - Bounded flooding with token bucket rate limiter (2 pkts/sec) and per-target cooldown to prevent broadcast storms.
/// - Re-discovers routes when intermediate next hops disconnect (`RouteDiscoveryService+Maintenance.swift`).
/// - Multi-group isolation: destinations and reverse routes are scoped to group sessions.
/// - Inbound packet validation and cryptographic verification (`RouteDiscoveryService+Inbound.swift`).
/// - On-demand route resolution and timeout handling (`RouteDiscoveryService+Initiation.swift`).
/// - 100% testable with injected `MeshClock` and actors.
public actor RouteDiscoveryService: RouteDiscoveryManaging {
    
    // MARK: - Dependencies & Configuration
    
    let routingTable: RoutingTableManaging
    let neighborTable: NeighborManaging
    let transport: MeshTransport
    let cryptoService: CryptoServiceProtocol
    let clock: MeshClock
    let maxHops: UInt8
    let maxInFlightCapacity: Int
    
    // MARK: - Token Bucket Rate Limiter
    
    let tokenCapacity: Double = 4.0
    let refillRatePerSec: Double = 2.0
    var tokens: Double = 4.0
    var lastRefillTime: Date
    
    // MARK: - Discovery State
    
    /// Map of discoveryNonce -> in-flight discovery
    var inFlightDiscoveries: [UInt32: InFlightDiscovery] = [:]
    
    /// Index of "sessionId:targetInitials" -> discoveryNonce for coalescing
    var inFlightByTarget: [String: UInt32] = [:]
    
    /// Last RREQ sent timestamp per "sessionId:targetInitials" for cooldown
    var targetCooldowns: [String: Date] = [:]
    
    /// Bounded LRU cache of seen (originatorInitials, discoveryNonce) -> SeenRREQEntry
    var seenRREQs: [String: SeenRREQEntry] = [:]
    let maxSeenRREQCapacity: Int = 128
    let seenRREQTtl: TimeInterval = 30.0
    
    /// Monotonic sequence counter per session
    var sequenceCounters: [UInt32: UInt32] = [:]
    
    // MARK: - Telemetry & Diagnostics Counters
    
    var totalDiscoveriesInitiatedCount: Int = 0
    var totalDiscoveriesSucceededCount: Int = 0
    var totalDiscoveriesFailedCount: Int = 0
    var totalRReqSentCount: Int = 0
    var totalRReqReceivedCount: Int = 0
    var totalRRespSentCount: Int = 0
    var totalRRespReceivedCount: Int = 0
    var totalRoutesInvalidatedCount: Int = 0
    
    /// Callback invoked when an inbound route request reaches the local device as destination.
    /// Used to trigger an immediate location response burst in one-to-many topologies.
    public var onTargetReached: (@Sendable (String) -> Void)?
    
    // MARK: - Initialization
    
    public init(
        routingTable: RoutingTableManaging,
        neighborTable: NeighborManaging,
        transport: MeshTransport,
        cryptoService: CryptoServiceProtocol,
        clock: MeshClock = SystemMeshClock(),
        maxHops: UInt8 = PacketConstants.defaultHopLimit,
        maxInFlightCapacity: Int = 16,
        onTargetReached: (@Sendable (String) -> Void)? = nil
    ) {
        self.routingTable = routingTable
        self.neighborTable = neighborTable
        self.transport = transport
        self.cryptoService = cryptoService
        self.clock = clock
        self.maxHops = min(maxHops, PacketConstants.defaultHopLimit)
        self.maxInFlightCapacity = max(1, maxInFlightCapacity)
        self.lastRefillTime = clock.now()
        self.onTargetReached = onTargetReached
    }
    
    public func setOnTargetReached(_ handler: (@Sendable (String) -> Void)?) {
        self.onTargetReached = handler
    }
    
    // MARK: - Helpers & Rate Limiting
    
    /// Public helper for testing token bucket rate limiter deterministically.
    @discardableResult
    public func consumeFloodingToken() -> Bool {
        consumeToken()
    }
    
    func nextSequenceNumber(for session: GroupSession) -> UInt32 {
        let sid = UInt32(session.sessionId)
        let counter = (sequenceCounters[sid] ?? 0) &+ 1
        sequenceCounters[sid] = counter
        return CleartextEnvelope.makeSequenceNumber(memberSlot: 1, counter: counter)
    }
    
    func consumeToken() -> Bool {
        let now = clock.now()
        let elapsed = max(0.0, now.timeIntervalSince(lastRefillTime))
        tokens = min(tokenCapacity, tokens + (elapsed * refillRatePerSec))
        lastRefillTime = now
        
        if tokens >= 1.0 {
            tokens -= 1.0
            return true
        }
        return false
    }
    
    func pruneExpiredSeenRREQs(now: Date) {
        seenRREQs = seenRREQs.filter { now.timeIntervalSince($0.value.recordedAt) < seenRREQTtl }
    }
}
