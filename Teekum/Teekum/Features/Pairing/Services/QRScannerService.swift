//
//  QRScannerService.swift
//  Teekum
//
//  Created by Ari Hasan on 07/11/26.
//

@preconcurrency import AVFoundation
import Foundation


final class QRScannerService: @unchecked Sendable {
    let session = AVCaptureSession()
    private let requestLock = NSLock()
    private var activeRequest: UUID?
    private let sessionQueue = DispatchQueue(label: "com.teekum.pairing.camera")

    func start() async -> String? {
        let request = UUID()
        requestLock.withLock { activeRequest = request }
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: granted = true
        case .notDetermined:
            granted = await AVCaptureDevice.requestAccess(for: .video)
        default: granted = false
        }
        guard !Task.isCancelled else { return nil }
        guard granted else {
            return String(localized: "Camera access is unavailable. Enable it in Settings to preview the camera.")
        }
        return await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                guard requestLock.withLock({ activeRequest == request }) else {
                    continuation.resume(returning: nil)
                    return
                }
                do {
                    if session.inputs.isEmpty {
                        guard let camera = AVCaptureDevice.default(for: .video) else {
                            continuation.resume(returning: String(localized: "Camera preview is unavailable on this device."))
                            return
                        }
                        let input = try AVCaptureDeviceInput(device: camera)
                        session.beginConfiguration()
                        session.sessionPreset = .high
                        guard session.canAddInput(input) else {
                            session.commitConfiguration()
                            continuation.resume(returning: String(localized: "Unable to start the camera preview."))
                            return
                        }
                        session.addInput(input)
                        session.commitConfiguration()
                    }
                    if !session.isRunning { session.startRunning() }
                    continuation.resume(returning: nil)
                } catch {
                    continuation.resume(returning: String(localized: "Unable to start the camera preview."))
                }
            }
        }
    }

    func stop() {
        requestLock.withLock { activeRequest = nil }
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }
}
