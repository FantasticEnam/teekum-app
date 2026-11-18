//
//  OrbitSettingsView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct OrbitSettingsView: View {
    private enum PacketFilter {
        case all, chatAndSOS, outsideGroup, relayed
    }
    
    let location: LocationService?
    let sos: SOSViewModel?
    let offlineMaps: OfflineMapManager?
    let connectivity: ConnectivityMonitor?
    let memberContactLog: @MainActor () -> [SessionStore.MemberContactLoss]
    let diagnostics: @MainActor () -> TransportDiagnostics?
    
    @Environment(\.dismiss) private var dismiss
    @State private var packetFilter: PacketFilter = .all
    @State private var showingDeleteAlert = false
    @State private var downloadErrorMessage: String?
    @State private var showingDownloadErrorAlert = false
    
    var body: some View {
        let snapshot = diagnostics()
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
                
                // Section Baru: Offline Map Management
                if let offlineMaps {
                    offlineMapSection(offlineMaps)
                }
                
                if let sos {
                    @Bindable var inactivityGuard = sos.inactivityGuard
                    InactivitySettingsView(isEnabled: $inactivityGuard.isEnabled)
                }
                groupActivity(activity)
                Section("Connection diagnostics") {
                    LabeledContent("Direct peers", value: "\(snapshot?.activeDirectPeers.filter(\.isDirectLink).count ?? 0)")
                    LabeledContent("Packets sent", value: "\(snapshot?.packetsSent ?? 0)")
                    LabeledContent("Packets received", value: "\(snapshot?.packetsReceived ?? 0)")
                    Text("Signal strength is unavailable for these links.").font(.caption)
                    if let error = snapshot?.lastError { Text(error).foregroundStyle(.red) }
                }
                packetLog(snapshot?.recentPackets ?? [])
            }
            .navigationTitle("Group settings")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark", action: dismiss.callAsFunction) } }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Offline Map Section
    private func offlineMapSection(_ maps: OfflineMapManager) -> some View {
        Section("Offline map") {
            HStack {
                Label("Engine", systemImage: "map")
                Spacer()
                Text(engineStatusText)
                    .foregroundStyle(engineStatusColor)
            }
            
            Toggle("Force offline mode", isOn: forcedOfflineBinding)
            Text("Always use offline vector map even when network connection is available.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let cached = maps.cachedCity {
                LabeledContent("Cached area", value: cached.cityName)
                LabeledContent("Storage used", value: maps.formattedCachedSize)
                LabeledContent("Downloaded", value: cached.downloadedAt.formatted(date: .abbreviated, time: .shortened))
                
                Button(role: .destructive) {
                                    print("[Settings] 🗑️ Tombol delete cached map ditekan!")
                                    showingDeleteAlert = true
                                } label: {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Delete cached map")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .alert("Delete Offline Map?", isPresented: $showingDeleteAlert) {
                                    Button("Delete", role: .destructive) {
                                        Task {
                                            print("[Settings] 🗑️ Menghapus peta...")
                                            await maps.deleteCachedCity()
                                            print("[Settings] ✅ Peta berhasil dihapus!")
                                        }
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("The cached map for \(cached.cityName) will be removed from your device storage.")
                                }            } else if case .downloading(let cityName, let progress) = maps.downloadState {                VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Downloading \(cityName)...")
                    Spacer()
                    Text("\(Int(progress * 100))%")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.buttonPrimary)
                
                ProgressView(value: progress, total: 1.0)
                    .tint(Color.buttonPrimary)
            }
            } else {
                Text("No offline map cached.").foregroundStyle(.secondary)
                
                Button {
                    print("[Settings] 🔘 Tombol 'Download map for current city' ditekan! State: \(maps.downloadState)")
                    guard !maps.downloadState.isBusy else {
                        print("[Settings] ⚠️ Sedang sibuk, abaikan tap ganda.")
                        return
                    }
                    downloadCurrentCity(maps)
                } label: {
                    HStack {
                        if maps.downloadState.isBusy {
                            ProgressView()
                                .tint(.black)
                                .padding(.trailing, 4)
                            Text("Mempersiapkan...")
                                .fontWeight(.semibold)
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
    
    private var forcedOfflineBinding: Binding<Bool> {
        Binding(
            get: { connectivity?.isForcedOfflineMode ?? false },
            set: { connectivity?.isForcedOfflineMode = $0 }
        )
    }
    
    private var engineStatusText: String {
        guard let connectivity else { return "Unknown" }
        if connectivity.isForcedOfflineMode {
            return "Mapbox (Forced offline)"
        }
        return connectivity.isVerifiedOnline ? "Apple Maps (Online)" : "Mapbox (Offline)"
    }
    
    private var engineStatusColor: Color {
        guard let connectivity else { return .secondary }
        if connectivity.isForcedOfflineMode {
            return .orange
        }
        return connectivity.isVerifiedOnline ? .green : Color.buttonPrimary
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
                print("[Settings] 📍 Memulai deteksi lokasi...")
                let city = try await maps.locateAndDetectCity(using: location)
                print("[Settings] 📍 Kota terdeteksi: \(city.name)")
                print("[Settings] 🚀 Memulai unduh peta...")
                let isOnline = !(connectivity?.isForcedOfflineMode ?? false)
                try await maps.downloadCity(city, isOnline: isOnline)
                print("[Settings] ✅ Unduh peta selesai!")
            } catch {
                print("[Settings] ❌ Gagal unduh peta: \(error)")
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
    
    private func packetLog(_ packets: [TransportDiagnostics.PacketEvent]) -> some View {
        let filtered = packets.reversed().filter { packet in
            switch packetFilter {
            case .all: true
            case .chatAndSOS: packet.envelope.type == .chatMessage || packet.envelope.type == .sos
            case .outsideGroup: packet.isOutsideGroup
            case .relayed: packet.isOutsideGroup && packet.direction == .dispatched
            }
        }
        return Section("Packet log") {
            Picker("Show packets", selection: $packetFilter) {
                Text("All packets").tag(PacketFilter.all)
                Text("Chat and SOS").tag(PacketFilter.chatAndSOS)
                Text("Outside group").tag(PacketFilter.outsideGroup)
                Text("Relayed").tag(PacketFilter.relayed)
            }
            if filtered.isEmpty {
                Text("No matching packets yet.").foregroundStyle(.secondary)
            }
            ForEach(filtered) { packet in
                packetRow(packet)
            }
        }
    }
    
    private func packetRow(_ packet: TransportDiagnostics.PacketEvent) -> some View {
        let received = packet.direction == .received
        let envelope = packet.envelope
        let peer = packet.peerId.hasPrefix("ble-") ? "BLE …\(packet.peerId.suffix(4))" : packet.peerId
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Label(packetTitle(envelope.type), systemImage: received ? "arrow.down.circle" : "arrow.up.circle")
                    .font(.subheadline.bold())
                Spacer()
                Text(packet.timestamp, format: .dateTime.hour().minute().second())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(packetStatus(packet))
                .font(.caption)
                .foregroundStyle(packet.isOutsideGroup ? Color.cyan : Color.secondary)
            if received {
                Text("From \(peer) · \(envelope.hopCount)/\(envelope.hopLimit) hops · Seq \(envelope.sequenceNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("To \(peer) · \(envelope.hopCount)/\(envelope.hopLimit) hops · Seq \(envelope.sequenceNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    private func packetTitle(_ type: PacketType) -> LocalizedStringKey {
        switch type {
        case .locationPing: "Location ping"
        case .sos: "SOS"
        case .meetingUpdate: "Meeting point"
        case .routeReq: "Route request"
        case .routeResp: "Route response"
        case .ack: "ACK"
        case .chatMessage: "Chat"
        case .sosResolved: "SOS resolved"
        }
    }
    
    private func packetStatus(_ packet: TransportDiagnostics.PacketEvent) -> LocalizedStringKey {
        switch (packet.direction, packet.isOutsideGroup) {
        case (.received, false): "Received · Group SID"
        case (.received, true): "Received · Outside group"
        case (.dispatched, false): "Sent · Group SID"
        case (.dispatched, true): "Relayed · Outside group"
        }
    }
}

#Preview("Group activity and diagnostics") {
    let activity = [SessionStore.MemberContactLoss(initials: "NIC", timestamp: .now.addingTimeInterval(-30))]
    let snapshot = TransportDiagnostics(
        localPeerId: "DAF",
        serviceType: "_teekum._tcp",
        sessionName: "Festival Crew",
        sessionId: 0x4321,
        state: .connected(peerCount: 1),
        activeDirectPeers: [PeerInfo(id: "ADI", displayName: "Adiat")],
        packetsSent: 1,
        packetsReceived: 2,
        obsoletePingsCoalesced: 0,
        sendErrors: 0,
        lastError: nil,
        recentEvents: [],
        recentPackets: [
            .init(envelope: .init(type: .chatMessage, sessionId: 0x4321, sequenceNumber: 12),
                  direction: .received, peerId: "ADI", isOutsideGroup: false),
            .init(envelope: .init(type: .sos, sessionId: 0x1234, sequenceNumber: 19),
                  direction: .received, peerId: "ble-c-13AB", isOutsideGroup: true),
            .init(envelope: .init(type: .sos, hopCount: 1, sessionId: 0x1234, sequenceNumber: 19),
                  direction: .dispatched, peerId: "ble-p-82CD", isOutsideGroup: true)
        ]
    )
    
    OrbitSettingsView(
        location: nil,
        sos: nil,
        offlineMaps: nil,
        connectivity: nil,
        memberContactLog: { activity },
        diagnostics: { snapshot }
    )
}
