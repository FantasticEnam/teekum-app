//
//  SOSACKPayload.swift
//  Teekum
//
//  Created by Nicholas Tanugroho on 19/11/26.
//

import Foundation

public struct SOSACKPayload: Equatable, Sendable {
    public var sosEventId: UInt32
    public var distressedSenderInitials: String
    public var ackStatus: ACKStatus
    public var receivedRssi: Int8

    public init(
        sosEventId: UInt32,
        distressedSenderInitials: String,
        ackStatus: ACKStatus,
        receivedRssi: Int8
    ) {
        self.sosEventId = sosEventId
        self.distressedSenderInitials = InitialsCodec.sanitize(distressedSenderInitials)
        self.ackStatus = ackStatus
        self.receivedRssi = receivedRssi
    }
}
