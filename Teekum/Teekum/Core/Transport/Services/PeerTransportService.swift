//
//  PeerTransportService.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public actor PeerTransportService: PeerTransport, MeshTransport {
    
    // MARK: - Active Session & Radio Configuration
    
    var activeSession: GroupSession?
    var serviceType: String = "_teekum._tcp"
    var isUDP: Bool = false
    var localPeerId: String = ""
    
    var listener: NWListener?
    var browser: NWBrowser?
    let dispatchQueue = DispatchQueue(label: "com.teekum.peertransport", qos: .userInitiated)
    
    /// Map of connected or connecting peers keyed by peer ID.
    var connections: [String: PeerConnection] = [:]
    
    /// Endpoints currently visible in NWBrowser results keyed by peer ID.
    var discoveredEndpoints: [String: (endpoint: NWEndpoint, displayName: String?, isGroup: Bool)] = [:]
    
    /// Dual-lane prioritized outbox with stranger relay ring buffer.
    let outbox = PriorityOutboxQueue()
    var isFlushingOutbox: Bool = false
    
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
        let inFrameStream = AsyncStream<InboundFrame> { continuation in
            localInboundFrame = continuation
        }
        self.inboundFrames = inFrameStream
        self.inboundFrameContinuation = localInboundFrame
        
        var localOutcomes: AsyncStream<SendOutcome>.Continuation?
        let outcomeStream = AsyncStream<SendOutcome> { continuation in
            localOutcomes = continuation
        }
        self.sendOutcomes = outcomeStream
        self.sendOutcomeContinuation = localOutcomes
        
        var localNeighborEvents: AsyncStream<NeighborEvent>.Continuation?
        let nEventStream = AsyncStream<NeighborEvent> { continuation in
            localNeighborEvents = continuation
        }
        self.neighborEvents = nEventStream
        self.neighborEventContinuation = localNeighborEvents
        
        var localPeerUpdates: AsyncStream<[PeerInfo]>.Continuation?
        let peerStream = AsyncStream<[PeerInfo]> { continuation in
            localPeerUpdates = continuation
        }
        self.peerUpdates = peerStream
        self.peerUpdatesContinuation = localPeerUpdates
        
        var localStateUpdates: AsyncStream<TransportState>.Continuation?
        let stateStream = AsyncStream<TransportState> { continuation in
            localStateUpdates = continuation
        }
        self.stateUpdates = stateStream
        self.stateUpdatesContinuation = localStateUpdates
        
        var localErrors: AsyncStream<TransportError>.Continuation?
        let errStream = AsyncStream<TransportError> { continuation in
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
        self.inboundFrames = AsyncStream { continuation in
            localInboundFrame = continuation
        }
        self.inboundFrameContinuation = localInboundFrame
        
        var localOutcomes: AsyncStream<SendOutcome>.Continuation?
        self.sendOutcomes = AsyncStream { continuation in
            localOutcomes = continuation
        }
        self.sendOutcomeContinuation = localOutcomes
        
        var localNeighborEvents: AsyncStream<NeighborEvent>.Continuation?
        self.neighborEvents = AsyncStream { continuation in
            localNeighborEvents = continuation
        }
        self.neighborEventContinuation = localNeighborEvents
        
        var localPeerUpdates: AsyncStream<[PeerInfo]>.Continuation?
        self.peerUpdates = AsyncStream { continuation in
            localPeerUpdates = continuation
        }
        self.peerUpdatesContinuation = localPeerUpdates
        
        var localStateUpdates: AsyncStream<TransportState>.Continuation?
        self.stateUpdates = AsyncStream { continuation in
            localStateUpdates = continuation
        }
        self.stateUpdatesContinuation = localStateUpdates
        
        var localErrors: AsyncStream<TransportError>.Continuation?
        self.transportErrors = AsyncStream { continuation in
            localErrors = continuation
        }
        self.transportErrorsContinuation = localErrors
    }
    
    // MARK: - PeerTransport Protocol Lifecycle Implementation
    
    /// Starts Bonjour advertising (NWListener) and discovery (NWBrowser) for the active session.
    public func start(serviceType: String, session: GroupSession) async throws {
        await stop()
        resetStreams()
        
        self.activeSession = session
        self.serviceType = serviceType
        self.isUDP = serviceType.contains("udp")
        self.localPeerId = session.localInitials
        
        logEvent("Starting radio transport (Initials: \(localPeerId), Service: \(serviceType), Mode: \(isUDP ? "UDP" : "TCP")).", level: .info)
        updateState(.starting)
        
        do {
            try startListener()
            try startBrowser()
            updateState(.discovering)
            logEvent("Bonjour listener and browser active. Advertising local peer.", level: .info)
        } catch {
            let transportError = TransportError.listenerFailed(error.localizedDescription)
            updateState(.failed(transportError))
            transportErrorsContinuation?.yield(transportError)
            logEvent("Failed to start radio transport: \(error.localizedDescription)", level: .error)
            throw transportError
        }
    }
    
    /// Stops all radio advertising, browsing, and active socket connections.
    public func stop() async {
        logEvent("Stopping radio transport and releasing sockets.", level: .info)
        
        browser?.cancel()
        browser = nil
        
        listener?.cancel()
        listener = nil
        
        for peer in connections.values {
            peer.connection.cancel()
        }
        connections.removeAll()
        discoveredEndpoints.removeAll()
        outbox.clear()
        
        for neighbor in await neighborTable.activeNeighbors() {
            await neighborTable.removeNeighbor(peerId: neighbor.id)
        }
        
        activeSession = nil
        updateState(.stopped)
        emitPeerUpdates()
    }
    
    // MARK: - State Management & Helpers
    
    func updateState(_ newState: TransportState) {
        guard currentState != newState else { return }
        currentState = newState
        stateUpdatesContinuation?.yield(newState)
    }
    
    func refreshConnectionState() {
        let count = connections.values.filter { $0.isReady }.count
        if count > 0 {
            updateState(.connected(peerCount: count))
        } else if currentState != .stopped && activeSession != nil {
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
        peerUpdatesContinuation?.yield(peerList)
    }
    
    func logEvent(_ message: String, level: DiagnosticEvent.EventLevel) {
        let event = DiagnosticEvent(message: message, level: level)
        diagnosticEvents.append(event)
        if diagnosticEvents.count > maxDiagnosticEvents {
            diagnosticEvents.removeFirst(diagnosticEvents.count - maxDiagnosticEvents)
        }
    }
}
