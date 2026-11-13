//
//  PacketKey.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Canonical compact 7-byte packet identity used for duplicate suppression and routing cache keys.
///
/// Computed from:
/// - `sessionId` (24-bit / 3 bytes, 16.7M combinations)
/// - `sequenceNumber` (32-bit / 4 bytes, memberSlot + counter)
///
/// Note: `hopCount` is explicitly excluded so packet identity remains identical across all hops.
/// With 16,777,215 session IDs, cross-group collision is virtually impossible while keeping RAM minimal.
public struct PacketKey: Hashable, Sendable, CustomStringConvertible {
    public let sessionId: UInt32        // 24-bit value (0x000000...0xFFFFFF)
    public let sequenceNumber: UInt32   // 32-bit sequence counter
    public let type: PacketType?        // Optional packet type discriminator
    
    public init(sessionId: UInt32, sequenceNumber: UInt32, type: PacketType? = nil) {
        self.sessionId = sessionId & PacketConstants.sessionIdMask
        self.sequenceNumber = sequenceNumber
        self.type = type
    }
    
    public init(wirePacket: RawWirePacket) {
        self.sessionId = wirePacket.envelope.sessionId & PacketConstants.sessionIdMask
        self.sequenceNumber = wirePacket.envelope.sequenceNumber
        self.type = wirePacket.envelope.type
    }
    
    public init?(wireData: Data) {
        guard wireData.count >= 10 else { return nil }
        let typeRaw = wireData[wireData.startIndex] & 0x0F
        let pType = PacketType(rawValue: typeRaw)
        let b3 = UInt32(wireData[wireData.startIndex + 3])
        let b4 = UInt32(wireData[wireData.startIndex + 4])
        let b5 = UInt32(wireData[wireData.startIndex + 5])
        let sid = (b3 << 16) | (b4 << 8) | b5
        let seq = wireData.subdata(in: (wireData.startIndex + 6)..<(wireData.startIndex + 10)).withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self).bigEndian
        }
        self.sessionId = sid
        self.sequenceNumber = seq
        self.type = pType
    }
    
    public var description: String {
        let typeStr = type.map { "\($0)" } ?? "any"
        return "PacketKey(sid: 0x\(PacketConstants.formatSessionId(sessionId)), seq: \(sequenceNumber), type: \(typeStr))"
    }
}
