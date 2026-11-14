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

    /// Sanitizes arbitrary user input into 1 to 3 uppercase alphanumeric characters (A...Z, 0...9).
    public static func sanitizeInitials(_ input: String) -> String {
        InitialsCodec.sanitize(input)
    }

    private static func deriveSlot(from cleanInitials: String) -> UInt8 {
        let bytes = InitialsCodec.encode(cleanInitials) ?? [0, 0]
        return bytes[0] ^ bytes[1]
    }
}
