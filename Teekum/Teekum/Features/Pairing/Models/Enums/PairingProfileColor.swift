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
