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

    var body: some View {
        VStack(spacing: 8) {
            if let sos {
                if let alert = sos.incomingAlert {
                    IncomingSOSAlertBannerView(alert: alert, onDismiss: sos.dismissIncomingAlert)
                }
                InactivityWarningView(guardService: sos.inactivityGuard)
                SOSDeliveryStatusView(state: sos.deliveryState, onRetry: sos.retrySOS, onDismiss: sos.dismissDeliveryStatus)
            }
            if let message = notifications?.message {
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
}

#if DEBUG
#Preview("Incoming SOS feedback") {
    @Previewable @State var sos = SOSViewModel.preview

    OrbitFeedbackView(sos: sos, notifications: nil)
        .padding(.vertical)
        .background(.black)
        .preferredColorScheme(.dark)
}
#endif
