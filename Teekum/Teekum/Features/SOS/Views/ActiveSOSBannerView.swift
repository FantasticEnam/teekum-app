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
    var helperOnTheWay: String?
    let onEnd: () -> Void
    var onDismissHelper: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("SOS Active")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    detail
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isEnding {
                ProgressView("Ending SOS…")
                    .tint(.white)
            } else {
                Button(action: showsHelper ? onDismissHelper : onEnd) {
                    Text(showsHelper ? "OKAY" : "END SOS")
                        .font(.headline)
                        .foregroundStyle(Color.alertRed)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(.white, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .foregroundStyle(.white)
        .background(Color.alertRed, in: .rect(cornerRadius: 30))
    }

    private var showsHelper: Bool { helperOnTheWay != nil && error == nil && !isEnding }

    private var detail: Text {
        if let error { return Text(error) }
        if showsHelper, let helperOnTheWay { return Text("\(helperOnTheWay) is on their way to you!") }
        switch deliveryState {
        case .localSending: return Text("Broadcasting…")
        case .searchingPeers: return Text("Searching for nearby friends…")
        case .relayedAck: return Text("Broadcasted.")
        case .deliveredToFriend(let friendId, _): return Text("Delivered to \(friendId).")
        case .failed(let reason): return Text(reason)
        default: return Text("Waiting for a friend to receive it.")
        }
    }
}

#Preview("Sender with active SOS") {
    ActiveSOSBannerView(deliveryState: .relayedAck(relayHopCount: 1, responderId: "ADI"),
        isEnding: false, error: nil, onEnd: {})
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("A friend is on their way") {
    ActiveSOSBannerView(deliveryState: .idle, isEnding: false, error: nil, helperOnTheWay: "HSN", onEnd: {})
        .padding()
        .preferredColorScheme(.dark)
}
