//
//  OrbitMapView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitMapView: View {
    @State private var viewModel: OrbitMapViewModel
    @State private var activeModal: OrbitModal?
    @State private var isLeavingGroup = false

    init(sessionStore: SessionStore) {
        _viewModel = State(initialValue: OrbitMapViewModel(sessionStore: sessionStore))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                OrbitSceneView(bloomRotation: .degrees(5))
                    .ignoresSafeArea()

                VStack(alignment: .leading) {
                    OrbitHeaderView(groupName: viewModel.groupName) {
                        activeModal = .mapPoint
                    }

                    Spacer()
                    OrbitControlsView(
                        onSOS: {
                            print("SOS requested")
                        },
                        onExpand: {
                            activeModal = .friends
                        },
                        bottomInset: geometry.safeAreaInsets.bottom
                    )
                }
                .padding(.horizontal)
            }
        }
        .disabled(isLeavingGroup)
        .fullScreenCover(item: $activeModal, onDismiss: finishModalDismissal) { modal in
            switch modal {
            case .mapPoint:
                MainMapView(sessionStore: viewModel.sessionStore)
            case .friends:
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        Button {
                            activeModal = nil
                        } label: {
                            Color.black.opacity(0.45)
                        }
                        .buttonStyle(.plain)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)

                        FriendListSheet(
                            sessionStore: viewModel.sessionStore,
                            onAddFriend: {
                                print("Open group invite")
                            },
                            onSelectMember: { member in
                                print("Selected \(member.initials)")
                            },
                            onLeaveGroup: requestLeaveGroup
                        )
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height * 0.78
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .presentationBackground(.clear)
            }
        }
    }

    private func requestLeaveGroup() {
        isLeavingGroup = true
        activeModal = nil
    }

    private func finishModalDismissal() {
        guard isLeavingGroup else { return }
        isLeavingGroup = false
        viewModel.leaveGroup()
    }
}

#Preview {
    OrbitMapView(sessionStore: .preview)
}
