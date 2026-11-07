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
