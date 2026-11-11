//
//  PairingProfileColor.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//


import SwiftUI

struct GroupQRCodeView: View {
    let session: GroupSession

    var body: some View {
        VStack(spacing: 10) {
            Text(session.sessionName)
                .font(.custom("Charter-Bold", size: 22, relativeTo: .title2))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            GroupPairingInviteView(session: session)
        }
    }
}

#Preview {
    GroupQRCodeView(session: GroupSession(sessionName: "Fantasix", localInitials: "NIC"))
        .foregroundStyle(.white)
        .padding(42)
        .background(.black)
}
