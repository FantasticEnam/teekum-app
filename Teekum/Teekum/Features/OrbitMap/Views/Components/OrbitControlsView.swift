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
    
    var body: some View {
        HStack {
            SOSHoldButton(onHoldCompleted: onSOS)
        
            Spacer()
            
            Button(action: onExpand) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 144, height: 64)
                    .background {
                        OrbitPanelShape(cornerRadius: 0)
                            .fill(Color(hex: 0x141414))
                            .ignoresSafeArea(edges: .bottom)
                    }
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open friends")
            
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
