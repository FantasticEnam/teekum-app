//
//  CardAgreement.swift
//  Teekum
//
//  Created by Ari Hasan on 06/11/26.
//

import SwiftUI

struct CardAgreement: View {
    var isScrollable = true
    var onReachEnd: () -> Void = {}

    var body: some View {
        Group {
            if isScrollable {
                ScrollView {
                    cardContent
                }
                .scrollIndicators(.visible)
                // Let ViewThatFits measure the viewport instead of the full text.
                .frame(minHeight: 160, idealHeight: 160, maxHeight: .infinity)
            } else {
                cardContent
            }
        }
        .background(Color(white: 0.15), in: .rect(cornerRadius: 8))
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            agreementText
            Color.clear
                .frame(height: 1)
                .accessibilityHidden(true)
                .onScrollVisibilityChange { isVisible in
                    if isVisible { onReachEnd() }
                }
        }
    }

    private var agreementText: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Before getting started, here's what you should know about how MEEPO works and how your device participates.")
                    .bold()
                    .foregroundStyle(.white)
                
                Spacer()

                section("01. Community-Powered Mesh Network") {
                    Text("MEEPO uses a community-powered mesh network that allows nearby participating devices to relay encrypted data between one another.")
                    Text("Your device can help pass messages and location updates across the network, allowing information to travel between group members even when internet access or conventional network signals are unavailable.")
                    Text("By participating, your device becomes part of a shared network that helps keep everyone connected.")
                }
            }

            section("02. End-to-End Encrypted Communication") {
                Text("Your communications are protected using ChaCha20-Poly1305 authenticated encryption.")
                Text("When your device relays information for other participants, it forwards encrypted data without needing to access the message contents.")
                Text("This helps protect your communications as they travel across the community network.")
            }

            section("03. Battery-Aware Relay Protection") {
                Text("MEEPO is designed with battery-conscious relay controls to help manage your device's power consumption.")
                Text("Network activity is rate-limited, while automatic relay protection pauses participation when your battery reaches 20% or when Low Power Mode is enabled.")
                Text("You remain in control of your device's participation throughout your experience.")
            }

            section("04. Background Activity & Live Updates") {
                Text("MEEPO supports iOS features such as Live Activities to help you keep track of important group updates without constantly opening the app.")
                Text("Depending on iOS background execution and device availability, supported network activities may continue while the app is not actively in use.")
            }

            section("Before You Continue") {
                Text("By continuing, you acknowledge and agree that:")
                agreementItem("Your device may participate in community mesh relaying when enabled and supported.")
                agreementItem("Your device may forward encrypted data for other participating users.")
                agreementItem("Network availability and location updates depend on device proximity, permissions, and system conditions.")
                agreementItem("Relay participation may consume battery, and automatic battery protection may pause network activity.")
                agreementItem("MEEPO uses device permissions and processes information as described in its Privacy Policy.")
            }
        }
        .font(.custom("Helvetica", size: 12, relativeTo: .body))
        .foregroundStyle(Color(white: 0.82))
        .lineSpacing(2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .bold()
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func agreementItem(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•")
                .accessibilityHidden(true)
            Text(text)
        }
    }
}

#Preview("Agreement Card") {
    CardAgreement()
        .frame(width: 318, height: 384)
        .padding()
        .preferredColorScheme(.dark)
}
