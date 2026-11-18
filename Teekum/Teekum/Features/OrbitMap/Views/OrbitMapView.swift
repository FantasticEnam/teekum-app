//
//  OrbitMapView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitMapView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOrbitVisible = false
    @State private var viewModel: OrbitMapViewModel
    @State private var activeModal: OrbitModal?
    @State private var selectedTarget: OrbitSceneView.Target?
    @State private var isLeavingGroup = false
    @State private var isShowingChat = false
    @State private var opensChatAfterModalDismissal = false
    @State private var memberToFollow: Member? = nil
    @State private var isShowingFollowAlert = false
    @State private var isShowingStopFollowAlert = false
    
    private let location: LocationService?
    private let chat: ChatViewModel?
    private let sos: SOSViewModel?
    private let meetingService: MeetingPointService?
    private let diagnostics: @MainActor () -> TransportDiagnostics?
    private let notifications: NotificationService?
    private let nearby: NearbyRangingService?
    
    private var meetingPoint: MeetingPoint? { viewModel.sessionStore.activeMeetingPoint }
    private var visibleMembers: [Member] { viewModel.sessionStore.visibleMembers }
    private var isSOSActive: Bool { sos?.outgoingEventId != nil }
    
    private var orbitScene: some View {
        OrbitSceneView(
            userColor: viewModel.localProfileColor.swiftUIColor,
            userBatteryLevel: location?.currentBatteryLevel,
            members: visibleMembers,
            nearbyPositions: nearby?.positions ?? [:],
            meetingPoint: meetingPoint,
            location: location?.currentLocation,
            heading: location?.currentHeading ?? 0,
            selectedTarget: selectedTarget,
            isUserSOSActive: isSOSActive,
            onSelectMeetingPoint: selectMeetingPoint,
            onSelectMember: selectMember
        )
    }
    
    private var selectedMember: Member? {
        guard case .member(let id) = selectedTarget else { return nil }
        return visibleMembers.first { $0.id == id }
    }
    
    init(sessionStore: SessionStore, location: LocationService? = nil, chat: ChatViewModel? = nil,
         sos: SOSViewModel? = nil, meetingService: MeetingPointService? = nil,
         diagnostics: @escaping @MainActor () -> TransportDiagnostics? = { nil }, notifications: NotificationService? = nil,
         nearby: NearbyRangingService? = nil,
         onLeaveGroup: (() -> Void)? = nil) {
        _viewModel = State(initialValue: OrbitMapViewModel(sessionStore: sessionStore, onLeaveGroup: onLeaveGroup))
        self.location = location
        self.chat = chat
        self.sos = sos
        self.meetingService = meetingService
        self.diagnostics = diagnostics
        self.notifications = notifications
        self.nearby = nearby
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            orbitScene
            
            VStack(alignment: .leading) {
                OrbitHeaderView(groupName: viewModel.groupName,
                                onOpenMap: { activeModal = .mapPoint }, onSettings: { activeModal = .settings })
                
                if let activity = notifications?.groupActivity {
                    groupActivityPill(activity.message, color: viewModel.sessionStore.profileColor(for: activity.memberID).swiftUIColor)
                }
                
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
            OrbitFeedbackView(sos: sos, notifications: notifications,
                showsChatAlert: !isShowingChat, onOpenChat: openChat)
        }
        .simultaneousGesture(TapGesture().onEnded { sos?.recordUserInteraction() })
        .disabled(isLeavingGroup)
        .onAppear {
            isOrbitVisible = true
            location?.setTacticalRadarActive(scenePhase == .active)
            nearby?.setForeground(scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, phase in
            location?.setTacticalRadarActive(isOrbitVisible && phase == .active)
            // iOS can temporarily make the scene inactive while asking for Nearby Interaction access.
            if phase != .inactive { nearby?.setForeground(isOrbitVisible && phase == .active) }
        }
        .onChange(of: location?.isTracking) { _, tracking in
            if tracking == true {
                location?.setTacticalRadarActive(isOrbitVisible && scenePhase == .active)
            }
        }
        .onDisappear {
            isOrbitVisible = false
            location?.setTacticalRadarActive(false)
            nearby?.setForeground(false)
        }
        .onChange(of: meetingPoint?.id) { _, id in
            if case .meetingPoint(let targetID) = selectedTarget, targetID != id {
                selectedTarget = nil
            }
        }
        .onChange(of: visibleMembers.map(\.id)) { _, ids in
            if case .member(let id) = selectedTarget, !ids.contains(id) {
                selectedTarget = nil
            }
        }
        .onChange(of: viewModel.sessionStore.pendingDeepLink, initial: true) { _, url in
            guard let url else { return }
            if url.host == "meeting" { activeModal = .mapPoint }
            if url.host == "sos", let alert = sos?.incomingAlert { selectedTarget = .member(alert.senderInitials) }
            viewModel.sessionStore.pendingDeepLink = nil
        }
        .sheet(isPresented: $isShowingChat, onDismiss: { chat?.isChatSheetPresented = false }) {
            if let chat {
                ChatSheetView(viewModel: chat, sessionStore: viewModel.sessionStore)
                    .safeAreaInset(edge: .top) {
                        OrbitFeedbackView(sos: sos, notifications: notifications, showsChatAlert: false)
                    }
                    .overlay { SOSEdgeGlowView(sos: sos) }
            }
        }
        .allowsHitTesting(activeModal != .invite)
        
        // 1. Alert Konfirmasi Mulai Follow
        .alert(
            "Follow \(memberToFollow?.initials ?? "Friend")?",
            isPresented: $isShowingFollowAlert
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Follow") {
                if let member = memberToFollow {
                    selectedTarget = .member(member.id)
                }
            }
        } message: {
            Text("You will be guided towards \(memberToFollow?.initials ?? "this friend").")
        }
        
        // 2. Alert Konfirmasi Berhenti Follow
        .alert("Stop Following?", isPresented: $isShowingStopFollowAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                selectedTarget = nil
            }
        } message: {
            if let name = selectedMember?.initials {
                Text("Are you sure you want to stop following \(name)?")
            } else {
                Text("Are you sure you want to stop following this target?")
            }
        }
        
        .fullScreenCover(item: $activeModal, onDismiss: finishModalDismissal) { modal in
            Group { switch modal {
            case .mapPoint:
                MainMapView(
                    sessionStore: viewModel.sessionStore,
                    meetingService: meetingService,
                    location: location,
                    selectedTarget: $selectedTarget
                )
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
                            onLeaveGroup: requestLeaveGroup,
                            selectedMemberId: selectedMember?.id,
                            onStopFollow: {       
                                sos?.recordUserInteraction()
                                selectedTarget = nil
                                activeModal = nil
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
            case .settings:
                OrbitSettingsView(location: location, sos: sos,
                                  memberContactLog: { viewModel.sessionStore.memberContactLog },
                                  diagnostics: diagnostics, nearby: nearby)
            case .invite:
                if let session = viewModel.sessionStore.activeSession {
                    ShareInviteView(session: session) {
                        activeModal = .friends
                    }
                    .presentationBackground(.black)
                }
            } }
            .safeAreaInset(edge: .top) {
                OrbitFeedbackView(sos: sos, notifications: notifications, onOpenChat: openChat)
            }
            .overlay { SOSEdgeGlowView(sos: sos) }
            .simultaneousGesture(TapGesture().onEnded { sos?.recordUserInteraction() })
        }
    }
    
    private func groupActivityPill(_ message: String, color: Color) -> some View {
        Label {
            Text(message).font(.subheadline.weight(.semibold))
        } icon: {
            Circle().fill(color).frame(width: 14, height: 14)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(white: 0.19), in: .capsule)
        .shadow(color: .white.opacity(0.26), radius: 5, y: 5)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
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
                Button("Clear target", systemImage: "xmark") {
                    isShowingStopFollowAlert = true
                }
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
        if isLeavingGroup {
            isLeavingGroup = false
            opensChatAfterModalDismissal = false
            viewModel.leaveGroup()
        } else if opensChatAfterModalDismissal {
            opensChatAfterModalDismissal = false
            openChat()
        }
    }
    
    private func openChat() {
        sos?.recordUserInteraction()
        notifications?.dismissChatAlert()
        if activeModal != nil {
            opensChatAfterModalDismissal = true
            activeModal = nil
            return
        }
        chat?.isChatSheetPresented = true
        isShowingChat = true
    }
    
    private func selectMember(_ id: Member.ID) {
        sos?.recordUserInteraction()
        if selectedTarget == .member(id) {
            isShowingStopFollowAlert = true
        } else if let member = visibleMembers.first(where: { $0.id == id }) {
            memberToFollow = member
            isShowingFollowAlert = true
        }
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
