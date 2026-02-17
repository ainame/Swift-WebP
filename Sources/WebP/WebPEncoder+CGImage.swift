import Foundation

#if canImport(CoreGraphics)
import CoreGraphics

extension WebPEncoder {
    public func encode(
        _ cgImage: CGImage,
        format: WebPEncodePixelFormat = .rgba,
        config: WebPEncoderConfig,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0
    ) throws -> Data {
        return try encode(
            cgImage.getBaseAddress(),
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

#endif
