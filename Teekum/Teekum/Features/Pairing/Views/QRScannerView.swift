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
    var isScanned = false
    var onCodeScanned: @MainActor @Sendable (String) -> Void = { _ in }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var scanner = QRScannerService()
    @State private var cameraMessage: String?

    var body: some View {
        Group {
            if isScanned {
                VStack(spacing: 14) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("Connecting…")
                        .font(.custom("Helvetica", size: 14, relativeTo: .body))
                        .foregroundStyle(Color(white: 0.8))
                }
            } else if isEnabled, let cameraMessage {
                VStack(spacing: 8) {
                    Text(cameraMessage)
                    Button("Open Settings", action: openSettings)
                        .foregroundStyle(Color.buttonPrimary)
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
        .font(.custom("Helvetica", size: 14, relativeTo: .body))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 255, maxHeight: 255)
        .background {
            if isScanned {
                Color(white: 0.12)
            } else {
                CameraPreviewView(session: scanner.session)
                    .opacity(isEnabled ? 1 : 0)
                    .background(Color.black)
                    .accessibilityLabel("Group QR code scanner")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(white: 0.28), lineWidth: 1)
        }
        .task(id: isEnabled && !isScanned && scenePhase == .active) {
            guard isEnabled, !isScanned, scenePhase == .active else {
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
