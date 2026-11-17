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
            VStack {
                AgreementGroupSummaryView(
                    groupName: form.trimmedSessionName,
                    initials: form.initials,
                    mode: mode,
                )
            }
            .foregroundStyle(.black)
            
            if isPublicFestivalMesh {
                Text("This is a public festival group. Other participants in this group can read your messages and shared location.")
                    .font(.custom("Helvetica", size: 16, relativeTo: .callout))
                    .foregroundStyle(Color.yellowProfile)
                    .multilineTextAlignment(.center)
                    .padding(.vertical)
            }
            
            CardAgreement(
                title: "Community-Powered Mesh Network",
                description: "Your device helps pass messages between nearby participating devices.",
                icon: "point.3.connected.trianglepath.dotted"
            )
            CardAgreement(
                title: "Encrypted by Design",
                description: "Your messages stay private with ChaCha20-Poly1305 encryption.",
                icon: "lock.shield"
            )
            CardAgreement(
                title: "Battery-Aware Protection",
                description: "Limits network activity to help save battery, with automatic safeguards to manage power usage.",
                icon: "battery.100percent.bolt"
            )
            CardAgreement(
                title: "Stay Connected",
                description: "Keep up with your group's activity through handy iOS features like Live Activities.",
                icon: "square.3.layers.3d"
            )
            
            FooterAgreement(
                termsOfUseURL: termsOfUseURL,
                privacyPolicyURL: privacyPolicyURL,
                onAgree: onAgree
            )
            if let errorMessage {
                Text(errorMessage)
                    .font(.custom("Helvetica", size: 13, relativeTo: .footnote))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 400)
        .padding(.horizontal, 42)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        
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
        form: PairingForm(initials: "ARI", profileColor: .purple),
        mode: .join
    )
}
