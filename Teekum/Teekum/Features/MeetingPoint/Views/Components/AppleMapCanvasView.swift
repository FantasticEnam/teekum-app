//
//  AppleMapCanvasView.swift
//  Teekum
//
//  Created by Adiat Rahman on 19/11/26.
//

import SwiftUI
import MapKit

struct AppleMapCanvasView: View {
    @Bindable var viewModel: MeetingPointViewModel
    var location: LocationService? = nil
    @Binding var selectedTarget: OrbitSceneView.Target?
    
    @Namespace private var mapScope
    @State private var mapHeading: CLLocationDirection = 0
    @State private var isSatellite: Bool = false
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: -6.2186, longitude: 106.8026),
            distance: 400
        )
    )
    @State private var hasInitialCentered: Bool = false
    @State private var lastTouchPoint: CGPoint? = nil
    private let holdDuration: Double = 0.7
    
    @State private var memberToFollow: Member? = nil
    @State private var isShowingFollowAlert: Bool = false
    @State private var isShowingStopFollowAlert: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapReader { proxy in
                Map(position: $cameraPosition, scope: mapScope) {
                    if let userCoord = location?.currentLocation?.coordinate {
                        Annotation("User", coordinate: userCoord) {
                            UserMarkerView(
                                location: location,
                                color: viewModel.localProfileColor,
                                nickname: viewModel.localNickname,
                                mapHeading: mapHeading
                            )
                        }
                        .annotationTitles(.hidden)
                    }
                    
                    if let userCoord = location?.currentLocation?.coordinate,
                       let targetCoord = followedCoordinate {
                        MapPolyline(coordinates: [userCoord, targetCoord])
                            .stroke(
                                Color.buttonPrimary,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [6, 4])
                            )
                    }
                    
                    ForEach(viewModel.members) { member in
                        if let coordinate = member.coordinate {
                            Annotation("", coordinate: coordinate) {
                                let isSelected = selectedTarget == .member(member.id)
                                
                                Button {
                                    selectMember(member)
                                } label: {
                                    OrbitMemberMarkerView(
                                        initials: member.initials,
                                        color: member.color.swiftUIColor,
                                        isSelected: isSelected,
                                        isEmergency: member.isEmergency,
                                        batteryLevel: member.batteryLevel,
                                        heading: member.heading.map { .degrees($0 - mapHeading) }
                                    )
                                    .overlay(alignment: .bottom) {
                                        if let distance = memberDistance(for: member) {
                                            let showsBattery = OrbitBatteryIndicatorView.percentage(for: member.batteryLevel) != nil
                                            Text(distance)
                                                .font(.caption2)
                                                .foregroundStyle(.white)
                                                .fixedSize()
                                                .shadow(color: .black.opacity(0.8), radius: 2)
                                                .offset(y: showsBattery ? 38 : 24)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                    
                    if let active = viewModel.activeMapPoint {
                        Annotation(active.name, coordinate: active.coordinate) {
                            MapPointPinView(title: active.name)
                                .onTapGesture {
                                    viewModel.handlePinTapped()
                                }
                        }
                    }
                    
                    if let candidate = viewModel.candidateCoordinate {
                        Annotation("Meeting Point", coordinate: candidate) {
                            MapPointPinView(title: "Meeting Point")
                        }
                    }
                }
                .mapStyle(isSatellite ? .hybrid(elevation: .flat) : .standard(elevation: .flat))
                .mapControlVisibility(.hidden)
                .onMapCameraChange(frequency: .continuous) { context in
                    mapHeading = context.camera.heading
                }
                .safeAreaPadding(.top, 56)
                .safeAreaPadding(.bottom, 24)
                .safeAreaPadding(.leading, 16)
                .ignoresSafeArea()
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            lastTouchPoint = value.location
                        }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: holdDuration)
                        .onEnded { _ in
                            guard let touch = lastTouchPoint,
                                  let coord = proxy.convert(touch, from: .local) else { return }
                            
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            viewModel.handleMapHold(at: coord)
                        }
                )
            }
            
            HStack(alignment: .bottom) {
                MapCompass(scope: mapScope)
                    .mapControlVisibility(.visible)
                    .scaleEffect(1.2)
                    .frame(width: 42, height: 42)
                    .padding(.leading, 24)
                
                Spacer()
                
                mapFloatingButtons
                    .padding(.trailing, 16)
            }
            .padding(.bottom, 40)
        }
        .overlay(alignment: .topLeading) {
            MapScaleView(scope: mapScope)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 16)
                .padding(.top, 12)
                .allowsHitTesting(false)
        }
        .mapScope(mapScope)
        .onChange(of: location?.currentLocation?.coordinate) { _, newCoord in
            guard !hasInitialCentered, let newCoord else { return }
            hasInitialCentered = true
            withAnimation {
                cameraPosition = .camera(MapCamera(centerCoordinate: newCoord, distance: 400))
            }
        }
        .onChange(of: location?.currentHeading) { _, _ in }
        .onAppear {
            location?.setTacticalRadarActive(true)
            if let userCoord = location?.currentLocation?.coordinate {
                cameraPosition = .camera(MapCamera(centerCoordinate: userCoord, distance: 400))
                hasInitialCentered = true
            }
        }
        .onDisappear {
            location?.setTacticalRadarActive(false)
        }
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
        .alert("Stop Following?", isPresented: $isShowingStopFollowAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                selectedTarget = nil
            }
        } message: {
            if let name = memberToFollow?.initials {
                Text("Are you sure you want to stop following \(name)?")
            } else {
                Text("Are you sure you want to stop following this target?")
            }
        }
    }
    
    private func memberDistance(for member: Member) -> String? {
        guard let userLocation = location?.currentLocation,
              let memberCoord = member.coordinate else { return nil }
        return userLocation.distance(to: memberCoord).formattedDistance()
    }
    
    private var followedCoordinate: CLLocationCoordinate2D? {
        guard let selectedTarget else { return nil }
        switch selectedTarget {
        case .member(let id):
            return viewModel.members.first(where: { $0.id == id })?.coordinate
        case .meetingPoint(let id):
            return viewModel.activeMapPoint?.id == id ? viewModel.activeMapPoint?.coordinate : nil
        }
    }
    
    private func selectMember(_ member: Member) {
        if selectedTarget == .member(member.id) {
            memberToFollow = member
            isShowingStopFollowAlert = true
        } else {
            memberToFollow = member
            isShowingFollowAlert = true
        }
    }
    
    private var mapFloatingButtons: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSatellite.toggle()
                }
            } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSatellite ? Color.buttonPrimary : .white)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .overlay {
                Circle()
                    .stroke(
                        isSatellite ? Color.buttonPrimary : Color.white.opacity(0.25),
                        lineWidth: isSatellite ? 1.5 : 0.8
                    )
            }
            .shadow(
                color: isSatellite ? Color.buttonPrimary.opacity(0.35) : .black.opacity(0.2),
                radius: 4,
                x: 0,
                y: 2
            )
            .accessibilityLabel("Toggle Satellite Map")
            
            Button {
                withAnimation(.easeInOut(duration: 0.4)) {
                    let targetCoord = location?.currentLocation?.coordinate
                    ?? CLLocationCoordinate2D(latitude: -6.2186, longitude: 106.8026)
                    
                    cameraPosition = .camera(
                        MapCamera(
                            centerCoordinate: targetCoord,
                            distance: 400
                        )
                    )
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            .accessibilityLabel("Recenter to user location")
        }
    }
}

// MARK: - Live User Marker View
private struct UserMarkerView: View {
    var location: LocationService?
    let color: Color
    let nickname: String
    let mapHeading: Double
    
    var body: some View {
        let heading = (location?.currentHeading ?? 0) - mapHeading
        OrbitUserMarkerView(
            color: color,
            nickname: nickname,
            heading: .degrees(heading),
            batteryLevel: location?.currentBatteryLevel
        )
    }
}

#Preview("Apple Map Canvas") {
    @Previewable @State var viewModel = {
        let store = SessionStore.preview
        return MeetingPointViewModel(sessionStore: store)
    }()
    @Previewable @State var selectedTarget: OrbitSceneView.Target? = nil
    
    AppleMapCanvasView(
        viewModel: viewModel,
        location: nil,
        selectedTarget: $selectedTarget
    )
    .preferredColorScheme(.dark)
}
