//
//  AggrementGroupSummaryView.swift
//  Teekum
//
//  Created by Ari Hasan on 06/11/26.
//

import SwiftUI

struct AgreementGroupSummaryView: View {
    let groupName: String
    let initials: String
    var mode: PairingMode = .create
    var profileColor: Color = .yellowProfile

    private let cardColor = Color(white: 0.15)
    private let secondaryText = Color(white: 0.68)

    private var summaryTitle: String {
        if groupName.isEmpty {
            return mode == .join ? String(localized: "Joining a group") : String(localized: "Creating a group")
        }
        return mode == .join
            ? String(localized: "Joining “\(groupName)”")
            : String(localized: "Creating “\(groupName)”")
    }

    var body: some View {
        HStack(spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text("GROUP SETUP")
                    .font(.custom("Charter-Bold", size: 9, relativeTo: .caption2))
                    .foregroundStyle(secondaryText)

                Text(summaryTitle)
                    .font(.custom("Charter-Roman", size: 14, relativeTo: .subheadline))

                Text(mode == .create
                     ? "You’re about to create a group as its host."
                     : "You’re about to join a group as a member.")
                    .font(.custom("Charter-Roman", size: 8, relativeTo: .caption2))
                    .foregroundStyle(secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Capsule()
                .fill(profileColor)
                .frame(width: 1, height: 34)
                .accessibilityHidden(true)

            VStack(spacing: 1) {
                Text(mode == .create ? "Host Initials" : "Your Initials")
                    .font(.custom("Charter-Roman", size: 8, relativeTo: .caption2))
                Text("[ \(initials) ]")
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
                .strokeBorder(profileColor, lineWidth: 1)
        }
    }
}

#Preview("Group Summary") {
    AgreementGroupSummaryView(groupName: "Meepo Group", initials: "NIC")
        
}
