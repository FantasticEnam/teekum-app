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
    
    public var body: some View {
        ZStack(alignment: .bottom){
            // MAP Section
            MapLayerView(viewModel: viewModel)
            
            // HAPUS VSTACK KALO UDAH ADA NAVIGATION
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
                // SIMULASI POV USER LAIN
                Button {
                    if viewModel.isLockedByOther {
                        viewModel.stopMeetingPoint()
                    } else {
                        viewModel.simulateOtherUserMeetingPoint()
                    }
                } label: {
                    Text(viewModel.isLockedByOther ? "Reset Mock" : "Mock POV Lain: NIC")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.yellow)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
            }
            
        }
        .onAppear {
            // Popup izin
            CLLocationManager().requestWhenInUseAuthorization()
        }
        .preferredColorScheme(.dark)
        
        // 1. Alert Creator: Set Meeting Point
        .alert("Set Meeting Point", isPresented: $viewModel.isShowingSetAlert) {
            Button("Not Yet", role: .cancel) {
                viewModel.cancelSetMeetingPoint()
            }
            Button("Continue") {
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
            Text("There's a meeting point at \(proposer)'s last known location.")
        }
        
        // 4. Alert Dicegat: Locked (Sudah dibersihkan, hanya 1 alert)
        .alert("Cannot Set Meeting Point", isPresented: $viewModel.isShowingLockedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let proposer = viewModel.activeMapPoint?.proposerInitials, viewModel.isLockedByOther {
                Text("There's already an active meeting point set by \(proposer). You cannot set a new one until it is stopped.")
            } else {
                Text("A meeting point is already active. Please stop the current one before setting a new location.")
            }
        }
        
    }
    
}

#Preview {
    MainMapView()
}
