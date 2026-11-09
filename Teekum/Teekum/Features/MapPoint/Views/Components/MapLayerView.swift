//
//  MapLayerView.swift
//  Teekum
//
//  Created by Adiat Rahman on 08/11/26.
//

import SwiftUI
import MapKit

public struct MapLayerView: View {
    @Bindable var viewModel: MapPointViewModel
    // Location based on user pos
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        fallback: .camera(
            MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: -6.2186, longitude: 106.8026),
                distance: 1200
            )
        )
    )
    // Simpan posisi finger touch sementara
    @State private var lastTouchPoint: CGPoint? = nil
    private let holdDuration: Double = 0.7
    
    public var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                // Current user point
                UserAnnotation()
                
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
                LongPressGesture(minimumDuration: holdDuration)
                    .onEnded { _ in
                        guard let touch = lastTouchPoint,
                              let coord = proxy.convert(touch, from: .local) else { return }
                        
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.handleMapHold(at: coord)
                    }
            )
        }
    }
}
