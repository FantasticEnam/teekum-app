//
//  AggrementGroupSummaryView.swift
//  Teekum
//
//  Created by Ari Hasan on 06/11/26.
//

import SwiftUI

struct AgreementGroupSummaryView: View {
    let groupName: String
    let hostInitials: String

    private let cardColor = Color(white: 0.15)
    private let secondaryText = Color(white: 0.68)

    var body: some View {
        HStack(spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text("GROUP SETUP")
                    .font(.custom("Charter-Bold", size: 9, relativeTo: .caption2))
                    .foregroundStyle(secondaryText)

                Text("Creating “\(groupName)”")
                    .font(.custom("Charter-Roman", size: 14, relativeTo: .subheadline))

                Text("You’re about to create a group as its host.")
                    .font(.custom("Charter-Roman", size: 8, relativeTo: .caption2))
                    .foregroundStyle(secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Capsule()
                .fill(Color.yellowProfile)
                .frame(width: 1, height: 34)
                .accessibilityHidden(true)

            VStack(spacing: 1) {
                Text("Host Initials")
                    .font(.custom("Charter-Roman", size: 8, relativeTo: .caption2))
                Text("[ \(hostInitials) ]")
                    .font(.custom("Charter-Roman", size: 18, relativeTo: .headline))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.25), in: RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 70)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.yellowProfile, lineWidth: 1)
        }
    }
}

#Preview("Group Summary") {
    AgreementGroupSummaryView(groupName: "FANTASIX", hostInitials: "NIC")
        
}
