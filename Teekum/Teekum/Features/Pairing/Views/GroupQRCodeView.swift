//
//  PairingProfileColor.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//


import SwiftUI

// Dummy Assets, soon will be change to real QR Code
struct GroupQRCodeView: View {
    let sessionName: String

    var body: some View {
        VStack(spacing: 10) {
            Text(sessionName)
                .font(.custom("Charter-Bold", size: 22, relativeTo: .title2))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            GroupPairingInviteView()
        }
    }
}

#Preview {
    GroupQRCodeView(sessionName: "Fantasix")
        .foregroundStyle(.white)
        .padding(42)
        .background(.black)
}
