//
//  SessionLiveActivityView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct SessionLiveActivityView: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label {
                    Text("Meepo")
                        .font(.custom("Charter-Bold", size: 12, relativeTo: .caption))
                } icon: {
                    Image("MeetPoint")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
                Spacer()
                Text(state.relayStatusText)
                    .font(.custom("Charter-Bold", size: 12, relativeTo: .caption))
                    .foregroundStyle(accentColor)
            }
            
            Divider()
                .overlay(.white.opacity(0.2))
            
            // Main Content
            HStack(spacing: 14) {
                // User Color
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
                // Judul grup & subjudul state (Default / Meeting Point / SOS)
                VStack(alignment: .leading, spacing: 3) {
                    Text(attributes.sessionName)
                        .font(.custom("Charter-Bold", size: 22, relativeTo: .title2))
                        .lineLimit(1)
                    Text(subtitleText)
                        .font(.custom("Charter-Bold", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(state.sosSenderInitials == nil ? .white.opacity(0.85) : .red)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                // Section Jumlah teman
                HStack(spacing: 6) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                    Text("\(state.directPeerCount) \(state.directPeerCount == 1 ? "Friend" : "Friends")")
                        .font(.custom("Charter-Bold", size: 12, relativeTo: .caption))
                        .foregroundStyle(accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
            }
        }
        .padding()
        .foregroundStyle(.white)
        .tint(.yellow)
    }
    
    private var accentColor: Color {
        state.sosSenderInitials == nil ? .yellow : .red
    }
    
    private var subtitleText: String {
        if state.sosSenderInitials != nil {
            return "Emergency SOS"
        }
        if let meeting = state.meetingPointName {
            if let meters = state.meetingPointDistanceMeters {
                return "\(meeting) • \(meters) m"
            }
            return meeting
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
    
    private var circleGlowColor: Color {
        state.sosSenderInitials == nil ? userColor : .red
    }
    
    private var circleTextColor: Color {
        state.sosSenderInitials == nil ? .black.opacity(0.85) : .white
    }
}

#Preview("Live Activity View", as: .content,
         using: SessionActivityAttributes(sessionId: 0x4321, sessionName: "Festival Crew", userInitials: "DAF")) {
    SessionActivityWidget()
} contentStates: {
    SessionActivityAttributes.ContentState()
    SessionActivityAttributes.ContentState(directPeerCount: 3, meetingPointName: "Gate 2",
                                           meetingPointDistanceMeters: 120, relayStatusText: "Relay active")
    SessionActivityAttributes.ContentState(directPeerCount: 3, sosSenderInitials: "ADI",
                                           relayStatusText: "Relay active")
}
