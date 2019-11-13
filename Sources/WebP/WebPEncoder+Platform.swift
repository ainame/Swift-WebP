import Foundation

#if os(macOS)
import AppKit
import CoreGraphics

extension WebPEncoder {
    public func encode(_ image: NSImage, config: WebPEncoderConfig, width: Int = 0, height: Int = 0) throws -> Data {
        guard let data = image.tiffRepresentation else {
            throw WebPError.unexpectedError(withMessage: "Given image doesn't support TIFF representation.")
        }
        guard let bitmapData = NSBitmapImageRep(data: data)?.bitmapData else {
            throw WebPError.unexpectedError(withMessage: "NSBitmapImageRep couldn't interpret given image.")
        }

        let stride = Int(image.size.width) * MemoryLayout<UInt8>.size * 3 // RGB = 3byte
        let webPData = try encode(RGB: bitmapData, config: config,
                                  originWidth: Int(image.size.width), originHeight: Int(image.size.height), stride: stride,
                                  resizeWidth: width, resizeHeight: height)
        return webPData
    }
}
#endif

#if os(iOS)
import UIKit
import CoreGraphics

extension WebPEncoder {
    public func encode(_ image: UIImage, config: WebPEncoderConfig, width: Int = 0, height: Int = 0) throws -> Data {
        let cgImage = try convertUIImageToCGImageWithRGBA(image)
        let stride = cgImage.bytesPerRow
        let webPData = try encode(RGBA: cgImage.getBaseAddress(), config: config,
                                  originWidth: Int(image.size.width), originHeight: Int(image.size.height), stride: stride,
                                  resizeWidth: width, resizeHeight: height)
        return webPData
    }

    private func convertUIImageToCGImageWithRGBA(_ image: UIImage) throws -> CGImage {
        guard let inputCGImage = image.cgImage else {
            throw WebPError.unexpectedError(withMessage: "")
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(data: nil, width: Int(image.size.width), height: Int(image.size.height),
                                      bitsPerComponent: 8, bytesPerRow: Int(image.size.width) * 4,
                                      space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't initialize CGContext")
        }

        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        guard let cgImage = context.makeImage() else {
            throw WebPError.unexpectedError(withMessage: "Couldn't ")
        }

        return cgImage
    }
}

#endif
