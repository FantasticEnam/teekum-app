//
//  MemberID.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Stable session member identifier; independent of display initials.
public struct MemberID: Hashable, Codable, Sendable, CustomStringConvertible {
    /// Unique identifier string within the active session (e.g. derived from slot + initials or UUID).
    public let rawValue: String

    /// Assigned 8-bit member slot (0...255) used for sequence-number partitioning.
    public let memberSlot: UInt8

    public var description: String { rawValue }

    public init(rawValue: String, memberSlot: UInt8 = 0) {
        self.rawValue = rawValue
        self.memberSlot = memberSlot
    }

    /// Creates a deterministic MemberID from sanitized 1-to-3 letter initials and optional slot.
    public static func fromInitials(_ initials: String, slot: UInt8? = nil) -> MemberID {
        let clean = Self.sanitizeInitials(initials)
        let resolvedSlot = slot ?? Self.deriveSlot(from: clean)
        return MemberID(rawValue: clean, memberSlot: resolvedSlot)
    }

    /// Sanitizes arbitrary user input into 1 to 3 uppercase ASCII letters (A...Z).
    public static func sanitizeInitials(_ input: String) -> String {
        let letters = input.uppercased().filter { $0 >= "A" && $0 <= "Z" }
        guard !letters.isEmpty else { return "A" }
        return String(letters.prefix(3))
    }

    private static func deriveSlot(from cleanInitials: String) -> UInt8 {
        let utf8 = Array(cleanInitials.utf8)
        let a = utf8.count >= 1 ? Int(utf8[0]) - 64 : 1
        let b = utf8.count >= 2 ? Int(utf8[1]) - 64 : 0
        let c = utf8.count >= 3 ? Int(utf8[2]) - 64 : 0
        let encoded = (a * 729) + (b * 27) + c
        let high = UInt8((encoded >> 8) & 0xFF)
        let low = UInt8(encoded & 0xFF)
        return high ^ low
    }
}
