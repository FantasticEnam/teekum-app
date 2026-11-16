//
//  PeerTransportService+Carry.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation

extension PeerTransportService {
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
        let peers = connections.values.filter(\.isReady).map(\.peerId).sorted()
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
