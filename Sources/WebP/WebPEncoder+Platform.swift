#if os(macOS)
import AppKit
import CoreGraphics
import Foundation

public extension WebPEncoder {
    func encode(_ image: NSImage, config: WebPEncoderConfig, width: Int = 0, height: Int = 0) throws -> Data {
        // No rectangle pointer is supplied; AppKit manages the returned CGImage lifetime.
        guard let cgImage = unsafe image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't convert NSImage to CGImage.")
        }

        // Straight 8-bit layouts (e.g. decoded PNGs) are encoded without copying; others are redrawn.
        if let encoded = try cgImage.withWebPStraightPixels({ bytes, format in
            try encode(
                bytes, format: format, config: config,
                originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.bytesPerRow,
                resizeWidth: width, resizeHeight: height
            )
        }) {
            return encoded
        }
        return try encode(
            cgImage.webPStraightRGBA(), format: .rgba, config: config,
            originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.width * 4,
            resizeWidth: width, resizeHeight: height
        )
    }
}
#endif

#if os(iOS)
import CoreGraphics
import Foundation
import UIKit

public extension WebPEncoder {
    func encode(_ image: UIImage, config: WebPEncoderConfig, width: Int = 0, height: Int = 0) throws -> Data {
        guard let cgImage = image.cgImage else {
            throw WebPError.unexpectedError(withMessage: "Couldn't convert UIImage to CGImage.")
        }
        // Straight 8-bit layouts (e.g. decoded PNGs) are encoded without copying; others are redrawn.
        if let encoded = try cgImage.withWebPStraightPixels({ bytes, format in
            try encode(
                bytes, format: format, config: config,
                originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.bytesPerRow,
                resizeWidth: width, resizeHeight: height
            )
        }) {
            return encoded
        }
        return try encode(
            cgImage.webPStraightRGBA(), format: .rgba, config: config,
            originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.width * 4,
            resizeWidth: width, resizeHeight: height
        )
    }
}
#endif
