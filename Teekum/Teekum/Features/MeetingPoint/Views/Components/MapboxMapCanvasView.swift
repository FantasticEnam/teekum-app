//
//  MapboxMapCanvasView.swift
//  Teekum
//
//  Created by Adiat Rahman on 19/11/26.
//

import SwiftUI
import CoreLocation
import MapboxMaps

struct MapboxMapCanvasView: View {
    @Bindable var viewModel: MeetingPointViewModel
    var location: LocationService? = nil
    @Binding var selectedTarget: OrbitSceneView.Target?
    var styleURI: String = OfflineMapManager.fallbackDarkStyleURI
    
    @State private var viewport: Viewport = .camera(
        center: CLLocationCoordinate2D(latitude: -6.2186, longitude: 106.8026),
        zoom: 15
    )
    @State private var hasInitialCentered: Bool = false
    
    // Follow Alerts
    @State private var memberToFollow: Member? = nil
    @State private var isShowingFollowAlert: Bool = false
    @State private var isShowingStopFollowAlert: Bool = false
    
    // Helper struct agar ForEvery tidak butuh branching if let di dalam closure
    private struct MemberPinItem: Identifiable {
        var id: String { member.id }
        let member: Member
        let coordinate: CLLocationCoordinate2D
    }
    
    private var activeMemberPins: [MemberPinItem] {
        viewModel.members.compactMap { member in
            guard let coordinate = member.coordinate else { return nil }
            return MemberPinItem(member: member, coordinate: coordinate)
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(viewport: $viewport) {
                // 1. User Location Puck dengan arah kompas
                Puck2D(bearing: .heading)
                    .showsAccuracyRing(true)
                
                // 2. Garis Navigasi ke Member/Target yang diikuti
                if let userCoord = location?.currentLocation?.coordinate,
                   let targetCoord = followedCoordinate {
                    PolylineAnnotationGroup {
                        PolylineAnnotation(lineCoordinates: [userCoord, targetCoord])
                            .lineColor("#A9CFF5")
                            .lineWidth(2.5)
                    }
                }
                
                // 3. Pin Member Grup (Teman)
                ForEvery(activeMemberPins) { item in
                    MapViewAnnotation(coordinate: item.coordinate) {
                        memberPinView(for: item.member)
                    }
                    .allowOverlap(true)
                }
                
                // 4. Pin Meeting Point Aktif
                if let active = viewModel.activeMapPoint {
                    MapViewAnnotation(coordinate: active.coordinate) {
                        MapPointPinView(title: active.name)
                            .onTapGesture {
                                viewModel.handlePinTapped()
                            }
                    }
                    .allowOverlap(true)
                }
                
                // 5. Pin Meeting Point Kandidat
                if let candidate = viewModel.candidateCoordinate {
                    MapViewAnnotation(coordinate: candidate) {
                        MapPointPinView(title: "Meeting Point")
                    }
                    .allowOverlap(true)
                }
            }
            .mapStyle(MapStyle(uri: StyleURI(rawValue: styleURI) ?? .dark))
            .onMapLongPressGesture { context in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.handleMapHold(at: context.coordinate)
            }
            .ornamentOptions(
                            OrnamentOptions(
                                compass: CompassViewOptions(
                                    position: .bottomLeading,
                                    margins: CGPoint(x: 20, y: 70),
                                    visibility: .visible
                                )
                            )
                        )
            
            .safeAreaPadding(.top, 56)
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Label("Offline Map", systemImage: "mappin.and.ellipse")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.buttonPrimary, in: .capsule)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                }
                Spacer()
            }
            .allowsHitTesting(false)
            
            // Floating Controls: Offline Badge & Recenter Button
            floatingControls
        }
        .onChange(of: location?.currentLocation?.coordinate) { _, newCoord in
            guard !hasInitialCentered, let newCoord else { return }
            hasInitialCentered = true
            viewport = .camera(center: newCoord, zoom: 15)
        }
        .onAppear {
            if let userCoord = location?.currentLocation?.coordinate {
                viewport = .camera(center: userCoord, zoom: 15)
                hasInitialCentered = true
            }
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
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func memberPinView(for member: Member) -> some View {
        Button {
            selectMember(member)
        } label: {
            OrbitMemberMarkerView(
                initials: member.initials,
                color: member.color.swiftUIColor,
                isSelected: selectedTarget == .member(member.id),
                isEmergency: member.isEmergency,
                size: 22,
                batteryLevel: member.batteryLevel,
                heading: member.heading.map { .degrees($0) }
            )
            .overlay(alignment: .bottom) {
                if let distance = memberDistance(for: member) {
                    let showsBattery = OrbitBatteryIndicatorView.percentage(for: member.batteryLevel) != nil
                    Text(distance)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .fixedSize()
                        .shadow(color: .black.opacity(0.8), radius: 2)
                        .offset(y: showsBattery ? 34 : 18)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var floatingControls: some View {
        HStack(alignment: .bottom) {
            Spacer()
            
            // Tombol Pusatkan Ulang ke Posisi User
            Button {
                withAnimation(.easeInOut(duration: 0.4)) {
                    if let userCoord = location?.currentLocation?.coordinate {
                        viewport = .camera(center: userCoord, zoom: 15)
                    }
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
            .padding(.trailing, 16)
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Helpers
    
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
}

#Preview("Mapbox Map Canvas") {
    @Previewable @State var viewModel = {
        let store = SessionStore.preview
        return MeetingPointViewModel(sessionStore: store)
    }()
    @Previewable @State var selectedTarget: OrbitSceneView.Target? = nil
    
    MapboxMapCanvasView(
        viewModel: viewModel,
        location: nil,
        selectedTarget: $selectedTarget
    )
    .preferredColorScheme(.dark)
}
