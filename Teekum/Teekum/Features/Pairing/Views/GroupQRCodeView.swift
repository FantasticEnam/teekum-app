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
                .font(isDraft ? .custom("Helvetica", size: 22, relativeTo: .title2) : .system(.title3, design: .serif, weight: .bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)

            if isDraft {
                GroupPairingInviteView(session: session)
                    .frame(maxHeight: .infinity, alignment: .top)

                shareLink
                    .padding(.top, 22)
                    .layoutPriority(1)
            } else {
                VStack(spacing: 0) {
                    GroupPairingInviteView(session: session, isDraft: false)
                    shareLink
                }
                .padding(.horizontal, 8)
                .padding(.top, 24)
                .padding(.bottom, 19)
                .frame(maxWidth: 318)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(white: 0.28), lineWidth: 1)
                        .allowsHitTesting(false)
                }

                Label("Key fingerprint \(session.keyFingerprint)", systemImage: "lock.shield")
                    .font(.custom("Helvetica", size: 12, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }

        }
    }

    private var shareLink: some View {
        ShareLink(
            item: session.inviteURL(),
            subject: Text("Join \(session.sessionName) on Meepo"),
            message: Text("Join my group on Meepo: \(session.sessionName)")
        ) {
            Text("Share Invite Link")
                .font(isDraft ? .custom("Helvetica", size: 14, relativeTo: .subheadline) : .system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(isDraft ? Color.white : Color.black)
                .padding(.horizontal, 12)
                .frame(minWidth: isDraft ? nil : 180, maxWidth: isDraft ? .infinity : nil, minHeight: isDraft ? 36 : 32)
                .background(isDraft ? Color(white: 0.11) : .buttonPrimary, in: Capsule())
                .frame(minHeight: isDraft ? nil : 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    GroupQRCodeView(session: GroupSession(sessionName: "Fantasix", localInitials: "NIC"), isDraft: true)
        .foregroundStyle(.white)
        .frame(height: 347)
        .padding(42)
        .background(.black)
}
