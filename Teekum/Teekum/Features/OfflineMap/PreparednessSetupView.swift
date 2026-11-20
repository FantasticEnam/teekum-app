//
//  PreparednessSetupView.swift
//  Teekum
//
//  Created by Adiat Rahman on 19/11/26.
//

import SwiftUI
import CoreLocation

struct PreparednessSetupView: View {
    @Bindable var offlineMaps: OfflineMapManager
    let locationService: LocationService
    let connectivity: ConnectivityMonitor
    let onComplete: () -> Void
    var previewState: OfflineMapDownloadState? = nil
    var previewCity: String? = nil
    
    @State private var isDetectingCity = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    private var currentCityName: String {
        if let previewCity {
            return previewCity
        }
        if let detected = offlineMaps.detectedCity?.name, !detected.isEmpty {
            return detected
        }
        if let cached = offlineMaps.cachedCity?.cityName, !cached.isEmpty {
            return cached
        }
        return "South Jakarta"
    }
    
    private var effectiveDownloadState: OfflineMapDownloadState {
        previewState ?? offlineMaps.downloadState
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                GeometryReader { geometry in
                    let baseSize = min(geometry.size.width, geometry.size.height)
                    let backgroundRadius = (baseSize * 1.55 / 2) * 1.12
                    
                    ZStack {
                        Color.black
                        
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: 0x131313), location: 0),
                                .init(color: Color(hex: 0x161616), location: 0.85),
                                .init(color: .black, location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: backgroundRadius
                        )
                    }
                    .ignoresSafeArea()
                }
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(Color.buttonPrimary)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "map.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(.black)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 20)
                        
                        VStack(spacing: 8) {
                            Text("Prepare Your Offline Map")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Text("Save your surrounding area now.\nAccess your map even when you're offline.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        
                        downloadAreaCard
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Button {
                            handleDownloadTap()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.to.line")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Download Now")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.buttonPrimary, in: Capsule())
                        }
                        .disabled(effectiveDownloadState.isBusy)
                        .opacity(effectiveDownloadState.isBusy ? 0.6 : 1.0)
                        
                        Button {
                            offlineMaps.cancelDownload()
                            offlineMaps.markPreparednessCompleted()
                            onComplete()
                        } label: {
                            Text("Skip for Now")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .padding(.vertical, 8)
                        }
                        .disabled(effectiveDownloadState.isBusy)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .task {
                if previewCity == nil && offlineMaps.detectedCity == nil {
                    detectCurrentCity()
                }
            }
            .alert("Download Failed", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred while downloading the map.")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var downloadAreaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            Text("DOWNLOAD AREA")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))
                .kerning(0.6)
            
            // City Row
            HStack(alignment: .center) {
                if isDetectingCity && offlineMaps.detectedCity == nil {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text(currentCityName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                } else {
                    Text(currentCityName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Button {
                    detectCurrentCity()
                } label: {
                    Image(systemName: "location.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.buttonPrimary)
                }
                .disabled(effectiveDownloadState.isBusy || isDetectingCity)
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 2)
            
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "circle.circle")
                        .font(.system(size: 12))
                    Text("20 km coverage")
                        .font(.system(size: 12))
                }
                
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 11)
                
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12))
                    Text("Offline Vector Map")
                        .font(.system(size: 12))
                }
            }
            .foregroundStyle(Color.white.opacity(0.65))
            
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 2)
            
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 12))
                Text("Estimated size: 30 - 116 MB")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Color.white.opacity(0.65))
            
            // Download Progress Row & Bar 
            if case .downloading(_, let progress) = effectiveDownloadState {
                VStack(spacing: 8) {
                    HStack {
                        Text(progress >= 0.90 ? "Storage and Indexing" : "Downloading...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(Color.buttonPrimary)
                                .frame(
                                    width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)),
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .padding(20)
        .background(Color(hex: 0x1C1C1E), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: effectiveDownloadState.isBusy)
    }
    
    private func handleDownloadTap() {
        if connectivity.isForcedOfflineMode {
            errorMessage = "Offline Mode is currently active in Settings. Please turn off Offline Mode to download."
            showingErrorAlert = true
            return
        }
        guard connectivity.isPathSatisfied || connectivity.isVerifiedOnline else {
            errorMessage = "No internet connection. Please make sure Wi-Fi or cellular data is turned on."
            showingErrorAlert = true
            return
        }
        
        if let city = offlineMaps.detectedCity {
            startCityDownload(city)
        } else {
            detectAndDownload()
        }
    }
    
    private func detectCurrentCity() {
        guard !isDetectingCity else { return }
        isDetectingCity = true
        Task {
            do {
                if let loc = locationService.currentLocation {
                    try await offlineMaps.detectCity(at: loc.coordinate)
                } else {
                    try await offlineMaps.locateAndDetectCity(using: locationService)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isDetectingCity = false
        }
    }
    
    private func detectAndDownload() {
        guard !isDetectingCity else { return }
        isDetectingCity = true
        Task {
            do {
                let city: DetectedCity
                if let loc = locationService.currentLocation {
                    city = try await offlineMaps.detectCity(at: loc.coordinate)
                } else {
                    city = try await offlineMaps.locateAndDetectCity(using: locationService)
                }
                isDetectingCity = false
                startCityDownload(city)
            } catch {
                isDetectingCity = false
                let coord = locationService.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: -6.2615, longitude: 106.8106)
                let fallbackCity = DetectedCity(name: currentCityName, coordinate: coord)
                startCityDownload(fallbackCity)
            }
        }
    }
    
    private func startCityDownload(_ city: DetectedCity) {
        Task {
            do {
                let isOnline = !connectivity.isForcedOfflineMode && (connectivity.isPathSatisfied || connectivity.isVerifiedOnline)
                try await offlineMaps.downloadCity(city, isOnline: isOnline)
                onComplete()
            } catch {
                if let err = error as? OfflineMapError, err == .cancelled {
                    return
                }
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
}

#Preview("Default / Idle") {
    PreparednessSetupView(
        offlineMaps: OfflineMapManager(),
        locationService: LocationService(),
        connectivity: ConnectivityMonitor(),
        onComplete: {}
    )
}

#Preview("Download Map Copy (78% Downloading)") {
    PreparednessSetupView(
        offlineMaps: OfflineMapManager(),
        locationService: LocationService(),
        connectivity: ConnectivityMonitor(),
        onComplete: {},
        previewState: .downloading(cityName: "South Jakarta", progress: 0.78),
        previewCity: "South Jakarta"
    )
}

#Preview("Download Map Copy 2 (98% Indexing)") {
    PreparednessSetupView(
        offlineMaps: OfflineMapManager(),
        locationService: LocationService(),
        connectivity: ConnectivityMonitor(),
        onComplete: {},
        previewState: .downloading(cityName: "South Jakarta", progress: 0.98),
        previewCity: "South Jakarta"
    )
}
