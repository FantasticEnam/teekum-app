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
    
    @State private var isShowingNoOfflineMapAlert: Bool = false
    
    init(
        viewModel: MeetingPointViewModel,
        location: LocationService? = nil,
        selectedTarget: Binding<OrbitSceneView.Target?> = .constant(nil),
        connectivity: ConnectivityMonitor? = nil,
        offlineMaps: OfflineMapManager? = nil
    ) {
        self.viewModel = viewModel
        self.location = location
        self._selectedTarget = selectedTarget
        self.connectivity = connectivity
        self.offlineMaps = offlineMaps
    }
    
    var body: some View {
        Group {
            if connectivity?.activeMapEngine == .mapboxOffline {
                MapboxMapCanvasView(
                    viewModel: viewModel,
                    location: location,
                    selectedTarget: $selectedTarget,
                    styleURI: offlineMaps?.activeStyleURIString ?? OfflineMapManager.fallbackDarkStyleURI
                )
            } else {
                AppleMapCanvasView(
                    viewModel: viewModel,
                    location: location,
                    selectedTarget: $selectedTarget
                )
            }
        }
        .onAppear {
            checkOfflineMapAvailability()
        }
        .onChange(of: connectivity?.activeMapEngine) { _, _ in
            checkOfflineMapAvailability()
        }
        .alert("Peta Offline Belum Tersedia", isPresented: $isShowingNoOfflineMapAlert) {
            Button("Mengerti", role: .cancel) { }
        } message: {
            Text("Peta untuk wilayah ini belum diunduh. Hubungkan perangkat ke internet dan buka Pengaturan Grup untuk mengunduh peta wilayah saat ini.")
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
