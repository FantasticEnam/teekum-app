//
//  MapLayerView.swift
//  Teekum
//
//  Created by Adiat Rahman on 08/11/26.
//

import SwiftUI
import CoreLocation

struct MapLayerView: View {
    @Bindable var viewModel: MeetingPointViewModel
    var location: LocationService? = nil
    @Binding var selectedTarget: OrbitSceneView.Target?
    var connectivity: ConnectivityMonitor? = nil
    var offlineMaps: OfflineMapManager? = nil
    var onMapReady: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    @State private var isShowingNoOfflineMapAlert: Bool = false
    
    init(
        viewModel: MeetingPointViewModel,
        location: LocationService? = nil,
        selectedTarget: Binding<OrbitSceneView.Target?> = .constant(nil),
        connectivity: ConnectivityMonitor? = nil,
        offlineMaps: OfflineMapManager? = nil,
        onMapReady: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.location = location
        self._selectedTarget = selectedTarget
        self.connectivity = connectivity
        self.offlineMaps = offlineMaps
        self.onMapReady = onMapReady
    }
    
    var body: some View {
        Group {
            if connectivity?.activeMapEngine == .mapboxOffline {
                if offlineMaps?.cachedCity != nil {
                    MapboxMapCanvasView(
                        viewModel: viewModel,
                        location: location,
                        selectedTarget: $selectedTarget,
                        styleURI: offlineMaps?.activeStyleURIString ?? OfflineMapManager.fallbackDarkStyleURI,
                        cachedCity: offlineMaps?.cachedCity,
                        onMapReady: onMapReady
                    )
                } else {
                    noOfflineMapPlaceholder
                }
            } else {
                AppleMapCanvasView(
                    viewModel: viewModel,
                    location: location,
                    selectedTarget: $selectedTarget,
                    onMapReady: onMapReady
                )
            }
        }
        .onAppear {
            checkOfflineMapAvailability()
        }
        .onChange(of: connectivity?.activeMapEngine) { _, _ in
            checkOfflineMapAvailability()
        }
        .alert("Offline Map Unavailable", isPresented: $isShowingNoOfflineMapAlert) {
            Button("Use Orbit Radar") {
                dismiss()
            }
            Button("Dismiss", role: .cancel) { }
        } message: {
            if offlineMaps?.cachedCity != nil {
                Text("You are outside the coverage of your downloaded offline map. Use the Orbit radar view to navigate to friends, or update your map in Group Settings when connected to the internet.")
            } else {
                Text("No offline map has been downloaded yet. Use the Orbit radar view to navigate to friends, or download a map in Group Settings when connected to the internet.")
            }
        }
    }
    
    private func checkOfflineMapAvailability() {
        guard connectivity?.activeMapEngine == .mapboxOffline else { return }
        
        let hasNoCache = offlineMaps?.cachedCity == nil
        let isRelocated = offlineMaps?.isRelocatedFarFromCache(currentCoordinate: location?.currentLocation?.coordinate) ?? false
        
        if hasNoCache || isRelocated {
            isShowingNoOfflineMapAlert = true
        }
    }
    
    private var noOfflineMapPlaceholder: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.09)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 88, height: 88)
                    
                    Image(systemName: "map.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.buttonPrimary)
                }
                
                VStack(spacing: 8) {
                    Text("No Offline Map Available")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    
                    Text("No offline map has been downloaded yet.\nUse the Orbit radar to navigate to friends, or download a map in Group Settings when connected to the internet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text("Use Orbit Radar")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.buttonPrimary, in: Capsule())
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            onMapReady?()
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
