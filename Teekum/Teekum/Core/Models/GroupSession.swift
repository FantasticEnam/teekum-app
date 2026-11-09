//
//  GroupSession.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Active group metadata, membership and expiry; no invite parsing or raw keys.
public struct GroupSession: Identifiable, Equatable, Hashable, Codable, Sendable {
    public static let defaultSessionId: UInt32 = 0x7E3A45
    public static let defaultDuration: TimeInterval = 24 * 60 * 60 // 24 hours

    public var id: UInt32 { sessionId }

    /// 24-bit group network session ID (`0x000001...0xFFFFFF`).
    public let sessionId: UInt32

    /// Human-readable group name (e.g. "Festival Crew").
    public var sessionName: String

    /// Stable identifier of the local user in this session.
    public let localMemberId: MemberID

    /// 1-to-3 letter display initials of the local user (e.g. "DAF").
    public var localInitials: String

    /// True if the local user created the group; false if joined via invite.
    public let isHost: Bool

    /// Timestamp when the session was created or joined.
    public let createdAt: Date

    /// Timestamp when the ephemeral session expires.
    public let expiresAt: Date

    public init(
        sessionId: UInt32 = Self.defaultSessionId,
        sessionName: String,
        localMemberId: MemberID? = nil,
        localInitials: String,
        isHost: Bool = true,
        createdAt: Date = .now,
        expiresAt: Date? = nil
    ) {
        let cleanInitials = MemberID.sanitizeInitials(localInitials)
        self.sessionId = sessionId == 0 ? 1 : sessionId
        self.sessionName = sessionName
        self.localInitials = cleanInitials
        self.localMemberId = localMemberId ?? MemberID.fromInitials(cleanInitials)
        self.isHost = isHost
        self.createdAt = createdAt
        self.expiresAt = expiresAt ?? createdAt.addingTimeInterval(Self.defaultDuration)
    }

    public func isExpired(relativeTo referenceDate: Date = .now) -> Bool {
        referenceDate >= expiresAt
    }
}
