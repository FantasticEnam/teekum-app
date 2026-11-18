//
//  OrbitControlsView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitControlsView: View {
    let onSOS: () -> Void
    let onOpenMap: () -> Void
    var onChat: () -> Void = {}
    var unreadCount = 0
    var isSOSActive = false

    var body: some View {
        HStack(alignment: .bottom) {
            if isSOSActive {
                Text("SOS")
                    .font(.custom("Helvetica", size: 25, relativeTo: .title2).bold())
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.alertRed, in: .circle)
                    .glassEffect(.regular.tint(.alertRed), in: .circle)
                    .accessibilityLabel("SOS active")
            } else {
                SOSSwipeButtonView(onSwipeCompleted: onSOS)
                    .zIndex(1)
            }

            Spacer()

            VStack(spacing: 6) {
                control("Open meeting point map", icon: "mappin.and.ellipse", action: onOpenMap)
                control("Open Group Chat", icon: "message.fill", action: onChat)
                    .accessibilityValue("\(unreadCount) unread messages")
                    .overlay(alignment: .topTrailing) {
                        if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(.caption2.bold())
                                .padding(5)
                                .background(Color.alertRed, in: .circle)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
            }
        }
    }

    private func control(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .labelStyle(.iconOnly)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OrbitControlsView(
        onSOS: {},
        onOpenMap: {},
        unreadCount: 2
    )
    .padding(24)
    .background(.black)
    .preferredColorScheme(.dark)
}
