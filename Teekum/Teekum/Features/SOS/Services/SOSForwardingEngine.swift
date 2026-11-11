//
//  SOSForwardingEngine.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CoreLocation
import CryptoKit

/// Authoritative Actor implementing Subsystem 5 of TeeKum Phase 2 Multi-Hop Mesh:
/// Emergency SOS Dispatch, Multi-Hop Forwarding, Authenticated Ingestion,
/// Route Preference, Bounded Flooding Fallback, and Multi-Hop Return ACK Routing.
///
/// Master Specification Guarantees:
/// 1. Emergency Priority: SOS packets bypass normal location ping cycles and coalescing (`SOSForwardingEngine+Outbound.swift`).
/// 2. Route Preference: Prefers known unexpired routes in `RoutingTable`; falls back to bounded flooding when none exist.
/// 3. Zero-Knowledge Safe Relaying: Relays forward without group keys; Poly1305 MAC tag is preserved across hops via AAD masking.
/// 4. Cryptographic Authentication: Only valid group keys and fresh timestamps trigger trusted sirens and alerts (`SOSForwardingEngine+Inbound.swift`).
/// 5. Return ACK Routing: Recipient group friends route authenticated Poly1305 ACKs back to sender via known route or bounded flooding (`SOSForwardingEngine+ACK.swift`).
/// 6. Honest Delivery States: Strictly distinguishes local sending, intermediary relay hops (`RELAY_ACK`), and cryptographic friend delivery (`DELIVERED_TO_FRIEND`).
/// 7. Duplicate Suppression: Received `sosEventId` values are deduplicated to prevent repeated audible sirens or alert flooding.
/// 8. Bounded Retries: Exactly 3 retransmissions before marking confirmation timeout / searching peers (`SOSForwardingEngine+Retries.swift`).
public actor SOSForwardingEngine: SOSForwardingManaging {
    
    // MARK: - Dependencies
    
    let transport: MeshTransport
    let cryptoService: CryptoServiceProtocol
    let routingTable: RoutingTableManaging?
    let neighborTable: NeighborManaging?
    let rateLimiter: ForwardingBudgetManaging?
    let clock: MeshClock
    let sequenceAllocator: PacketSequenceAllocator?
    let sessionProvider: (@Sendable () -> GroupSession?)?
    let audioAlerter: SOSAudioAlerting?
    
    // MARK: - Active Outbound SOS State
    
    public internal(set) var activeSOSEventId: UInt32?
    public internal(set) var currentDeliveryState: SOSDeliveryState = .idle
    public internal(set) var currentRouteChoice: RouteChoice = .none
    public internal(set) var retryCount: Int = 0
    public let maxRetries: Int = 3
    public var retryInterval: TimeInterval = 1.5
    
    // MARK: - Ingestion & Duplicate Suppression
    
    public internal(set) var seenSOSEventIds: Set<UInt32> = []
    public internal(set) var activeIncomingAlert: IncomingSOSAlert?
    public internal(set) var isSirenActive: Bool = false
    
    // MARK: - Evidence & Diagnostics
    
    public internal(set) var lastDeliveredFriendId: String?
    public internal(set) var lastDeliveredTimestamp: Date?
    public internal(set) var lastDeliveredHopCount: UInt8?
    public internal(set) var lastRelayHopCount: UInt8?
    public internal(set) var lastRelayResponderId: String?
    
    public internal(set) var monotonicCounter: UInt32 = 1
    public internal(set) var totalDispatchedCount: Int = 0
    public internal(set) var totalReceivedCount: Int = 0
    public internal(set) var totalDuplicatesSuppressedCount: Int = 0
    public internal(set) var totalAcksSentCount: Int = 0
    public internal(set) var totalAcksReceivedCount: Int = 0
    
    // Internal tasks
    var retryTask: Task<Void, Never>?
    var lastDispatchedPayload: SOSPayload?
    var sessionGeneration = UUID()
    var outgoingGeneration = UUID()
    var measurementProvider: (@MainActor @Sendable () -> (LocationPin?, Float))?
    
    // MARK: - State Change Handlers
    
    var onDeliveryStateChanged: (@Sendable (SOSDeliveryState) -> Void)?
    var onIncomingAlertTriggered: (@Sendable (IncomingSOSAlert) -> Void)?
    
    // MARK: - Initialization
    
    public init(
        transport: MeshTransport,
        cryptoService: CryptoServiceProtocol,
        routingTable: RoutingTableManaging? = nil,
        neighborTable: NeighborManaging? = nil,
        rateLimiter: ForwardingBudgetManaging? = nil,
        clock: MeshClock = SystemMeshClock(),
        sequenceAllocator: PacketSequenceAllocator? = nil,
        sessionProvider: (@Sendable () -> GroupSession?)? = nil,
        audioAlerter: SOSAudioAlerting? = nil,
        onDeliveryStateChanged: (@Sendable (SOSDeliveryState) -> Void)? = nil,
        onIncomingAlertTriggered: (@Sendable (IncomingSOSAlert) -> Void)? = nil
    ) {
        self.transport = transport
        self.cryptoService = cryptoService
        self.routingTable = routingTable
        self.neighborTable = neighborTable
        self.rateLimiter = rateLimiter
        self.clock = clock
        self.sequenceAllocator = sequenceAllocator
        self.sessionProvider = sessionProvider
        self.audioAlerter = audioAlerter
        self.onDeliveryStateChanged = onDeliveryStateChanged
        self.onIncomingAlertTriggered = onIncomingAlertTriggered
    }
    
    public func setCallbacks(
        onDeliveryStateChanged: (@Sendable (SOSDeliveryState) -> Void)? = nil,
        onIncomingAlertTriggered: (@Sendable (IncomingSOSAlert) -> Void)? = nil
    ) {
        self.onDeliveryStateChanged = onDeliveryStateChanged
        self.onIncomingAlertTriggered = onIncomingAlertTriggered
    }

    public func setMeasurementProvider(_ provider: (@MainActor @Sendable () -> (LocationPin?, Float))?) {
        measurementProvider = provider
    }
    
    func nextSequenceNumber(for session: GroupSession) async throws -> UInt32 {
        if let sequenceAllocator { return try await sequenceAllocator.next(for: session) }
        let sequence = CleartextEnvelope.makeSequenceNumber(memberSlot: session.memberSlot, counter: monotonicCounter)
        monotonicCounter &+= 1
        return sequence
    }

    // MARK: - State Management & Diagnostics
    
    func updateDeliveryState(_ newState: SOSDeliveryState) {
        self.currentDeliveryState = newState
        onDeliveryStateChanged?(newState)
    }
    
    public func dismissIncomingAlert() {
        activeIncomingAlert = nil
        isSirenActive = false
        audioAlerter?.stopEmergencyAlertFeedback()
    }
    
    public func reset() {
        sessionGeneration = UUID()
        cancelOutgoingSOS()
        dismissIncomingAlert()
        seenSOSEventIds.removeAll()
        measurementProvider = nil
    }

    public func cancelOutgoingSOS() {
        outgoingGeneration = UUID()
        cancelRetries()
        lastDeliveredFriendId = nil
        lastDeliveredTimestamp = nil
        lastDeliveredHopCount = nil
        lastRelayHopCount = nil
        lastRelayResponderId = nil
        updateDeliveryState(.idle)
        currentRouteChoice = .none
        activeSOSEventId = nil
        retryCount = 0
        lastDispatchedPayload = nil
    }
    
    public func diagnosticsSnapshot() -> SOSDiagnostics {
        SOSDiagnostics(
            eventId: activeSOSEventId,
            hopCount: lastDeliveredHopCount ?? lastRelayHopCount,
            retryCount: retryCount,
            routeChoice: currentRouteChoice,
            stage: currentDeliveryState.stage,
            lastDeliveredFriendId: lastDeliveredFriendId,
            lastRelayResponderId: lastRelayResponderId,
            timestamp: clock.now()
        )
    }
}
