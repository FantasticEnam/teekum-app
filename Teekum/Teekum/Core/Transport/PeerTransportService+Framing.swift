//
//  PeerTransportService+Framing.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import Network

// MARK: - Message Framing & Reception

extension PeerTransportService {
    
    func receiveNextBytes(from peer: PeerConnection) {
        let conn = peer.connection
        
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self, weak peer] content, _, isComplete, error in
            guard let self = self, let peer = peer else { return }
            
            Task {
                await self.processReceivedData(peer: peer, content: content, isComplete: isComplete, error: error)
            }
        }
    }
    
    func processReceivedData(peer: PeerConnection, content: Data?, isComplete: Bool, error: NWError?) {
        guard activeSession != nil, connections[peer.peerId] === peer else { return }
        if let error = error {
            logEvent("Read error on \(peer.peerId): \(error.localizedDescription)", level: .warning)
            handleDisconnection(peer: peer, error: error)
            return
        }
        
        if let data = content, !data.isEmpty {
            peer.lastSeen = Date()
            
            do {
                // Ingest chunk into the message framer to handle partial reads / coalescing
                let frames = try peer.framer.processIncomingChunk(data)
                
                for frame in frames {
                    packetsReceivedCount += 1
                    
                    Task {
                        await neighborTable.recordNeighborActivity(
                            peerId: peer.peerId,
                            rssi: nil,
                            isGroupMember: peer.isGroupMember
                        )
                    }
                    
                    let wirePacket = try? RawWirePacket.fromWireData(frame)
                    
                    let inboundFrame = InboundFrame(
                        rawData: frame,
                        rawPacket: wirePacket,
                        sourcePeerId: peer.peerId,
                        receivedRssi: nil,
                        receivedAt: Date()
                    )
                    inboundFrameContinuation?.yield(inboundFrame)
                    
                    if let wirePacket = wirePacket {
                        recordPacket(wirePacket.envelope, direction: .received, peerId: peer.peerId)
                        let inbound = InboundPacket(
                            rawPacket: wirePacket,
                            sourcePeerId: peer.peerId,
                            receivedRssi: nil,
                            receivedAt: Date()
                        )
                        inboundContinuation?.yield(inbound)
                    }
                }
            } catch {
                logEvent("Framer processing failure: \(error.localizedDescription)", level: .error)
            }
        }
        
        if isComplete {
            logEvent("Peer \(peer.peerId) stream closed (EOF received).", level: .info)
            handleDisconnection(peer: peer, error: nil)
            return
        }
        
        // Loop receive
        receiveNextBytes(from: peer)
    }
}
