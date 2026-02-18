import Foundation

#if canImport(CoreGraphics)
import CoreGraphics

public extension WebPEncoder {
    func encode(
        _ cgImage: CGImage,
        format: WebPEncodePixelFormat = .rgba,
        config: WebPEncoderConfig,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0
    ) throws -> Data {
        let baseAddress = try cgImage.getBaseAddress()
        let byteCount = cgImage.bytesPerRow * cgImage.height
        let buffer = UnsafeBufferPointer(start: baseAddress, count: byteCount)
        return try encode(
            buffer,
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
