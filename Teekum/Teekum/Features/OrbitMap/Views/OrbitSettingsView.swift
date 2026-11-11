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
    let relayPolicy: RelayPolicyManager?
    let relayState: RelayPolicyState
    let diagnostics: @MainActor () -> TransportDiagnostics?
    @Environment(\.dismiss) private var dismiss
    @State private var changingRelay = false
    @State private var packetFilter: PacketFilter = .all

    var body: some View {
        let snapshot = diagnostics()
        NavigationStack {
            Form {
                if let location {
                    @Bindable var location = location
                    Section("Location") {
                        Toggle("Live sharing", isOn: $location.isLiveSharingEnabled)
                        LabeledContent("GPS", value: location.isGPSAvailable ? "Available" : "Unavailable")
                        LabeledContent("Power", value: location.isSurvivalModeActive ? "Survival mode" : "Normal")
                        if let measured = location.currentLocation {
                            LabeledContent("Accuracy", value: "±\(Int(measured.horizontalAccuracy)) m")
                            Text("Measured \(measured.timestamp, style: .relative) ago").font(.caption)
                        }
                    }
                }
                if relayPolicy != nil {
                    Section("Relay participation") {
                        Text(relayState.statusDescription())
                        ForEach(RelayParticipationMode.allCases, id: \.self) { mode in
                            Button {
                                setRelay(mode)
                            } label: {
                                Label(title(for: mode), systemImage: relayState.mode == mode ? "checkmark.circle.fill" : "circle")
                            }
                                .disabled(changingRelay)
                        }
                        Text("Relaying pauses below 20% battery and in Low Power Mode.").font(.caption)
                    }
                }
                if let sos { InactivitySettingsView(guardService: sos.inactivityGuard) }
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
        case .uwbTokenExchange: "UWB token"
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

    private func title(for mode: RelayParticipationMode) -> LocalizedStringKey {
        switch mode {
        case .disabled: "Off"
        case .communalRelayActive: "Always"
        case .timed30Minutes: "For 30 minutes"
        }
    }

    private func setRelay(_ mode: RelayParticipationMode) {
        guard let relayPolicy else { return }
        changingRelay = true
        Task { @MainActor in
            await relayPolicy.setParticipationMode(mode)
            changingRelay = false
        }
    }
}
