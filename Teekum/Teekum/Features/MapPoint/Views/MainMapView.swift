// xcode: set sdk=iOS

//
//  MainMapView.swift
//
//
//  Created by Adiat Rahman on 05/11/26.
//

import SwiftUI
import MapKit

public struct MainMapView: View {
    //    @State private var viewModel = MapPointViewModel()
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
        ZStack(){
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    // Current user point
                    UserAnnotation()
                    
                    if let coord = candidateCoordinate {
                        Annotation("Meeting Point", coordinate: coord) {
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
                    LongPressGesture(minimumDuration: 0)
                        .onEnded { _ in
                            guard let touch = lastTouchPoint,
                                  let coord = proxy.convert(touch, from: .local) else { return }
                        
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            
                            candidateCoordinate = coord
                        }
                )
            }
        }
        .onAppear {
            // Memicu munculnya dialog pop-up izin lokasi saat layar pertama dibuka
            CLLocationManager().requestWhenInUseAuthorization()
        }
        .preferredColorScheme(.dark)
    }
    
}

#Preview {
    MainMapView()
}
