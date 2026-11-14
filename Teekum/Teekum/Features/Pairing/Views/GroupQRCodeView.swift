//
//  PairingProfileColor.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//


import SwiftUI

struct GroupQRCodeView: View {
    let session: GroupSession
    var isDraft = false

    var body: some View {
        VStack(spacing: 0) {
            Text(session.sessionName)
                .font(.custom("Helvetica", size: 22, relativeTo: .title2))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)

            GroupPairingInviteView(session: session)
                .frame(maxHeight: isDraft ? .infinity : nil, alignment: .top)

            if !isDraft {
                Label("Key fingerprint \(session.keyFingerprint)", systemImage: "lock.shield")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }

            ShareLink(
                item: session.inviteURL(),
                subject: Text("Join \(session.sessionName) on Meepo"),
                message: Text("Join my group on Meepo: \(session.sessionName)")
            ) {
                Text("Share Invite Link")
                    .font(.custom("Helvetica", size: 14, relativeTo: .subheadline))
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(Color(white: 0.11), in: Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, isDraft ? 22 : 12)
            .layoutPriority(1)
        }
    }
}

#Preview {
    GroupQRCodeView(session: GroupSession(sessionName: "Fantasix", localInitials: "NIC"), isDraft: true)
        .foregroundStyle(.white)
        .frame(height: 347)
        .padding(42)
        .background(.black)
}
