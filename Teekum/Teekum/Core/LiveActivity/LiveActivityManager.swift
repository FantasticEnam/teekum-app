//
//  LiveActivityManager.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    private var activityID: String?
    private var lastState: SessionActivityAttributes.ContentState?

    func start(session: GroupSession) async {
        await stop()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = SessionActivityAttributes(sessionId: session.sessionId,
            sessionName: session.sessionName, userInitials: session.localInitials, userColorCode: session.localColorCode)
        activityID = try? Activity.request(attributes: attributes,
            content: ActivityContent(state: .init(), staleDate: .now.addingTimeInterval(30)), pushType: nil).id
    }

    func update(peerCount: Int, unreadCount: Int, meeting: MeetingPoint?, location: LocationPin?, sosSender: String?, relay: RelayPolicyState) async {
        guard let activityID else { return }
        let distance = meeting.flatMap { point in location.map { Int($0.distance(to: point.coordinate)) } }
        var state = SessionActivityAttributes.ContentState(directPeerCount: peerCount,
            meetingPointName: meeting?.name, meetingPointDistanceMeters: distance,
            sosSenderInitials: sosSender, relayStatusText: relay.statusDescription())
        if let previous = lastState {
            state.lastUpdated = previous.lastUpdated
            guard state != previous || Date.now.timeIntervalSince(previous.lastUpdated) >= 15 else { return }
            state.lastUpdated = .now
        }
        lastState = state
        await Self.pushUpdate(id: activityID, state: state)
    }

    @concurrent private static func pushUpdate(id: String, state: SessionActivityAttributes.ContentState) async {
        for activity in Activity<SessionActivityAttributes>.activities where activity.id == id {
            await activity.update(ActivityContent(state: state, staleDate: .now.addingTimeInterval(30)))
            break
        }
    }

    func stop() async {
        activityID = nil
        lastState = nil
        for existing in Activity<SessionActivityAttributes>.activities {
            await existing.end(nil, dismissalPolicy: .immediate)
        }
    }
}
