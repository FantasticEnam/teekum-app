//
//  SOSEvent.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Emergency event identity, originator, sample and delivery records.
public struct SOSEvent: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UInt32
    public let originatorId: MemberID
    public let originatorInitials: String
    public var originatorName: String
    public let emergencyType: SOSType

    /// Freshest valid location sample at the moment SOS was triggered (preserves original hardware timestamp).
    public let locationSample: LocationSample?

    /// Reported battery percentage of the distressed member's device (0...100).
    public let batteryPercentage: UInt8?

    /// Local timestamp when the event was created or first received.
    public let receivedAt: Date

    /// Current delivery state phase.
    public var deliveryState: SOSDeliveryState

    /// Number of relay hops observed, if in `.relayedAck` state.
    public var relayHopCount: UInt8

    /// Initials of group members who have cryptographically confirmed receipt (`DELIVERED_TO_FRIEND`).
    public var confirmedRecipientInitials: [String]

    /// Optional failure or warning description when in `.failed` state.
    public var failureReason: String?

    public init(
        id: UInt32 = UInt32.random(in: 1...UInt32.max),
        originatorId: MemberID? = nil,
        originatorInitials: String,
        originatorName: String? = nil,
        emergencyType: SOSType = .general,
        locationSample: LocationSample? = nil,
        batteryPercentage: UInt8? = nil,
        receivedAt: Date = .now,
        deliveryState: SOSDeliveryState = .localSending,
        relayHopCount: UInt8 = 0,
        confirmedRecipientInitials: [String] = [],
        failureReason: String? = nil
    ) {
        let cleanInitials = MemberID.sanitizeInitials(originatorInitials)
        self.id = id
        self.originatorId = originatorId ?? MemberID.fromInitials(cleanInitials)
        self.originatorInitials = cleanInitials
        self.originatorName = originatorName ?? cleanInitials
        self.emergencyType = emergencyType
        self.locationSample = locationSample
        self.batteryPercentage = batteryPercentage.map { min($0, 100) }
        self.receivedAt = receivedAt
        self.deliveryState = deliveryState
        self.relayHopCount = relayHopCount
        self.confirmedRecipientInitials = confirmedRecipientInitials
        self.failureReason = failureReason
    }
}
