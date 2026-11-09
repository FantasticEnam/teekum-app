//
//  ForwardingDecision.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public enum ForwardingDecision: Sendable, Equatable {
    case deliverLocally                              // Packet is addressed to our session and authenticated
    case forward(mutatedWireData: Data, nextHops: [String]) // Relay blindly
    case dropDuplicate                              // Already seen in 5m LRU cache
    case dropHopLimitExceeded                       // hopCount >= hopLimit (max 8)
    case dropRateLimitExceeded                      // Exceeded 2 pkts/sec budget
    case dropPolicyDisabled                         // Relay participation is OFF or battery < 20%
    case dropMalformed                              // Size != 56B or invalid version
    case dropSecurityVerificationFailed             // Authenticated tag mismatch, replay rejected, or forged packet
}
