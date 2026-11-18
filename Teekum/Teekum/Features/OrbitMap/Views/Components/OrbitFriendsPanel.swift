//
//  OrbitFriendsPanel.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

import SwiftUI

struct OrbitFriendsPanel: View {
    let nickname: String
    let profileColor: Color
    let members: [Member]
    let onOpen: () -> Void

    static let height: CGFloat = 88
    private let friendSlots = 4
    private let sectionSpacing: CGFloat = 18
    private let friendSpacing: CGFloat = 7
    private let badgeSize: CGFloat = 46

    var body: some View {
        let visibleFriends = members.prefix(members.count > friendSlots ? friendSlots - 1 : friendSlots)
        let hiddenCount = members.count - visibleFriends.count

        Button(action: onOpen) {
            VStack(spacing: 16) {
                Capsule()
                    .fill(.white.opacity(0.12))
                    .frame(width: 96, height: 3)

                GeometryReader { geometry in
                    let spacing = sectionSpacing * 2 + friendSpacing * CGFloat(friendSlots - 1) + 1
                    let size = min(badgeSize, max(0, geometry.size.width - spacing) / CGFloat(friendSlots + 1))
                    HStack(spacing: sectionSpacing) {
                        badge(nickname, color: profileColor, size: size)

                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 1, height: size)

                        HStack(spacing: friendSpacing) {
                            ForEach(visibleFriends) { member in
                                badge(member.initials, color: member.color.swiftUIColor, size: size)
                            }
                            if hiddenCount > 0 {
                                badge("+\(hiddenCount)", color: .white.opacity(0.45), size: size)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .frame(height: badgeSize)
            }
            .padding(.horizontal, 28)
            .padding(.top, 6)
            .frame(height: Self.height, alignment: .top)
            .background(Color.blackCard, in: .rect(cornerRadius: 40))
            .contentShape(.rect(cornerRadius: 40))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open friends")
        .accessibilityValue("\(members.count) friends")
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let upwardDistance = -value.translation.height
                    if upwardDistance >= 36, upwardDistance > abs(value.translation.width) {
                        onOpen()
                    }
                }
        )
    }

    private func badge(_ text: String, color: Color, size: CGFloat) -> some View {
        Circle()
            .strokeBorder(color, lineWidth: 0.75)
            .frame(width: size, height: size)
            .overlay {
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 3)
            }
    }
}

#Preview("Four friends and overflow") {
    let friends = ["NIC", "AYU", "GES", "ADY", "HSN", "ALX"].map { Member(id: $0) }
    VStack(spacing: 16) {
        OrbitFriendsPanel(nickname: "VAN", profileColor: .purple, members: Array(friends.prefix(4)), onOpen: {})
        OrbitFriendsPanel(nickname: "VAN", profileColor: .purple, members: friends, onOpen: {})
    }
    .padding(24)
    .background(.black)
    .preferredColorScheme(.dark)
}
