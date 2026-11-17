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
                    .font(.custom("Helvetica", size: 9, relativeTo: .caption2))
                    .foregroundStyle(.primary)

                Text(summaryTitle)
                    .font(.custom("Helvetica", size: 14, relativeTo: .body))
                    .padding(.bottom, 3)
                    .foregroundStyle(.primary)
                    .bold()

                Text(mode == .create
                     ? "You’re about to create a group as its host."
                     : "You’re about to join a group as a member.")
                    .font(.custom("Helvetica", size: 7, relativeTo: .caption2))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        

            VStack(spacing: 1) {
                Text("Your Initials")
                    .font(.custom("Helvetica", size: 8, relativeTo: .caption2))
                    .foregroundStyle(.white)
                Text("[ \(initials) ]")
                    .font(.custom("Helvetica", size: 18, relativeTo: .headline))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 70)
        .background(Color.buttonPrimary, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview("Group Summary") {
    AgreementGroupSummaryView(groupName: "Meepo Group", initials: "NIC")
        
}
