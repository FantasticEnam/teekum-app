//
//  SessionStore.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CoreLocation
import Observation

/// Accepted session state shared by feature ViewModels; owns no background work.
@MainActor
@Observable
public final class SessionStore {
    /// Active group session; nil when unpaired (AppRootView shows Pairing).
    public var activeSession: GroupSession?
    public var pendingInvite: GroupSessionInvite?
    public var pendingDeepLink: URL?

    /// Accepted peer members in the current group session.
    public var members: [Member]

    /// Local presentation state; status presets travel through chat, not location pings.
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
            var accepted = incoming
            if let existingTime = existing.measurementTimestamp,
               incoming.measurementTimestamp.map({ $0 < existingTime }) ?? true {
                accepted.coordinate = existing.coordinate
                accepted.horizontalAccuracy = existing.horizontalAccuracy
                accepted.measurementTimestamp = existingTime
                accepted.heading = existing.heading
            }
            accepted.lastSeen = max(existing.lastSeen, incoming.lastSeen)
            members[index] = accepted
        } else {
            members.append(incoming)
        }
    }

    /// Resets all in-memory session state on leave or expiry.
    public func resetSessionState() {
        activeSession = nil
        pendingInvite = nil
        pendingDeepLink = nil
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

        let adiat = Member(id: "ADI", name: "Adiat", coordinate: .init(latitude: baseCoord.latitude + 0.0004, longitude: baseCoord.longitude + 0.0003), horizontalAccuracy: 6, batteryLevel: 0.84, heading: 90, isDirectPeer: true, rssi: -62, measurementTimestamp: .now.addingTimeInterval(-8))
        let nicho = Member(id: "NIC", name: "Nicho", coordinate: .init(latitude: baseCoord.latitude - 0.0005, longitude: baseCoord.longitude + 0.0006), horizontalAccuracy: 12, batteryLevel: 0.65, heading: 180, isDirectPeer: true, rssi: -74, measurementTimestamp: .now.addingTimeInterval(-95))
        let hasan = Member(id: "HAS", name: "Hasan", coordinate: .init(latitude: baseCoord.latitude + 0.0008, longitude: baseCoord.longitude - 0.0004), horizontalAccuracy: 25, batteryLevel: 0.42, heading: 270, measurementTimestamp: .now.addingTimeInterval(-360))

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
        meeting.attendance[.fromInitials(adiat.id)] = .accepted
        meeting.attendance[.fromInitials(nicho.id)] = .accepted
        meeting.attendance[.fromInitials(hasan.id)] = .pending

        return SessionStore(
            activeSession: session,
            members: [adiat, nicho, hasan],
            localStatus: .available,
            activeMeetingPoint: meeting
        )
    }
}
