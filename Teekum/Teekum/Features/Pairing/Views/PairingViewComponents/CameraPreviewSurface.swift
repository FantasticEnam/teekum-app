//
//  CameraPreviewSurface.swift
//  Teekum
//
//  Created by Ari Hasan on 07/11/26.
//

import AVFoundation
import UIKit

final class CameraPreviewSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // layerClass guarantees the backing layer's type.
        layer as! AVCaptureVideoPreviewLayer
    }
}

#Preview("Camera surface", traits: .fixedLayout(width: 320, height: 300)) {
    let surface = CameraPreviewSurface()
    surface.backgroundColor = .black
    return surface
}
