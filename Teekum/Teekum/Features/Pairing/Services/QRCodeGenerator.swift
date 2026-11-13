//
//  QRCodeGenerator.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

enum QRCodeGenerator {
    static func image(for url: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = 432 / output.extent.width
        let image = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
