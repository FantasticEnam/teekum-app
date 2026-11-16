//
//  PeerTransportService.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import WiFiAware

public actor PeerTransportService: PeerTransport, MeshTransport {
    
    // MARK: - Active Session & Radio Configuration
    
    var activeSession: GroupSession?
    var serviceType = MeepoConfiguration.Network.wifiAwareService
    var connections: [String: PeerConnection] = [:]
    var pairedDeviceIDs: Set<WAPairedDevice.ID> = []
    var discoveredEndpoints: [WAPairedDevice.ID: WAEndpoint] = [:]
    var dialAttempts: [WAPairedDevice.ID: UUID] = [:]
    var nextDial: [WAPairedDevice.ID: ContinuousClock.Instant] = [:]
    var linkTasks: [UUID: Task<Void, Never>] = [:]
    var pairingTask: Task<Void, Never>?
    var discoveryTask: Task<Void, Never>?
    var discoveryGeneration = UUID()
    var radioGeneration = UUID()

    let outbox = PriorityOutboxQueue()
    var isFlushingOutbox = false
    var carryStore = CarryMessageStore()
    var carryTask: Task<Void, Never>?
    var carryPowerPermitted = true
    var outboxRetries: [UUID: (task: Task<Void, Never>, isRelay: Bool)] = [:]
    var outboxFlushTask: Task<Void, Never>?

    /// Neighbor management registry.
    public let neighborTable: NeighborTable
    
    /// Forwarding rate limiter enforcing Decision 7 token bucket budgets.
    public let rateLimiter: ForwardingBudgetManaging
    
    /// User-controlled communal mesh relay toggle.
    public internal(set) var isRelayEnabled: Bool = true
    
    // MARK: - Streams & Continuations
    
    var inboundContinuation: AsyncStream<InboundPacket>.Continuation?
    public private(set) var inboundPackets: AsyncStream<InboundPacket>
    
    var inboundFrameContinuation: AsyncStream<InboundFrame>.Continuation?
    public private(set) var inboundFrames: AsyncStream<InboundFrame>
    
    var sendOutcomeContinuation: AsyncStream<SendOutcome>.Continuation?
    public private(set) var sendOutcomes: AsyncStream<SendOutcome>
    
    var neighborEventContinuation: AsyncStream<NeighborEvent>.Continuation?
    public private(set) var neighborEvents: AsyncStream<NeighborEvent>
    
    var peerUpdatesContinuation: AsyncStream<[PeerInfo]>.Continuation?
    public private(set) var peerUpdates: AsyncStream<[PeerInfo]>
    
    var stateUpdatesContinuation: AsyncStream<TransportState>.Continuation?
    public private(set) var stateUpdates: AsyncStream<TransportState>
    
    var transportErrorsContinuation: AsyncStream<TransportError>.Continuation?
    public private(set) var transportErrors: AsyncStream<TransportError>
    
    // MARK: - Diagnostics Telemetry
    
    public internal(set) var currentState: TransportState = .stopped
    var packetsSentCount: Int = 0
    var packetsReceivedCount: Int = 0
    var sendErrorsCount: Int = 0
    var lastErrorMessage: String?
    var diagnosticEvents: [DiagnosticEvent] = []
    let maxDiagnosticEvents: Int = 50
    var packetEvents: [TransportDiagnostics.PacketEvent] = []
    
    // MARK: - Initialization
    
    public init(
        neighborTable: NeighborTable? = nil,
        rateLimiter: ForwardingBudgetManaging? = nil,
        clock: MeshClock = SystemMeshClock()
    ) {
        let nTable = neighborTable ?? NeighborTable(clock: clock)
        self.neighborTable = nTable
        self.rateLimiter = rateLimiter ?? ForwardingRateLimiter(clock: clock)
        
        var localInbound: AsyncStream<InboundPacket>.Continuation?
        let inStream = AsyncStream<InboundPacket> { continuation in
            localInbound = continuation
        }
        self.inboundPackets = inStream
        self.inboundContinuation = localInbound
        
        var localInboundFrame: AsyncStream<InboundFrame>.Continuation?
        let inFrameStream = AsyncStream<InboundFrame>(bufferingPolicy: .bufferingNewest(128)) { continuation in
            localInboundFrame = continuation
        }
        self.inboundFrames = inFrameStream
        self.inboundFrameContinuation = localInboundFrame
        
        var localOutcomes: AsyncStream<SendOutcome>.Continuation?
        let outcomeStream = AsyncStream<SendOutcome>(bufferingPolicy: .bufferingNewest(128)) { continuation in
            localOutcomes = continuation
        }
        self.sendOutcomes = outcomeStream
        self.sendOutcomeContinuation = localOutcomes
        
        var localNeighborEvents: AsyncStream<NeighborEvent>.Continuation?
        let nEventStream = AsyncStream<NeighborEvent>(bufferingPolicy: .bufferingNewest(128)) { continuation in
            localNeighborEvents = continuation
        }
        self.neighborEvents = nEventStream
        self.neighborEventContinuation = localNeighborEvents
        
        var localPeerUpdates: AsyncStream<[PeerInfo]>.Continuation?
        let peerStream = AsyncStream<[PeerInfo]>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            localPeerUpdates = continuation
        }
        self.peerUpdates = peerStream
        self.peerUpdatesContinuation = localPeerUpdates
        
        var localStateUpdates: AsyncStream<TransportState>.Continuation?
        let stateStream = AsyncStream<TransportState>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            localStateUpdates = continuation
        }
        self.stateUpdates = stateStream
        self.stateUpdatesContinuation = localStateUpdates
        
        var localErrors: AsyncStream<TransportError>.Continuation?
        let errStream = AsyncStream<TransportError>(bufferingPolicy: .bufferingNewest(16)) { continuation in
            localErrors = continuation
        }
        self.transportErrors = errStream
        self.transportErrorsContinuation = localErrors
    }
    
    /// Recreates streams and continuations ensuring fresh, un-terminated streams for each session.
    func resetStreams() {
        var localInbound: AsyncStream<InboundPacket>.Continuation?
        self.inboundPackets = AsyncStream { continuation in
            localInbound = continuation
        }
        self.inboundContinuation = localInbound
        
        var localInboundFrame: AsyncStream<InboundFrame>.Continuation?
        self.inboundFrames = AsyncStream(bufferingPolicy: .bufferingNewest(128)) { continuation in
            localInboundFrame = continuation
        }
        self.inboundFrameContinuation = localInboundFrame
        
        var localOutcomes: AsyncStream<SendOutcome>.Continuation?
        self.sendOutcomes = AsyncStream(bufferingPolicy: .bufferingNewest(128)) { continuation in
            localOutcomes = continuation
        }
        self.sendOutcomeContinuation = localOutcomes
        
        var localNeighborEvents: AsyncStream<NeighborEvent>.Continuation?
        self.neighborEvents = AsyncStream(bufferingPolicy: .bufferingNewest(128)) { continuation in
            localNeighborEvents = continuation
        }
        self.neighborEventContinuation = localNeighborEvents
        
        var localPeerUpdates: AsyncStream<[PeerInfo]>.Continuation?
        self.peerUpdates = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            localPeerUpdates = continuation
        }
        self.peerUpdatesContinuation = localPeerUpdates
        
        var localStateUpdates: AsyncStream<TransportState>.Continuation?
        self.stateUpdates = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            localStateUpdates = continuation
        }
        self.stateUpdatesContinuation = localStateUpdates
        
        var localErrors: AsyncStream<TransportError>.Continuation?
        self.transportErrors = AsyncStream(bufferingPolicy: .bufferingNewest(16)) { continuation in
            localErrors = continuation
        }
        self.transportErrorsContinuation = localErrors
    }
    
    // MARK: - PeerTransport Protocol Lifecycle Implementation
    
    public func start(serviceType: String, session: GroupSession) async throws {
        await stop()
        resetStreams()
        activeSession = session
        self.serviceType = serviceType
        packetsSentCount = 0
        packetsReceivedCount = 0
        sendErrorsCount = 0
        lastErrorMessage = nil
        diagnosticEvents.removeAll()

        guard WACapabilities.supportedFeatures.contains(.wifiAware) else {
            throw reportRadioFailure(.wifiAwareUnavailable)
        }
        guard let publish = WAPublishableService.allServices[serviceType],
              let subscribe = WASubscribableService.allServices[serviceType] else {
            throw reportRadioFailure(.wifiAwareMisconfigured)
        }

        updateState(.discovering)
        let generation = radioGeneration
        pairingTask = Task { [weak self] in
            await self?.observePairedDevices(publish: publish, subscribe: subscribe, generation: generation)
        }
        carryTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(500)) } catch { break }
                await self?.connectDiscoveredPeers(generation: generation)
                await self?.replayCarriedMessage()
            }
        }
    }

    public func stop() async {
        radioGeneration = UUID()
        let generation = radioGeneration
        activeSession = nil
        let radioTasks = [pairingTask, discoveryTask].compactMap { $0 } + linkTasks.values
        for task in radioTasks { task.cancel() }
        pairingTask = nil
        discoveryTask = nil
        linkTasks.removeAll()
        connections.removeAll()
        pairedDeviceIDs.removeAll()
        discoveredEndpoints.removeAll()
        dialAttempts.removeAll()
        nextDial.removeAll()
        for retry in outboxRetries.values { retry.task.cancel() }
        outboxRetries.removeAll()
        outboxFlushTask?.cancel()
        outboxFlushTask = nil
        isFlushingOutbox = false
        carryTask?.cancel()
        carryTask = nil
        carryStore.removeAll()
        outbox.clear()
        packetEvents.removeAll()

        updateState(.stopped)
        emitPeerUpdates()
        inboundContinuation?.finish()
        inboundFrameContinuation?.finish()
        sendOutcomeContinuation?.finish()
        neighborEventContinuation?.finish()
        peerUpdatesContinuation?.finish()
        stateUpdatesContinuation?.finish()
        transportErrorsContinuation?.finish()
        for task in radioTasks { await task.value }
        for neighbor in await neighborTable.activeNeighbors() {
            guard generation == radioGeneration else { break }
            await neighborTable.removeNeighbor(peerId: neighbor.id)
        }
    }

    @discardableResult
    func reportRadioFailure(_ error: TransportError) -> TransportError {
        lastErrorMessage = error.localizedDescription
        transportErrorsContinuation?.yield(error)
        logEvent(error.localizedDescription, level: .warning)
        if !connections.values.contains(where: \.isReady) { updateState(.failed(error)) }
        return error
    }

    func isCurrentGeneration(_ generation: UUID) -> Bool {
        generation == radioGeneration && activeSession != nil
    }

    // MARK: - State Management & Helpers
    
    func updateState(_ newState: TransportState) {
        guard currentState != newState else { return }
        currentState = newState
        stateUpdatesContinuation?.yield(newState)
    }
    
    func refreshConnectionState() {
        guard activeSession != nil else { return }
        let count = connections.values.count(where: \.isReady)
        if count > 0 {
            updateState(.connected(peerCount: count))
        } else {
            updateState(.discovering)
        }
    }
    
    func emitPeerUpdates() {
        let peerList = connections.values.map { peer in
            PeerInfo(
                id: peer.peerId,
                displayName: peer.displayName,
                rssi: nil,
                isDirectLink: peer.isReady,
                isGroupMember: peer.isGroupMember,
                lastSeen: peer.lastSeen
            )
        }
        peerUpdatesContinuation?.yield(peerList.filter(\.isDirectLink))
    }
    
    func logEvent(_ message: String, level: DiagnosticEvent.EventLevel) {
        let event = DiagnosticEvent(message: message, level: level)
        diagnosticEvents.append(event)
        if diagnosticEvents.count > maxDiagnosticEvents {
            diagnosticEvents.removeFirst(diagnosticEvents.count - maxDiagnosticEvents)
        }
    }
}
