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
    @State private var selectedTarget: OrbitSceneView.Target?
    @State private var isLeavingGroup = false
    @State private var isShowingChat = false
    private let location: LocationService?
    private let chat: ChatViewModel?
    private let sos: SOSViewModel?
    private let meetingService: MeetingPointService?
    private let relayPolicy: RelayPolicyManager?
    private let relayState: RelayPolicyState
    private let diagnostics: @MainActor () -> TransportDiagnostics?
    private let notifications: NotificationService?

    private var meetingPoint: MeetingPoint? { viewModel.sessionStore.activeMeetingPoint }
    private var visibleMembers: [Member] { viewModel.sessionStore.visibleMembers }
    private var isSOSActive: Bool { sos?.outgoingEventId != nil }

    private var orbitScene: some View {
        OrbitSceneView(
            userColor: viewModel.localProfileColor.swiftUIColor,
            members: visibleMembers,
            meetingPoint: meetingPoint,
            location: location?.currentLocation,
            heading: location?.currentHeading ?? 0,
            selectedTarget: selectedTarget,
            isUserSOSActive: isSOSActive,
            onSelectMember: openFinder,
            onSelectMeetingPoint: selectMeetingPoint
        )
        .ignoresSafeArea()
    }

    private var selectedMember: Member? {
        guard case .member(let id) = selectedTarget else { return nil }
        return visibleMembers.first { $0.id == id }
    }

    init(sessionStore: SessionStore, location: LocationService? = nil, chat: ChatViewModel? = nil,
         sos: SOSViewModel? = nil, meetingService: MeetingPointService? = nil,
         relayPolicy: RelayPolicyManager? = nil, relayState: RelayPolicyState = .init(mode: .disabled),
         diagnostics: @escaping @MainActor () -> TransportDiagnostics? = { nil }, notifications: NotificationService? = nil,
         onLeaveGroup: (() -> Void)? = nil) {
        _viewModel = State(initialValue: OrbitMapViewModel(sessionStore: sessionStore, onLeaveGroup: onLeaveGroup))
        self.location = location
        self.chat = chat
        self.sos = sos
        self.meetingService = meetingService
        self.relayPolicy = relayPolicy
        self.relayState = relayState
        self.diagnostics = diagnostics
        self.notifications = notifications
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            orbitScene

            VStack(alignment: .leading) {
                OrbitHeaderView(groupName: viewModel.groupName,
                    onOpenMap: { activeModal = .mapPoint }, onSettings: { activeModal = .settings })

                if location?.currentLocation == nil {
                    Label("Waiting for your location", systemImage: "location.slash")
                        .font(.caption).padding(8)
                        .background(Color.blackCard, in: .capsule)
                    if let meetingPoint, selectedTarget != .meetingPoint(meetingPoint.id) {
                        Button("Meeting point set", systemImage: "mappin.circle.fill") {
                            selectMeetingPoint(meetingPoint.id)
                        }
                        .buttonStyle(.glass)
                    }
                }

                targetSummary

                Spacer()
                OrbitControlsView(
                    onSOS: {
                        sos?.triggerSOS()
                    },
                    onExpand: {
                        activeModal = .friends
                    },
                    onChat: openChat,
                    unreadCount: chat?.unreadCount ?? 0,
                    isSOSActive: isSOSActive
                )
            }
            .padding(.horizontal)
        }
        .overlay {
            if activeModal == nil && !isShowingChat { SOSEdgeGlowView(sos: sos) }
        }
        .overlay(alignment: .top) {
            OrbitFeedbackView(sos: sos, notifications: notifications)
        }
        .simultaneousGesture(TapGesture().onEnded { sos?.recordUserInteraction() })
        .disabled(isLeavingGroup)
        .onChange(of: meetingPoint?.id) { _, id in
            if case .meetingPoint(let targetID) = selectedTarget, targetID != id {
                selectedTarget = nil
            }
        }
        .onChange(of: visibleMembers.map(\.id)) { _, ids in
            if case .member(let id) = selectedTarget, !ids.contains(id) {
                selectedTarget = nil
            }
            if case .finder(let id) = activeModal, !ids.contains(id) {
                activeModal = nil
            }
        }
        .onChange(of: viewModel.sessionStore.pendingDeepLink, initial: true) { _, url in
            guard let url else { return }
            if url.host == "meeting" { activeModal = .mapPoint }
            if url.host == "sos", let alert = sos?.incomingAlert { activeModal = .finder(alert.senderInitials) }
            viewModel.sessionStore.pendingDeepLink = nil
        }
        .sheet(isPresented: $isShowingChat, onDismiss: { chat?.isChatSheetPresented = false }) {
            if let chat {
                ChatSheetView(viewModel: chat, sessionStore: viewModel.sessionStore)
                    .safeAreaInset(edge: .top) { OrbitFeedbackView(sos: sos, notifications: notifications) }
                    .overlay { SOSEdgeGlowView(sos: sos) }
            }
        }
        .allowsHitTesting(activeModal != .invite)
        .fullScreenCover(item: $activeModal, onDismiss: finishModalDismissal) { modal in
            Group { switch modal {
            case .mapPoint:
                MainMapView(sessionStore: viewModel.sessionStore, meetingService: meetingService, location: location)
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
                                activeModal = .invite
                            },
                            onSelectMember: { member in
                                sos?.recordUserInteraction()
                                selectedTarget = .member(member.id)
                                activeModal = nil
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
            case .settings:
                OrbitSettingsView(location: location, sos: sos, relayPolicy: relayPolicy,
                    relayState: relayState, memberContactLog: { viewModel.sessionStore.memberContactLog },
                    diagnostics: diagnostics)
            case .invite:
                NavigationStack {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        if let session = viewModel.sessionStore.activeSession {
                            GroupQRCodeView(session: session)
                                .padding()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark") { activeModal = nil }
                        }
                    }
                }
                .presentationBackground(.black)
            case .finder(let id):
                if let member = visibleMembers.first(where: { $0.id == id }) {
                    FriendFinderView(member: member, location: location)
                }
            } }
            .safeAreaInset(edge: .top) { OrbitFeedbackView(sos: sos, notifications: notifications) }
            .overlay { SOSEdgeGlowView(sos: sos) }
            .simultaneousGesture(TapGesture().onEnded { sos?.recordUserInteraction() })
        }
    }

    @ViewBuilder
    private var targetSummary: some View {
        let member = selectedMember
        let selectedMeetingPoint = meetingPoint.flatMap { point in
            selectedTarget == .meetingPoint(point.id) ? point : nil
        }
        if let title = member?.initials ?? selectedMeetingPoint?.name {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Target: \(title)", systemImage: "scope")
                        .font(.subheadline.bold())
                    if let member {
                        if member.coordinate == nil {
                            Text("Waiting for \(member.initials)’s location").font(.caption)
                        } else if let timestamp = member.measurementTimestamp {
                            Text("Location measured \(timestamp, style: .relative) ago").font(.caption)
                        }
                    }
                }
                Button("Clear target", systemImage: "xmark") { selectedTarget = nil }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.leading, 12)
            .background(Color.blackCard, in: .rect(cornerRadius: 12))
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

    private func openChat() {
        sos?.recordUserInteraction()
        chat?.isChatSheetPresented = true
        isShowingChat = true
    }

    private func openFinder(_ member: Member) {
        sos?.recordUserInteraction()
        activeModal = .finder(member.id)
    }

    private func selectMeetingPoint(_ id: MeetingPoint.ID) {
        sos?.recordUserInteraction()
        let target = OrbitSceneView.Target.meetingPoint(id)
        selectedTarget = selectedTarget == target ? nil : target
    }
}

#Preview {
    OrbitMapView(sessionStore: .preview)
}
