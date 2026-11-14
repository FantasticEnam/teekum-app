//
//  PairingProfileColor.swift
//  Teekum
//
//  Created by Ari Hasan on 07/11/26.
//

import SwiftUI

enum PairingProfileColor: String, CaseIterable, Identifiable, Codable {
    case yellow, red, green, purple, pink

    var id: String { rawValue }

    var wireColorCode: UInt8 { memberColor.rawValue }
    var color: Color { memberColor.swiftUIColor }

    private var memberColor: MemberColor {
        switch self {
        case .red: .reddish
        case .green: .greenishTeal
        case .yellow: .yellow
        case .purple: .purple
        case .pink: .pink
        }
    }
}
