//
//  ACKPayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum ACKPayload: Equatable, Sendable {
    case chat(ChatACKPayload, timestamp: Date, responderInitials: String)
    case sos(SOSACKPayload, timestamp: Date, responderInitials: String)
    case follow(FollowIntentPayload, timestamp: Date, responderInitials: String)

    public var subtype: ACKSubtype {
        switch self {
        case .chat: return .chat
        case .sos: return .sos
        case .follow: return .follow
        }
    }

    public var timestamp: Date {
        switch self {
        case .chat(_, let ts, _): return ts
        case .sos(_, let ts, _): return ts
        case .follow(_, let ts, _): return ts
        }
    }

    public var responderInitials: String {
        switch self {
        case .chat(_, _, let resp): return resp
        case .sos(_, _, let resp): return resp
        case .follow(_, _, let resp): return resp
        }
    }

    public func serialize() -> Data {
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        // Byte 0: subtype
        data.append(subtype.rawValue)

        // Bytes 1..4: timestamp (UInt32 Unix seconds)
        var ts = UInt32(timestamp.timeIntervalSince1970).bigEndian
        data.append(Data(bytes: &ts, count: 4))

        // Bytes 5..6: responderInitials (2 bytes)
        let respBytes = InitialsCodec.encode(responderInitials) ?? [0, 0]
        data.append(contentsOf: respBytes)

        switch self {
        case .chat(let chatPayload, _, _):
            // Bytes 7..10: ackedSeqNumber (UInt32)
            var seq = chatPayload.ackedSeqNumber.bigEndian
            data.append(Data(bytes: &seq, count: 4))

            // Bytes 11..12: ackedSenderInitials (2 bytes)
            let ackedBytes = InitialsCodec.encode(chatPayload.ackedSenderInitials) ?? [0, 0]
            data.append(contentsOf: ackedBytes)

            // Byte 13: ackStatus (UInt8)
            data.append(chatPayload.ackStatus.rawValue)

            // Byte 14: receivedRssi (Int8)
            var rssi = chatPayload.receivedRssi
            data.append(Data(bytes: &rssi, count: 1))

            // Bytes 15..29: 15 zero reserved padding bytes
            data.append(Data(repeating: 0, count: 15))

        case .sos(let sosPayload, _, _):
            // Bytes 7..10: sosEventId (UInt32)
            var eventId = sosPayload.sosEventId.bigEndian
            data.append(Data(bytes: &eventId, count: 4))

            // Bytes 11..12: distressedSenderInitials (2 bytes)
            let distressedBytes = InitialsCodec.encode(sosPayload.distressedSenderInitials) ?? [0, 0]
            data.append(contentsOf: distressedBytes)

            // Byte 13: ackStatus (UInt8)
            data.append(sosPayload.ackStatus.rawValue)

            // Byte 14: receivedRssi (Int8)
            var rssi = sosPayload.receivedRssi
            data.append(Data(bytes: &rssi, count: 1))

            // Bytes 15..29: 15 zero reserved padding bytes
            data.append(Data(repeating: 0, count: 15))

        case .follow(let followPayload, _, _):
            // Bytes 7..8: recipientInitials (2 bytes)
            let recipientBytes = InitialsCodec.encode(followPayload.recipientInitials) ?? [0, 0]
            data.append(contentsOf: recipientBytes)

            // Bytes 9..12: sosEventId (UInt32)
            var eventId = (followPayload.sosEventId ?? 0).bigEndian
            data.append(Data(bytes: &eventId, count: 4))

            // Bytes 13..29: 17 zero reserved padding bytes
            data.append(Data(repeating: 0, count: 17))
        }

        return data
    }

    public static func deserialize(from data: Data) throws -> ACKPayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }

        let subtypeRaw = data[data.startIndex]
        guard let subtype = ACKSubtype(rawValue: subtypeRaw) else {
            throw PacketCodecError.payloadDeserializationFailed
        }

        let tsRaw = data.subdata(in: (data.startIndex + 1)..<(data.startIndex + 5)).withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self).bigEndian
        }
        let date = Date(timeIntervalSince1970: TimeInterval(tsRaw))

        let respBytes = [data[data.startIndex + 5], data[data.startIndex + 6]]
        let respInitials = InitialsCodec.decode(respBytes) ?? "UNK"

        switch subtype {
        case .chat:
            let seq = data.subdata(in: (data.startIndex + 7)..<(data.startIndex + 11)).withUnsafeBytes {
                $0.loadUnaligned(as: UInt32.self).bigEndian
            }
            let ackedBytes = [data[data.startIndex + 11], data[data.startIndex + 12]]
            let ackedInitials = InitialsCodec.decode(ackedBytes) ?? "UNK"
            let statusByte = data[data.startIndex + 13]
            let rssi = Int8(bitPattern: data[data.startIndex + 14])
            let status = ACKStatus(rawValue: statusByte) ?? .deliveredToFriend

            let chat = ChatACKPayload(
                ackedSeqNumber: seq,
                ackedSenderInitials: ackedInitials,
                ackStatus: status,
                receivedRssi: rssi
            )
            return .chat(chat, timestamp: date, responderInitials: respInitials)

        case .sos:
            let eventId = data.subdata(in: (data.startIndex + 7)..<(data.startIndex + 11)).withUnsafeBytes {
                $0.loadUnaligned(as: UInt32.self).bigEndian
            }
            let distressedBytes = [data[data.startIndex + 11], data[data.startIndex + 12]]
            let distressedInitials = InitialsCodec.decode(distressedBytes) ?? "UNK"
            let statusByte = data[data.startIndex + 13]
            let rssi = Int8(bitPattern: data[data.startIndex + 14])
            let status = ACKStatus(rawValue: statusByte) ?? .deliveredToFriend

            let sos = SOSACKPayload(
                sosEventId: eventId,
                distressedSenderInitials: distressedInitials,
                ackStatus: status,
                receivedRssi: rssi
            )
            return .sos(sos, timestamp: date, responderInitials: respInitials)

        case .follow:
            let recipientBytes = [data[data.startIndex + 7], data[data.startIndex + 8]]
            let recipientInitials = InitialsCodec.decode(recipientBytes) ?? "UNK"
            let eventId = data.subdata(in: (data.startIndex + 9)..<(data.startIndex + 13)).withUnsafeBytes {
                $0.loadUnaligned(as: UInt32.self).bigEndian
            }
            let follow = FollowIntentPayload(
                senderInitials: respInitials,
                recipientInitials: recipientInitials,
                sosEventId: eventId == 0 ? nil : eventId
            )
            return .follow(follow, timestamp: date, responderInitials: respInitials)
        }
    }
}
