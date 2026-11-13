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
    var bottomInset: CGFloat = 0
    var onActiveSOS: (() -> Void)?
    
    var body: some View {
        HStack {
            if let onActiveSOS {
                Button("SOS", action: onActiveSOS)
                    .font(.custom("Futura", size: 25, relativeTo: .title2).bold())
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.alertRed, in: .circle)
                    .glassEffect(.regular.tint(.alertRed).interactive(), in: .circle)
                    .buttonStyle(.plain)
                    .accessibilityLabel("SOS active")
                    .accessibilityHint("Opens the confirmation to end the SOS")
            } else {
                SOSHoldButton(onHoldCompleted: onSOS)
            }
        
            Spacer()
            
            Button(action: onExpand) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 144, height: 64)
                    .background(alignment: .top) {
                        OrbitPanelShape(
                            cornerRadius: 0,
                            crestHeight: 64
                        )
                            .fill(Color.blackCard)
                            .frame(height: 64)
                    }
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open friends")
            .offset(y: bottomInset)
            
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
