//
//  WiFiAwarePairingSection.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 15/11/26.
//

import DeviceDiscoveryUI
import SwiftUI
import WiFiAware

struct WiFiAwarePairingSection: View {
    let pairedDeviceCount: Int?
    var directPeerCount = 0
    var onInteraction: () -> Void = {}

    @State private var message: String?

    // Wi-Fi Aware permits one publisher per service. This can run while mesh links stay live.
    private let pairingService = "_meepo-pair._tcp"

    var body: some View {
        Section("Nearby device pairing") {
            if !WACapabilities.supportedFeatures.contains(.wifiAware) {
                Text("Wi-Fi Aware is unavailable on this device.")
            } else if let publish = WAPublishableService.allServices[pairingService],
                      let subscribe = WASubscribableService.allServices[pairingService] {
                if let pairedDeviceCount {
                    LabeledContent("Paired devices", value: "\(pairedDeviceCount)")
                }
                DevicePairingView(.wifiAware(.connecting(to: publish, from: .userSpecifiedDevices)), access: .permanent) {
                    Label("Make this iPhone discoverable", systemImage: "wifi")
                } fallback: {
                    Text("iOS cannot make this iPhone discoverable. Check Wi-Fi and Local Network access.")
                }
                DevicePicker(.wifiAware(.connecting(to: .userSpecifiedDevices, from: subscribe)), access: .permanent) { _ in
                    onInteraction()
                    if directPeerCount == 0 { message = "iPhone selected. Waiting for a direct link." }
                } label: {
                    Label("Find a nearby iPhone", systemImage: "iphone")
                } fallback: {
                    Text("iOS cannot open device discovery. Check Wi-Fi and Local Network access.")
                }
                Text("Make one iPhone discoverable, then select it from the other. iOS shows a code when the other iPhone requests pairing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let message {
                    Text(message).font(.caption)
                } else if pairedDeviceCount == 0 {
                    Text("Pair the iPhones to see nearby group members.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if pairedDeviceCount != nil, directPeerCount == 0 {
                    Text("Waiting for a connection to a paired iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("The Wi-Fi Aware service is missing from this build.")
            }
        }
        .onChange(of: pairedDeviceCount) { previous, current in
            if let previous, let current, current > previous { onInteraction() }
        }
        .onChange(of: directPeerCount) {
            if directPeerCount > 0 { message = nil }
        }
    }
}

#Preview {
    Form {
        WiFiAwarePairingSection(pairedDeviceCount: 2)
    }
}
