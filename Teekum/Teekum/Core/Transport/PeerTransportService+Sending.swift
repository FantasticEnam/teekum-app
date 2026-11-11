//
//  PeerTransportService+Sending.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import Network

// MARK: - Frame Transmission & Priority Outbox

extension PeerTransportService {
    
    // MARK: - MeshTransport Sending & Forwarding
    
    /// Submits a complete 56-byte protocol frame to a specific connected peer.
    public func sendFrame(_ data: Data, to peerId: String) async throws -> SendOutcome {
        guard currentState != .stopped, activeSession != nil else {
            throw TransportError.notStarted
        }
        guard data.count == PacketConstants.wirePacketSize else {
            throw TransportError.invalidPacketSize
        }
        if blePeers.contains(peerId) {
            rememberForCarry(data)
            try outbox.enqueue(data: data, destinationPeerId: peerId, isRelay: false)
            triggerOutboxFlush()
            let packet = try RawWirePacket.fromWireData(data)
            return SendOutcome(destinationPeerId: peerId, packetType: packet.envelope.type, isSuccess: true)
        }
        guard let peer = connections[peerId], peer.isReady else {
            let err = TransportError.peerNotFound(peerId)
            let byte0 = data[data.startIndex]
            let pType = PacketType(rawValue: byte0 & 0x0F) ?? .locationPing
            let failedOutcome = SendOutcome(destinationPeerId: peerId, packetType: pType, isSuccess: false, error: err)
            sendOutcomeContinuation?.yield(failedOutcome)
            throw err
        }
        
        rememberForCarry(data)
        let item = try outbox.enqueue(data: data, destinationPeerId: peerId, isRelay: false)
        triggerOutboxFlush()
        
        let outcome = SendOutcome(id: item.id, destinationPeerId: peerId, packetType: item.packetType, isSuccess: true)
        return outcome
    }
    
    /// Submits a complete 56-byte protocol frame for broadcast to all connected direct peers.
    public func broadcastFrame(_ data: Data) async throws {
        try await broadcastPacket(data)
    }
    
    /// Blindly forwards an opaque 56-byte protocol frame to a designated next hop.
    /// Does not decrypt the payload. Mutates only hopCount (+1) and enforces hopLimit.
    public func forwardFrame(_ data: Data, to nextHopPeerId: String) async throws -> SendOutcome {
        guard currentState != .stopped, activeSession != nil else {
            throw TransportError.notStarted
        }
        guard isRelayEnabled else {
            throw TransportError.relayDisabled
        }
        guard data.count == PacketConstants.wirePacketSize else {
            throw TransportError.invalidPacketSize
        }
        
        let byte0 = data[data.startIndex]
        guard (byte0 >> 4) == PacketConstants.protocolVersion else {
            throw PacketCodecError.unsupportedVersion(byte0 >> 4)
        }
        
        let hopLimit = data[data.startIndex + 1]
        let hopCount = data[data.startIndex + 2]
        
        guard hopLimit >= 1 && hopLimit <= PacketConstants.sosHopLimit else {
            throw PacketCodecError.invalidHopLimit(hopLimit)
        }
        guard hopCount < hopLimit else {
            throw PacketCodecError.hopCountExceededLimit(count: hopCount, limit: hopLimit)
        }
        
        guard blePeers.contains(nextHopPeerId) || connections[nextHopPeerId]?.isReady == true else {
            let err = TransportError.peerNotFound(nextHopPeerId)
            let pType = PacketType(rawValue: byte0 & 0x0F) ?? .locationPing
            let failedOutcome = SendOutcome(destinationPeerId: nextHopPeerId, packetType: pType, isSuccess: false, error: err)
            sendOutcomeContinuation?.yield(failedOutcome)
            throw err
        }
        
        // Rate limiting budget check
        let packetType = PacketType(rawValue: byte0 & 0x0F) ?? .locationPing
        if packetType == .sos {
            let allowed = await rateLimiter.consumeSOSToken()
            guard allowed else {
                throw TransportError.rateLimitExceeded("Urgent SOS forwarding budget exceeded")
            }
        } else {
            let allowed = packetType == .chatMessage || packetType == .ack
                ? await rateLimiter.consumeOrdinaryToken() : await rateLimiter.consumeTelemetryToken()
            guard allowed else {
                throw TransportError.rateLimitExceeded("Ordinary relay budget exhausted")
            }
        }
        
        // Mutate only hopCount: Byte 2 incremented by 1
        var mutatedData = data
        mutatedData[mutatedData.startIndex + 2] = hopCount + 1
        
        rememberForCarry(mutatedData)
        let item = try outbox.enqueue(data: mutatedData, destinationPeerId: nextHopPeerId, isRelay: true)
        triggerOutboxFlush()
        
        let outcome = SendOutcome(id: item.id, destinationPeerId: nextHopPeerId, packetType: packetType, isSuccess: true)
        return outcome
    }
    
    // MARK: - Legacy PeerTransport Broadcast & Send
    
    /// Broadcasts a 56-byte wire datagram to all currently connected direct peers.
    public func broadcastPacket(_ data: Data) async throws {
        guard currentState != .stopped, activeSession != nil else {
            throw TransportError.notStarted
        }
        guard data.count == PacketConstants.wirePacketSize else {
            throw TransportError.invalidPacketSize
        }
        
        rememberForCarry(data)
        try outbox.enqueue(data: data, destinationPeerId: nil, isRelay: false)
        triggerOutboxFlush()
    }
    
    /// Transmits a 56-byte wire datagram to a specific connected peer, or broadcasts to direct peers if peerId is not an active transport connection key.
    public func sendPacket(_ data: Data, to peerId: String) async throws {
        if let peer = connections[peerId], peer.isReady {
            _ = try await sendFrame(data, to: peerId)
        } else {
            // Direct connection key not mapped (e.g. member initials target); broadcast over 1-hop direct link
            try await broadcastPacket(data)
        }
    }
    
    // MARK: - Relay Configuration & Outbox State
    
    /// Current queue depth across urgent, normal, and relay queues.
    public func queueDepth() async -> QueueDepth {
        outbox.queueDepth
    }
    
    /// Updates relay participation status.
    public func setRelayParticipation(enabled: Bool) async {
        guard isRelayEnabled != enabled else { return }
        isRelayEnabled = enabled
        if !enabled {
            outbox.clearRelayQueue()
            carryStore.removeForeign()
            logEvent("Mesh relay participation disabled. Purged relay outbox.", level: .info)
        } else {
            logEvent("Mesh relay participation enabled.", level: .info)
        }
        
        // Results may have arrived while relay was disabled. NWBrowser need not emit
        // another change when only our local preference changes.
        if enabled, activeSession != nil {
            handleBrowseResults(latestBrowseResults, changes: [])
        }

        // Update Bonjour TXT record dynamically with relay flag
        if let session = activeSession, let currentListener = listener {
            var txtDict: [String: Data] = [:]
            txtDict["sid"] = PacketConstants.formatSessionId(session.sessionId).data(using: .utf8)
            txtDict["name"] = session.localMemberName.data(using: .utf8)
            txtDict["relay"] = (enabled ? "1" : "0").data(using: .utf8)
            let txtData = NetService.data(fromTXTRecord: txtDict)
            currentListener.service = NWListener.Service(
                name: localPeerId,
                type: serviceType,
                domain: nil,
                txtRecord: txtData
            )
        }
    }
    
    /// Checks if relaying is currently permitted.
    public func isRelayPermitted() async -> Bool {
        isRelayEnabled
    }
    
    // MARK: - Outbox Draining & Wire Dispatch
    
    func triggerOutboxFlush() {
        guard !isFlushingOutbox else { return }
        isFlushingOutbox = true
        
        outboxFlushTask = Task { [weak self] in
            await self?.drainOutbox()
        }
    }
    
    func drainOutbox() async {
        let generation = radioGeneration
        while generation == radioGeneration, let item = outbox.dequeue() {
            guard !item.isRelay || isRelayEnabled else { continue }
            let readyPeers = connections.values.filter { $0.isReady }
            
            if let targetId = item.destinationPeerId {
                // Send to specific target peer
                if blePeers.contains(targetId) {
                    await bleLink?.send(item.packetData, to: targetId)
                    guard generation == radioGeneration else { break }
                    carryStore.markAttempt(item.packetData, to: targetId)
                } else if let peer = connections[targetId], peer.isReady {
                    sendData(item.packetData, on: peer, outboxItem: item)
                } else {
                    logEvent("Target peer \(targetId) unavailable for packet \(item.packetType).", level: .warning)
                    sendErrorsCount += 1
                    let err = TransportError.peerNotFound(targetId)
                    transportErrorsContinuation?.yield(err)
                    
                    Task {
                        await neighborTable.recordTransmissionOutcome(peerId: targetId, success: false)
                    }
                    let failedOutcome = SendOutcome(
                        id: item.id,
                        destinationPeerId: targetId,
                        packetType: item.packetType,
                        isSuccess: false,
                        error: err
                    )
                    sendOutcomeContinuation?.yield(failedOutcome)
                }
            } else {
                // Broadcast to all active direct peers
                await bleLink?.send(item.packetData, to: nil)
                guard generation == radioGeneration else { break }
                for peer in blePeers { carryStore.markAttempt(item.packetData, to: peer) }
                if readyPeers.isEmpty && blePeers.isEmpty {
                    logEvent("No direct peers available to broadcast \(item.packetType).", level: .warning)
                } else {
                    for peer in readyPeers {
                        sendData(item.packetData, on: peer, outboxItem: item)
                    }
                }
            }
        }
        
        if generation == radioGeneration { isFlushingOutbox = false }
    }
    
    func sendData(_ data: Data, on peer: PeerConnection, outboxItem: OutboxItem) {
        let peerId = peer.peerId
        carryStore.markAttempt(data, to: peerId)
        let generation = radioGeneration
        peer.connection.send(content: data, completion: .contentProcessed { [weak self, weak peer] error in
            guard let self = self else { return }
            Task {
                guard await self.isCurrentGeneration(generation) else { return }
                if let error = error {
                    if let p = peer {
                        await self.neighborTable.recordTransmissionOutcome(peerId: p.peerId, success: false)
                    }
                    await self.handleSendError(error, on: peer, outboxItem: outboxItem)
                    
                    let outcome = SendOutcome(
                        id: outboxItem.id,
                        destinationPeerId: peer?.peerId ?? (outboxItem.destinationPeerId ?? "broadcast"),
                        packetType: outboxItem.packetType,
                        isSuccess: false,
                        error: .sendFailed(error.localizedDescription)
                    )
                    await self.recordSendOutcome(outcome)
                } else {
                    if let p = peer {
                        await self.neighborTable.recordTransmissionOutcome(peerId: p.peerId, success: true)
                    }
                    let envelope = try? CleartextEnvelope.deserialize(from: data)
                    await self.recordSendSuccess(envelope, to: peerId, generation: generation)
                    
                    let outcome = SendOutcome(
                        id: outboxItem.id,
                        destinationPeerId: peer?.peerId ?? (outboxItem.destinationPeerId ?? "broadcast"),
                        packetType: outboxItem.packetType,
                        isSuccess: true
                    )
                    await self.recordSendOutcome(outcome)
                }
            }
        })
    }
    
    func recordSendOutcome(_ outcome: SendOutcome) {
        sendOutcomeContinuation?.yield(outcome)
    }
    
    func recordSendSuccess(_ envelope: CleartextEnvelope?, to peerId: String, generation: UUID) {
        guard isCurrentGeneration(generation) else { return }
        packetsSentCount += 1
        if let envelope {
            recordPacket(envelope, direction: .dispatched, peerId: peerId)
        }
    }
    
    func handleSendError(_ error: NWError, on peer: PeerConnection?, outboxItem: OutboxItem) {
        sendErrorsCount += 1
        lastErrorMessage = error.localizedDescription
        logEvent("Transmission error for \(outboxItem.packetType): \(error.localizedDescription)", level: .warning)
        
        // Do not resurrect a foreign retry after the user/power policy stopped relaying.
        guard !outboxItem.isRelay || isRelayEnabled else { return }
        // If retries remain (urgent SOS/ACK or distant relay), requeue with configurable backoff
        if outbox.requeueForRetry(outboxItem) {
            let attempt = outboxItem.attemptCount + 1
            logEvent("Re-queuing \(outboxItem.isRelay ? "stranger relay" : "urgent") packet \(outboxItem.packetType) (attempt \(attempt)/\(outboxItem.maxRetries + 1)).", level: .info)
            let delay = MeshTimingConfiguration.default.distantLinkRetryDelay
            let generation = radioGeneration
            outboxRetryTask?.cancel()
            outboxRetryTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard await self?.isCurrentGeneration(generation) == true else { return }
                await self?.triggerOutboxFlush()
            }
        } else {
            transportErrorsContinuation?.yield(.sendFailed(error.localizedDescription))
        }
    }
}
