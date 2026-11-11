//
//  InactivityWarningView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct InactivityWarningView: View {
    let guardService: InactivityGuardService

    var body: some View {
        if guardService.isWarningActive {
            VStack(spacing: 12) {
                Label("Are you OK?", systemImage: "hand.raised.fill")
                    .font(.headline)
                Text("Auto-SOS in \(Int(guardService.countdownRemaining.rounded(.up))) seconds. Move your phone or tap below.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                PrimaryButtonView(title: "I'm OK", action: guardService.cancelWarning)
            }
            .padding()
            .background(Color.blackCard, in: .rect(cornerRadius: 20))
        }
    }
}
