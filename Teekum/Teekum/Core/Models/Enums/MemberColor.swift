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
        }
    }
        
    /// The display color in SwiftUI.
    public var swiftUIColor: Color {
        switch self {
        case .unset:
            return Color(red: 0.0, green: 0.85, blue: 1.0)
        case .reddish:
            return Color(red: 0.73, green: 0.30, blue: 0.26) // #CB443D
        case .orangeSalmon:
            return Color(red: 0.75, green: 0.45, blue: 0.37) // #CE7059
        case .artyClickOrange:
            return Color(red: 0.92, green: 0.5, blue: 0.19) // #FD7900
        case .apricot:
            return Color(red: 0.93, green: 0.72, blue: 0.47) // #F7B66E
        case .sandrift:
            return Color(red: 0.64, green: 0.58, blue: 0.51) // #A79581
        case .paleBlueLily:
            return Color(red: 0.85, green: 0.93, blue: 0.93) // #D5EEEF
        case .darkSkyBlue:
            return Color(red: 0.33, green: 0.58, blue: 0.86) // #3A97E3
        case .greenishTeal:
            return Color(red: 0.37, green: 0.77, blue: 0.55) // #1EC989
        }
    }
    
    /// The 8 active selectable palette colors for user selection.
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
    
    /// Deterministically maps 1 to 3 uppercase initials into one of the 8 neon palette colors.
    public static func deterministicColor(for initials: String) -> MemberColor {
        let clean = initials.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return .reddish }
        
        let hash = clean.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
        let index = abs(hash) % 8 // 0...7
        let raw = UInt8(index + 1) // 1...8
        return MemberColor(rawValue: raw) ?? .reddish
    }
}
