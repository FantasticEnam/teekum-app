//
//  SOSForwardingEngineRetries.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CryptoKit

// MARK: - Bounded Retries Scheduler

extension SOSForwardingEngine {
    
    func startRetryTask(payload: SOSPayload, session: GroupSession) {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                let interval = await self.retryInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                
                let isDelivered = await self.currentDeliveryState.isDelivered
                if isDelivered { break }
                
                await self.executeRetryAttempt(payload: payload, session: session)
            }
        }
    }
    
    /// Executes a single bounded retry attempt. Publicly callable for synchronous unit tests.
    public func executeRetryAttempt(payload: SOSPayload, session: GroupSession) async {
        let isDelivered = currentDeliveryState.isDelivered
        guard !isDelivered else { return }
        
        if retryCount < maxRetries {
            retryCount += 1
            
            let neighbors = await transport.activeNeighbors()
            if neighbors.isEmpty {
                updateDeliveryState(.searchingPeers)
                self.currentRouteChoice = .none
            } else if !currentDeliveryState.isRelayed {
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
            try? await broadcastEmergencySOS(payload: payload, envelope: envelope, symmetricKey: key)
        } else {
            // Retries exhausted without confirmation
            cancelRetries()
            let neighbors = await transport.activeNeighbors()
            if currentDeliveryState.isRelayed {
                // Intermediary acknowledged, but recipient friend never confirmed
                // Keep relayed state honestly showing it was relayed but unconfirmed by friend
            } else if neighbors.isEmpty {
                updateDeliveryState(.searchingPeers)
            } else {
                updateDeliveryState(.failed(reason: "Delivery confirmation timeout: exhausted \(maxRetries) retries without recipient ACK."))
            }
        }
    }
    
    public func triggerRetryNow() async {
        guard let payload = lastDispatchedPayload, let session = sessionProvider?() else { return }
        await executeRetryAttempt(payload: payload, session: session)
    }
    
    public func cancelRetries() {
        retryTask?.cancel()
        retryTask = nil
    }
}
