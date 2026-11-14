//
//  Theme.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 02/11/26.
//

import SwiftUI

extension Color {
    
    // MARK: - Brand & Accent Colors
    static let themePrimary     = Color(hex: 0xF2EFE7) // Pantone Coconut Milk
    static let themeMaple       = Color(hex: 0xC36316) // Pantone Autumn Maple
    static let alertRed       = Color(hex: 0x910002) // Alert Red
    static let alertRedFire = Color(hex: 0xF82F0D)
    
    // MARK: - Backgrounds & Shadows
    static let themeShadow      = Color(hex: 0x1C1F2A) // Pantone 532 C
    static let blackCard        = Color(hex: 0x141414)
    
    // MARK: - Profile Color
    static let yellowProfile = Color(hex: 0xFDC600)
    static let redProfile = Color(hex: 0xCB443D)
    static let peachProfile = Color(hex: 0xCE7059)
    static let orangeProfile = Color(hex: 0xFD7900)
    static let creamProfile = Color(hex: 0xF7B66E)
    static let greyProfile = Color(hex: 0xA79581)
    static let whiteProfile = Color(hex: 0xD5EEEF)
    static let blueProfile = Color(hex: 0x3A97E3)
    static let greenProfile = Color(hex: 0x1EC989)
}

// MARK: - Convenience Initializers
extension Color {
    
    /// Initialize a color using a hex integer value (e.g., `0xF2EFE7`)
    init(hex: UInt32, opacity: Double = 1.0) {
        let red   = Double((hex & 0xFF0000) >> 16) / 255.0
        let green = Double((hex & 0x00FF00) >> 8)  / 255.0
        let blue  = Double(hex & 0x0000FF)         / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
