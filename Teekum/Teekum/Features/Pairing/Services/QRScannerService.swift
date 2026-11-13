//
//  QRScannerService.swift
//  Teekum
//
//  Created by Ari Hasan on 07/11/26.
//

@preconcurrency import AVFoundation
import Foundation


final class QRScannerService: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let requestLock = NSLock()
    private var activeRequest: UUID?
    private var codeHandler: (@MainActor @Sendable (String) -> Void)?
    private var lastCode: String?
    private let sessionQueue = DispatchQueue(label: "com.teekum.pairing.camera")

    func start(onCodeScanned: @escaping @MainActor @Sendable (String) -> Void) async -> String? {
        let request = UUID()
        requestLock.withLock {
            activeRequest = request
            codeHandler = onCodeScanned
            lastCode = nil
        }
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: granted = true
        case .notDetermined:
            granted = await AVCaptureDevice.requestAccess(for: .video)
        default: granted = false
        }
        guard !Task.isCancelled else { return nil }
        guard granted else {
            return String(localized: "Camera access is unavailable. Enable it in Settings or paste an invite link.")
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
                    if session.outputs.isEmpty {
                        let output = AVCaptureMetadataOutput()
                        session.beginConfiguration()
                        guard session.canAddOutput(output) else {
                            session.commitConfiguration()
                            continuation.resume(returning: String(localized: "QR scanning is unavailable. Paste an invite link instead."))
                            return
                        }
                        session.addOutput(output)
                        output.setMetadataObjectsDelegate(self, queue: sessionQueue)
                        output.metadataObjectTypes = [.qr]
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
        requestLock.withLock {
            activeRequest = nil
            codeHandler = nil
            lastCode = nil
        }
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let code = metadataObjects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first else { return }
        let delivery = requestLock.withLock { () -> (UUID, @MainActor @Sendable (String) -> Void)? in
            guard let activeRequest, let codeHandler, lastCode != code else { return nil }
            lastCode = code
            return (activeRequest, codeHandler)
        }
        guard let (request, handler) = delivery else { return }
        Task { @MainActor [weak self] in
            guard let self, requestLock.withLock({ activeRequest == request }) else { return }
            handler(code)
        }
    }
}
