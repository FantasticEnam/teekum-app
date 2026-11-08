//
//  SOSDeliveryState.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Payload-free delivery phases for Emergency SOS; event/recipient details stay in SOSEvent.
public enum SOSDeliveryState: String, CaseIterable, Codable, Sendable {
    case idle
    case countdown
    case localSending
    case searchingPeers
    case relayedAck
    case deliveredToFriend
    case failed

    public var title: String {
        switch self {
        case .idle:              return "SOS Ready"
        case .countdown:         return "Hold for SOS..."
        case .localSending:      return "Broadcasting SOS over Radio..."
        case .searchingPeers:    return "Searching for Nearby Friends / Relays..."
        case .relayedAck:        return "Relayed by Mesh Hop (Not Yet Friend)"
        case .deliveredToFriend: return "Delivered to Friend Devices!"
        case .failed:            return "SOS Delivery Unconfirmed"
        }
    }

    public var systemImage: String {
        switch self {
        case .idle:              return "sos"
        case .countdown:         return "timer"
        case .localSending:      return "antenna.radiowaves.left.and.right"
        case .searchingPeers:    return "waveform.badge.magnifyingglass"
        case .relayedAck:        return "arrow.triangle.branch"
        case .deliveredToFriend: return "checkmark.shield.fill"
        case .failed:            return "exclamationmark.triangle.fill"
        }
    }
}
