//
//  MemberColor.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import SwiftUI

/// 1-byte coded color enum for personal member color-coding in TeeKum.
/// Optimized for AMOLED #000000 dark mode with vibrant neon festival colors.
/// Pure Red is intentionally excluded and strictly reserved for Emergency SOS.
public enum MemberColor: UInt8, CaseIterable, Identifiable, Sendable {
    case unset            = 0x00
    case reddish          = 0x01
    case orangeSalmon     = 0x02
    case artyClickOrange  = 0x03
    case apricot          = 0x04
    case sandrift         = 0x05
    case paleBlueLily     = 0x06
    case darkSkyBlue      = 0x07
    case greenishTeal     = 0x08
    case yellow           = 0x09
    
    public var id: UInt8 { rawValue }
    
    public var name: String {
        switch self {
        case .unset:          return "Automatic"
        case .reddish:        return "Reddish"
        case .orangeSalmon:   return "Orange Salmon"
        case .artyClickOrange:return "ArtyClick Orange"
        case .apricot:        return "Apricot"
        case .sandrift:       return "Sandrift"
        case .paleBlueLily:   return "Pale Blue Lily"
        case .darkSkyBlue:    return "Dark Sky Blue"
        case .greenishTeal:   return "Greenish Teal"
        case .yellow:         return "Yellow"
        }
    }
        
    /// The display color in SwiftUI.
    public var swiftUIColor: Color {
        switch self {
        case .unset:
            return Color(red: 0.0, green: 0.85, blue: 1.0)
        case .reddish: return .redProfile
        case .orangeSalmon: return .peachProfile
        case .artyClickOrange: return .orangeProfile
        case .apricot: return .creamProfile
        case .sandrift: return .greyProfile
        case .paleBlueLily: return .whiteProfile
        case .darkSkyBlue: return .blueProfile
        case .greenishTeal: return .greenProfile
        case .yellow: return .yellowProfile
        }
    }
    
    /// Explicit profile colors available to select.
    public static var selectableColors: [MemberColor] {
        allCases.filter { $0 != .unset }
    }
    
    /// Resolves the color code into a specific `MemberColor`.
    /// If `code == 0x00` (unset / legacy zero-padding) or invalid, deterministically hashes `initials` mod 8.
    public static func resolve(code: UInt8, initials: String) -> MemberColor {
        if let specific = MemberColor(rawValue: code), specific != .unset {
            return specific
        }
        return deterministicColor(for: initials)
    }
    
    /// Uses the original eight-color palette to keep automatic colors stable.
    public static func deterministicColor(for initials: String) -> MemberColor {
        let clean = initials.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return .reddish }
        
        let hash = clean.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
        let index = abs(hash) % 8 // 0...7
        let raw = UInt8(index + 1) // 1...8
        return MemberColor(rawValue: raw) ?? .reddish
    }
}
