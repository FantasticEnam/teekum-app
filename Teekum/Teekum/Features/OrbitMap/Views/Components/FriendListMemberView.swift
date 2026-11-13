//
//  FriendListMemberView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 06/11/26.
//

import SwiftUI

struct FriendListMemberView: View {
    let member: Member
    let color: Color

    @ScaledMetric(relativeTo: .title2)
    private var avatarSize = 60

    var body: some View {
        VStack(spacing: 8) {
            Text(member.initials)
                .font(
                    .custom(
                        "Charter-Bold",
                        size: 26,
                        relativeTo: .title2
                    )
                )
                .foregroundStyle(
                    color == .whiteProfile
                        ? Color.black
                        : Color.white
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: avatarSize, height: avatarSize)
                .background(color, in: .circle)

            if let date = member.measurementTimestamp {
                TimelineView(.periodic(from: date, by: 1)) { timeline in
                    let label = FriendListViewModel.locationAgeLabel(from: date, relativeTo: timeline.date)

                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Location age")
                        .accessibilityValue(Text(label))
                }
            } else {
                Text("No location")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

}

#Preview("Seconds, minutes, and no location") {
    HStack(alignment: .top, spacing: 16) {
        FriendListMemberView(
            member: Member(
                id: "NIC", measurementTimestamp: .now.addingTimeInterval(-25)
            ),
            color: .peachProfile
        )
        FriendListMemberView(
            member: Member(
                id: "AYU", measurementTimestamp: .now.addingTimeInterval(-125)
            ),
            color: .orangeProfile
        )
        FriendListMemberView(
            member: Member(id: "ADI"),
            color: .whiteProfile
        )
    }
    .padding(24)
    .background(.black)
    .preferredColorScheme(.dark)
}
