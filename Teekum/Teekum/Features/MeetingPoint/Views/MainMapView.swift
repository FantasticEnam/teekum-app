//
//  MainMapView.swift
//
//
//  Created by Adiat Rahman on 05/11/26.
//

import SwiftUI

struct MainMapView: View {
    @State private var viewModel: MeetingPointViewModel
    var location: LocationService? = nil
    @Binding var selectedTarget: OrbitSceneView.Target?
    var connectivity: ConnectivityMonitor? = nil
    var offlineMaps: OfflineMapManager? = nil
    @Environment(\.dismiss) private var dismiss
    
    @State private var isMapReady: Bool = false
    @State private var showLoadingIndicator: Bool = true
    
    init(
        sessionStore: SessionStore,
        meetingService: MeetingPointService? = nil,
        location: LocationService? = nil,
        selectedTarget: Binding<OrbitSceneView.Target?> = .constant(nil),
        connectivity: ConnectivityMonitor? = nil,
        offlineMaps: OfflineMapManager? = nil
    ) {
        _viewModel = State(initialValue: MeetingPointViewModel(sessionStore: sessionStore, meetingService: meetingService))
        self.location = location
        self._selectedTarget = selectedTarget
        self.connectivity = connectivity
        self.offlineMaps = offlineMaps
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom){
                // MAP Section
                MapLayerView(
                    viewModel: viewModel,
                    location: location,
                    selectedTarget: $selectedTarget,
                    connectivity: connectivity,
                    offlineMaps: offlineMaps,
                    onMapReady: {
                        guard !isMapReady else { return }
                        isMapReady = true
                        withAnimation(.easeOut(duration: 0.3)) {
                            showLoadingIndicator = false
                        }
                    }
                )
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .padding()
                        .background(.black.opacity(0.8), in: .rect(cornerRadius: 12))
                        .padding()
                }
            }
            .overlay(alignment: .center) {
                if showLoadingIndicator {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(Color.buttonPrimary)
                        
                        Text("Loading Map...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .navigationTitle("Set Meeting Point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .task {
            // Safety timeout: jika dalam 5 detik tidak ada callback (misal GPS mati total / simulator hening), tutup loading
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !isMapReady {
                withAnimation(.easeOut(duration: 0.3)) {
                    showLoadingIndicator = false
                }
            }
        }
        .onChange(of: connectivity?.activeMapEngine) { _, _ in
            isMapReady = false
            withAnimation(.easeInOut(duration: 0.2)) {
                showLoadingIndicator = true
            }
        }
        .onAppear {
            viewModel.requestLocationPermission()
            location?.setTacticalRadarActive(true)
        }
        .onDisappear {
            location?.setTacticalRadarActive(false)
        }
        .preferredColorScheme(.dark)
        
        // 1. Alert Creator: Set Meeting Point
        .alert("Set Meeting Point", isPresented: $viewModel.isShowingSetAlert) {
            Button("Not Yet", role: .cancel) {
                viewModel.cancelSetMeetingPoint()
            }
            Button("Set Point") {
                viewModel.confirmSetMeetingPoint()
            }
        } message: {
            Text("Has Everyone Joined? Friends who haven't joined the group won't be able to see your meeting point.")
        }
        
        // 2. Alert Creator: Stop Meeting Point
        .alert("Stop Meeting Point?", isPresented: $viewModel.isShowingStopAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                viewModel.stopMeetingPoint()
            }
        } message: {
            Text("Are you sure you want to stop the meeting point for everyone?")
        }
        
        // 3. Alert User Lain: RSVP
        .alert("Meeting Point Set!", isPresented: $viewModel.isShowingRSVPAlert) {
            Button("Not Now", role: .cancel) {
                viewModel.respondRSVP(attending: false)
            }
            Button("Be Right There") {
                viewModel.respondRSVP(attending: true)
            }
        } message: {
            let proposer = viewModel.activeMapPoint?.proposerInitials ?? "Member"
            Text("There's a meeting point selected by \(proposer). Would you like to join?")
        }
        
    }
}

#Preview {
    MainMapView(sessionStore: .preview)
}
