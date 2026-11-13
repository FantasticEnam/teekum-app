//
//  ChatMessageEngine.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation
import CryptoKit

/// Authoritative Actor implementing the TeeKum Phase 3 Festival Group Mesh Chat Engine.
///
/// Implements Master Specification Guarantees:
/// 1. Validation & Encoding: Accepts, validates (1..20 UTF-8 bytes), encodes, encrypts with ChaCha20-Poly1305,
///    and dispatches 56-byte wire packets (`ChatMessageEngine+Outbound.swift`).
/// 2. Direct & Multi-Hop: Supports direct radio links and bounded multi-hop mesh forwarding (up to 8 hops).
/// 3. Zero-Knowledge Blind Relays: Relays forward opaque ciphertexts without group keys (`ChatMessageEngine+Inbound.swift`).
/// 4. Duplicate Suppression: Deduplicates by canonical `(sessionId, sequenceNumber)` via `SeenPacketCache`.
/// 5. Timing Semantics: Strict FIFO transmission, max 2 retries (3 total attempts), 3.0s client-side cooldown.
/// 6. Per-Recipient ACK Tracking: Tracks delivery state separately for every intended group recipient (`ChatMessageEngine+Delivery.swift`).
/// 7. Honest UX: Never treats intermediary relay ACKs (`0x02`) as final friend recipient delivery (`0x01`).
/// 8. Explicit 5-State Progression: `locallyAccepted` -> `forwardedToNextHop` -> `relayedByMesh` -> `deliveredToRecipient` -> `deliveryTimedOut`.
/// 9. Ephemeral Security: Retains at most 50 messages strictly in memory. Never persists plaintext or logs content.
///    All chat history is purged upon session termination.
/// 10. Battery Guard: Automatically disables chat below 20% battery (Festival Survival Mode) without disabling SOS.
/// 11. Preserves SOS Priority: Local chat operates in Tier 3 FIFO, strictly behind Tier 1 Emergency SOS.
public actor ChatMessageEngine {
    
    // MARK: - Dependencies
    
    let transport: MeshTransport
    let cryptoService: CryptoServiceProtocol
    let routingTable: RoutingTableManaging?
    let neighborTable: NeighborManaging?
    let rateLimiter: ForwardingBudgetManaging?
    let seenPacketCache: SeenPacketCache
    let clock: MeshClock
    let sequenceAllocator: PacketSequenceAllocator?
    var sessionProvider: (@Sendable () -> GroupSession?)?
    var recipientsProvider: (@MainActor @Sendable () -> [String])?
    
    // MARK: - Configuration & Tunables
    
    public var timingConfig: MeshTimingConfiguration
    public let maxHistoryCount: Int = 50
    
    // MARK: - Ephemeral In-Memory State
    
    var inMemoryMessages: [ChatMessage] = []
    var lastSentTimestamp: Date = .distantPast
    var monotonicCounter: UInt32 = 1
    
    // Hardware battery & survival tracking
    public private(set) var currentBatteryLevel: Float = 1.0
    public private(set) var isLowPowerMode: Bool = false
    public private(set) var isSurvivalMode: Bool = false
    
    // In-flight message tracking for retries and ACK confirmation timeouts
    var inFlightMessages: [UInt32: InFlightMessage] = [:]
    
    // Deduplication tracking for received chat sequence numbers
    var seenChatSequences: Set<UInt32> = []
    
    // Direct callback for state updates
    var onMessageUpdated: (@Sendable (ChatMessage) -> Void)?
    var retrySupervisorTask: Task<Void, Never>?
    var sessionGeneration = UUID()
    
    // MARK: - Initialization
    
    public init(
        transport: MeshTransport,
        cryptoService: CryptoServiceProtocol,
        routingTable: RoutingTableManaging? = nil,
        neighborTable: NeighborManaging? = nil,
        rateLimiter: ForwardingBudgetManaging? = nil,
        seenPacketCache: SeenPacketCache? = nil,
        clock: MeshClock = SystemMeshClock(),
        sequenceAllocator: PacketSequenceAllocator? = nil,
        timingConfig: MeshTimingConfiguration = MeshTimingConfiguration(),
        sessionProvider: (@Sendable () -> GroupSession?)? = nil,
        recipientsProvider: (@MainActor @Sendable () -> [String])? = nil,
        onMessageUpdated: (@Sendable (ChatMessage) -> Void)? = nil
    ) {
        self.transport = transport
        self.cryptoService = cryptoService
        self.routingTable = routingTable
        self.neighborTable = neighborTable
        self.rateLimiter = rateLimiter
        self.seenPacketCache = seenPacketCache ?? SeenPacketCache(clock: clock)
        self.clock = clock
        self.sequenceAllocator = sequenceAllocator
        self.timingConfig = timingConfig
        self.sessionProvider = sessionProvider
        self.recipientsProvider = recipientsProvider
        self.onMessageUpdated = onMessageUpdated
        
    }
    
    public func setOnMessageUpdated(_ handler: (@Sendable (ChatMessage) -> Void)?) {
        self.onMessageUpdated = handler
    }
    
    /// Reconfigures session and recipient providers for an active session lifecycle.
    public func configure(
        sessionProvider: (@Sendable () -> GroupSession?)?,
        recipientsProvider: (@MainActor @Sendable () -> [String])? = nil
    ) {
        sessionGeneration = UUID()
        self.sessionProvider = sessionProvider
        self.recipientsProvider = recipientsProvider
        
        retrySupervisorTask?.cancel()
        if sessionProvider != nil {
            retrySupervisorTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { break }
                    await self?.evaluateTimeoutsAndRetries()
                }
            }
        } else {
            retrySupervisorTask = nil
        }
    }
    
    func nextSequenceNumber(for session: GroupSession) async throws -> UInt32 {
        if let sequenceAllocator { return try await sequenceAllocator.next(for: session) }
        let sequence = CleartextEnvelope.makeSequenceNumber(memberSlot: session.memberSlot, counter: monotonicCounter)
        monotonicCounter &+= 1
        return sequence
    }

    // MARK: - Battery & Power Policy
    
    /// Updates hardware power state. Automatically disables outgoing chat at <20% battery or Low Power Mode.
    /// Does NOT disable Emergency SOS.
    public func setBatteryLevel(_ level: Float, isLowPowerMode: Bool = false) {
        self.currentBatteryLevel = level
        self.isLowPowerMode = isLowPowerMode
        self.isSurvivalMode = (level < 0.20) || isLowPowerMode
    }
    
    // MARK: - Internal Message Storage Helpers
    
    func appendMessage(_ message: ChatMessage) {
        inMemoryMessages.append(message)
        if inMemoryMessages.count > maxHistoryCount {
            inMemoryMessages.removeFirst(inMemoryMessages.count - maxHistoryCount)
        }
        notifyMessageUpdated(message)
    }
    
    func updateMessage(_ message: ChatMessage) {
        if let idx = inMemoryMessages.firstIndex(where: { $0.sequenceNumber == message.sequenceNumber }) {
            inMemoryMessages[idx] = message
        }
        notifyMessageUpdated(message)
    }
    
    func notifyMessageUpdated(_ message: ChatMessage) {
        onMessageUpdated?(message)
    }
    
    func decryptPayload(rawPacket: RawWirePacket) async throws -> Data {
        guard let session = sessionProvider?() else {
            throw ChatEngineError.noActiveSession
        }
        let symmetricKey = SymmetricKey(data: session.symmetricKeyData)
        return try await cryptoService.open(
            ciphertext: rawPacket.ciphertext,
            envelope: rawPacket.envelope,
            authTag: rawPacket.authTag,
            using: symmetricKey
        )
    }
    
    func forwardOpaquePacket(_ wireData: Data, exceptPeerId: String?) async throws {
        let generation = sessionGeneration
        if let neighbors = neighborTable {
            let active = await neighbors.activeNeighbors()
            guard generation == sessionGeneration else { return }
            let targets = active.filter { $0.id != exceptPeerId }
            for peer in targets {
                guard generation == sessionGeneration else { return }
                _ = try? await transport.sendFrame(wireData, to: peer.id)
            }
        } else {
            try? await transport.broadcastFrame(wireData)
        }
    }
}

