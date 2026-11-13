//
//  SOSHelpConfirmationView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 13/11/26.
//

import SwiftUI

struct SOSHelpConfirmationView: View {
    let isSending: Bool
    let error: String?
    let onConfirm: () -> Void
    let onKeepActive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Have you received help?")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let error {
                Text(error)
                    .font(.subheadline)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if isSending {
                ProgressView("Sending SOS update…")
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack { actions }
                    VStack(alignment: .leading) { actions }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blackCard, in: .rect(cornerRadius: 18))
        .tint(.yellowProfile)
    }

    @ViewBuilder private var actions: some View {
        Button("Yes, end SOS", action: onConfirm)
            .buttonStyle(.borderedProminent)
        Button("Not yet", action: onKeepActive)
            .buttonStyle(.bordered)
    }
}

#Preview {
    SOSHelpConfirmationView(isSending: false, error: nil, onConfirm: {}, onKeepActive: {})
        .padding()
        .preferredColorScheme(.dark)
}
