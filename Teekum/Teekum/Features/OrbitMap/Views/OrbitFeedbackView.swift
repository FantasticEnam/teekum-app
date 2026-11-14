//
//  OrbitFeedbackView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct OrbitFeedbackView: View {
    var sos: SOSViewModel?
    var notifications: NotificationService?
    var showsChatAlert = true

    var body: some View {
        VStack(spacing: 8) {
            if let sos {
                if let alert = sos.incomingAlert {
                    IncomingSOSAlertBannerView(alert: alert) {
                        Task { await sos.acknowledgeIncomingAlert() }
                    }
                }
                InactivityWarningView(guardService: sos.inactivityGuard)
                if sos.outgoingEventId != nil {
                    ActiveSOSBannerView(deliveryState: sos.deliveryState, isEnding: sos.isResolving,
                        error: sos.resolutionError, onEnd: sos.endSOS)
                } else {
                    SOSDeliveryStatusView(state: sos.deliveryState, onRetry: sos.retrySOS, onDismiss: sos.dismissDeliveryStatus)
                }
            }
            if showsChatAlert, let alert = notifications?.chatAlert {
                Self.chatBanner(sender: alert.sender, message: alert.body)
            } else if let message = notifications?.message {
                Text(message)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blackCard, in: .rect(cornerRadius: 16))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding(.horizontal)
    }

    static func chatBanner(sender: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sender)
                .font(.title3.bold())
            Text(message)
                .font(.body.weight(.medium))
                .lineLimit(3)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .background(Color(white: 0.26), in: .rect(cornerRadius: 32))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Incoming SOS feedback") {
    @Previewable @State var sos = SOSViewModel.preview

    OrbitFeedbackView(sos: sos, notifications: nil)
        .padding(.vertical)
        .background(.black)
        .preferredColorScheme(.dark)
}

#Preview("Chat notification") {
    OrbitFeedbackView.chatBanner(sender: "NIC", message: "aku mau pipis")
        .padding()
        .background(.black)
        .preferredColorScheme(.dark)
}
#endif
