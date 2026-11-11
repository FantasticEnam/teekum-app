//
//  LocationPublisher.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CryptoKit
import Observation

/// Publishes measured location while live sharing is active.
@Observable
@MainActor
public final class LocationPublisher {
    
    // MARK: - Dependencies
    
    public let locationService: LocationServiceProtocol
    private let sessionProvider: @Sendable () -> GroupSession?
    public let cryptoService: CryptoServiceProtocol
    public let transport: PeerTransport
    private let sequenceAllocator: PacketSequenceAllocator?
    private var generation = UUID()
    
    // MARK: - State Properties
    
    /// Monotonic sequence counter for outbound packets.
    public private(set) var monotonicCounter: UInt32 = 1
    
    /// Total number of ordinary location pings published over the air.
    public private(set) var publishedPingsCount: Int = 0
    
    /// Background listening task observing `locationService.publishedPings`.
    private var listeningTask: Task<Void, Never>?
    
    /// True when publisher is actively listening and broadcasting.
    public private(set) var isRunning: Bool = false
    
    // MARK: - Initialization
    
    public init(
        locationService: LocationServiceProtocol,
        sessionProvider: @escaping @Sendable () -> GroupSession?,
        cryptoService: CryptoServiceProtocol,
        transport: PeerTransport,
        sequenceAllocator: PacketSequenceAllocator? = nil
    ) {
        self.locationService = locationService
        self.sessionProvider = sessionProvider
        self.cryptoService = cryptoService
        self.transport = transport
        self.sequenceAllocator = sequenceAllocator
    }
    
    // MARK: - Lifecycle Controls
    
    /// Starts observing the location service and broadcasting pings when Live Sharing is active.
    public func start() {
        guard !isRunning else { return }
        generation = UUID()
        isRunning = true
        
        listeningTask?.cancel()
        let pingsStream = locationService.publishedPings
        listeningTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if let location = locationService.currentLocation, locationService.isLiveSharingEnabled {
                await handleLocationPingReady(location: location)
            }
            for await location in pingsStream {
                guard !Task.isCancelled, self.isRunning else { break }
                await self.handleLocationPingReady(location: location)
            }
        }
    }
    
    /// Stops observing and broadcasting ordinary location pings.
    public func stop() {
        generation = UUID()
        isRunning = false
        listeningTask?.cancel()
        listeningTask = nil
    }
    
    // MARK: - Ordinary Location Publishing
    
    /// Assembles, seals, and broadcasts a 56-byte wire packet carrying location.
    /// Strictly suppressed if Live Sharing is disabled.
    public func handleLocationPingReady(location: LocationPin) async {
        // Acceptance Criterion 2: Live Sharing OFF prevents ordinary location broadcasting
        guard locationService.isLiveSharingEnabled else { return }
        
        guard let session = sessionProvider() else {
            // No active session to encrypt or address packets to
            return
        }
        
        let batteryPct = locationService.currentBatteryLevel.asBatteryPercentage
        let headingByte = locationService.currentHeading?.quantizedHeadingByte ?? 0
        
        // Option B: Pure geographic & sensor telemetry (Status is transmitted independently via Chat)
        let payload = LocationPingPayload(
            coordinate: location.coordinate,
            timestamp: location.timestamp, // Preserves hardware measurement timestamp
            accuracy: location.rawAccuracyByte,
            senderInitials: session.localInitials,
            batteryLevel: batteryPct,
            heading: headingByte,
            colorCode: session.localColorCode
        )
        
        let payloadData = payload.serialize()
        
        let current = generation
        let seq: UInt32
        do { seq = try await nextSequence(for: session) }
        catch { return }
        guard generation == current, sessionProvider() == session, !Task.isCancelled else { return }
        
        let envelope = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .locationPing,
            hopLimit: PacketConstants.defaultHopLimit,
            hopCount: 0,
            sessionId: session.sessionId,
            sequenceNumber: seq
        )
        
        do {
            let key = SymmetricKey(data: session.symmetricKeyData)
            let sealed = try await cryptoService.seal(payload: payloadData, envelope: envelope, using: key)
            let wirePacket = RawWirePacket(envelope: envelope, ciphertext: sealed.ciphertext, authTag: sealed.authTag)
            let wireData = try wirePacket.toWireData()
            guard generation == current, sessionProvider() == session, !Task.isCancelled else { return }
            try await transport.broadcastPacket(wireData)
            publishedPingsCount += 1
        } catch {
            // Failed transmissions are handled by transport / retry policy
        }
    }
    
    private func nextSequence(for session: GroupSession) async throws -> UInt32 {
        if let sequenceAllocator { return try await sequenceAllocator.next(for: session) }
        let sequence = CleartextEnvelope.makeSequenceNumber(memberSlot: session.memberSlot, counter: monotonicCounter)
        monotonicCounter &+= 1
        return sequence
    }
}
