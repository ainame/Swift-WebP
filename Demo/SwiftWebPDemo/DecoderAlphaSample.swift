import CoreGraphics
import Foundation
import UIKit
import WebP

/// Round-trips a half-transparent gray square through WebP and decodes it with the old and current decoders.
/// The legacy path intentionally preserves the bug so the Demo can show a real before/after comparison.
enum DecoderAlphaSample {
    static let side = 160
    /// Straight RGBA: mid gray at 50% opacity. Over white it should look light gray (about 192).
    /// The old decoder adds the full gray on top of half the white background (128 + 127), giving white.
    static let pixel: [UInt8] = [128, 128, 128, 128]

    static let legacyCode = """
    // Old decodeCGImage: straight-alpha bytes tagged as premultiplied.
    let data = try decoder.decode(webPData, options: options, format: .rgba)
    CGImage(..., bitmapInfo: byteOrder32Big | premultipliedLast, ...)
    """

    static let fixedCode = """
    // Current API: decodes premultiplied .rgbA to match the bitmap info.
    try WebPDecoder().decodeUIImage(from: webPData, options: options)
    """

    static func makeComparison() throws -> DecoderAlphaComparison {
        var config = WebPEncoderConfig.preset(.picture, quality: 100)
        config.lossless = 1
        let rgba = [[UInt8]](repeating: pixel, count: side * side).flatMap(\.self)
        let webPData = try WebPEncoder().encode(
            rgba, format: .rgba, config: config, originWidth: side, originHeight: side, stride: side * 4
        )
        let options = WebPDecoderOptions()
        // This calls the actual platform API, rather than a copy of its implementation.
        guard let after = try WebPDecoder().decodeUIImage(from: webPData, options: options).cgImage else {
            throw SampleError.imageCreation
        }
        return try DecoderAlphaComparison(before: legacyDecodeCGImage(webPData, options: options), after: after)
    }

    /// Reproduces `decodeCGImage` from 0.3.0 through 0.7.0.
    private static func legacyDecodeCGImage(_ webPData: Data, options: WebPDecoderOptions) throws -> CGImage {
        let decoded = try WebPDecoder().decode(webPData, options: options, format: .rgba)
        guard let provider = CGDataProvider(data: decoded as CFData),
              let image = CGImage(
                  width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                      | CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { throw SampleError.imageCreation }
        return image
    }

    enum SampleError: Error {
        case imageCreation
    }
}

struct DecoderAlphaComparison {
    let before: CGImage
    let after: CGImage
}
