//
//  Member.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CoreLocation

/// Member identity, initials, latest location sample, status and reported battery.
public struct Member: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: MemberID

    /// 1-to-3 uppercase letter display initials (e.g. "DNA", "ADI", "NIC").
    public var initials: String

    /// Full display name if known locally; defaults to `initials`.
    public var displayName: String

    /// Latest verified location sample (retains original GPS hardware timestamp).
    public var latestLocation: LocationSample?

    /// Timestamp when a valid authenticated packet was last received from this member.
    /// Kept separate from `latestLocation.timestamp` to preserve measurement honesty.
    public var lastPacketReceivedAt: Date

    /// Current festival activity status.
    public var status: Status

    /// Optional target reference ID when status is `.goingTo`.
    public var targetRefId: UInt32?

    /// Reported battery percentage (0...100), or nil if unknown.
    public var batteryPercentage: UInt8?

    /// True if currently connected via direct 1-hop peer link.
    public var isDirectPeer: Bool

    /// Observed signal strength in dBm if connected directly.
    public var rssi: Int8?

    public init(
        id: MemberID,
        initials: String,
        displayName: String? = nil,
        latestLocation: LocationSample? = nil,
        lastPacketReceivedAt: Date = .now,
        status: Status = .available,
        targetRefId: UInt32? = nil,
        batteryPercentage: UInt8? = nil,
        isDirectPeer: Bool = false,
        rssi: Int8? = nil
    ) {
        let cleanInitials = MemberID.sanitizeInitials(initials)
        self.id = id
        self.initials = cleanInitials
        self.displayName = displayName ?? cleanInitials
        self.latestLocation = latestLocation
        self.lastPacketReceivedAt = lastPacketReceivedAt
        self.status = status
        self.targetRefId = targetRefId
        self.batteryPercentage = batteryPercentage.map { min($0, 100) }
        self.isDirectPeer = isDirectPeer
        self.rssi = rssi
    }

    /// Convenience initializer using initials string directly.
    public init(
        initials: String,
        displayName: String? = nil,
        latestLocation: LocationSample? = nil,
        lastPacketReceivedAt: Date = .now,
        status: Status = .available,
        targetRefId: UInt32? = nil,
        batteryPercentage: UInt8? = nil,
        isDirectPeer: Bool = false,
        rssi: Int8? = nil
    ) {
        let cleanInitials = MemberID.sanitizeInitials(initials)
        self.init(
            id: MemberID.fromInitials(cleanInitials),
            initials: cleanInitials,
            displayName: displayName,
            latestLocation: latestLocation,
            lastPacketReceivedAt: lastPacketReceivedAt,
            status: status,
            targetRefId: targetRefId,
            batteryPercentage: batteryPercentage,
            isDirectPeer: isDirectPeer,
            rssi: rssi
        )
    }

    /// Honest freshness classification of the member's location sample.
    public func locationFreshness(relativeTo referenceDate: Date = .now) -> LocationFreshness {
        guard let latestLocation else { return .unavailable }
        return latestLocation.freshness(relativeTo: referenceDate)
    }
}
