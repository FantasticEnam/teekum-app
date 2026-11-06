//
//  FriendListSheet.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 06/11/26.
//

import SwiftUI

struct FriendListSheet: View {
    let onAddFriend: () -> Void
    let onSelectMember: (Member) -> Void
    let onLeaveGroup: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: FriendListViewModel
    @State private var confirmLeave = false
    
    @ScaledMetric(relativeTo: .title2)
    private var cellWidth = 66
    
    // temporary palette, share the color contract with orbit markers during integration.
    private static let colors: [Color] = [
        .peachProfile,
        .orangeProfile,
        .redProfile,
        .greyProfile,
        .whiteProfile,
        .blueProfile,
        .creamProfile
    ]
    
    init(
        sessionStore: SessionStore,
        onAddFriend: @escaping () -> Void,
        onSelectMember: @escaping (Member) -> Void,
        onLeaveGroup: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: FriendListViewModel(sessionStore: sessionStore))
        self.onAddFriend = onAddFriend
        self.onSelectMember = onSelectMember
        self.onLeaveGroup = onLeaveGroup
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        let members = viewModel.filteredMembers
        
        VStack(spacing: 0) {
            Button(
                "Close friends",
                systemImage: "chevron.down"
            ) {
                dismiss()
            }
            .labelStyle(.iconOnly)
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 144, height: 44)
            .contentShape(.rect)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height > 50,
                           value.translation.height > abs(value.translation.width) {
                            dismiss()
                        }
                    }
            )
            
            HStack(spacing: 12) {
                HStack {
                    TextField("Search initials…", text: $viewModel.searchQuery)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 54)
                .background(
                    .white.opacity(0.1),
                    in: .capsule
                )
                
                Button(
                    "Add friend",
                    systemImage: "person.badge.plus",
                    action: onAddFriend
                )
                .labelStyle(.iconOnly)
                .font(.title3)
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 28)
            
            ScrollView {
                if members.isEmpty {
                    ContentUnavailableView(
                        "No friends found",
                        systemImage: "person.2",
                        description: Text(
                            "Try another initial or add a friend."
                        )
                    )
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(
                                .adaptive(minimum: cellWidth),
                                spacing: 16
                            )
                        ],
                        spacing: 24
                    ) {
                        ForEach(members) { member in
                            Button {
                                onSelectMember(member)
                            } label: {
                                FriendListMemberView(
                                    member: member,
                                    color: Self.colors[
                                        Int(member.id.memberSlot)
                                        % Self.colors.count
                                    ]
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            
            PrimaryButtonView(title: "Leave Group") {
                confirmLeave = true
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            OrbitPanelShape()
                .fill(Color.blackCard)
                .ignoresSafeArea(edges: .bottom)
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
    }
}

#Preview {
    FriendListSheet(
        sessionStore: .preview,
        onAddFriend: {},
        onSelectMember: { _ in },
        onLeaveGroup: {}
    )
    .preferredColorScheme(.dark)
}
