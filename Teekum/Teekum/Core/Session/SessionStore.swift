//
//  SessionStore.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CoreLocation
import Observation

/// One MainActor observable session-state owner; holds no sockets or cryptographic keys.
@MainActor
@Observable
public final class SessionStore {
    /// Active group session; nil when unpaired (AppRootView shows Pairing).
    public var activeSession: GroupSession?

    /// Accepted peer members in the current group session.
    public var members: [Member]

    /// Local user's current activity status (piggybacked on next normal location ping).
    public var localStatus: Status

    /// Optional target reference ID when `localStatus == .goingTo`.
    public var localTargetRefId: UInt32?

    /// Single active group meeting point proposal, if any.
    public var activeMeetingPoint: MeetingPoint?

    /// Active outgoing or incoming emergency SOS event, if any.
    public var activeSOSEvent: SOSEvent?

    public var hasActiveSession: Bool {
        activeSession != nil
    }

    public init(
        activeSession: GroupSession? = nil,
        members: [Member] = [],
        localStatus: Status = .available,
        localTargetRefId: UInt32? = nil,
        activeMeetingPoint: MeetingPoint? = nil,
        activeSOSEvent: SOSEvent? = nil
    ) {
        self.activeSession = activeSession
        self.members = members
        self.localStatus = localStatus
        self.localTargetRefId = localTargetRefId
        self.activeMeetingPoint = activeMeetingPoint
        self.activeSOSEvent = activeSOSEvent
    }

    // MARK: - State Mutations

    /// Inserts or updates a member record only if the incoming sample is not older than existing state.
    public func upsertMember(_ incoming: Member) {
        if let index = members.firstIndex(where: { $0.id == incoming.id }) {
            let existing = members[index]
            if let existingSample = existing.latestLocation,
               let incomingSample = incoming.latestLocation,
               incomingSample.timestamp < existingSample.timestamp {
                // Preserve newer hardware measurement timestamp (anti-stale overwrite)
                return
            }
            members[index] = incoming
        } else {
            members.append(incoming)
        }
    }

    /// Resets all in-memory session state on leave or expiry.
    public func resetSessionState() {
        activeSession = nil
        members.removeAll()
        localStatus = .available
        localTargetRefId = nil
        activeMeetingPoint = nil
        activeSOSEvent = nil
    }
}

// MARK: - Preview Fixtures for UI Migration

extension SessionStore {
    /// Ready-to-use fixture store for MainMapView, MeetingPointsView, and FriendDetailView previews.
    public static var preview: SessionStore {
        let baseCoord = CLLocationCoordinate2D(latitude: -6.1988, longitude: 106.8225) // Thamrin / Central Jakarta area

        let session = GroupSession(
            sessionId: 0x4321,
            sessionName: "Fantasix Festival Crew",
            localInitials: "DAF",
            isHost: true
        )

        let adiat = Member(
            initials: "ADI",
            displayName: "Adiat",
            latestLocation: LocationSample(
                latitude: baseCoord.latitude + 0.0004,
                longitude: baseCoord.longitude + 0.0003,
                horizontalAccuracy: 6.0,
                timestamp: .now.addingTimeInterval(-8), // Live (8s ago)
                heading: 90
            ),
            status: .gettingDrinks,
            batteryPercentage: 84,
            isDirectPeer: true,
            rssi: -62
        )

        let nicho = Member(
            initials: "NIC",
            displayName: "Nicho",
            latestLocation: LocationSample(
                latitude: baseCoord.latitude - 0.0005,
                longitude: baseCoord.longitude + 0.0006,
                horizontalAccuracy: 12.0,
                timestamp: .now.addingTimeInterval(-95), // Stale (1m 35s ago)
                heading: 180
            ),
            status: .omw,
            batteryPercentage: 65,
            isDirectPeer: true,
            rssi: -74
        )

        let hasan = Member(
            initials: "HAS",
            displayName: "Hasan",
            latestLocation: LocationSample(
                latitude: baseCoord.latitude + 0.0008,
                longitude: baseCoord.longitude - 0.0004,
                horizontalAccuracy: 25.0,
                timestamp: .now.addingTimeInterval(-360), // Expired (6m ago)
                heading: 270
            ),
            status: .exploring,
            batteryPercentage: 42,
            isDirectPeer: false,
            rssi: nil
        )

        var meeting = MeetingPoint(
            name: "Main Stage Sound Booth",
            coordinate: CLLocationCoordinate2D(
                latitude: baseCoord.latitude + 0.0002,
                longitude: baseCoord.longitude - 0.0002
            ),
            targetTime: .now.addingTimeInterval(1800),
            proposerInitials: "ADI",
            landmarkId: 1
        )
        meeting.attendance[adiat.id] = .accepted
        meeting.attendance[nicho.id] = .accepted
        meeting.attendance[hasan.id] = .pending

        return SessionStore(
            activeSession: session,
            members: [adiat, nicho, hasan],
            localStatus: .available,
            activeMeetingPoint: meeting
        )
    }
}
