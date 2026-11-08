//
//  OrbitMapView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitMapView: View {
    @State private var viewModel: OrbitMapViewModel
    @State private var isPanelPresented = false

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
                    OrbitHeaderView(groupName: viewModel.groupName)

                    Spacer()
                    OrbitControlsView(
                        onSOS: {
                            print("SOS requested")
                        },
                        onExpand: {
                            isPanelPresented = true
                        },
                        bottomInset: geometry.safeAreaInsets.bottom
                    )
                }
                .padding(.horizontal)
            }
        }
        .fullScreenCover(isPresented: $isPanelPresented) {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Button {
                        isPanelPresented = false
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
                        onLeaveGroup: {
                            print("Request session teardown")
                        }
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

#Preview {
    OrbitMapView(sessionStore: .preview)
}
