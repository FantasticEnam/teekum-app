//
//  AcknowledgementStage.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation

/// Verifiable delivery and acknowledgement stages matching Phase 2 specifications.
public enum AcknowledgementStage: String, Equatable, Sendable {
    case idle = "IDLE"
    case localSending = "LOCAL_SENDING"
    case searchingPeers = "SEARCHING_PEERS"
    case relayedAck = "RELAY_ACK"
    case deliveredToFriend = "DELIVERED_TO_FRIEND"
    case deliveryTimedOut = "DELIVERY_TIMED_OUT"
}
