//
//  PeerTransportService+Framing.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import Network

extension PeerTransportService {
    func receiveFrames(on connection: NetworkConnection<TCP>, peerID: String, token: UUID, generation: UUID) async throws {
        let framer = StreamMessageFramer()
        while !Task.isCancelled {
            let (data, metadata) = try await connection.receive(atLeast: 1, atMost: 4096)
            guard isCurrentGeneration(generation), !Task.isCancelled,
                  let peer = connections[peerID], peer.token == token else { return }
            if peer.isReady, peer.isGroupMember || isRelayEnabled, !data.isEmpty {
                peer.lastSeen = .now
                let frames = try framer.processIncomingChunk(data)
                for frame in frames { acceptFrame(frame, from: peerID, generation: generation) }
                if !frames.isEmpty {
                    await neighborTable.recordNeighborActivity(peerId: peerID, rssi: nil, isGroupMember: peer.isGroupMember)
                }
            }
            if metadata.endOfStream { return }
        }
    }

    func acceptFrame(_ data: Data, from peerID: String, generation: UUID) {
        guard isCurrentGeneration(generation), let packet = try? RawWirePacket.fromWireData(data) else { return }
        let receivedAt = Date.now
        packetsReceivedCount += 1
        recordPacket(packet.envelope, direction: .received, peerId: peerID)
        inboundFrameContinuation?.yield(InboundFrame(rawData: data, rawPacket: packet, sourcePeerId: peerID, receivedAt: receivedAt))
        inboundContinuation?.yield(InboundPacket(rawPacket: packet, sourcePeerId: peerID, receivedAt: receivedAt))
    }
}
