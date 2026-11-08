//
//  PacketWritter.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation

/// Fast, bounds-checked binary buffer builder for fixed-size wire datagrams.
public struct PacketWriter: Sendable {
    public private(set) var data: Data
    
    public init(capacity: Int) {
        self.data = Data(capacity: capacity)
    }
    
    public mutating func writeUInt8(_ value: UInt8) {
        data.append(value)
    }
    
    public mutating func writeUInt16BigEndian(_ value: UInt16) {
        var be = value.bigEndian
        data.append(Data(bytes: &be, count: MemoryLayout<UInt16>.size))
    }
    
    public mutating func writeUInt24BigEndian(_ value: UInt32) {
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }
    
    public mutating func writeUInt32BigEndian(_ value: UInt32) {
        var be = value.bigEndian
        data.append(Data(bytes: &be, count: MemoryLayout<UInt32>.size))
    }
    
    public mutating func writeInt32BigEndian(_ value: Int32) {
        var be = value.bigEndian
        data.append(Data(bytes: &be, count: MemoryLayout<Int32>.size))
    }
    
    public mutating func writeBytes(_ bytes: Data) {
        data.append(bytes)
    }
    
    public mutating func writeZeroPadding(count: Int) {
        data.append(contentsOf: [UInt8](repeating: 0x00, count: count))
    }
}
