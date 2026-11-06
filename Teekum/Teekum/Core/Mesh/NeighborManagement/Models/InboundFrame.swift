//
//  InboundFrame.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Complete received protocol frame carrying raw wire bytes and optional decoded packet.
nonisolated public struct InboundFrame: Sendable {
    public let rawData: Data
    public let rawPacket: RawWirePacket?
    public let sourcePeerId: String
    public let receivedRssi: Int8?
    public let receivedAt: Date
    
    public nonisolated init(
        rawData: Data,
        rawPacket: RawWirePacket? = nil,
        sourcePeerId: String,
        receivedRssi: Int8? = nil,
        receivedAt: Date = Date()
    ) {
        self.rawData = rawData
        self.rawPacket = rawPacket
        self.sourcePeerId = sourcePeerId
        self.receivedRssi = receivedRssi
        self.receivedAt = receivedAt
    }
}
