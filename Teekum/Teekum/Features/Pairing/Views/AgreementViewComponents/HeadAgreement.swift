//
//  HeadAgreement.swift
//  Teekum
//
//  Created by Ari Hasan on 06/11/26.
//

import SwiftUI

struct HeadAgreement: View {
    let profileColor: Color

    private let secondaryText = Color(white: 0.68)

    var body: some View {
        VStack(spacing: 7) {
            Circle()
                .fill(profileColor)
                .frame(width: 80, height: 80)
                .shadow(color: profileColor.opacity(0.5), radius: 7)
                .accessibilityHidden(true)

            Text("Together, Beyond the Signal")
                .font(.custom("Charter-Bold", size: 18, relativeTo: .headline))
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 2)

            Text("Stay connected. Here’s how Teekum keeps your group connected")
                .font(.custom("Charter-Italic", size: 11, relativeTo: .caption))
                .foregroundStyle(secondaryText)
        }
        .multilineTextAlignment(.center)
    }
}

#Preview("Agreement Header") {
    HeadAgreement(profileColor: .yellowProfile)
}
