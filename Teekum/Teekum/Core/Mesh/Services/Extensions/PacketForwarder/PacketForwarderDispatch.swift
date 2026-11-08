//
//  PacketForwarderDispatch.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation

// MARK: - Forwarding Execution & Flooding

extension PacketForwarder {
    
    /// Executes blind forwarding of the mutated wire packet to the specified next-hop peers.
    public func executeForward(
        wireData: Data,
        toPeerIds: [String]
    ) async throws {
        guard let transport = transport else { return }
        for peerId in toPeerIds {
            _ = try await transport.sendFrame(wireData, to: peerId)
        }
    }
    
    /// Floods an opaque wire packet across all active neighbors except the specified peer.
    public func floodPacket(
        wireData: Data,
        exceptPeerId: String?
    ) async throws {
        let neighbors = await neighborTable.activeNeighbors()
        let targets = neighbors.map(\.id).filter { $0 != exceptPeerId }
        try await executeForward(wireData: wireData, toPeerIds: targets)
    }
}
