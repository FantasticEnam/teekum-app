//
//  ActiveSOSBannerView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 13/11/26.
//

import SwiftUI

struct ActiveSOSBannerView: View {
    let deliveryState: SOSDeliveryState
    let isEnding: Bool
    let error: String?
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("SOS active", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let error {
                Text(error)
                    .font(.subheadline)
                    .accessibilityAddTraits(.updatesFrequently)
            } else if deliveryState != .idle, !isEnding {
                Text(deliveryState.title)
                    .font(.subheadline)
            }
            if isEnding {
                ProgressView("Ending SOS…")
            } else {
                Button("End SOS", action: onEnd)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blackCard, in: .rect(cornerRadius: 18))
        .tint(.yellowProfile)
    }

}

#Preview("Sender with active SOS") {
    ActiveSOSBannerView(deliveryState: .searchingPeers, isEnding: false, error: nil, onEnd: {})
        .padding()
        .preferredColorScheme(.dark)
}
