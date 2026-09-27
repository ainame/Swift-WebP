#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

public extension WebPEncoder {
    func encode(
        _ cgImage: CGImage,
        format: WebPEncodePixelFormat = .rgba,
        config: WebPEncoderConfig,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0
    ) throws -> Data {
        try cgImage.withPixelBytes { bytes in
            try encode(
                bytes,
                format: format,
                config: config,
                originWidth: cgImage.width,
                originHeight: cgImage.height,
                stride: cgImage.bytesPerRow,
                resizeWidth: resizeWidth,
                resizeHeight: resizeHeight
            )
        }
    }
}

#endif
