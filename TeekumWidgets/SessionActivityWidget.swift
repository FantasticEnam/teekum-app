//
//  SessionActivityWidget.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct SessionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            SessionLiveActivityView(attributes: context.attributes, state: context.state)
                .background(.black)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        }  dynamicIsland: { context in
            let accent: Color = context.state.sosSenderInitials == nil ? .yellow : .red
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SessionAppBadge(accentColor: accent)
                        .padding(.leading, 8)
                        .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.relayStatusText)
                        .font(.custom("Charter-Bold", size: 12, relativeTo: .caption))
                        .foregroundStyle(accent)
                        .padding(.trailing, 8)
                        .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionSummaryRow(attributes: context.attributes, state: context.state)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
            } compactLeading: {
                islandIcon(for: context.state)
            } compactTrailing: {
                compactTrailingContent(for: context.state)
            } minimal: {
                if context.state.sosSenderInitials == nil && context.state.unreadMessageCount > 0 {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.yellow)
                                } else {
                                    islandIcon(for: context.state)
                                }
            }
        }
    }
    
    @ViewBuilder
        private func islandIcon(for state: SessionActivityAttributes.ContentState) -> some View {
            if state.sosSenderInitials != nil {
                Image(systemName: "sos.circle.fill")
                    .foregroundStyle(.red)
            } else {
                Image("MeetPoint")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.yellow)
            }
        }
    
    @ViewBuilder
    private func compactTrailingContent(
        for state: SessionActivityAttributes.ContentState
    ) -> some View {
        if let sosInitials = state.sosSenderInitials {
            Text(sosInitials)
                .font(.custom("Charter-Bold", size: 12, relativeTo: .caption))
                .foregroundStyle(.red)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } else {
            let badge = state.unreadMessageCount > 0
                ? (count: state.unreadMessageCount, icon: "message.fill")
                : (count: state.directPeerCount, icon: "person.2.fill")
            HStack(spacing: 3) {
                Text("\(badge.count)")
                    .font(.custom("Charter-Bold", size: 12, relativeTo: .caption))
                    .monospacedDigit()
                Image(systemName: badge.icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.yellow)
            .lineLimit(1)
        }
    }
}

#Preview("Lock Screen Live Activity", as: .content,
         using: SessionActivityAttributes(sessionId: 0x4321, sessionName: "Festival Crew", userInitials: "DAF")) {
    SessionActivityWidget()
} contentStates: {
    SessionActivityAttributes.ContentState()
    SessionActivityAttributes.ContentState(directPeerCount: 3, unreadMessageCount: 2, relayStatusText: "Relay active")
    SessionActivityAttributes.ContentState(directPeerCount: 3, sosSenderInitials: "ADI", relayStatusText: "Relay active")
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded),
         using: SessionActivityAttributes(sessionId: 0x4321, sessionName: "Festival Crew", userInitials: "DAF")) {
    SessionActivityWidget()
} contentStates: {
    SessionActivityAttributes.ContentState()
    SessionActivityAttributes.ContentState(directPeerCount: 3, unreadMessageCount: 2, relayStatusText: "Relay active")
    SessionActivityAttributes.ContentState(directPeerCount: 3, sosSenderInitials: "ADI", relayStatusText: "Relay active")
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact),
         using: SessionActivityAttributes(sessionId: 0x4321, sessionName: "Festival Crew", userInitials: "DAF")) {
    SessionActivityWidget()
} contentStates: {
    SessionActivityAttributes.ContentState()
    SessionActivityAttributes.ContentState(directPeerCount: 3, unreadMessageCount: 2, relayStatusText: "Relay active")
    SessionActivityAttributes.ContentState(directPeerCount: 3, sosSenderInitials: "ADI", relayStatusText: "Relay active")
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal),
         using: SessionActivityAttributes(sessionId: 0x4321, sessionName: "Festival Crew", userInitials: "DAF")) {
    SessionActivityWidget()
} contentStates: {
    SessionActivityAttributes.ContentState()
    SessionActivityAttributes.ContentState(directPeerCount: 3, unreadMessageCount: 2, relayStatusText: "Relay active")
    SessionActivityAttributes.ContentState(directPeerCount: 3, sosSenderInitials: "ADI", relayStatusText: "Relay active")
}
