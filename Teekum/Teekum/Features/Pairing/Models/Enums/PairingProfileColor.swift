//
//  PairingProfileColor.swift
//  Teekum
//
//  Created by Ari Hasan on 07/11/26.
//

import SwiftUI

enum PairingProfileColor: String, CaseIterable, Identifiable, Codable {
    case red, peach, orange, cream, gray, white, blue, green, yellow

    var id: String { rawValue }

    var wireColorCode: UInt8 { memberColor.rawValue }
    var color: Color { memberColor.swiftUIColor }

    private var memberColor: MemberColor {
        switch self {
        case .red: .reddish
        case .peach: .orangeSalmon
        case .orange: .artyClickOrange
        case .cream: .apricot
        case .gray: .sandrift
        case .white: .paleBlueLily
        case .blue: .darkSkyBlue
        case .green: .greenishTeal
        case .yellow: .yellow
        }
    }
}
