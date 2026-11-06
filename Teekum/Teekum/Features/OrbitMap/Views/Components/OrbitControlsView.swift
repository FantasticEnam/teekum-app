//
//  OrbitControlsView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitControlsView: View {
    let onExpand: () -> Void
    
    var body: some View {
        HStack {
            Button {
                print("SOS Tapped")
            } label: {
                Text("SOS")
                    .font(.custom("Charter-Roman", size: 25))
                    .bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
//                    .frame(width: 32, height: 62)
            }
            .buttonStyle(.glassProminent)
            .tint(.alertRed)
            .foregroundStyle(.white)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Hold for SOS")
            
            Spacer()
            
            Button(action: onExpand) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 64, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open orbit panel")
            
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
    OrbitControlsView(onExpand: {})
}
