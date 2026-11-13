//
//  MapLayerView.swift
//  Teekum
//
//  Created by Adiat Rahman on 08/11/26.
//

import SwiftUI
import MapKit

public struct MapLayerView: View {
    @State private var selectedMember: Member?
    @Bindable var viewModel: MeetingPointViewModel
    var location: LocationService? = nil
    
    // State untuk mode Satelit
    @State private var isSatellite: Bool = false
    // Location based on user pos
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: -6.2186, longitude: 106.8026),
            distance: 400
        )
    )
    // Simpan posisi finger touch sementara
    @State private var lastTouchPoint: CGPoint? = nil
    private let holdDuration: Double = 0.7
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing){
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    // Current user point
                    UserAnnotation()
                    
                    // Member Points (Teman)
                    ForEach(viewModel.members) { member in
                        if let coordinate = member.coordinate {
                            Annotation("", coordinate: coordinate) {
                                OrbitMemberMarkerView(
                                    initials: member.initials,
                                    color: member.color.swiftUIColor,
                                    isSelected: selectedMember?.id == member.id,
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
                                .onTapGesture {
                                    selectedMember = member
                                }
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
                .ignoresSafeArea()
                // Posisi sentuhan jari
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            lastTouchPoint = value.location
                        }
                )
                // Detekse jari yg di hold
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
            mapFloatingButtons
                .padding(.trailing, 16)
                .padding(.bottom, 60)
        }
        .fullScreenCover(item: $selectedMember) { member in
            FriendFinderView(member: member, location: location)
        }
        .onChange(of: location?.currentLocation?.coordinate) { _, newCoord in
            if let newCoord {
                withAnimation {
                    cameraPosition = .camera(MapCamera(centerCoordinate: newCoord, distance: 400))
                }
            }
        }
        .onAppear {
            if let userCoord = location?.currentLocation?.coordinate {
                cameraPosition = .camera(MapCamera(centerCoordinate: userCoord, distance: 400))
            }
        }
    }
    
    private func memberDistance(for member: Member) -> String? {
        guard let userLocation = location?.currentLocation,
              let memberCoord = member.coordinate else { return nil }
        return userLocation.distance(to: memberCoord).formattedDistance()
    }
    
    private var mapFloatingButtons: some View {
        VStack(spacing: 12) {
            // Tombol 1: Balik ke Lokasi User
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
                    .frame(width: 48, height: 48)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .accessibilityLabel("Recenter to user location")
            
            // Tombol 2: Toggle Satelit / Standar
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSatellite.toggle()
                }
            } label: {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSatellite ? .yellow : .white) // Kuning saat satelit aktif
                    .frame(width: 48, height: 48)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSatellite ? Color.yellow.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .accessibilityLabel("Toggle Satellite Map")
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


