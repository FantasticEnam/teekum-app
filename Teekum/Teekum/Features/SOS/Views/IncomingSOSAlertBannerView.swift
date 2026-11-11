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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("SOS from \(alert.senderName)", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text(alert.emergencyType.title).font(.subheadline)
            if alert.timestamp.timeIntervalSince1970 > 0 {
                HStack {
                    Text("Location measured")
                    Text(alert.timestamp, style: .relative)
                    Text("ago · ±\(alert.accuracy)m")
                }
                .font(.caption)
            } else {
                Text("Location unavailable").font(.caption)
            }
            Button("Dismiss alert", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.alertRed, in: .rect(cornerRadius: 20))
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
    }
}
