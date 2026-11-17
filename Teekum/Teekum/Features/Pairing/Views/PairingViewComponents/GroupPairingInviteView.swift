//
//  GroupPairingInviteView.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import SwiftUI

struct GroupPairingInviteView: View {
    let session: GroupSession
    var isDraft = true
    @State private var qrImage: UIImage?

    var body: some View {
        let inviteURL = session.inviteURL()
        VStack(spacing: 0) {
            Text("Scan this barcode to join private\ngroup with zero cell reception")
                .font(isDraft ? .custom("Helvetica", size: 12, relativeTo: .caption) : .system(.caption, design: .serif))
                .multilineTextAlignment(.center)
                .lineSpacing(isDraft ? 3 : 1)
                .padding(.bottom, isDraft ? 12 : 2)
                .fixedSize(horizontal: false, vertical: true)

            if let qrImage {
                let qrCode = Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: isDraft ? 166 : 258, maxHeight: isDraft ? 166 : 258)
                    .padding(isDraft ? 10 : 20)
                    .background(.white)

                Group {
                    if isDraft {
                        qrCode
                    } else {
                        qrCode.colorInvert()
                    }
                }
                    .accessibilityLabel("Group invitation QR code")
            } else {
                Label("QR unavailable", systemImage: "qrcode")
                    .font(.custom("Helvetica", size: 12, relativeTo: .caption))
                    .frame(maxHeight: 186)
            }

        }
        .foregroundStyle(.white)
        .padding(.horizontal, isDraft ? 16 : 0)
        .padding(.vertical, isDraft ? 14 : 0)
        .frame(maxWidth: isDraft ? 255 : nil)
        .background {
            if isDraft {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(white: 0.28), lineWidth: 1)
            }
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
