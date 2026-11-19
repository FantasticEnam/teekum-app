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
    
    // MARK: - Button Color
    static let buttonPrimary = Color(hex: 0xA9CFF5)
    
    // MARK: - Profile Color
    static let yellowProfile = Color(hex: 0xFFED60)
    static let greenProfile = Color(hex: 0x7BFFCD)
    static let blueProfile = Color(hex: 0x719BFF)
    static let purpleProfile = Color(hex: 0xAC94FF)
    static let pinkProfile = Color(hex: 0xFF84EF)
    static let redProfile = Color(hex: 0xFF797B)
   
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
