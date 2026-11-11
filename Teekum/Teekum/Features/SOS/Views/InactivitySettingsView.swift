//
//  InactivitySettingsView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct InactivitySettingsView: View {
    @Bindable var guardService: InactivityGuardService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Inactivity Guard", isOn: $guardService.isEnabled)
                .tint(.yellowProfile)
            Text("After 3 minutes without detected movement or interaction, a 30-second warning lets you cancel before an SOS is sent.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
