//
//  FollowIntentPayload.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

import Foundation

/// Follow intent payload transferred via ACK packet subtype (.follow).
public struct FollowIntentPayload: Equatable, Sendable {
    public var senderInitials: String
    public var recipientInitials: String
    public var sosEventId: UInt32?

    public init(senderInitials: String, recipientInitials: String, sosEventId: UInt32? = nil) {
        self.senderInitials = InitialsCodec.sanitize(senderInitials)
        self.recipientInitials = InitialsCodec.sanitize(recipientInitials)
        self.sosEventId = sosEventId
    }

    public func serialize(timestamp: Date = Date()) -> Data {
        ACKPayload.follow(self, timestamp: timestamp, responderInitials: senderInitials).serialize()
    }
}
