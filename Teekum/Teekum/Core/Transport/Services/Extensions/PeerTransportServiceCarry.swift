//
//  PeerTransportServiceCarry.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation

extension PeerTransportService {
    func updateBLEPeers(_ peers: [String], generation: UUID) async {
        guard generation == radioGeneration, activeSession != nil else { return }
        for peer in blePeers where !peers.contains(peer) {
            carryStore.disconnected(peer)
            await neighborTable.removeNeighbor(peerId: peer)
            guard isCurrentGeneration(generation) else { return }
        }
        blePeers = peers
        for peer in peers {
            await neighborTable.registerOrUpdateNeighbor(id: peer, displayName: "Bluetooth peer", state: .connected,
                rssi: nil, isGroupMember: false, capabilities: .standardMesh)
            guard isCurrentGeneration(generation) else { return }
        }
        refreshConnectionState()
        emitPeerUpdates()
    }

    func receiveBLE(_ data: Data, from peer: String, generation: UUID) {
        guard generation == radioGeneration, activeSession != nil,
              let packet = try? RawWirePacket.fromWireData(data) else { return }
        packetsReceivedCount += 1
        recordPacket(packet.envelope, direction: .received, peerId: peer)
        inboundContinuation?.yield(InboundPacket(rawPacket: packet, sourcePeerId: peer))
        inboundFrameContinuation?.yield(InboundFrame(rawData: data, rawPacket: packet, sourcePeerId: peer))
    }

    public func retainReceivedForCarry(_ packet: RawWirePacket, excludingPeerId: String? = nil) {
        guard activeSession != nil,
              packet.envelope.hopCount < packet.envelope.hopLimit else { return }
        var forwarded = packet
        forwarded.envelope.hopCount += 1
        if let data = try? forwarded.toWireData() { rememberForCarry(data, excludingPeerId: excludingPeerId) }
    }

    func rememberForCarry(_ data: Data, excludingPeerId: String? = nil) {
        guard let session = activeSession, let packet = try? RawWirePacket.fromWireData(data) else { return }
        let foreign = packet.envelope.sessionId != session.sessionId
        guard !foreign || isRelayEnabled else { return }
        carryStore.remember(data, isForeign: foreign, excludingPeerId: excludingPeerId)
    }

    public func updateCarryPowerMetrics(_ batteryLevel: Float, isLowPowerMode: Bool) {
        carryPowerPermitted = batteryLevel >= 0.20 && !isLowPowerMode
    }

    func replayCarriedMessage() async {
        guard carryPowerPermitted, activeSession != nil, currentState != .stopped else { return }
        let peers = (connections.values.filter { $0.isReady }.map(\.peerId) + blePeers).sorted()
        let generation = radioGeneration
        guard carryStore.nextTransmission(to: peers) != nil,
              await rateLimiter.consumeOrdinaryToken(), activeSession != nil,
              generation == radioGeneration, carryPowerPermitted else { return }
        guard let next = carryStore.nextTransmission(to: peers),
              !next.isForeign || isRelayEnabled else { return }
        do {
            // Already incremented when custody was taken: retries never spend another hop.
            try outbox.enqueue(data: next.data, destinationPeerId: next.peer, isRelay: next.isForeign)
            triggerOutboxFlush()
        } catch {
            logEvent("Carry enqueue deferred: \(error)", level: .warning)
        }
    }
}
