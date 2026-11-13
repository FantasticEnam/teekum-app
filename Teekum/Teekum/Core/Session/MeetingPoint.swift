//
//  MeetingPoint.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CoreLocation

// Active proposal identity, coordinate, author and attendance data.
// Enforces the single active meeting point rule per group session.
public struct MeetingPoint: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UInt32
    public var name: String
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public var targetTime: Date?
    public let proposerId: MemberID
    public let proposerInitials: String
    public var landmarkId: UInt32?
    public var attendance: [MemberID: MeetingAttendance]
    public let createdAt: Date
    public var isRightNow: Bool
    public var anchorToProposerGPS: Bool
    public var arrivalRadiusMeters: Double

    public var meetupTime: Date { targetTime ?? createdAt }
    public var isExpired: Bool { Date.now.timeIntervalSince(meetupTime) > 3600 }
    public var formattedTitle: String { "\(proposerInitials)'s Rendezvous" }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(
        id: UInt32 = UInt32.random(in: 1...UInt32.max),
        name: String,
        coordinate: CLLocationCoordinate2D,
        targetTime: Date? = nil,
        proposerId: MemberID? = nil,
        proposerInitials: String,
        landmarkId: UInt32? = nil,
        attendance: [MemberID: MeetingAttendance] = [:],
        createdAt: Date = .now,
        isRightNow: Bool = false,
        anchorToProposerGPS: Bool = false,
        arrivalRadiusMeters: Double = 25
    ) {
        let cleanInitials = MemberID.sanitizeInitials(proposerInitials)
        let resolvedProposerId = proposerId ?? MemberID.fromInitials(cleanInitials)
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.targetTime = targetTime
        self.proposerId = resolvedProposerId
        self.proposerInitials = cleanInitials
        self.landmarkId = landmarkId
        self.attendance = attendance
        self.createdAt = createdAt
        self.isRightNow = isRightNow
        self.anchorToProposerGPS = anchorToProposerGPS
        self.arrivalRadiusMeters = min(100, max(5, arrivalRadiusMeters))
    }
}
