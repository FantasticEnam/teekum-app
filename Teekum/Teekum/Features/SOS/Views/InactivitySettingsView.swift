//
//  InactivitySettingsView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct InactivitySettingsView: View {
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Inactivity Guard", isOn: $isEnabled)
                .tint(.yellowProfile)
            Text("After 3 minutes without detected movement or interaction, a 30-second warning lets you cancel before an SOS is sent.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Inactivity opt-in") {
    @Previewable @State var isEnabled = false

    Form {
        InactivitySettingsView(isEnabled: $isEnabled)
    }
    .preferredColorScheme(.dark)
}
