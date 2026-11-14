//
//  InitialsCodec.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

nonisolated public enum InitialsCodec {
    
    // MARK: - Encode
    public static func encode(_ initials: String) -> [UInt8]? {
        let chars = Array(initials.uppercased().utf8)
        
        // Must be 1 to 3 alphanumeric characters: A–Z (ASCII 65..90) or 0–9 (ASCII 48..57)
        guard chars.count >= 1 && chars.count <= 3,
              chars.allSatisfy({ isAlphanumeric($0) }) else {
            return nil
        }
        
        // Convert to numbers: A=1..Z=26, 0=27..9=36, empty=0
        guard let a = charToValue(chars[0]) else { return nil }
        let b = chars.count >= 2 ? (charToValue(chars[1]) ?? 0) : 0
        let c = chars.count >= 3 ? (charToValue(chars[2]) ?? 0) : 0
        
        // Base-37 positional formula: (a * 1369) + (b * 37) + c
        let number = (a * 1369) + (b * 37) + c
        
        // Split into 2 bytes (big-endian)
        let highByte = UInt8(number / 256)
        let lowByte = UInt8(number % 256)
        
        return [highByte, lowByte]
    }
    
    public static func encodeToUInt16(_ initials: String) -> UInt16? {
        guard let bytes = encode(initials) else { return nil }
        return (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
    }
    
    // MARK: - Decode
    public static func decode(_ bytes: [UInt8]) -> String? {
        guard bytes.count == 2 else {
            return nil
        }
        
        let number = (Int(bytes[0]) * 256) + Int(bytes[1])
        
        // Valid range: minimum is "A" (1 * 1369 = 1,369), maximum is "999" (36 * 1369 + 36 * 37 + 36 = 50,652)
        guard number >= 1369 && number <= 50652 else {
            return nil
        }
        
        let a = number / 1369
        let b = (number % 1369) / 37
        let c = number % 37
        
        // Range validation
        guard a >= 1 && a <= 36, b <= 36, c <= 36 else {
            return nil
        }
        
        // Structural validation: cannot have c > 0 if b == 0 (no character 3 without character 2)
        guard !(b == 0 && c > 0) else {
            return nil
        }
        
        guard let firstChar = valueToChar(a) else { return nil }
        var charBytes: [UInt8] = [firstChar]
        if b > 0 {
            guard let secondChar = valueToChar(b) else { return nil }
            charBytes.append(secondChar)
        }
        if c > 0 {
            guard let thirdChar = valueToChar(c) else { return nil }
            charBytes.append(thirdChar)
        }
        
        return String(bytes: charBytes, encoding: .utf8)
    }
    
    public static func decodeFromUInt16(_ value: UInt16) -> String? {
        let high = UInt8((value >> 8) & 0xFF)
        let low = UInt8(value & 0xFF)
        return decode([high, low])
    }
    
    public static func sanitize(_ input: String) -> String {
        let chars = input.uppercased().filter { ($0 >= "A" && $0 <= "Z") || ($0 >= "0" && $0 <= "9") }
        if chars.isEmpty {
            return "A"
        }
        return String(chars.prefix(3))
    }

    public static func isValid(_ initials: String) -> Bool {
        let trimmed = initials.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count >= 1 && trimmed.count <= 3 else { return false }
        return trimmed.allSatisfy { ($0 >= "A" && $0 <= "Z") || ($0 >= "0" && $0 <= "9") }
    }

    // MARK: - Helpers

    private static func isAlphanumeric(_ byte: UInt8) -> Bool {
        (byte >= 65 && byte <= 90) || (byte >= 48 && byte <= 57)
    }

    private static func charToValue(_ byte: UInt8) -> Int? {
        if byte >= 65 && byte <= 90 {
            return Int(byte) - 64 // 1..26 for 'A'..'Z'
        }
        if byte >= 48 && byte <= 57 {
            return Int(byte) - 48 + 27 // 27..36 for '0'..'9'
        }
        return nil
    }

    private static func valueToChar(_ value: Int) -> UInt8? {
        if value >= 1 && value <= 26 {
            return UInt8(value + 64) // 'A'..'Z'
        }
        if value >= 27 && value <= 36 {
            return UInt8(value - 27 + 48) // '0'..'9'
        }
        return nil
    }
}
