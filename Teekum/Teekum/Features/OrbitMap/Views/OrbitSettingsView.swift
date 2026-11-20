//
//  OrbitSettingsView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct OrbitSettingsView: View {
    let location: LocationService?
    let sos: SOSViewModel?
    let offlineMaps: OfflineMapManager?
    let connectivity: ConnectivityMonitor?
    let memberContactLog: @MainActor () -> [SessionStore.MemberContactLoss]
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var downloadErrorMessage: String?
    @State private var showingDownloadErrorAlert = false
    
    var body: some View {
        let activity = memberContactLog()
        NavigationStack {
            Form {
                if let location {
                    Section("Location") {
                        LabeledContent("GPS", value: location.isGPSAvailable ? "Available" : "Unavailable")
                        LabeledContent("Power", value: location.isSurvivalModeActive ? "Survival mode" : "Normal")
                        if let measured = location.currentLocation {
                            LabeledContent("Accuracy", value: "±\(Int(measured.horizontalAccuracy)) m")
                            Text("Measured \(measured.timestamp, style: .relative) ago").font(.caption)
                        }
                    }
                }
                
                if let connectivity {
                    @Bindable var connectivity = connectivity
                    Section("Offline map") {
                        Toggle("Force offline mode", isOn: $connectivity.isForcedOfflineMode)
                    }
                }
                if let offlineMaps {
                    savedMapSection(offlineMaps)
                }
                
                if let sos {
                    @Bindable var inactivityGuard = sos.inactivityGuard
                    InactivitySettingsView(isEnabled: $inactivityGuard.isEnabled)
                }
                groupActivity(activity)
            }
            .navigationTitle("Group settings")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark", action: dismiss.callAsFunction) } }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Saved Map Section
    private func savedMapSection(_ maps: OfflineMapManager) -> some View {
        Section("Saved map") {
            // 1. Jika Sedang Mengunduh / Update
            if case .downloading(let cityName, let progress) = maps.downloadState {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Downloading \(cityName)...")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.buttonPrimary)
                    }
                    ProgressView(value: progress, total: 1.0)
                        .tint(Color.buttonPrimary)
                }
            }
            // 2. Jika Sudah Ada Peta Tersimpan
            else if let cached = maps.cachedCity {
                LabeledContent("Cached area", value: cached.cityName)
                LabeledContent("Storage used", value: maps.formattedCachedSize)
                LabeledContent("Downloaded", value: cached.downloadedAt.formatted(date: .abbreviated, time: .shortened))
                
                // A. BLOK RELOKASI: Muncul HANYA jika user pindah kota (>25 km)
                if maps.isRelocatedFarFromCache(currentCoordinate: location?.currentLocation?.coordinate) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("New Region Detected", systemImage: "location.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Color.buttonPrimary)
                        
                        Text("You are outside \(cached.cityName). Switch to your current area?")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            guard !maps.downloadState.isBusy else { return }
                            downloadCurrentCity(maps)
                        } label: {
                            HStack {
                                if maps.downloadState.isBusy {
                                    ProgressView()
                                        .tint(.black)
                                        .padding(.trailing, 4)
                                    Text("Preparing...")
                                        .fontWeight(.semibold)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Switch to Current City Map")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.buttonPrimary, in: .rect(cornerRadius: 10))
                            .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                        
                        Text("Your \(cached.cityName) map is safely kept until the new map is 100% downloaded.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else {
                    // B. BLOK STORAGE: Tombol Hapus muncul HANYA jika berada di lokasi sekarang
                    VStack(alignment: .leading, spacing: 4) {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove Map from Storage")
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Text("Frees up \(maps.formattedCachedSize) of device storage.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    .alert("Delete Offline Map?", isPresented: $showingDeleteAlert) {
                        Button("Delete", role: .destructive) {
                            Task {
                                await maps.deleteCachedCity()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("The cached map for \(cached.cityName) will be removed from your device storage.")
                    }
                }
            }
            // 3. Jika Belum Ada Peta Offline Sama Sekali
            else {
                Text("No offline map cached.").foregroundStyle(.secondary)
                
                Button {
                    guard !maps.downloadState.isBusy else { return }
                    downloadCurrentCity(maps)
                } label: {
                    HStack {
                        if maps.downloadState.isBusy {
                            ProgressView()
                                .tint(.black)
                                .padding(.trailing, 4)
                            Text("Preparing download...")
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download map for current city")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.buttonPrimary, in: .rect(cornerRadius: 10))
                    .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .alert("Download Failed", isPresented: $showingDownloadErrorAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(downloadErrorMessage ?? "An unexpected error occurred.")
                }
            }
        }
    }
    
    private func downloadCurrentCity(_ maps: OfflineMapManager) {
        if connectivity?.isForcedOfflineMode == true {
            downloadErrorMessage = "Cannot download while Forced Offline Mode is active. Turn off 'Force offline mode' first."
            showingDownloadErrorAlert = true
            return
        }
        guard let location else {
            downloadErrorMessage = "Location service is unavailable."
            showingDownloadErrorAlert = true
            return
        }
        Task {
            do {
                let city = try await maps.locateAndDetectCity(using: location)
                let isOnline = !(connectivity?.isForcedOfflineMode ?? false)
                try await maps.downloadCity(city, isOnline: isOnline)
            } catch {
                downloadErrorMessage = error.localizedDescription
                showingDownloadErrorAlert = true
            }
        }
    }
    
    // MARK: - Existing Sections
    private func groupActivity(_ losses: [SessionStore.MemberContactLoss]) -> some View {
        Section("Group activity") {
            if losses.isEmpty {
                Text("No activity yet.").foregroundStyle(.secondary)
            }
            ForEach(losses.reversed()) { loss in
                VStack(alignment: .leading, spacing: 4) {
                    Label("Lost contact with \(loss.initials)", systemImage: "wifi.slash")
                    Text(loss.timestamp, format: .dateTime.hour().minute().second())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview("Group settings") {
    let activity = [SessionStore.MemberContactLoss(initials: "NIC", timestamp: .now.addingTimeInterval(-30))]

    if let defaults = UserDefaults(suiteName: "meepo.preview.groupSettings") {
        OrbitSettingsView(
            location: nil,
            sos: nil,
            offlineMaps: nil,
            connectivity: ConnectivityMonitor(defaults: defaults),
            memberContactLog: { activity }
        )
    }
}
