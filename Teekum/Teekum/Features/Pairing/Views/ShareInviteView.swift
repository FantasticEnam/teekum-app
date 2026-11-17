//
//  ShareInviteView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 16/11/26.
//

import SwiftUI

struct ShareInviteView: View {
    let session: GroupSession
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Share Invite")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 52)
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(alignment: .leading) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Back to friends")
                }
                .padding(.horizontal, 28)

            ScrollView {
                GroupQRCodeView(session: session)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 48)
            }
            .defaultScrollAnchor(.center, for: .alignment)
        }
        .foregroundStyle(.white)
        .background(.black)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ShareInviteView(session: GroupSession(sessionName: "Fantasix", localInitials: "NIC"), onBack: {})
}
