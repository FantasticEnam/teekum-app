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
                .font(.custom("Helvetica", size: 12, relativeTo: .caption))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 12)
                .fixedSize(horizontal: false, vertical: true)

            if let qrImage {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 166, maxHeight: 166)
                    .padding(10)
                    .background(.white)
                    .accessibilityLabel("Group invitation QR code")
            } else {
                Label("QR unavailable", systemImage: "qrcode")
                    .frame(maxHeight: 186)
            }

        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: 255)
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
