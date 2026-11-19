//
//  ChatACKPayload.swift
//  Teekum
//
//  Created by Nicholas Tanugroho on 19/11/26.
//

import Foundation

public struct ChatACKPayload: Equatable, Sendable {
    public var ackedSeqNumber: UInt32
    public var ackedSenderInitials: String
    public var ackStatus: ACKStatus
    public var receivedRssi: Int8

    public init(
        ackedSeqNumber: UInt32,
        ackedSenderInitials: String,
        ackStatus: ACKStatus,
        receivedRssi: Int8
    ) {
        self.ackedSeqNumber = ackedSeqNumber
        self.ackedSenderInitials = InitialsCodec.sanitize(ackedSenderInitials)
        self.ackStatus = ackStatus
        self.receivedRssi = receivedRssi
    }
}
