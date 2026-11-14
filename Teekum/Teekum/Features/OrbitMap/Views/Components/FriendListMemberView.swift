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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .title2)
    private var avatarSize = 60

    var body: some View {
        VStack(spacing: 4) {
            Text(member.initials)
                .font(
                    .custom(
                        "Helvetica",
                        size: 22,
                        relativeTo: .title2
                    )
                )
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: avatarSize, height: avatarSize)
                .background {
                    if member.isEmergency {
                        if reduceMotion {
                            emergencyAvatar
                        } else {
                            emergencyAvatar.phaseAnimator([1.0, 0.55]) { avatar, opacity in
                                avatar.opacity(opacity)
                            } animation: { _ in .easeInOut(duration: 0.8) }
                        }
                    } else {
                        Circle().strokeBorder(color, lineWidth: 1)
                    }
                }
                .accessibilityValue(member.isEmergency ? Text("SOS active") : Text(""))

            if let date = member.measurementTimestamp {
                TimelineView(.periodic(from: date, by: 1)) { timeline in
                    let label = FriendListViewModel.locationAgeLabel(from: date, relativeTo: timeline.date)

                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .accessibilityLabel("Location age")
                        .accessibilityValue(Text(label))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var emergencyAvatar: some View {
        Circle()
            .inset(by: 3)
            .fill(Color.alertRed)
            .overlay {
                Circle().strokeBorder(Color.alertRed, lineWidth: 2)
            }
    }
}

#Preview("Location age and active SOS") {
    HStack(alignment: .top, spacing: 16) {
        FriendListMemberView(
            member: Member(
                id: "NIC", measurementTimestamp: .now.addingTimeInterval(-25)
            ),
            color: .peachProfile
        )
        FriendListMemberView(
            member: Member(
                id: "AYU", isEmergency: true, measurementTimestamp: .now.addingTimeInterval(-125)
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
