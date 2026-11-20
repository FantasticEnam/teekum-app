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
    var previewIsDetecting: Bool = false
    var previewDetectionFailed: Bool = false
    
    @State private var isDetectingCity = false
    @State private var hasDetectionFailed = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    private var isDetecting: Bool {
        previewIsDetecting || isDetectingCity || offlineMaps.downloadState == .locating
    }
    
    private var isFailed: Bool {
        if previewDetectionFailed { return true }
        if previewCity != nil { return false }
        if case .failed = effectiveDownloadState {
            return resolvedCityName == nil
        }
        return hasDetectionFailed && resolvedCityName == nil
    }
    
    private var resolvedCityName: String? {
        if let previewCity {
            return previewCity
        }
        if let detected = offlineMaps.detectedCity?.name, !detected.isEmpty {
            return detected
        }
        if let cached = offlineMaps.cachedCity?.cityName, !cached.isEmpty {
            return cached
        }
        return nil
    }
    
    private var currentCityName: String {
        resolvedCityName ?? "South Jakarta"
    }
    
    private var effectiveDownloadState: OfflineMapDownloadState {
        previewState ?? offlineMaps.downloadState
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background copied directly from OrbitView / OrbitSceneView
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
                    // TOP CONTENT: Icon, Titles, and Download Area Card
                    VStack(spacing: 0) {
                        // Top Graphic Icon
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
                        
                        // Header Title & Subtitle
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
                        
                        // Download Area Card
                        downloadAreaCard
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    // BOTTOM BUTTONS: Download Now / Detect Location and Skip for Now
                    VStack(spacing: 12) {
                        if isDetecting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.black)
                                Text("Detecting Location...")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.buttonPrimary.opacity(0.7), in: Capsule())
                        } else if isFailed {
                            Button {
                                detectCurrentCity()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Detect Location")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.buttonPrimary, in: Capsule())
                            }
                        } else {
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
                        }
                        
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
                if previewCity == nil && !previewDetectionFailed && offlineMaps.detectedCity == nil {
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
                if isDetecting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("Detecting Location...")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                } else if isFailed {
                    HStack(spacing: 8) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.6))
                        Text("Location Not Found")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.8))
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
                    Image(systemName: isFailed ? "arrow.clockwise.circle" : "location.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.buttonPrimary)
                }
                .disabled(effectiveDownloadState.isBusy || isDetecting)
            }
            
            // Thin Separator Line
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 2)
            
            // Metadata Row 1: Coverage & Type
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
            
            // Thin Separator Line below Coverage & Type
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 2)
            
            // Metadata Row 2: Estimated Size
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 12))
                Text("Estimated size: ~100 MB")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Color.white.opacity(0.65))
            
            // Download Progress Row & Bar (Shown when downloading/indexing)
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
        } else if let cached = offlineMaps.cachedCity {
            let city = DetectedCity(name: cached.cityName, coordinate: cached.centerCoordinate)
            startCityDownload(city)
        } else {
            detectAndDownload()
        }
    }
    
    private func detectCurrentCity() {
        guard !isDetectingCity else { return }
        isDetectingCity = true
        hasDetectionFailed = false
        Task {
            do {
                if let loc = locationService.currentLocation {
                    try await offlineMaps.detectCity(at: loc.coordinate)
                } else {
                    try await offlineMaps.locateAndDetectCity(using: locationService)
                }
                hasDetectionFailed = false
            } catch {
                hasDetectionFailed = true
                errorMessage = error.localizedDescription
            }
            isDetectingCity = false
        }
    }
    
    private func detectAndDownload() {
        guard !isDetectingCity else { return }
        isDetectingCity = true
        hasDetectionFailed = false
        Task {
            do {
                let city: DetectedCity
                if let loc = locationService.currentLocation {
                    city = try await offlineMaps.detectCity(at: loc.coordinate)
                } else {
                    city = try await offlineMaps.locateAndDetectCity(using: locationService)
                }
                hasDetectionFailed = false
                isDetectingCity = false
                startCityDownload(city)
            } catch {
                hasDetectionFailed = true
                isDetectingCity = false
                errorMessage = error.localizedDescription
                showingErrorAlert = true
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

#Preview("1. Location Detected (Ready)") {
    PreparednessSetupView(
        offlineMaps: OfflineMapManager(),
        locationService: LocationService(),
        connectivity: ConnectivityMonitor(),
        onComplete: {},
        previewCity: "South Jakarta"
    )
}

#Preview("2. Detecting Location (Loading)") {
    PreparednessSetupView(
        offlineMaps: OfflineMapManager(),
        locationService: LocationService(),
        connectivity: ConnectivityMonitor(),
        onComplete: {},
        previewIsDetecting: true
    )
}

#Preview("3. Detection Failed (Retry)") {
    PreparednessSetupView(
        offlineMaps: OfflineMapManager(),
        locationService: LocationService(),
        connectivity: ConnectivityMonitor(),
        onComplete: {},
        previewDetectionFailed: true
    )
}

#Preview("4. Downloading (78%)") {
    PreparednessSetupView(
        offlineMaps: OfflineMapManager(),
        locationService: LocationService(),
        connectivity: ConnectivityMonitor(),
        onComplete: {},
        previewState: .downloading(cityName: "South Jakarta", progress: 0.78),
        previewCity: "South Jakarta"
    )
}

#Preview("5. Storage and Indexing (98%)") {
    PreparednessSetupView(
        offlineMaps: OfflineMapManager(),
        locationService: LocationService(),
        connectivity: ConnectivityMonitor(),
        onComplete: {},
        previewState: .downloading(cityName: "South Jakarta", progress: 0.98),
        previewCity: "South Jakarta"
    )
}
