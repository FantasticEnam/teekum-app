//
//  GroupPairingInviteView.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import SwiftUI

struct GroupPairingInviteView: View {
    let session: GroupSession
    @State private var qrImage: UIImage?

    var body: some View {
        let inviteURL = session.inviteURL()
        VStack(spacing: 0) {
            Text("Scan this barcode to join private\ngroup with zero cell reception")
                .font(.custom("Charter-Roman", size: 12, relativeTo: .caption))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 12)

            if let qrImage {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 166, height: 166)
                    .padding(10)
                    .background(.white)
                    .accessibilityLabel("Group invitation QR code")
                    .padding(.bottom, 10)
            } else {
                ContentUnavailableView("QR unavailable", systemImage: "qrcode")
                    .frame(height: 186)
            }

            Label("Key fingerprint \(session.keyFingerprint)", systemImage: "lock.shield")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
                .padding(.bottom, 16)

            ShareLink(item: inviteURL) {
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
        .task(id: inviteURL) { qrImage = QRCodeGenerator.image(for: inviteURL) }
    }
}

#Preview {
    GroupPairingInviteView(session: GroupSession(localInitials: "NIC"))
        .padding(42)
        .background(.black)
        .preferredColorScheme(.dark)
}
