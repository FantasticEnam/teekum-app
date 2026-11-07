//
//  CameraPreviewView.swift
//  Teekum
//
//  Created by Ari Hasan on 07/11/26.
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewSurface {
        let view = CameraPreviewSurface()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewSurface, context: Context) {}

    static func dismantleUIView(_ uiView: CameraPreviewSurface, coordinator: ()) {
        uiView.previewLayer.session = nil
    }
}
