//
//  SendOutcome.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Outcome of a local frame submission or next-hop forwarding attempt.
nonisolated public struct SendOutcome: Sendable, Equatable {
    public let id: UUID
    public let destinationPeerId: String
    public let packetType: PacketType
    public let isSuccess: Bool
    public let error: TransportError?
    public let timestamp: Date
    
    public nonisolated init(
        id: UUID = UUID(),
        destinationPeerId: String,
        packetType: PacketType,
        isSuccess: Bool,
        error: TransportError? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.destinationPeerId = destinationPeerId
        self.packetType = packetType
        self.isSuccess = isSuccess
        self.error = error
        self.timestamp = timestamp
    }
}
