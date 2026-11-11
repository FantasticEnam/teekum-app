//
//  SOSForwardingEngine+Retries.swift
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
    public func executeRetryAttempt(payload originalPayload: SOSPayload, session: GroupSession) async {
        let generation = sessionGeneration
        let outgoing = outgoingGeneration
        let isDelivered = currentDeliveryState.isDelivered
        guard !isDelivered, activeSOSEventId == originalPayload.sosEventId else { return }
        
        if retryCount < maxRetries {
            retryCount += 1
            
            let neighbors = await transport.activeNeighbors()
            guard generation == sessionGeneration, outgoing == outgoingGeneration else { return }
            if neighbors.isEmpty && !currentDeliveryState.isRelayed {
                updateDeliveryState(.searchingPeers)
                self.currentRouteChoice = .none
            } else if !currentDeliveryState.isRelayed {
                updateDeliveryState(.localSending)
            }

            var payload = originalPayload
            if let measurementProvider {
                let (location, battery) = await measurementProvider()
                guard generation == sessionGeneration, outgoing == outgoingGeneration, activeSOSEventId == payload.sosEventId else { return }
                payload = SOSPayload(coordinate: location?.coordinate ?? .init(latitude: 0, longitude: 0),
                    timestamp: location?.timestamp ?? Date(timeIntervalSince1970: 0), accuracy: location?.rawAccuracyByte ?? 255,
                    sosEventId: payload.sosEventId, senderInitials: session.localInitials, emergencyType: payload.emergencyType,
                    batteryLevel: battery.asBatteryPercentage, colorCode: session.localColorCode)
            }
            lastDispatchedPayload = payload
            
            let seq: UInt32
            do { seq = try await nextSequenceNumber(for: session) } catch {
                cancelRetries()
                updateDeliveryState(.failed(reason: error.localizedDescription))
                return
            }
            
            guard generation == sessionGeneration, outgoing == outgoingGeneration else { return }
            let envelope = CleartextEnvelope(
                version: PacketConstants.protocolVersion,
                type: .sos,
                hopLimit: PacketConstants.sosHopLimit,
                hopCount: 0,
                sessionId: session.sessionId,
                sequenceNumber: seq
            )
            
            let key = SymmetricKey(data: session.symmetricKeyData)
            do { try await broadcastEmergencySOS(payload: payload, envelope: envelope, symmetricKey: key) }
            catch { await recordSendFailure(error, generation: generation, outgoing: outgoing) }
        } else {
            // Retries exhausted without confirmation
            cancelRetries()
            let neighbors = await transport.activeNeighbors()
            guard generation == sessionGeneration, outgoing == outgoingGeneration else { return }
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

    func recordSendFailure(_ error: Error, generation: UUID, outgoing: UUID) async {
        let neighbors = await transport.activeNeighbors()
        guard generation == sessionGeneration, outgoing == outgoingGeneration else { return }
        updateDeliveryState(neighbors.isEmpty ? .searchingPeers : .failed(reason: error.localizedDescription))
    }
}
