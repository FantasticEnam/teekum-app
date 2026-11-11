//
//  SOSDeliveryStatusView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct SOSDeliveryStatusView: View {
    let state: SOSDeliveryState
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        if state != .idle {
            VStack(alignment: .leading, spacing: 10) {
                Label(state.title, systemImage: state.systemImage)
                    .font(.subheadline)
                HStack {
                    if !state.isDelivered {
                        Button("Retry SOS", action: onRetry)
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color.blackCard, in: .rect(cornerRadius: 18))
            .tint(.yellowProfile)
        }
    }
}
