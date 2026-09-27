#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

extension CGImage {
    /// Convert any Core Graphics bitmap layout to straight-alpha RGBA bytes for libwebp.
    /// "Straight alpha" means RGB values have not been multiplied by alpha.
    /// For example, half-transparent red is (255, 0, 0, 128), not (128, 0, 0, 128).
    func webPStraightRGBA() throws -> [UInt8] {
        let maximumDimension = 16383
        guard width > 0, height > 0, width <= maximumDimension, height <= maximumDimension else {
            throw WebPEncoderError.invalidParameter
        }

        let bytesPerRow = width * 4
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        // Drawing normalizes source channel order, but Core Graphics premultiplies alpha.
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = unsafe CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            ) else {
                throw WebPError.unexpectedError(withMessage: "Couldn't initialize RGBA CGContext.")
            }

            context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        unpremultiplyRGBA(&pixels)
        return pixels
    }

    func withPixelBytes<Result>(_ body: (borrowing Span<UInt8>) throws -> Result) throws -> Result {
        guard let data = dataProvider?.data, let pointer = unsafe CFDataGetBytePtr(data) else {
            throw WebPError.unexpectedPointerError
        }
        // Retain the actual CFData owner, not only the image/provider, through the entire borrow.
        return try withExtendedLifetime(data) {
            let buffer = unsafe UnsafeBufferPointer(start: pointer, count: CFDataGetLength(data))
            return unsafe try body(Span(_unsafeElements: buffer))
        }
    }
}

/// libwebp expects color channels before alpha was applied, unlike a Core Graphics bitmap.
private func unpremultiplyRGBA(_ pixels: inout [UInt8]) {
    let maximumChannelValue = 255

    for pixelOffset in stride(from: 0, to: pixels.count, by: 4) {
        let alpha = Int(pixels[pixelOffset + 3])
        guard alpha > 0, alpha < maximumChannelValue else { continue }

        for channelOffset in 0 ..< 3 {
            let premultipliedValue = Int(pixels[pixelOffset + channelOffset])
            // Add half the divisor to round to the nearest 8-bit channel value.
            let straightValue = (premultipliedValue * maximumChannelValue + alpha / 2) / alpha
            pixels[pixelOffset + channelOffset] = UInt8(min(maximumChannelValue, straightValue))
        }
    }
}
#endif
