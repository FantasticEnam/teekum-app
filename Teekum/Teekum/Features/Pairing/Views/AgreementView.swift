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

    @State private var hasAgreed = false
    @State private var hasReachedAgreementEnd = false
    
    var body: some View {
        ViewThatFits(in: .vertical) {
            agreementContent(cardScrolls: true)
            ScrollView {
                agreementContent(cardScrolls: false)
            }
        }
        .frame(maxWidth: 400)
        .padding(.horizontal, 42)
        .padding(.vertical, 20)
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

    private func agreementContent(cardScrolls: Bool) -> some View {
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
            
            CardAgreement(isScrollable: cardScrolls) {
                hasReachedAgreementEnd = true
            }
            
            FooterAgreement(
                hasAgreed: $hasAgreed,
                canCheckAgreement: hasReachedAgreementEnd,
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
