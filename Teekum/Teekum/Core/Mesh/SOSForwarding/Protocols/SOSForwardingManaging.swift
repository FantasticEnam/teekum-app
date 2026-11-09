//
//  SOSForwardingManaging.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public protocol SOSForwardingManaging: Actor {
    /// Dispatches an immediate emergency SOS alert across all mesh links via bounded flooding.
    func broadcastEmergencySOS(
        payload: SOSPayload,
        envelope: CleartextEnvelope,
        symmetricKey: SymmetricKey
    ) async throws
    
    /// Processes an inbound SOS packet: authenticates, sounds siren if new, and routes ACK.
    func handleInboundSOSPacket(
        rawPacket: RawWirePacket,
        fromPeerId: String
    ) async throws
    
    /// Generates and transmits an authenticated ACK back to the distressed member.
    func sendDeliveryACK(
        for originalPacket: RawWirePacket,
        status: ACKStatus
    ) async throws
    
    /// Processes an incoming delivery ACK and updates delivery state.
    func handleInboundACK(
        rawPacket: RawWirePacket,
        fromPeerId: String
    ) async
}
