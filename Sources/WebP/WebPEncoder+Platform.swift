import Foundation

#if os(macOS)
import AppKit
import CoreGraphics

public extension WebPEncoder {
    func encode(_ image: NSImage, config: WebPEncoderConfig, width: Int = 0, height: Int = 0) throws -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't convert NSImage to CGImage.")
        }

        let stride = cgImage.bytesPerRow
        return try encode(
            cgImage.getBaseAddress(),
            format: .rgba,
            config: config,
            originWidth: cgImage.width,
            originHeight: cgImage.height,
            stride: stride,
            resizeWidth: width,
            resizeHeight: height
        )
    }
}
#endif

#if os(iOS)
import CoreGraphics
import UIKit

extension WebPEncoder {
    public func encode(_ image: UIImage, config: WebPEncoderConfig, width: Int = 0, height: Int = 0) throws -> Data {
        let cgImage = try convertUIImageToCGImageWithRGBA(image)
        let stride = cgImage.bytesPerRow
        return try encode(
            cgImage.getBaseAddress(),
            format: .rgba,
            config: config,
            originWidth: Int(image.size.width),
            originHeight: Int(image.size.height),
            stride: stride,
            resizeWidth: width,
            resizeHeight: height
        )
    }

    private func convertUIImageToCGImageWithRGBA(_ image: UIImage) throws -> CGImage {
        guard let inputCGImage = image.cgImage else {
            throw WebPError.unexpectedError(withMessage: "")
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(image.size.width),
            height: Int(image.size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(image.size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
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
