//
//  PeerTransportService+Sending.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

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
        
        guard connections[nextHopPeerId]?.isReady == true else {
            let err = TransportError.peerNotFound(nextHopPeerId)
            let pType = PacketType(rawValue: byte0 & 0x0F) ?? .locationPing
            let failedOutcome = SendOutcome(destinationPeerId: nextHopPeerId, packetType: pType, isSuccess: false, error: err)
            sendOutcomeContinuation?.yield(failedOutcome)
            throw err
        }
        
        let generation = radioGeneration
        // Rate limiting budget check
        let packetType = PacketType(rawValue: byte0 & 0x0F) ?? .locationPing
        if packetType == .sos {
            let allowed = await rateLimiter.consumeSOSToken()
            guard allowed else {
                throw TransportError.rateLimitExceeded("Urgent SOS forwarding budget exceeded")
            }
        } else {
            let allowed = [.chatMessage, .ack, .sosResolved].contains(packetType)
                ? await rateLimiter.consumeOrdinaryToken() : await rateLimiter.consumeTelemetryToken()
            guard allowed else {
                throw TransportError.rateLimitExceeded("Ordinary relay budget exhausted")
            }
        }
        
        guard isCurrentGeneration(generation), isRelayEnabled else { throw TransportError.relayDisabled }

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
        
        let isSOSResolution = (data[data.startIndex] & 0x0F) == PacketType.sosResolved.rawValue
        if !isSOSResolution { rememberForCarry(data) }
        try outbox.enqueue(data: data, destinationPeerId: nil, isRelay: false)
        // A failed resolution enqueue leaves the SOS active, so don't retain it for later sending.
        if isSOSResolution { rememberForCarry(data) }
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
            for (id, retry) in outboxRetries.filter({ $0.value.isRelay }) {
                retry.task.cancel()
                outboxRetries.removeValue(forKey: id)
            }
            logEvent("Mesh relay participation disabled. Purged relay outbox.", level: .info)
        } else {
            logEvent("Mesh relay participation enabled.", level: .info)
        }
        
        // Re-exchange the relay flag on outside-group links when participation changes.
        let generation = radioGeneration
        for peer in connections.values.filter({ !$0.isGroupMember }) {
            linkTasks[peer.token]?.cancel()
            await removeLink(peerID: peer.peerId, token: peer.token, generation: generation)
            guard isCurrentGeneration(generation), isRelayEnabled == enabled else { return }
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
        while isCurrentGeneration(generation), !Task.isCancelled, let item = outbox.dequeue() {
            guard !item.isRelay || isRelayEnabled else { continue }
            if let target = item.destinationPeerId {
                await sendData(item, to: target, generation: generation)
            } else {
                let targets = connections.values.filter(\.isReady).map(\.peerId)
                if targets.isEmpty {
                    logEvent("No direct peers available to broadcast \(item.packetType).", level: .warning)
                }
                await withTaskGroup(of: Void.self) { tasks in
                    for target in targets {
                        tasks.addTask { [weak self] in
                            await self?.sendData(item, to: target, generation: generation)
                        }
                    }
                }
            }
        }
        if isCurrentGeneration(generation) { isFlushingOutbox = false }
    }

    private func sendData(_ item: OutboxItem, to peerId: String, generation: UUID) async {
        guard isCurrentGeneration(generation), !Task.isCancelled, !item.isRelay || isRelayEnabled else { return }
        guard let peer = connections[peerId], peer.isReady, peer.isGroupMember || isRelayEnabled else {
            let error = TransportError.peerNotFound(peerId)
            logEvent("Target peer \(peerId) unavailable for packet \(item.packetType).", level: .warning)
            sendErrorsCount += 1
            transportErrorsContinuation?.yield(error)
            sendOutcomeContinuation?.yield(.init(id: item.id, destinationPeerId: peerId,
                packetType: item.packetType, isSuccess: false, error: error))
            await neighborTable.recordTransmissionOutcome(peerId: peerId, success: false)
            return
        }

        carryStore.markAttempt(item.packetData, to: peerId)
        do {
            try await peer.connection.send(item.packetData)
            guard isCurrentGeneration(generation), !Task.isCancelled else { return }
            recordSendSuccess(try? CleartextEnvelope.deserialize(from: item.packetData), to: peerId, generation: generation)
            sendOutcomeContinuation?.yield(.init(id: item.id, destinationPeerId: peerId,
                packetType: item.packetType, isSuccess: true))
            await neighborTable.recordTransmissionOutcome(peerId: peerId, success: true)
        } catch {
            guard isCurrentGeneration(generation), !Task.isCancelled else { return }
            handleSendError(error, outboxItem: item)
            sendOutcomeContinuation?.yield(.init(id: item.id, destinationPeerId: peerId,
                packetType: item.packetType, isSuccess: false, error: .sendFailed(error.localizedDescription)))
            await neighborTable.recordTransmissionOutcome(peerId: peerId, success: false)
        }
    }

    func recordSendSuccess(_ envelope: CleartextEnvelope?, to peerId: String, generation: UUID) {
        guard isCurrentGeneration(generation) else { return }
        packetsSentCount += 1
        if let envelope {
            recordPacket(envelope, direction: .dispatched, peerId: peerId)
        }
    }
    
    func handleSendError(_ error: Error, outboxItem: OutboxItem) {
        sendErrorsCount += 1
        lastErrorMessage = error.localizedDescription
        logEvent("Transmission error for \(outboxItem.packetType): \(error.localizedDescription)", level: .warning)
        
        guard !outboxItem.isRelay || isRelayEnabled else { return }
        guard outboxRetries[outboxItem.id] == nil else { return }
        let retryCapacity = outbox.maxUrgentCapacity + outbox.maxChatCapacity + outbox.maxRelayCapacity
        guard outboxItem.attemptCount < outboxItem.maxRetries, outboxRetries.count < retryCapacity else {
            transportErrorsContinuation?.yield(.sendFailed(error.localizedDescription))
            return
        }

        let delay = MeshTimingConfiguration.default.distantLinkRetryDelay
        let generation = radioGeneration
        let task = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            await self?.enqueueRetry(outboxItem, generation: generation)
        }
        outboxRetries[outboxItem.id] = (task, outboxItem.isRelay)
    }

    private func enqueueRetry(_ item: OutboxItem, generation: UUID) {
        // Delay the requeue itself so an already running drain can't bypass the backoff.
        guard isCurrentGeneration(generation), !Task.isCancelled,
              outboxRetries.removeValue(forKey: item.id) != nil,
              !item.isRelay || isRelayEnabled, outbox.requeueForRetry(item) else { return }
        triggerOutboxFlush()
    }
}
