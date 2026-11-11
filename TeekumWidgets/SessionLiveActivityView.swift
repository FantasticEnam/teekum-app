//
//  SessionLiveActivityView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct SessionLiveActivityView: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(attributes.sessionName).font(.headline)
                Spacer()
                Label("\(state.directPeerCount)", systemImage: "person.2")
                if let url = URL(string: "teekum://session") { Link("Leave", destination: url) }
            }
            if let sender = state.sosSenderInitials {
                Label("SOS from \(sender)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                if let url = URL(string: "teekum://sos") { Link("Find friend", destination: url) }
            } else if let meeting = state.meetingPointName {
                Text(meeting)
                if let meters = state.meetingPointDistanceMeters { Text("\(meters) m away").font(.caption) }
                if let url = URL(string: "teekum://meeting") { Link("Open map", destination: url) }
            }
            Text(state.relayStatusText).font(.caption)
            Text("Updated \(state.lastUpdated, style: .relative) ago").font(.caption2)
        }
        .padding()
        .foregroundStyle(.white)
        .tint(.yellow)
    }
}
