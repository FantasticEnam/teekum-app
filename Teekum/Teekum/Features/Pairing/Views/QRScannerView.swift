//
//  PairingProfileColor.swift
//  Teekum
//
//  Created by Ari Hasan on 07/11/26.
//

import SwiftUI

struct QRScannerView: View {
    var isEnabled = false
    var onCodeScanned: @MainActor @Sendable (String) -> Void = { _ in }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var scanner = QRScannerService()
    @State private var cameraMessage: String?

    var body: some View {
        ZStack {
            Color.black
            if isEnabled {
                CameraPreviewView(session: scanner.session)
                    .accessibilityLabel("Group QR code scanner")
                if let cameraMessage {
                    VStack(spacing: 12) {
                        Text(cameraMessage)
                        Button("Open Settings", action: openSettings)
                            .foregroundStyle(Color.yellowProfile)
                    }
                    .font(.custom("Charter-Roman", size: 14, relativeTo: .body))
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .background(.black.opacity(0.8))
                }
            } else {
                Text("Enter your initials to enable the camera.")
                    .font(.custom("Charter-Roman", size: 14, relativeTo: .body))
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .opacity(0.5)
            }
        }
        .foregroundStyle(.white)
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(white: 0.28), lineWidth: 1)
        }
        .task(id: isEnabled && scenePhase == .active) {
            guard isEnabled, scenePhase == .active else {
                scanner.stop()
                return
            }
            let message = await scanner.start(onCodeScanned: onCodeScanned)
            guard !Task.isCancelled else { return }
            cameraMessage = message
        }
        .onDisappear { scanner.stop() }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    QRScannerView()
        .padding(42)
        .background(.black)
}
