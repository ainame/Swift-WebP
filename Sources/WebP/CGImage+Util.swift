#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

extension CGImage {
    /// Rasterize arbitrary platform bitmap layouts, then undo Core Graphics' alpha premultiplication.
    func webPStraightRGBA() throws -> [UInt8] {
        guard width > 0, height > 0, width <= 16383, height <= 16383 else {
            throw WebPEncoderError.invalidParameter
        }
        let stride = width * 4
        var pixels = [UInt8](repeating: 0, count: stride * height)
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = unsafe CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: stride,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw WebPError.unexpectedError(withMessage: "Couldn't initialize RGBA CGContext.")
            }
            context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        for offset in Swift.stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Int(pixels[offset + 3])
            guard alpha > 0, alpha < 255 else { continue }
            for channel in 0 ..< 3 {
                pixels[offset + channel] = UInt8(min(255, (Int(pixels[offset + channel]) * 255 + alpha / 2) / alpha))
            }
        }
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
#endif
