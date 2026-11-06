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

            if let date = member.latestLocation?.timestamp {
                TimelineView(.periodic(from: date, by: 1)) { timeline in
                    let label = Self.locationAgeLabel(from: date, relativeTo: timeline.date)

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

    static func locationAgeLabel(from date: Date, relativeTo now: Date) -> LocalizedStringResource {
        let age = now.timeIntervalSince(date)
        guard age.isFinite, age >= 0, age < Double(Int.max) else {
            return "Unavailable"
        }

        if age < 60 {
            return "\(Int(age))s ago"
        }
        return "\(Int(age / 60))m ago"
    }
}

#Preview("Seconds, minutes, and no location") {
    HStack(alignment: .top, spacing: 16) {
        FriendListMemberView(
            member: Member(
                initials: "NIC",
                latestLocation: LocationSample(
                    latitude: 0, longitude: 0,
                    horizontalAccuracy: 5,
                    timestamp: .now.addingTimeInterval(-25)
                )
            ),
            color: .peachProfile
        )
        FriendListMemberView(
            member: Member(
                initials: "AYU",
                latestLocation: LocationSample(
                    latitude: 0, longitude: 0,
                    horizontalAccuracy: 5,
                    timestamp: .now.addingTimeInterval(-125)
                )
            ),
            color: .orangeProfile
        )
        FriendListMemberView(
            member: Member(initials: "ADI"),
            color: .whiteProfile
        )
    }
    .padding(24)
    .background(.black)
    .preferredColorScheme(.dark)
}
