//
//  PairingProfileColor.swift
//  Teekum
//
//  Created by Ari Hasan on 07/11/26.
//

import SwiftUI
import UIKit

struct QRScannerView: View {
    var isEnabled = false
    var onCodeScanned: @MainActor @Sendable (String) -> Void = { _ in }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var scanner = QRScannerService()
    @State private var cameraMessage: String?

    var body: some View {
        Group {
            if isEnabled, let cameraMessage {
                VStack(spacing: 8) {
                    Text(cameraMessage)
                    Button("Open Settings", action: openSettings)
                        .foregroundStyle(Color.yellowProfile)
                }
                .padding(8)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
            } else if !isEnabled {
                Text("Enter your initials to enable the camera.")
                    .opacity(0.5)
            } else {
                Color.clear
            }
        }
        .font(.custom("Futura", size: 14, relativeTo: .body))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 255, maxHeight: 255)
        .background {
            if isEnabled {
                CameraPreviewView(session: scanner.session)
                    .accessibilityLabel("Group QR code scanner")
            } else {
                Color.black
            }
        }
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
