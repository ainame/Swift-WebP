#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import libwebp

extension CGImage {
    /// The libwebp format matching this image's backing bytes, or `nil` if they need `webPStraightRGBA()`.
    /// Decoded 8-bit PNGs and JPEGs usually qualify. Drawn images do not, because Core Graphics
    /// contexts premultiply alpha. The color space must be sRGB-compatible so that encoding the bytes
    /// directly gives the same colors as redrawing them into device RGB.
    /// A `decode` array remaps component values when drawn, so images with one are redrawn too.
    /// Masks applied with `masking(_:)` or `copy(maskingColorComponents:)` cannot be detected
    /// through `CGImage` and are ignored when the bytes are encoded directly.
    var webPStraightPixelFormat: WebPEncodePixelFormat? {
        guard bitsPerComponent == 8,
            !bitmapInfo.contains(.floatComponents),
            decode == nil,
            let colorSpace,
            colorSpace.name == CGColorSpace.sRGB || colorSpace.name == CGColorSpaceCreateDeviceRGB().name
        else { return nil }

        // libwebp's WebPPictureImport* functions (webp/encode.h) read bytes in the memory order named
        // by the function: R, G, B, A for RGBA, B, G, R, A for BGRA, and so on. The X variants ignore
        // the fourth byte. libwebp has no importer for ARGB or ABGR memory order.
        //
        // Core Graphics describes a pixel as one word, not as bytes in memory:
        // - `alphaInfo` places alpha (or an ignored byte for `noneSkip*`) in "the least significant
        //   bits of each pixel" for `.last` and "the most significant bits" for `.first`, so the word
        //   reads R G B A or A R G B from most to least significant.
        //   https://developer.apple.com/documentation/coregraphics/cgimagealphainfo
        // - The byte order is documented only as "32-bit, big/little endian format", i.e. how that
        //   word is stored in memory: `byteOrder32Big` stores the most significant byte first and
        //   `byteOrder32Little` stores it last. The default order is not specified by the docs; it
        //   stores bytes like big-endian, which the explicit-format encoder tests confirm.
        //   https://developer.apple.com/documentation/coregraphics/cgbitmapinfo
        //
        // Combining the two gives the memory order libwebp needs:
        // - `.last` + big-endian: R G B A in memory, which is RGBA (or RGBX)
        // - `.first` + little-endian: A R G B word stored as B G R A, which is BGRA (or BGRX)
        // - `.last` + little-endian stores A B G R, and `.first` + big-endian stores A R G B.
        //   libwebp cannot import either, so they return `nil` and get redrawn.
        // 24-bit pixels have no alpha or 32-bit word, so only the default layout (R G B) qualifies.
        let byteOrder = bitmapInfo.intersection(.byteOrderMask)
        let isBigEndian = byteOrder == [] || byteOrder == .byteOrder32Big
        switch (bitsPerPixel, alphaInfo) {
        case (32, .last) where isBigEndian: return .rgba
        case (32, .noneSkipLast) where isBigEndian: return .rgbx
        case (32, .first) where byteOrder == .byteOrder32Little: return .bgra
        case (32, .noneSkipFirst) where byteOrder == .byteOrder32Little: return .bgrx
        case (24, .none) where byteOrder == []: return .rgb
        default: return nil
        }
    }

    /// Convert any Core Graphics bitmap layout to straight-alpha RGBA bytes for libwebp.
    /// The CGContext below stores premultiplied RGBA: it multiplies RGB values by alpha.
    /// For example, half-transparent red (255, 0, 0, 128) is stored as (128, 0, 0, 128).
    /// libwebp expects the original RGB values, so this undoes that multiplication.
    func webPStraightRGBA() throws -> [UInt8] {
        // Check libwebp's per-side pixel limit before allocating the RGBA buffer.
        let maximumDimension = Int(WEBP_MAX_DIMENSION)
        guard width > 0,
            height > 0,
            width <= maximumDimension,
            height <= maximumDimension
        else {
            throw WebPEncoderError.invalidParameter
        }

        let (bytesPerRow, rowOverflow) = width.multipliedReportingOverflow(by: 4)
        let (bufferSize, sizeOverflow) = bytesPerRow.multipliedReportingOverflow(by: height)
        guard !rowOverflow, !sizeOverflow else {
            throw WebPEncoderError.invalidParameter
        }
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        var pixels = [UInt8](repeating: 0, count: bufferSize)

        // Drawing normalizes source channel order, but Core Graphics premultiplies alpha.
        try pixels.withUnsafeMutableBytes { buffer in
            // swift-format-ignore
            guard let context = unsafe CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo,
            ) else {
                throw WebPError.unexpectedError(withMessage: "Couldn't initialize RGBA CGContext.")
            }

            context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        unpremultiplyRGBA(&pixels)
        return pixels
    }

    func withPixelBytes<Result>(_ body: (borrowing Span<UInt8>) throws -> Result) throws -> Result {
        guard let data = dataProvider?.data else {
            throw WebPError.unexpectedPointerError
        }
        return try withBorrowedBytes(of: data, body)
    }

    /// Borrows the backing bytes with their `webPStraightPixelFormat`, or returns `nil` so the caller
    /// can redraw with `webPStraightRGBA()`. Also returns `nil` when the bytes do not cover
    /// `bytesPerRow * height`: `cropping(to:)` keeps the parent's `bytesPerRow` but ends its data at
    /// the crop's last pixel, which libwebp's full-row contract would reject.
    func withWebPStraightPixels<Result>(
        _ body: (borrowing Span<UInt8>, WebPEncodePixelFormat) throws -> Result
    ) throws -> Result? {
        let (required, overflow) = bytesPerRow.multipliedReportingOverflow(by: height)
        guard let format = webPStraightPixelFormat,
            !overflow,
            let data = dataProvider?.data,
            CFDataGetLength(data) >= required
        else { return nil }
        return try withBorrowedBytes(of: data) { bytes in try body(bytes, format) }
    }

    private func withBorrowedBytes<Result>(
        of data: CFData,
        _ body: (borrowing Span<UInt8>) throws -> Result,
    ) throws -> Result {
        guard let pointer = unsafe CFDataGetBytePtr(data) else {
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
