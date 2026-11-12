//
//  SessionLiveActivityView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct SessionAppBadge: View {
    let accentColor: Color
    
    var body: some View {
        Label {
            Text("Meepo")
                .font(.custom("Charter-Bold", size: 12, relativeTo: .caption))
        } icon: {
            Image("MeetPoint")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
        }
        .foregroundStyle(accentColor)
    }
}

struct SessionSummaryRow: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(circleFillColor)
                Text(circleInitials)
                    .font(.custom("Charter-Bold", size: 16, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 56, height: 56)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(attributes.sessionName)
                    .font(.custom("Charter-Bold", size: 20, relativeTo: .title2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitleText)
                    .font(.custom("Charter-Bold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(state.sosSenderInitials == nil ? .white.opacity(0.85) : .red)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            HStack(spacing: 6) {
                Image(systemName: rightBadge.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(rightBadge.text)
                    .font(.custom("Charter-Bold", size: 12, relativeTo: .caption))
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
        }
        .foregroundStyle(.white)
    }
    
    private var accentColor: Color {
        state.sosSenderInitials == nil ? .yellow : .red
    }
    
    private var subtitleText: String {
        if state.sosSenderInitials != nil {
            return "Emergency SOS"
        }
        return "YOU"
    }
    
    private var userColor: Color {
        MemberColor.resolve(code: attributes.userColorCode, initials: attributes.userInitials).swiftUIColor
    }
    
    private var circleInitials: String {
        state.sosSenderInitials ?? attributes.userInitials
    }
    
    private var circleFillColor: Color {
        state.sosSenderInitials == nil ? userColor : .red
    }
    
    private var rightBadge: (icon: String, text: String) {
        if state.sosSenderInitials != nil {
            return ("exclamationmark.triangle.fill", "SOS")
        }
        if state.unreadMessageCount > 0 {
            return ("message.fill", "\(state.unreadMessageCount) Unread")
        }
        return ("person.2.fill", "\(state.directPeerCount) \(state.directPeerCount == 1 ? "Friend" : "Friends")")
    }
}

struct SessionLiveActivityView: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SessionAppBadge(accentColor: accentColor)
                Spacer()
                Text(state.relayStatusText)
                    .font(.custom("Charter-Bold", size: 12, relativeTo: .caption))
                    .foregroundStyle(accentColor)
            }
            Divider()
                .overlay(.white.opacity(0.2))
            SessionSummaryRow(attributes: attributes, state: state)
        }
        .padding(16)
        .foregroundStyle(.white)
        .tint(.yellow)
    }
    
    private var accentColor: Color {
        state.sosSenderInitials == nil ? .yellow : .red
    }
}

#Preview("Live Activity View", as: .content,
         using: SessionActivityAttributes(sessionId: 0x4321, sessionName: "Festival Crew", userInitials: "DAF")) {
    SessionActivityWidget()
} contentStates: {
    SessionActivityAttributes.ContentState()
    SessionActivityAttributes.ContentState(directPeerCount: 3, unreadMessageCount: 2, relayStatusText: "Relay active")
    SessionActivityAttributes.ContentState(directPeerCount: 3, sosSenderInitials: "ADI", relayStatusText: "Relay active")
}
