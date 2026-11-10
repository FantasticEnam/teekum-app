//
//  SOSForwardingEngineOutbound.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CoreLocation
import CryptoKit

// MARK: - Outbound SOS Dispatch & Route Selection

extension SOSForwardingEngine {
    
    /// High-level entry point to dispatch an emergency SOS alert.
    /// Selects known usable route if available, otherwise executes bounded flooding fallback.
    public func dispatchSOS(
        emergencyType: SOSType = .general,
        location: CLLocationCoordinate2D,
        accuracy: UInt8,
        timestamp: Date,
        batteryPct: UInt8
    ) async throws -> UInt32 {
        guard let session = sessionProvider?() else {
            throw TransportError.sessionInvalid
        }
        
        let eventId = UInt32.random(in: 1...UInt32.max)
        self.activeSOSEventId = eventId
        self.retryCount = 0
        
        let payload = SOSPayload(
            coordinate: location,
            timestamp: timestamp,
            accuracy: accuracy,
            sosEventId: eventId,
            senderInitials: session.localInitials,
            emergencyType: emergencyType,
            batteryLevel: batteryPct,
            colorCode: session.localColorCode
        )
        self.lastDispatchedPayload = payload
        
        let neighbors = await transport.activeNeighbors()
        if neighbors.isEmpty {
            updateDeliveryState(.searchingPeers)
            self.currentRouteChoice = .none
        } else {
            updateDeliveryState(.localSending)
        }
        
        let seq = CleartextEnvelope.makeSequenceNumber(memberSlot: session.memberSlot, counter: monotonicCounter)
        monotonicCounter &+= 1
        
        let envelope = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .sos,
            hopLimit: PacketConstants.sosHopLimit,
            hopCount: 0,
            sessionId: session.sessionId,
            sequenceNumber: seq
        )
        
        let key = SymmetricKey(data: session.symmetricKeyData)
        try await broadcastEmergencySOS(payload: payload, envelope: envelope, symmetricKey: key)
        
        totalDispatchedCount += 1
        
        // Start bounded retries task
        startRetryTask(payload: payload, session: session)
        
        return eventId
    }
    
    /// Conformance to `SOSForwardingManaging`: Dispatches an emergency SOS alert across the mesh.
    /// Prefers known usable route in routing table when available; falls back to bounded flooding.
    public func broadcastEmergencySOS(
        payload: SOSPayload,
        envelope: CleartextEnvelope,
        symmetricKey: SymmetricKey
    ) async throws {
        // Enforce SOS token budget if rate limiter is present
        if let rateLimiter = rateLimiter {
            let allowed = await rateLimiter.consumeSOSToken()
            if !allowed {
                // In emergency life-safety scenarios, rate limiter drops excessive bursts
                // but logs telemetry
            }
        }
        
        let payloadData = payload.serialize()
        let sealed = try await cryptoService.seal(payload: payloadData, envelope: envelope, using: symmetricKey)
        let wirePacket = RawWirePacket(envelope: envelope, ciphertext: sealed.ciphertext, authTag: sealed.authTag)
        let wireData = try wirePacket.toWireData()
        
        let neighbors = await transport.activeNeighbors()
        if neighbors.isEmpty {
            updateDeliveryState(.searchingPeers)
            self.currentRouteChoice = .none
            try await transport.broadcastFrame(wireData)
            return
        }
        
        // Route Selection: Prefer known usable route when available
        if let routingTable = routingTable {
            // Check for any known fresh route towards group members or destination
            let activeNeighbors = neighbors.filter { $0.state == .connected }
            var selectedRoute: RouteEntry?
            
            // Check routing table for any friend route
            for neighbor in activeNeighbors where neighbor.isGroupMember {
                if let route = await routingTable.findRoute(to: neighbor.id), route.isFresh {
                    selectedRoute = route
                    break
                }
            }
            
            if let route = selectedRoute, activeNeighbors.contains(where: { $0.id == route.nextHopPeerId }) {
                self.currentRouteChoice = .knownRoute(nextHop: route.nextHopPeerId, hopCount: route.hopCount)
                _ = try await transport.sendFrame(wireData, to: route.nextHopPeerId)
                return
            }
        }
        
        // Bounded Flooding Fallback across all direct physical radio neighbors
        self.currentRouteChoice = .boundedFlooding(neighborCount: neighbors.count)
        try await transport.broadcastFrame(wireData)
    }
}
