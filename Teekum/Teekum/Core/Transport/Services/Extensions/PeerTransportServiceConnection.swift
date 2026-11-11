//
//  PeerTransportServiceConnection.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import Network

// MARK: - Connection Lifecycle & Reconnection

extension PeerTransportService {
    
    func initiateOutboundConnection(to endpoint: NWEndpoint, peerId: String, displayName: String?, isGroupMember: Bool) {
        // Prevent duplicate connection attempts
        if let existing = connections[peerId], existing.isReady {
            return
        }
        
        let params = createParameters()
        let nwConn = NWConnection(to: endpoint, using: params)
        
        let peer = PeerConnection(
            peerId: peerId,
            displayName: displayName ?? "Peer-\(peerId.prefix(4))",
            endpoint: endpoint,
            connection: nwConn,
            isOutbound: true,
            isGroupMember: isGroupMember
        )
        connections[peerId] = peer
        
        setupConnectionHandlers(peer)
        nwConn.start(queue: dispatchQueue)
    }
    
    func handleIncomingConnection(_ connection: NWConnection) {
        // Inbound connection from NWListener
        var resolvedPeerId = "inbound-\(UUID().uuidString.prefix(6))"
        var resolvedDisplayName = "Connecting..."
        var isGroup = false
        
        // Find awaiting discovered peer that should be connecting to us (remoteId < localPeerId)
        if let awaitingPeer = discoveredEndpoints.keys.first(where: { remoteId in
            remoteId < localPeerId && connections[remoteId] == nil
        }) {
            resolvedPeerId = awaitingPeer
            if let info = discoveredEndpoints[awaitingPeer] {
                resolvedDisplayName = info.displayName ?? "Peer-\(awaitingPeer.prefix(3))"
                isGroup = info.isGroup
            }
        }
        
        let peer = PeerConnection(
            peerId: resolvedPeerId,
            displayName: resolvedDisplayName,
            endpoint: connection.endpoint,
            connection: connection,
            isOutbound: false,
            isGroupMember: isGroup
        )
        connections[resolvedPeerId] = peer
        
        logEvent("Incoming link established with peer \(resolvedPeerId) from endpoint \(connection.endpoint).", level: .info)
        setupConnectionHandlers(peer)
        connection.start(queue: dispatchQueue)
    }
    
    func setupConnectionHandlers(_ peer: PeerConnection) {
        let conn = peer.connection
        
        conn.stateUpdateHandler = { [weak self, weak peer] state in
            guard let self = self, let peer = peer else { return }
            Task { await self.handleConnectionStateChange(peer: peer, state: state) }
        }
    }
    
    func handleConnectionStateChange(peer: PeerConnection, state: NWConnection.State) {
        guard activeSession != nil, connections[peer.peerId] === peer else { return }
        switch state {
        case .ready:
            peer.isReady = true
            peer.retryCount = 0
            peer.lastSeen = Date()
            logEvent("Connection to \(peer.peerId) reached READY state (isGroup: \(peer.isGroupMember)).", level: .info)
            
            Task {
                await neighborTable.registerOrUpdateNeighbor(
                    id: peer.peerId,
                    displayName: peer.displayName,
                    state: .connected,
                    rssi: nil,
                    isGroupMember: peer.isGroupMember,
                    capabilities: peer.capabilities
                )
            }
            
            // Start reading frames directly without handshake
            receiveNextBytes(from: peer)
            
            refreshConnectionState()
            emitPeerUpdates()
            triggerOutboxFlush()
            
        case let .failed(error):
            logEvent("Connection to \(peer.peerId) FAILED: \(error.localizedDescription)", level: .warning)
            handleDisconnection(peer: peer, error: error)
            
        case .cancelled:
            logEvent("Connection to \(peer.peerId) CANCELLED.", level: .info)
            handleDisconnection(peer: peer, error: nil)
            
        case let .waiting(error):
            logEvent("Connection to \(peer.peerId) WAITING: \(error.localizedDescription)", level: .warning)
            
        default:
            break
        }
    }
    
    func handleDisconnection(peer: PeerConnection, error: Error?) {
        guard connections[peer.peerId] === peer else { return }
        let peerId = peer.peerId
        peer.isReady = false
        carryStore.disconnected(peerId)
        peer.connection.cancel()
        connections.removeValue(forKey: peerId)
        
        Task {
            await neighborTable.removeNeighbor(peerId: peerId)
        }
        
        refreshConnectionState()
        emitPeerUpdates()
        
        if let error = error {
            let err = TransportError.connectionFailed(error.localizedDescription)
            transportErrorsContinuation?.yield(err)
            
            // Bounded Reconnect Attempt
            scheduleReconnection(for: peerId, lastEndpoint: peer.endpoint, currentRetry: peer.retryCount)
        }
    }
    
    func scheduleReconnection(for peerId: String, lastEndpoint: NWEndpoint, currentRetry: Int) {
        guard activeSession != nil, currentState != .stopped else { return }
        
        let maxRetries = 3
        guard currentRetry < maxRetries else {
            logEvent("Peer \(peerId) exceeded max reconnect retries (\(maxRetries)). Marking unreachable.", level: .warning)
            transportErrorsContinuation?.yield(.peerNotFound(peerId))
            return
        }
        
        let nextRetry = currentRetry + 1
        // Exponential backoff: 1.0s, 2.0s, 4.0s + jitter
        let delaySeconds = min(5.0, Double(1 << (nextRetry - 1))) + Double.random(in: 0.1...0.3)
        logEvent("Scheduling reconnection attempt \(nextRetry)/\(maxRetries) to \(peerId) in \(String(format: "%.1f", delaySeconds))s.", level: .info)
        
        let generation = radioGeneration
        reconnectTasks[peerId]?.cancel()
        reconnectTasks[peerId] = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delaySeconds)) } catch { return }
            await self?.attemptReconnection(peerId: peerId, endpoint: lastEndpoint, retryCount: nextRetry,
                generation: generation)
        }
    }
    
    func attemptReconnection(peerId: String, endpoint: NWEndpoint, retryCount: Int, generation: UUID) {
        guard isCurrentGeneration(generation), currentState != .stopped else { return }
        reconnectTasks.removeValue(forKey: peerId)
        // Ensure no active connection exists before reconnecting
        if let existing = connections[peerId], existing.isReady {
            return
        }
        
        logEvent("Executing reconnection attempt \(retryCount) to peer \(peerId)...", level: .info)
        let params = createParameters()
        let nwConn = NWConnection(to: endpoint, using: params)
        
        let peer = PeerConnection(
            peerId: peerId,
            displayName: "Peer-\(peerId.prefix(4))",
            endpoint: endpoint,
            connection: nwConn,
            isOutbound: true
        )
        peer.retryCount = retryCount
        connections[peerId] = peer
        
        setupConnectionHandlers(peer)
        nwConn.start(queue: dispatchQueue)
    }
}
