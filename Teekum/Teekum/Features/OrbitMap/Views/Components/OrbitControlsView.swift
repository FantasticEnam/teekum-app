//
//  OrbitControlsView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitControlsView: View {
    let onSOS: () -> Void
    let onExpand: () -> Void
    var onChat: () -> Void = {}
    var unreadCount = 0
    var isSOSActive = false

    private let friendsPanelHeight: CGFloat = 44
    
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
            
            Button(action: onExpand) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 30, weight: .semibold))
                    .offset(y:15)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 176)
                    .frame(height: friendsPanelHeight)
                    .background {
                        OrbitPanelShape(
                            cornerRadius: 0,
                            crestHeight: nil,
                            crestWidth: 176
                        )
                        .fill(Color.blackCard)
                        .ignoresSafeArea(.container, edges: .bottom)
                        .allowsHitTesting(false)
                    }
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .layoutPriority(1)
            .accessibilityLabel("Open friends")
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let upwardDistance = -value.translation.height
                        if upwardDistance >= 36, upwardDistance > abs(value.translation.width) {
                            onExpand()
                        }
                    }
            )
            
            Spacer()
            
            Button(action: onChat) {
                Image(systemName: "message.fill")
                    .font(.system(size: 30, weight: .semibold))
//                    .frame(width: 62, height: 62)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Open Group Chat")
            .accessibilityValue("\(unreadCount) unread messages")
            .overlay(alignment: .topTrailing) {
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption2.bold())
                        .padding(5)
                        .background(Color.alertRed, in: .circle)
                        .accessibilityHidden(true)
                }
            }
        }

    }
}

#Preview {
    OrbitControlsView(
        onSOS: {},
        onExpand: {}
    )
}
