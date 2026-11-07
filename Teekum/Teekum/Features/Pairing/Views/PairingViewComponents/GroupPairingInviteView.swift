//
//  GroupPairingInviteView.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import SwiftUI

struct GroupPairingInviteView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Scan this barcode to join private\ngroup with zero cell reception")
                .font(.custom("Charter-Roman", size: 12, relativeTo: .caption))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 12)

            // Static artwork
            Image("pairing_qr_placeholder")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 166, height: 166)
                .accessibilityLabel("Group invitation QR code placeholder")
                .padding(.bottom, 20)

            Button(action: shareInviteLink) {
                Text("Share Invite Link")
                    .font(.custom("Charter-Bold", size: 14, relativeTo: .subheadline))
                    .frame(minWidth: 180, minHeight: 32)
                    .background(Color(white: 0.11), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, minHeight: 300)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(white: 0.28), lineWidth: 1)
        }
    }

    private func shareInviteLink() {
        // UI only. Invite sharing will be connected separately.
    }
}

#Preview {
    GroupPairingInviteView()
        .padding(42)
        .background(.black)
        .preferredColorScheme(.dark)
}
