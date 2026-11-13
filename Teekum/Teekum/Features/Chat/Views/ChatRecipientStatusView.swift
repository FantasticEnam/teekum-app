//
//  ChatRecipientStatusView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct ChatRecipientStatusView: View {
    let states: [String: RecipientDeliveryState]
    let profileColor: @MainActor (String) -> MemberColor

    var body: some View {
        DisclosureGroup("Delivery details") {
            ForEach(states.keys.sorted(), id: \.self) { initials in
                if let state = states[initials] {
                    HStack {
                        Text(initials)
                            .foregroundStyle(profileColor(initials).swiftUIColor)
                        Spacer()
                        Text(title(for: state))
                    }
                    .font(.caption)
                }
            }
        }
        .font(.caption)
        .tint(.yellowProfile)
    }

    private func title(for state: RecipientDeliveryState) -> LocalizedStringResource {
        switch state {
        case .locallyAccepted: "Sending"
        case .forwardedToNextHop: "Sent over radio"
        case .relayedByMesh: "Relayed; unconfirmed"
        case .deliveredToRecipient: "Delivered"
        case .deliveryTimedOut: "Timed out"
        case .failed: "Failed"
        }
    }
}

#Preview("Recipient status") {
    ChatRecipientStatusView(states: [
        "ADI": .deliveredToRecipient(timestamp: .now, rssi: nil),
        "HAS": .relayedByMesh(hops: 1, relayPeerId: "NIC"),
        "NIC": .deliveryTimedOut
    ], profileColor: SessionStore.preview.profileColor)
    .padding()
    .background(Color.blackCard)
    .preferredColorScheme(.dark)
}
