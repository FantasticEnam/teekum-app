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
    var bottomInset: CGFloat = 0
    
    var body: some View {
        HStack {
            SOSHoldButton(onHoldCompleted: onSOS)
        
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
            
            Button {
                print("Message Tapped")
            } label: {
                Image(systemName: "message.fill")
                    .font(.system(size: 30, weight: .semibold))
//                    .frame(width: 62, height: 62)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Open Group Chat")
        }

    }
}

#Preview {
    OrbitControlsView(
        onSOS: {},
        onExpand: {}
    )
}
