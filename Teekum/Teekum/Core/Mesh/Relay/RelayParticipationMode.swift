//
//  RelayParticipationMode.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public enum RelayParticipationMode: String, Sendable, Codable, CaseIterable {
    case disabled            // Relay OFF: never forwards stranger packets
    case communalRelayActive // Always relay while battery >= 20%
    case timed30Minutes      // Relay for 30 minutes, then automatically pause
}
