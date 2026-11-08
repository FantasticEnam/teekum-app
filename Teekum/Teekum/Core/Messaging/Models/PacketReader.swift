//
//  PacketReader.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation

/// Bounds-checked binary stream reader that prevents buffer overflows and underflows.
public struct PacketReader: Sendable {
    private let data: Data
    public private(set) var offset: Int
    
    public init(data: Data) {
        self.data = data
        self.offset = data.startIndex
    }
    
    public var remainingBytes: Int {
        data.endIndex - offset
    }
    
    public mutating func readUInt8() throws -> UInt8 {
        guard remainingBytes >= 1 else { throw PacketCodecError.bufferUnderflow }
        let byte = data[offset]
        offset += 1
        return byte
    }
    
    public mutating func readUInt16BigEndian() throws -> UInt16 {
        guard remainingBytes >= 2 else { throw PacketCodecError.bufferUnderflow }
        let sub = data.subdata(in: offset..<(offset + 2))
        offset += 2
        return sub.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
    }
    
    public mutating func readUInt24BigEndian() throws -> UInt32 {
        guard remainingBytes >= 3 else { throw PacketCodecError.bufferUnderflow }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        offset += 3
        return (b0 << 16) | (b1 << 8) | b2
    }
    
    public mutating func readUInt32BigEndian() throws -> UInt32 {
        guard remainingBytes >= 4 else { throw PacketCodecError.bufferUnderflow }
        let sub = data.subdata(in: offset..<(offset + 4))
        offset += 4
        return sub.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }
    
    public mutating func readInt32BigEndian() throws -> Int32 {
        guard remainingBytes >= 4 else { throw PacketCodecError.bufferUnderflow }
        let sub = data.subdata(in: offset..<(offset + 4))
        offset += 4
        return sub.withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
    }
    
    public mutating func readBytes(count: Int) throws -> Data {
        guard remainingBytes >= count else { throw PacketCodecError.bufferUnderflow }
        let sub = data.subdata(in: offset..<(offset + count))
        offset += count
        return sub
    }
}
