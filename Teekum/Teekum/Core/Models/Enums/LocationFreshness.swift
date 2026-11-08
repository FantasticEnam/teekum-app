//
//  LocationFreshness.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Payload-free sample classifications; exact age and accuracy remain in LocationSample.
public enum LocationFreshness: String, CaseIterable, Codable, Sendable {
    /// Sample measured within the active live threshold (< 30 seconds).
    case live
    /// Sample is older than live threshold but still within recent window (30s ... 5m).
    case stale
    /// Sample is very old (> 5 minutes); should be visually dimmed with explicit warning.
    case expired
    /// No valid coordinate sample has been received yet.
    case unavailable

    public var badgeLabel: String {
        switch self {
        case .live:        return "Live"
        case .stale:       return "Stale Fix"
        case .expired:     return "Offline / Old"
        case .unavailable: return "No GPS Fix"
        }
    }
}
