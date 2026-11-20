//
//  MainMapView.swift
//
//
//  Created by Adiat Rahman on 05/11/26.
//

import SwiftUI
import MapKit

struct MainMapView: View {
    @State private var viewModel: MeetingPointViewModel
    var location: LocationService? = nil
    private let nearbyDistance: (Member.ID) -> Double?
    @Binding var selectedTarget: OrbitSceneView.Target?
    @Environment(\.dismiss) private var dismiss
    
    init(
        sessionStore: SessionStore,
        meetingService: MeetingPointService? = nil,
        location: LocationService? = nil,
        nearbyDistance: @escaping (Member.ID) -> Double? = { _ in nil },
        selectedTarget: Binding<OrbitSceneView.Target?> = .constant(nil)
    ) {
        _viewModel = State(initialValue: MeetingPointViewModel(sessionStore: sessionStore, meetingService: meetingService))
        self.location = location
        self.nearbyDistance = nearbyDistance
        self._selectedTarget = selectedTarget
    }
    
    var body: some View {
        ZStack(alignment: .bottom){
            // MAP Section
            MapLayerView(viewModel: viewModel, location: location,
                nearbyDistance: nearbyDistance, selectedTarget: $selectedTarget)
            
            VStack {
                HStack {
                    Button {
                        dismiss() // Menutup peta dan kembali ke Orbit
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel("Back to Orbit")
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                Spacer()
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .padding()
                        .background(.black.opacity(0.8), in: .rect(cornerRadius: 12))
                        .padding()
                }
            }
            
        }
        .onAppear {
            viewModel.requestLocationPermission()
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

#Preview("Map with a nearby peer distance") {
    MainMapView(sessionStore: .preview, nearbyDistance: { $0 == "ADI" ? 0.6 : nil })
}
