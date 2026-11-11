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

    var wireColorCode: UInt8 {
        switch self {
        case .red: 1
        case .peach: 2
        case .orange: 3
        case .cream: 4
        case .gray: 5
        case .white: 6
        case .blue: 7
        case .green: 8
        // shortcut: nine UI colors share eight wire codes; give yellow its own code only after a protocol decision.
        case .yellow: 4
        }
    }

    var color: Color {
        switch self {
        case .red: .redProfile
        case .peach: .peachProfile
        case .orange: .orangeProfile
        case .cream: .creamProfile
        case .gray: .greyProfile
        case .white: .whiteProfile
        case .blue: .blueProfile
        case .green: .greenProfile
        case .yellow: .yellowProfile
        }
    }
}
