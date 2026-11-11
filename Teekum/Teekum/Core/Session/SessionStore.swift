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

    /// Single active group meeting point proposal, if any.
    public var activeMeetingPoint: MeetingPoint?

    public var hasActiveSession: Bool {
        activeSession != nil
    }

    public init(
        activeSession: GroupSession? = nil,
        members: [Member] = [],
        activeMeetingPoint: MeetingPoint? = nil
    ) {
        self.activeSession = activeSession
        self.members = members
        self.activeMeetingPoint = activeMeetingPoint
    }

    // MARK: - State Mutations

    func applyLocationPing(_ ping: LocationPingPayload, inbound: InboundPacket) {
        let existing = members.first { $0.id == ping.senderInitials }
        upsertMember(Member(id: ping.senderInitials, lastSeen: inbound.receivedAt, coordinate: ping.coordinate,
            horizontalAccuracy: Double(ping.accuracy), isEmergency: existing?.isEmergency ?? false,
            batteryLevel: Float(ping.batteryLevel) / 100, heading: ping.headingDegrees,
            isDirectPeer: inbound.rawPacket.envelope.hopCount == 0, rssi: inbound.receivedRssi,
            color: .resolve(code: ping.colorCode, initials: ping.senderInitials), measurementTimestamp: ping.timestamp))
    }

    func applySOSLocation(_ payload: SOSPayload, inbound: InboundPacket) {
        let existing = members.first { $0.id == payload.senderInitials }
        let hasLocation = payload.timestamp.timeIntervalSince1970 > 0
        upsertMember(Member(id: payload.senderInitials, lastSeen: inbound.receivedAt,
            coordinate: hasLocation ? payload.coordinate : nil,
            horizontalAccuracy: hasLocation ? Double(payload.accuracy) : nil,
            isEmergency: existing?.isEmergency ?? false, batteryLevel: Float(payload.batteryLevel) / 100,
            heading: existing?.heading, isDirectPeer: inbound.rawPacket.envelope.hopCount == 0,
            rssi: inbound.receivedRssi, color: .resolve(code: payload.colorCode, initials: payload.senderInitials),
            measurementTimestamp: hasLocation ? payload.timestamp : nil))
    }

    func applyPeerSnapshot(_ peers: [PeerInfo], connected: Set<String>) {
        for index in members.indices {
            members[index].isDirectPeer = connected.contains(members[index].id)
        }
        for peer in peers where peer.isGroupMember && peer.id != activeSession?.localInitials {
            var member = members.first { $0.id == peer.id } ?? Member(id: peer.id)
            member.isDirectPeer = peer.isDirectLink
            member.rssi = peer.rssi
            member.lastSeen = max(member.lastSeen, peer.lastSeen)
            upsertMember(member)
        }
    }

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
        activeMeetingPoint = nil
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
            activeMeetingPoint: meeting
        )
    }
}
