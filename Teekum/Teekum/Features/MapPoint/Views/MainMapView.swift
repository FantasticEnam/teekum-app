//
//  MainMapView.swift
//
//
//  Created by Adiat Rahman on 05/11/26.
//

import SwiftUI
import MapKit

public struct MainMapView: View {
    @State private var viewModel = MapPointViewModel()
    @Environment(\.dismiss) private var dismiss
    // Location based on user pos
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        fallback: .camera(
            MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: -6.2186, longitude: 106.8026),
                distance: 1200
            )
        )
    )
    
    // Simpan titik yg di hold (titik kuning)
    @State private var candidateCoordinate: CLLocationCoordinate2D? = nil
    // Simpan posisi finger touch sementara
    @State private var lastTouchPoint: CGPoint? = nil
    
    public var body: some View {
        ZStack(alignment: .bottom){
            // MAP Section
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    // Current user point
                    UserAnnotation()
                    
                    // Active Meeting Point
                    if let active = viewModel.activeMapPoint {
                        Annotation(active.title, coordinate: active.coordinate) {
                            MapPointPinView(title: active.title)
                                .onTapGesture {
                                    viewModel.handlePinTapped()
                                }
                        }
                    }
                    
                    // Candicate Meeting Point
                    if let candidate = viewModel.candidateCoordinate {
                        Annotation("Meeting Point", coordinate: candidate) {
                            MapPointPinView(title: "Meeting Point")
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .mapControls {
                    MapUserLocationButton()
                }
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
                    LongPressGesture(minimumDuration: 0.7)
                        .onEnded { _ in
                            guard let touch = lastTouchPoint,
                                  let coord = proxy.convert(touch, from: .local) else { return }
                            
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            
                            viewModel.handleMapHold(at: coord)
                        }
                )
            }
            
            VStack {
                HStack {
                    Button {
                        dismiss() // Menutup peta dan kembali ke Orbit
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .padding(12)
                            .background(Color.black.opacity(0.75))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                    .padding(.leading, 16)
                    .padding(.top, 60) // Agar tidak nabrak Dynamic Island
                    
                    Spacer()
                }
                Spacer()
            }
                
        }
        .onAppear {
            // Popup izin
            CLLocationManager().requestWhenInUseAuthorization()
        }
        .preferredColorScheme(.dark)
        .alert("Set Meeting Point", isPresented: $viewModel.isShowingSetAlert){
            Button("Not Yet", role: .cancel){
                viewModel.cancelSetMeetingPoint()
            }
            Button("Continue"){
                viewModel.confirmSetMeetingPoint()
            }
        } message : {
            Text("Has Everyone Joined? Friends who haven't joined the group won't be able to see your meeting point.")
        }
        .alert("Stop Meeting Point?", isPresented: $viewModel.isShowingStopAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                viewModel.confirmStopMeetingPoint()
            }
        } message: {
            Text("Are you sure you want to stop the meeting point for everyone?")
        }
        .alert("Cannot Set Meeting Point", isPresented: $viewModel.isShowingLockedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if viewModel.hasActiveMapPoint && !viewModel.isCurrentUserProposer {
                Text("A meeting point is already set by another member. Only the creator can stop it.")
            } else {
                Text("A meeting point is already active. Please stop the current one before setting a new location.")
            }
        }
    }
    
}

#Preview {
    MainMapView()
}
