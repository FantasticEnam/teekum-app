//
//  FriendListSheet.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 06/11/26.
//

import SwiftUI

struct FriendListSheet: View {
    let onShareInvite: () -> Void
    let onSelectMember: (Member) -> Void
    let onLeaveGroup: () -> Void
    private let isUserSOSActive: @MainActor () -> Bool
    var selectedMemberId: String? = nil
    var onStopFollow: () -> Void = {}
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: FriendListViewModel
    @State private var confirmLeave = false
    @State private var memberToConfirm: Member? = nil
    @FocusState private var isSearchFocused: Bool
    
    @ScaledMetric(relativeTo: .title2)
    private var cellWidth = 66

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cellWidth), spacing: 16)]
    }
    
    init(
        sessionStore: SessionStore,
        onShareInvite: @escaping () -> Void,
        onSelectMember: @escaping (Member) -> Void,
        onLeaveGroup: @escaping () -> Void,
        isUserSOSActive: @escaping @MainActor () -> Bool = { false },
        selectedMemberId: String? = nil,
        onStopFollow: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: FriendListViewModel(sessionStore: sessionStore))
        self.onShareInvite = onShareInvite
        self.onSelectMember = onSelectMember
        self.onLeaveGroup = onLeaveGroup
        self.isUserSOSActive = isUserSOSActive
        self.selectedMemberId = selectedMemberId
        self.onStopFollow = onStopFollow
    }
    
    var body: some View {
        let members = viewModel.filteredMembers
        
        VStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Capsule()
                    .fill(.white.opacity(0.12))
                    .frame(width: 96, height: 3)
                    .padding(.top, 9)
                    .frame(width: 144, height: 40, alignment: .top)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close friends")
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height > 50,
                           value.translation.height > abs(value.translation.width) {
                            dismiss()
                        }
                    }
            )
            
            VStack(spacing: 0) {
                searchAndInvite

                localProfileRow
                    .padding(.top, 29)
                    .padding(.bottom, 20)

                Divider()

                GeometryReader { geometry in
                    ScrollView {
                        if members.isEmpty {
                            ContentUnavailableView(
                                "No friends found",
                                systemImage: "person.2",
                                description: Text("Try another name or share an invite.")
                            )
                            .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                        } else {
                            memberGrid(members)
                                .padding(.top, 14)
                                .padding(.bottom, 16)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .contentShape(.rect)
                    .simultaneousGesture(TapGesture().onEnded { isSearchFocused = false })
                }
            }
            .padding(.horizontal, 24)
            
            if !isSearchFocused {
                PrimaryButtonView(title: "Leave Group") {
                    confirmLeave = true
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 54)
                .fill(Color.blackCard)
                .ignoresSafeArea(edges: .bottom)
                .onTapGesture { isSearchFocused = false }
        }
        .alert(
            "Leave this group?",
            isPresented: $confirmLeave
        ) {
            Button("Cancel", role: .cancel) {}
            
            Button(
                "Leave Group",
                role: .destructive,
                action: onLeaveGroup
            )
        } message: {
            Text("Are you sure you want to leave this group?")
        }
        .alert(
            selectedMemberId == memberToConfirm?.id ? "Stop Following?" : "Follow \(memberToConfirm?.initials ?? "Friend")?",
            isPresented: Binding(
                get: { memberToConfirm != nil },
                set: { if !$0 { memberToConfirm = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                memberToConfirm = nil
            }
            if selectedMemberId == memberToConfirm?.id {
                Button("Stop", role: .destructive) {
                    onStopFollow()
                    memberToConfirm = nil
                }
            } else {
                Button("Follow") {
                    if let member = memberToConfirm {
                        onSelectMember(member)
                    }
                    memberToConfirm = nil
                }
            }
        } message: {
            if selectedMemberId == memberToConfirm?.id {
                Text("Stop following \(memberToConfirm?.initials ?? "this friend") on the radar?")
            } else {
                Text("You will be guided towards \(memberToConfirm?.initials ?? "this friend").")
            }
        }
    }

    private var searchAndInvite: some View {
        @Bindable var viewModel = viewModel
        return HStack(spacing: 10) {
            HStack {
                TextField("Search name", text: $viewModel.searchQuery)
                    .focused($isSearchFocused)
                    .submitLabel(.done)
                    .onSubmit { isSearchFocused = false }
                    .autocorrectionDisabled()

                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
            .padding(.horizontal, 20)
            .frame(minHeight: 46)
            .background(.white.opacity(0.1), in: .capsule)

            Button {
                isSearchFocused = false
                onShareInvite()
            } label: {
                Image(systemName: "person.fill.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 46)
                    .contentShape(.capsule)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share invite QR")
        }
    }

    @ViewBuilder
    private var localProfileRow: some View {
        if let profile = localProfile {
            LazyVGrid(columns: columns) {
                FriendListMemberView(member: profile, color: profile.color.swiftUIColor)
                    .accessibilityLabel("\(profile.initials), your profile")
                    .accessibilityValue(profile.isEmergency ? Text("SOS active") : Text(""))
            }
        }
    }

    private func memberGrid(_ members: [Member]) -> some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(members) { member in
                Button {
                    isSearchFocused = false
                    memberToConfirm = member
                } label: {
                    FriendListMemberView(member: member, color: member.color.swiftUIColor)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Show this friend on the Orbit radar")
            }
        }
    }

    private var localProfile: Member? {
        var profile = viewModel.localProfile
        profile?.isEmergency = isUserSOSActive()
        return profile
    }
}

#Preview("Invite beside search and aligned friend grid") {
    let store = SessionStore.preview
    store.activeSession?.localInitials = "VAN"
    store.members = ["NIC", "AYU", "GES", "ADY", "AYI", "HSN", "RIO", "NAD", "ALX", "ADI",
                     "AML", "EBI", "DAF", "ANA", "JON", "MIA", "NOV", "EVA", "UNA"].enumerated().map { index, id in
        Member(id: id, measurementTimestamp: .now.addingTimeInterval(-Double(index % 8 + 1) * 60))
    }
    return FriendListSheet(
        sessionStore: store,
        onShareInvite: {},
        onSelectMember: { _ in },
        onLeaveGroup: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Centered empty friends list") {
    let store = SessionStore.preview
    store.members = []
    return FriendListSheet(
        sessionStore: store,
        onShareInvite: {},
        onSelectMember: { _ in },
        onLeaveGroup: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Local and friend SOS") {
    let store = SessionStore.preview
    store.setEmergency(true, for: "ADI")
    
    return FriendListSheet(
        sessionStore: store,
        onShareInvite: {},
        onSelectMember: { _ in },
        onLeaveGroup: {},
        isUserSOSActive: { true }
    )
    .preferredColorScheme(.dark)
}
