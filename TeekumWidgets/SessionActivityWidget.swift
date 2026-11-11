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
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(context.attributes.sessionName).font(.headline) }
                DynamicIslandExpandedRegion(.trailing) { Label("\(context.state.directPeerCount)", systemImage: "person.2") }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionLiveActivityView(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                Image(systemName: context.state.sosSenderInitials == nil ? "location.circle" : "sos.circle.fill")
                    .foregroundStyle(context.state.sosSenderInitials == nil ? .yellow : .red)
            } compactTrailing: {
                Text(context.state.sosSenderInitials == nil ? "\(context.state.directPeerCount)" : "SOS")
            } minimal: {
                Image(systemName: context.state.sosSenderInitials == nil ? "location.circle" : "sos.circle.fill")
            }
        }
    }
}
