//
//  NearbyTokenFragment.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

import Foundation

public struct NearbyTokenFragment {
    static let chunkSize = 19
    static let maxFragments = 54

    let sender: String
    let recipient: String?
    let advertisedColor: UInt8?
    private let transfer: UInt32
    private let index: Int
    private let count: Int
    private let chunk: Data

    init?(payload: Data) {
        guard payload.count == PacketConstants.encryptedPayloadSize else { return nil }
        let bytes = Array(payload)
        guard let sender = InitialsCodec.decode(Array(bytes[0..<2])) else { return nil }
        self.sender = sender
        if bytes[2] == 0, bytes[3] == 0, bytes[5...].allSatisfy({ $0 == 0 }) {
            recipient = nil
            advertisedColor = bytes[4]
            transfer = 0
            index = 0
            count = 0
            chunk = Data()
            return
        }
        guard let recipient = InitialsCodec.decode(Array(bytes[2..<4])) else { return nil }
        let index = Int(bytes[8])
        let count = Int(bytes[9])
        let size = Int(bytes[10])
        guard (1...Self.maxFragments).contains(count), index < count,
              (1...Self.chunkSize).contains(size),
              index == count - 1 || size == Self.chunkSize else { return nil }
        self.recipient = recipient
        advertisedColor = nil
        transfer = bytes[4..<8].reduce(0) { ($0 << 8) | UInt32($1) }
        self.index = index
        self.count = count
        chunk = Data(bytes[11..<(11 + size)])
    }

    static func advertisement(from sender: String, color: UInt8) -> Data? {
        guard let source = InitialsCodec.encode(sender) else { return nil }
        return Data(source + [0, 0, color] + Array(repeating: 0, count: 25))
    }

    static func payloads(for token: Data, from sender: String, to recipient: String, transfer: UInt32) -> [Data] {
        guard !token.isEmpty, token.count <= chunkSize * maxFragments,
              let source = InitialsCodec.encode(sender), let destination = InitialsCodec.encode(recipient) else { return [] }
        let count = (token.count + chunkSize - 1) / chunkSize
        var transferBytes = transfer.bigEndian
        let header = source + destination + withUnsafeBytes(of: &transferBytes) { Array($0) }
        return (0..<count).map { index in
            let start = token.startIndex + index * chunkSize
            let chunk = token[start..<min(start + chunkSize, token.endIndex)]
            var payload = Data(header + [UInt8(index), UInt8(count), UInt8(chunk.count)])
            payload.append(contentsOf: chunk)
            payload.append(Data(repeating: 0, count: chunkSize - chunk.count))
            return payload
        }
    }

    struct Assembly {
        private var transfer: UInt32?
        private var count = 0
        private var chunks: [Int: Data] = [:]

        mutating func receive(_ fragment: NearbyTokenFragment) -> Data? {
            guard fragment.recipient != nil else { return nil }
            if fragment.transfer != transfer {
                transfer = fragment.transfer
                count = fragment.count
                chunks.removeAll()
            }
            guard fragment.count == count else { return nil }
            chunks[fragment.index] = fragment.chunk
            guard chunks.count == count else { return nil }
            var token = Data()
            for index in 0..<count {
                guard let chunk = chunks[index] else { return nil }
                token.append(chunk)
            }
            chunks.removeAll()
            return token
        }
    }
}
