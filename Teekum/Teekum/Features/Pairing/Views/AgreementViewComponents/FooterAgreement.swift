//
//  FooterAgreement.swift
//  Teekum
//
//  Created by Ari Hasan on 06/11/26.
//

import SwiftUI

struct FooterAgreement: View {
    @Binding var hasAgreed: Bool
    let canCheckAgreement: Bool
    let termsOfUseURL: URL?
    let privacyPolicyURL: URL?
    let onAgree: () -> Void

    private let secondaryText = Color(white: 0.68)

    var body: some View {
        VStack(spacing: 10) {
            Divider().overlay(Color(white: 0.4))

            Button(action: toggleAgreement) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: hasAgreed ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundStyle(hasAgreed ? Color.buttonPrimary : secondaryText)
                        .opacity(canCheckAgreement ? 1 : 0.5)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("I understand and agree to the above conditions and Meepo's \(Text("Privacy Policy").underline()).")
                        if !canCheckAgreement {
                            Text("Scroll to the end to enable the checkbox.")
                        }
                    }
                    .font(.custom("Helvetica", size: 12, relativeTo: .subheadline))
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .disabled(!canCheckAgreement)
            .accessibilityAddTraits(hasAgreed ? .isSelected : [])

            PrimaryButtonView(
                title: "Agree & Join Group",
                trailingSystemImage: "arrow.right",
                action: onAgree
            )
            .disabled(!hasAgreed)
            .opacity(hasAgreed ? 1 : 0.90)

            Text("By continuing, you agree to Meepo's \(policyText(String(localized: "Terms of Use"), url: termsOfUseURL)) and \(policyText(String(localized: "Privacy Policy"), url: privacyPolicyURL))")
                .font(.custom("Helvetica", size: 10, relativeTo: .caption))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.plain)
        .padding(.top, 3)
    }

    private func policyText(_ title: String, url: URL?) -> Text {
        var text = AttributedString(title)
        text.link = url
        return Text(text).underline()
    }

    private func toggleAgreement() {
        hasAgreed.toggle()
    }
}

#Preview("Consent and Join") {
    @Previewable @State var hasAgreed = false

    FooterAgreement(hasAgreed: $hasAgreed, canCheckAgreement: true, termsOfUseURL: nil, privacyPolicyURL: nil, onAgree: {})
}
