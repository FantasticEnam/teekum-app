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
    @ScaledMetric(relativeTo: .title) private var warningIconSize = 42

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: warningIconSize))
                    .foregroundStyle(Color.yellowProfile)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Emergency Alert!")
                        .font(.custom("Charter-Bold", size: 19, relativeTo: .headline))
                        .accessibilityAddTraits(.isHeader)
                    if alert.timestamp.timeIntervalSince1970 > 0 {
                        Text("**\(alert.senderInitials)** has sent an SOS request. Head to their location and check on them!")
                    } else {
                        Text("**\(alert.senderInitials)** has sent an SOS request. Their location is unavailable.")
                    }
                }
                .font(.custom("Charter-Roman", size: 14, relativeTo: .subheadline))
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)

            Button(action: onDismiss) {
                Text("I’ll be there!")
                    .font(.custom("Charter-Bold", size: 17, relativeTo: .headline))
                    .foregroundStyle(Color.alertRed)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.white, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.alertRed, in: .rect(cornerRadius: 30))
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview("Incoming SOS") {
    IncomingSOSAlertBannerView(alert: .preview, onDismiss: {})
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
