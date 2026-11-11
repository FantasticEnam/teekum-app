//
//  MeshTransport.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Authoritative transport-independent abstraction for Phase 2 multi-hop mesh networking.
public protocol MeshTransport: Actor {
    /// Inbound stream of complete received wire frames.
    var inboundFrames: AsyncStream<InboundFrame> { get }
    
    /// Stream of transmission outcomes for each submitted or forwarded packet.
    var sendOutcomes: AsyncStream<SendOutcome> { get }
    
    /// Stream of neighbor connection and state change events.
    var neighborEvents: AsyncStream<NeighborEvent> { get }
    
    /// Stream of transport errors.
    var transportErrors: AsyncStream<TransportError> { get }
    
    /// Starts the transport for an active session.
    func start(serviceType: String, session: GroupSession) async throws
    
    /// Stops the transport and cleans up all radio/socket resources.
    func stop() async
    
    /// Submits a complete 56-byte protocol frame to a specific connected peer.
    func sendFrame(_ data: Data, to peerId: String) async throws -> SendOutcome
    
    /// Submits a complete 56-byte protocol frame for broadcast to all connected direct peers.
    func broadcastFrame(_ data: Data) async throws
    
    /// Blindly forwards an opaque 56-byte protocol frame to a designated next hop.
    /// Does not decrypt the payload. Mutates only hopCount (+1) and enforces hopLimit.
    func forwardFrame(_ data: Data, to nextHopPeerId: String) async throws -> SendOutcome
    
    /// Current view of directly reachable neighbors.
    func activeNeighbors() async -> [NeighborInfo]
    
    /// Current queue depth across urgent, normal, and relay queues.
    func queueDepth() async -> QueueDepth
    
    /// Updates relay participation status.
    func setRelayParticipation(enabled: Bool) async
    
    /// Checks if relaying is currently permitted.
    func isRelayPermitted() async -> Bool
}
