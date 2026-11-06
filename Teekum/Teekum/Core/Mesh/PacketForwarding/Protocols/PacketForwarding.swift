//
//  PacketForwarding.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public protocol PacketForwarding: Actor {
    /// Evaluates an inbound wire packet to determine whether it should be delivered locally,
    /// forwarded to other peers, or dropped.
    func evaluateInboundPacket(
        wireData: Data,
        fromPeerId: String
    ) async -> ForwardingDecision
    
    /// Executes the blind forwarding of a packet across designated next hops.
    func executeForward(
        wireData: Data,
        toPeerIds: [String]
    ) async throws
    
    /// Bounded flooding fallback: transmits packet to all connected peers except originator.
    func floodPacket(
        wireData: Data,
        exceptPeerId: String?
    ) async throws
}
