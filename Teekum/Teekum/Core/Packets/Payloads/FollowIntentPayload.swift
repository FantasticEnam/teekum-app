//
//  FollowIntentPayload.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

import Foundation

/// Uses reserved ACK bytes so older peers can forward it without confirming delivery.
public struct FollowIntentPayload {
    let senderInitials: String
    let recipientInitials: String
    let sosEventId: UInt32?

    func serialize() -> Data {
        var data = ACKPayload(ackedSeqNumber: 0, ackedSenderInitials: recipientInitials,
            ackStatus: .deliveredToFriend, receivedRssi: 0, originalEventId: 0,
            responderInitials: senderInitials).serialize()
        data[18] = 1
        var event = (sosEventId ?? 0).bigEndian
        withUnsafeBytes(of: &event) { data.replaceSubrange(19..<23, with: $0) }
        return data
    }

    static func decode(_ data: Data, ack: ACKPayload) -> Self? {
        guard data.count == PacketConstants.encryptedPayloadSize,
              ack.ackedSeqNumber == 0, ack.originalEventId == 0, data[data.startIndex + 18] == 1,
              let recipient = InitialsCodec.decode(Array(data.dropFirst(4).prefix(2))),
              let sender = InitialsCodec.decode(Array(data.dropFirst(16).prefix(2))),
              sender != recipient else { return nil }
        let event = data.dropFirst(19).prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        return Self(senderInitials: sender, recipientInitials: recipient, sosEventId: event == 0 ? nil : event)
    }
}
