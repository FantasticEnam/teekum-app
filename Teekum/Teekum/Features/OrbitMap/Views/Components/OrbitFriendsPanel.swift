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
    var isUserSOSActive = false
    var followedMember: Member?
    var followDistance: Double?
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let height: CGFloat = 88
    private let friendSlots = 4
    private let sectionSpacing: CGFloat = 18
    private let friendSpacing: CGFloat = 7
    private let badgeSize: CGFloat = 46

    var body: some View {
        let hasOverflow = members.count > friendSlots
        let orderedFriends = hasOverflow
            ? members.filter(\.isEmergency) + members.filter { !$0.isEmergency }
            : members
        let visibleFriends = orderedFriends.prefix(hasOverflow ? friendSlots - 1 : friendSlots)
        let hiddenCount = members.count - visibleFriends.count
        let hiddenSOS = orderedFriends.dropFirst(visibleFriends.count).contains(where: \.isEmergency)
        let hasSOS = isUserSOSActive || members.contains(where: \.isEmergency)

        Button(action: onOpen) {
            VStack(spacing: 16) {
                Capsule()
                    .fill(.white.opacity(0.12))
                    .frame(width: 96, height: 3)

                GeometryReader { geometry in
                    let spacing = sectionSpacing * 2 + friendSpacing * CGFloat(friendSlots - 1) + 1
                    let size = min(badgeSize, max(0, geometry.size.width - spacing) / CGFloat(friendSlots + 1))
                    HStack(spacing: 0) {
                        badge(nickname, color: profileColor, size: size, isEmergency: isUserSOSActive)

                        friendsRow(visibleFriends, hiddenCount: hiddenCount, hiddenSOS: hiddenSOS,
                            width: max(0, geometry.size.width - size), size: size)
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
        .accessibilityValue(panelAccessibilityValue(hasSOS: hasSOS))
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

    private func friendsRow(_ visibleFriends: ArraySlice<Member>, hiddenCount: Int, hiddenSOS: Bool,
                            width: CGFloat, size: CGFloat) -> some View {
        let isFollowing = followedMember != nil
        let targetX = max(0, width - size)
        let firstFriendX = sectionSpacing * 2 + 1
        let spacing = size + friendSpacing
        let slide: Animation? = reduceMotion ? nil : .smooth(duration: 0.36)
        let hiddenTarget = followedMember.flatMap { target in
            visibleFriends.contains(where: { $0.id == target.id }) ? nil : target
        }

        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1, height: size)
                .offset(x: sectionSpacing)
                .opacity(isFollowing ? 0 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isFollowing)

            Color.clear.overlay(alignment: .leading) {
                if let followedMember {
                    OrbitFollowTrack(nickname: followedMember.initials, distance: followDistance)
                        .frame(width: max(0, targetX - 16), height: badgeSize)
                        .offset(x: 8)
                        .id(followedMember.id)
                        .transition(followTrackTransition)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.28).delay(isFollowing ? 0.26 : 0),
                       value: followedMember?.id)

            ForEach(Array(visibleFriends.enumerated()), id: \.element.id) { index, member in
                let isTarget = member.id == followedMember?.id
                badge(member.initials, color: member.color.swiftUIColor, size: size, isEmergency: member.isEmergency)
                    .offset(x: isFollowing ? targetX : firstFriendX + CGFloat(index) * spacing)
                    .animation(slide, value: isFollowing)
                    .opacity(!isFollowing || isTarget ? 1 : 0)
                    .animation(badgeFade(isFollowing: isFollowing), value: !isFollowing || isTarget)
                    .zIndex(isTarget ? 2 : 1)
            }
            if hiddenCount > 0 {
                badge("+\(hiddenCount)", color: .white.opacity(0.45), size: size, isEmergency: hiddenSOS)
                    .offset(x: isFollowing ? targetX : firstFriendX + CGFloat(visibleFriends.count) * spacing)
                    .animation(slide, value: isFollowing)
                    .opacity(isFollowing ? 0 : 1)
                    .animation(badgeFade(isFollowing: isFollowing), value: isFollowing)
                    .zIndex(1)
            }

            Color.clear.overlay(alignment: .trailing) {
                if let hiddenTarget {
                    badge(hiddenTarget.initials, color: hiddenTarget.color.swiftUIColor, size: size,
                          isEmergency: hiddenTarget.isEmergency)
                        .id(hiddenTarget.id)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
            .animation(badgeFade(isFollowing: isFollowing), value: hiddenTarget?.id)
            .zIndex(2)
        }
        .frame(width: width, height: size, alignment: .leading)
    }

    private func badgeFade(isFollowing: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.16).delay(isFollowing ? 0.20 : 0)
    }

    private var followTrackTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .modifier(active: OrbitFollowTrackReveal(progress: 0),
                                 identity: OrbitFollowTrackReveal(progress: 1)),
            removal: .opacity
        )
    }

    private func panelAccessibilityValue(hasSOS: Bool) -> Text {
        if let followedMember {
            if let followDistance {
                let measurement = followDistance.formattedDistance()
                return Text("Following \(followedMember.initials), \(measurement) away")
            }
            return Text("Following \(followedMember.initials), waiting for location")
        }
        return hasSOS ? Text("\(members.count) friends, SOS active") : Text("\(members.count) friends")
    }

    private func badge(_ text: String, color: Color, size: CGFloat, isEmergency: Bool) -> some View {
        FriendAvatarBackground(color: color, isEmergency: isEmergency, borderWidth: 0.75)
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

#Preview("Friends to Follow") {
    @Previewable @State var following = false
    @Previewable @State var distance = 12.0
    let friends = ["NIC", "AYU", "GES", "ADY"].map { Member(id: $0) }

    VStack {
        OrbitFriendsPanel(nickname: "VAN", profileColor: .purple, members: friends,
            followedMember: following ? friends.first : nil, followDistance: distance, onOpen: {})
        Button(following ? "Stop following" : "Follow NIC") {
            if !following { distance = 12 }
            following.toggle()
        }
        Slider(value: $distance, in: 0...18)
            .accessibilityLabel("Distance in meters")
    }
    .padding(24)
    .background(.black)
    .preferredColorScheme(.dark)
}

#Preview("Local and friend SOS") {
    let friends = [Member(id: "NIC"), Member(id: "AYU"), Member(id: "GES"), Member(id: "ADY"),
                   Member(id: "HSN", isEmergency: true)]
    OrbitFriendsPanel(nickname: "VAN", profileColor: .purple, members: friends, isUserSOSActive: true, onOpen: {})
        .padding(24)
        .background(.black)
        .preferredColorScheme(.dark)
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
