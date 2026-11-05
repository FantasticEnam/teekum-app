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
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(
                latitude: -6.2186,
                longitude: 106.8026
            ),
            distance: 1500
        )
    )
    
    public var body: some View {
        ZStack(){
            Map(position: $cameraPosition)
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .including([.stadium, .park])))
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }
    
}

#Preview {
    MainMapView()
}
