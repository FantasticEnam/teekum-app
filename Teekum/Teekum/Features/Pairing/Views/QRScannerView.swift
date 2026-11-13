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
    var onPasteCandidates: @MainActor ([String]) -> Void = { _ in }

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
                    .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 48)
                }
            } else {
                Text("Enter your initials to enable the camera.")
                    .font(.custom("Charter-Roman", size: 14, relativeTo: .body))
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .padding(.bottom, 44)
                    .opacity(0.5)
            }
        }
        .overlay(alignment: .bottom) {
            Button(action: pasteFromClipboard) {
                PairingCardPillLabel(title: "Paste Invite Link")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
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

    private func pasteFromClipboard() {
        var candidates: [String] = []
        if UIPasteboard.general.hasStrings, let text = UIPasteboard.general.string {
            candidates.append(text)
        }
        if UIPasteboard.general.hasURLs, let urlString = UIPasteboard.general.url?.absoluteString {
            candidates.append(urlString)
        }
        onPasteCandidates(candidates)
    }
}

#Preview {
    QRScannerView()
        .padding(42)
        .background(.black)
}
