import Foundation

#if canImport(CoreGraphics)
import CoreGraphics

extension WebPEncoder {
    public func encode(RGB cgImage: CGImage, config: WebPEncoderConfig, resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        return try encode(RGB: cgImage.getBaseAddress(), config: config,
                          originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.bytesPerRow)
    }

    public func encode(RGBA cgImage: CGImage, config: WebPEncoderConfig, resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        return try encode(RGBA: cgImage.getBaseAddress(), config: config,
                          originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.bytesPerRow)
    }

    public func encode(RGBX cgImage: CGImage, config: WebPEncoderConfig, resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        return try encode(RGBX: cgImage.getBaseAddress(), config: config,
                          originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.bytesPerRow)
    }

    public func encode(BGR cgImage: CGImage, config: WebPEncoderConfig, resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        return try encode(BGR: cgImage.getBaseAddress(), config: config,
                          originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.bytesPerRow)
    }

    public func encode(BGRA cgImage: CGImage, config: WebPEncoderConfig, resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        return try encode(BGRA: cgImage.getBaseAddress(), config: config,
                          originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.bytesPerRow)
    }

    public func encode(BGRX cgImage: CGImage, config: WebPEncoderConfig, resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        return try encode(BGRX: cgImage.getBaseAddress(), config: config,
                          originWidth: cgImage.width, originHeight: cgImage.height, stride: cgImage.bytesPerRow)
    }
}

#endif
