//
//  InboundPacket.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// An incoming 56-byte packet received from the peer-to-peer radio transport.
public struct InboundPacket: Sendable {
    public let rawPacket: RawWirePacket
    public let sourcePeerId: String
    public let receivedRssi: Int8?
    public let receivedAt: Date
    
    public init(
        rawPacket: RawWirePacket,
        sourcePeerId: String,
        receivedRssi: Int8? = nil,
        receivedAt: Date = Date()
    ) {
        self.rawPacket = rawPacket
        self.sourcePeerId = sourcePeerId
        self.receivedRssi = receivedRssi
        self.receivedAt = receivedAt
    }
}
