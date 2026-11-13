//
//  AgreementView.swift
//  Teekum
//
//  Created by Ari Hasan on 06/11/26.
//

import SwiftUI

struct AgreementView: View {
    let form: PairingForm
    var mode: PairingMode = .create
    var termsOfUseURL: URL? = nil
    var privacyPolicyURL: URL? = nil
    var errorMessage: String? = nil
    var isPublicFestivalMesh = false
    var onAgree: () -> Void = {}

    var body: some View {
        VStack(spacing: 13) {
            HeadAgreement(profileColor: form.profileColor.color)
            AgreementGroupSummaryView(
                groupName: form.trimmedSessionName,
                initials: form.initials,
                mode: mode,
                profileColor: form.profileColor.color
            )

            if isPublicFestivalMesh {
                Text("This is a public festival group. Other participants in this group can read your messages and shared location.")
                    .font(.callout)
                    .foregroundStyle(Color.yellowProfile)
                    .multilineTextAlignment(.center)
                    .padding(.vertical)
            }

            CardAgreement(
                title: "Community-Powered Mesh Network",
                description: "Your device can help relay encrypted data between nearby participating devices, helping your group stay connected when conventional network signals are weak or unavailable.",
                icon: "point.3.connected.trianglepath.dotted"
            )
            CardAgreement(
                title: "Encrypted by Design",
                description: "Your communications are protected using ChaCha20-Poly1305 encryption. Participating relay devices forward encrypted data without accessing its contents.",
                icon: "lock.shield"
            )
            CardAgreement(
                title: "Battery-Aware Protection",
                description: "Network activity is rate-limited to help conserve battery. Automatic relay protection pauses when your battery reaches 20% or Low Power Mode is enabled.",
                icon: "battery.100percent.bolt"
            )
            CardAgreement(
                title: "Stay Connected",
                description: "Keep track of your group's activity through supported iOS features, including Live Activities and Offline Chat",
                icon: "square.3.layers.3d"
            )

            FooterAgreement(
                termsOfUseURL: termsOfUseURL,
                privacyPolicyURL: privacyPolicyURL,
                onAgree: onAgree
            )
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 400)
        .padding(.horizontal, 42)
        .padding(.top, 43)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .background {
            RadialGradient(
                colors: [Color(white: 0.09), Color(white: 0.09), .black],
                center: .center,
                startRadius: 40,
                endRadius: 405
            )
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AgreementView(form: PairingForm(
        initials: "NIC", sessionName: "Fantasix", profileColor: .yellow
    ))
}

#Preview("Join without group name") {
    AgreementView(
        form: PairingForm(initials: "ARI", profileColor: .blue),
        mode: .join
    )
}
