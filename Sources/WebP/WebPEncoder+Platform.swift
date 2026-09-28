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

        return try encode(normalizing: cgImage, config: config, resizeWidth: width, resizeHeight: height)
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
        return try encode(normalizing: cgImage, config: config, resizeWidth: width, resizeHeight: height)
    }
}
#endif
