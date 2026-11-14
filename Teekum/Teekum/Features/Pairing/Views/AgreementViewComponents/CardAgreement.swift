//
//  CardAgreement.swift
//  Teekum
//
//  Created by Ari Hasan on 06/11/26.
//

import SwiftUI

struct CardAgreement: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let icon: String

    private let cardColor = Color(white: 0.15)
    private let secondaryText = Color(white: 0.68)

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 23))
                .frame(width: 35)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Helvetica", size: 12, relativeTo: .subheadline))
                Text(description)
                    .font(.custom("Helvetica", size: 8.5, relativeTo: .caption2))
                    .foregroundStyle(secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(minHeight: 70)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Feature Card") {
    CardAgreement(
        title: "Encrypted by Design",
        description: "Participating relay devices forward encrypted data without accessing its contents.",
        icon: "lock.shield"
    )
}
