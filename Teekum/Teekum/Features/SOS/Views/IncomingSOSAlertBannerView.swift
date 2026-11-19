//
//  IncomingSOSAlertBannerView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct IncomingSOSAlertBannerView: View {
    let alert: IncomingSOSAlert
    let onDismiss: () -> Void
    let onOfferHelp: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var warningIconSize = 42

    var body: some View {
        let actions = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: warningIconSize))
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Emergency Alert!")
                        .font(.custom("Helvetica", size: 19, relativeTo: .headline).bold())
                        .accessibilityAddTraits(.isHeader)
                    if alert.timestamp.timeIntervalSince1970 > 0 {
                        Text("**\(alert.senderInitials)** has sent an SOS request. Head to their location and check on them!")
                    } else {
                        Text("**\(alert.senderInitials)** has sent an SOS request. Their location is unavailable.")
                    }
                }
                .font(.custom("Helvetica", size: 14, relativeTo: .subheadline))
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)

            actions {
                actionButton("Dismiss", action: onDismiss)
                actionButton("I’ll be there!", action: onOfferHelp)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.alertRed, in: .rect(cornerRadius: 30))
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
    }

    private func actionButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.alertRed)
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(.white, in: .capsule)
                .contentShape(.capsule)
        }
    }
}

#if DEBUG
#Preview("Incoming SOS with Dismiss and Follow") {
    IncomingSOSAlertBannerView(alert: .preview, onDismiss: {}, onOfferHelp: {})
        .padding()
        .background(.black)
        .preferredColorScheme(.dark)
}

extension IncomingSOSAlert {
    static var preview: IncomingSOSAlert {
        IncomingSOSAlert(id: 1, senderInitials: "ADI", senderName: "Adiat",
            emergencyType: .medical, coordinate: .init(latitude: -6.1988, longitude: 106.8225),
            accuracy: 12, timestamp: .now.addingTimeInterval(-15), batteryLevel: 64)
    }
}
#endif
