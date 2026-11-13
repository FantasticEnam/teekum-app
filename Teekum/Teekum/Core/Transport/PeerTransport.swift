//
//  PeerTransport.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Authoritative contract for the low-level Apple Peer-to-Peer transport service (`Network.framework`).
/// Must be implemented as a Swift `actor` to guarantee thread-safe radio access.
public protocol PeerTransport: Actor {
    /// Live asynchronous stream of inbound 56-byte binary datagrams.
    var inboundPackets: AsyncStream<InboundPacket> { get }
    
    /// Live asynchronous stream of active peer updates.
    var peerUpdates: AsyncStream<[PeerInfo]> { get }
    
    /// Live asynchronous stream of transport operational state changes.
    var stateUpdates: AsyncStream<TransportState> { get }
    
    /// Live asynchronous stream of transport errors.
    var transportErrors: AsyncStream<TransportError> { get }
    
    /// Starts local Bonjour listener and browser for the active session.
    func start(serviceType: String, session: GroupSession) async throws
    
    /// Stops all listeners, connections, and advertising, releasing radio resources.
    func stop() async
    
    /// Broadcasts a 56-byte datagram to all currently connected direct peers.
    func broadcastPacket(_ data: Data) async throws
    
    /// Transmits a 56-byte datagram to a specific connected peer.
    func sendPacket(_ data: Data, to peerId: String) async throws
    
    /// Retains authenticated or policy-approved frames for later delivery.
    func retainReceivedForCarry(_ packet: RawWirePacket, excludingPeerId: String?) async

    /// Returns the number of direct peer connections currently established.
    func activeDirectPeerCount() async -> Int
    
    /// Captures a live diagnostic snapshot of transport state and peer telemetry.
    func getDiagnostics() async -> TransportDiagnostics
}

public extension PeerTransport {
    func retainReceivedForCarry(_ packet: RawWirePacket, excludingPeerId: String?) async {}
}
