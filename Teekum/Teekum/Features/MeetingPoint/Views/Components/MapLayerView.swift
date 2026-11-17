//
//  MapLayerView.swift
//  Teekum
//
//  Created by Adiat Rahman on 08/11/26.
//

import SwiftUI
import MapKit

struct MapLayerView: View {
    @Bindable var viewModel: MeetingPointViewModel
    var location: LocationService? = nil
    @Binding var selectedTarget: OrbitSceneView.Target?
    @Namespace private var mapScope
    
    // State untuk mode Satelit
    @State private var isSatellite: Bool = false
    // Location based on user pos
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: -6.2186, longitude: 106.8026),
            distance: 400
        )
    )
    @State private var hasInitialCentered: Bool = false
    // Simpan posisi finger touch sementara
    @State private var lastTouchPoint: CGPoint? = nil
    private let holdDuration: Double = 0.7
    
    // State Follow Alert
    @State private var memberToFollow: Member? = nil
    @State private var isShowingFollowAlert: Bool = false
    @State private var isShowingStopFollowAlert: Bool = false
    
    init(
        viewModel: MeetingPointViewModel,
        location: LocationService? = nil,
        selectedTarget: Binding<OrbitSceneView.Target?> = .constant(nil)
    ) {
        self.viewModel = viewModel
        self.location = location
        self._selectedTarget = selectedTarget
    }
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapReader { proxy in
                Map(position: $cameraPosition, scope: mapScope) {
                    // Current user point
                    UserAnnotation()
                    
                    if let userCoord = location?.currentLocation?.coordinate,
                       let targetCoord = followedCoordinate {
                        MapPolyline(coordinates: [userCoord, targetCoord])
                            .stroke(
                                Color.buttonPrimary,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [6, 4])
                            )
                    }
                    
                    // Member Points (Teman)
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
                                        size: 22
                                    )
                                    .overlay(alignment: .bottom) {
                                        if let distance = memberDistance(for: member) {
                                            Text(distance)
                                                .font(.caption2)
                                                .foregroundStyle(.white)
                                                .fixedSize()
                                                .shadow(color: .black.opacity(0.8), radius: 2)
                                                .offset(y: 18)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                    
                    // Pin Aktif
                    if let active = viewModel.activeMapPoint {
                        Annotation(active.name, coordinate: active.coordinate) {
                            MapPointPinView(title: active.name)
                                .onTapGesture {
                                    viewModel.handlePinTapped()
                                }
                        }
                    }
                    
                    // Pin Kandidat
                    if let candidate = viewModel.candidateCoordinate {
                        Annotation("Meeting Point", coordinate: candidate) {
                            MapPointPinView(title: "Meeting Point")
                        }
                    }
                }
                .mapStyle(isSatellite ? .hybrid(elevation: .flat) : .standard(elevation: .flat))
                .mapControlVisibility(.hidden)
                .safeAreaPadding(.top, 56)
                .ignoresSafeArea()
                // Posisi sentuhan jari
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            lastTouchPoint = value.location
                        }
                )
                // Deteksi jari yg di hold
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
                    .scaleEffect(1.17)
                    .frame(width: 42, height: 42)
                    .offset(y: -4)
                    .padding(.leading, 20)
                
                Spacer()
                
                mapFloatingButtons
                    .padding(.trailing, 16)
            }
            .padding(.bottom, 60)
        }
        .overlay(alignment: .top) {
            MapScaleView(scope: mapScope)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: 26)
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
        .onAppear {
            if let userCoord = location?.currentLocation?.coordinate {
                cameraPosition = .camera(MapCamera(centerCoordinate: userCoord, distance: 400))
                hasInitialCentered = true
            }
        }
        // 1. Alert Mulai Follow
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
        
        // 2. Alert Berhenti Follow
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
            // 1. Tombol Satelit
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
            
            // 2. Tombol Lokasi User
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

#Preview("Active meeting point") {
    @Previewable @State var viewModel = {
        let store = SessionStore.preview
        store.activeMeetingPoint = MeetingPoint(
            name: "Gate 2",
            coordinate: .init(latitude: -6.2186, longitude: 106.8026),
            proposerInitials: "DAF"
        )
        return MeetingPointViewModel(sessionStore: store)
    }()
    
    MapLayerView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}


