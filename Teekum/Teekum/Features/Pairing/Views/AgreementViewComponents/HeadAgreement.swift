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
                .accessibilityHidden(true)

            Text("Together, Beyond the Signal")
                .font(.custom("Helvetica", size: 20, relativeTo: .title3))
                .bold()
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 2)

            Text("Stay connected. Here’s how Meepo keeps your group connected")
                .font(.custom("Helvetica-Oblique", size: 13, relativeTo: .footnote))
                .foregroundStyle(secondaryText)
        }
        .multilineTextAlignment(.center)
    }
}

#Preview("Agreement Header") {
    HeadAgreement(profileColor: .yellowProfile)
}
