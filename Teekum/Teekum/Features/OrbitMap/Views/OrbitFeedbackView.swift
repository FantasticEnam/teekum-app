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
    var onOpenChat: () -> Void = {}
    var onHelpOffered: (IncomingSOSAlert) -> Void = { _ in }
    var onDeepLink: ((URL) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            if let sos {
                if let alert = sos.incomingAlert {
                    IncomingSOSAlertBannerView(alert: alert, onDismiss: {
                        Task { await sos.acknowledgeIncomingAlert(alert) }
                    }, onOfferHelp: {
                        Task {
                            await sos.acknowledgeIncomingAlert(alert) { onHelpOffered(alert) }
                        }
                    })
                }
                InactivityWarningView(guardService: sos.inactivityGuard)
                if sos.outgoingEventId != nil {
                    ActiveSOSBannerView(deliveryState: sos.deliveryState, isEnding: sos.isResolving,
                        error: sos.resolutionError, helperOnTheWay: sos.helperOnTheWay,
                        onEnd: sos.endSOS, onDismissHelper: sos.dismissHelperOnTheWay)
                } else {
                    SOSDeliveryStatusView(state: sos.deliveryState, onRetry: sos.retrySOS, onDismiss: sos.dismissDeliveryStatus)
                }
            }
            if showsChatAlert, let alert = notifications?.chatAlert {
                ChatNotificationBannerView(sender: alert.sender, message: alert.body,
                    onOpen: onOpenChat, onDismiss: dismissChatAlert)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            } else if let banner = notifications?.banner {
                Button {
                    if let url = banner.deepLinkURL {
                        onDeepLink?(url)
                    }
                    notifications?.dismissBanner()
                } label: {
                    NotificationBannerView(title: banner.title, message: banner.body, icon: banner.icon)
                }
                .buttonStyle(.plain)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .animation(.easeOut(duration: 0.2), value: notifications?.chatAlert != nil)
        .animation(.easeOut(duration: 0.2), value: notifications?.banner != nil)
    }

    private func dismissChatAlert() {
        notifications?.dismissChatAlert()
    }
}

#if DEBUG
#Preview("Dismiss SOS banner and keep the glow") {
    @Previewable @State var sos = SOSViewModel.preview

    OrbitFeedbackView(sos: sos, notifications: nil)
        .padding(.vertical)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.black)
        .overlay { SOSEdgeGlowView(sos: sos) }
        .preferredColorScheme(.dark)
}

#endif
