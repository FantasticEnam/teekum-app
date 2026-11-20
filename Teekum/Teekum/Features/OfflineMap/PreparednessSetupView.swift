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
    
    @State private var isDetectingCity = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header Icon & Title
                VStack(spacing: 12) {
                    Image(systemName: "map.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.buttonPrimary)
                        .padding(.top, 24)
                    
                    Text("Peta Darurat Offline")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    
                    Text("Unduh peta area 15 km di sekitar Anda sekarang selagi ada internet. Peta ini akan otomatis aktif saat jaringan seluler terputus pasca-bencana.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // City Detection & Download Status Card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("KOTA ANDA")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            
                            if isDetectingCity {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Mendeteksi GPS...")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            } else if let city = offlineMaps.detectedCity {
                                Text(city.name)
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                            } else {
                                Text("Lokasi belum terdeteksi")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            detectCurrentCity()
                        } label: {
                            Image(systemName: "location.circle")
                                .font(.title2)
                                .foregroundStyle(Color.buttonPrimary)
                        }
                        .disabled(offlineMaps.downloadState.isBusy || isDetectingCity)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Info Badge: Radius & Estimasi Ukuran
                    HStack {
                        Label("Radius 15 km", systemImage: "circle.circle")
                        Spacer()
                        Label("Peta Vektor Lengkap", systemImage: "arrow.down.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    // Download Progress (Jika Sedang Berjalan)
                    if case .downloading(_, let progress) = offlineMaps.downloadState {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(progress >= 0.90 ? "Menyimpan & mengindeks..." : "Mengunduh peta...")
                                Spacer()
                                Text("\(Int(progress * 100))%")
                            }
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.buttonPrimary)
                            
                            ProgressView(value: progress, total: 1.0)
                                .tint(Color.buttonPrimary)
                        }
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.06), in: .rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    if let city = offlineMaps.detectedCity {
                        Button {
                            if connectivity.isForcedOfflineMode {
                                errorMessage = "Mode Offline sedang dipaksa aktif. Matikan mode offline di Pengaturan untuk mengunduh."
                                showingErrorAlert = true
                                return
                            }
                            guard connectivity.isPathSatisfied || connectivity.isVerifiedOnline else {
                                errorMessage = "Tidak ada koneksi internet. Pastikan Wi-Fi atau data seluler Anda aktif."
                                showingErrorAlert = true
                                return
                            }
                            startCityDownload(city)
                        } label: {
                            HStack {
                                if offlineMaps.downloadState.isBusy {
                                    ProgressView()
                                        .tint(.black)
                                        .padding(.trailing, 4)
                                }
                                Text(offlineMaps.downloadState.isBusy ? "Mengunduh Peta..." : "Unduh Peta \(city.name)")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.buttonPrimary, in: .rect(cornerRadius: 14))
                            .foregroundStyle(.black)
                        }
                        .disabled(offlineMaps.downloadState.isBusy)
                    } else {
                        Button {
                            detectCurrentCity()
                        } label: {
                            Text("Deteksi Lokasi Saya")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.buttonPrimary, in: .rect(cornerRadius: 14))
                                .foregroundStyle(.black)
                        }
                        .disabled(isDetectingCity)
                    }
                    
                    Button {
                        offlineMaps.cancelDownload()
                        offlineMaps.markPreparednessCompleted()
                        onComplete()
                    } label: {
                        Text("Lewati untuk Sekarang")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                    .disabled(offlineMaps.downloadState.isBusy)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .task {
                if offlineMaps.detectedCity == nil {
                    detectCurrentCity()
                }
            }
            .alert("Gagal Mengunduh Peta", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Terjadi kesalahan saat mengunduh.")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func detectCurrentCity() {
        guard !isDetectingCity else { return }
        isDetectingCity = true
        Task {
            do {
                try await offlineMaps.locateAndDetectCity(using: locationService)
            } catch {
                errorMessage = error.localizedDescription
            }
            isDetectingCity = false
        }
    }
    
    private func startCityDownload(_ city: DetectedCity) {
        Task {
            do {
                let isOnline = !connectivity.isForcedOfflineMode && (connectivity.isPathSatisfied || connectivity.isVerifiedOnline)
                try await offlineMaps.downloadCity(city, isOnline: isOnline)
                onComplete()
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
}
