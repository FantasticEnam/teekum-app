//
//  SOSResolvedPayload.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 13/11/26.
//

import Foundation

public struct SOSResolvedPayload: Hashable, Sendable {
    public let senderInitials: String
    public let eventId: UInt32

    public init(senderInitials: String, eventId: UInt32) {
        self.senderInitials = senderInitials
        self.eventId = eventId
    }

    func serialize() throws -> Data {
        guard eventId != 0, let initials = InitialsCodec.encode(senderInitials) else {
            throw PacketCodecError.payloadSerializationFailed
        }
        var bigEndianId = eventId.bigEndian
        var data = Data(bytes: &bigEndianId, count: 4)
        data.append(contentsOf: initials)
        data.append(Data(repeating: 0, count: PacketConstants.encryptedPayloadSize - 6))
        return data
    }

    static func deserialize(from data: Data) throws -> Self {
        guard data.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.payloadDeserializationFailed
        }
        let eventId = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let initials = Array(data.dropFirst(4).prefix(2))
        guard eventId != 0, let sender = InitialsCodec.decode(initials) else {
            throw PacketCodecError.payloadDeserializationFailed
        }
        return Self(senderInitials: sender, eventId: eventId)
    }
}
