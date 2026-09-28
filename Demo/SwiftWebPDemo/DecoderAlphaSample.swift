import CoreGraphics
import Foundation
import UIKit
import WebP

/// Round-trips an alpha gradient through WebP and decodes it with the old and current platform decoders.
/// The legacy path intentionally preserves the bug so the Demo can show a real before/after comparison.
enum DecoderAlphaSample {
    static let width = 256
    static let bandHeight = 40
    /// Red, green, blue, and white bands. Alpha increases from 0 on the left to 255 on the right.
    static let bands: [(name: String, rgb: (UInt8, UInt8, UInt8))] = [
        ("Red", (255, 0, 0)), ("Green", (0, 255, 0)), ("Blue", (0, 0, 255)), ("White", (255, 255, 255)),
    ]
    static var height: Int { bandHeight * bands.count }
    /// The pixel that the readout samples: the middle of the red band at alpha 128.
    static let samplePoint = (x: 128, y: bandHeight / 2)

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
        let webPData = try WebPEncoder().encode(
            makeStraightRGBA(), format: .rgba, config: config,
            originWidth: width, originHeight: height, stride: width * 4
        )
        let options = WebPDecoderOptions()
        let before = try legacyDecodeCGImage(webPData, options: options)
        // This calls the actual platform API, rather than a copy of its implementation.
        guard let after = try WebPDecoder().decodeUIImage(from: webPData, options: options).cgImage else {
            throw SampleError.imageCreation
        }
        let source = sourcePixel()
        return try DecoderAlphaComparison(
            before: .init(image: before, overBlack: compositeOverBlack(before)),
            after: .init(image: after, overBlack: compositeOverBlack(after)),
            sourcePixel: source,
            expectedOverBlack: premultiply(source)
        )
    }

    /// Straight (non-premultiplied) RGBA bytes, as stored in the WebP bitstream.
    private static func makeStraightRGBA() -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for (bandIndex, band) in bands.enumerated() {
            for y in bandIndex * bandHeight ..< (bandIndex + 1) * bandHeight {
                for x in 0 ..< width {
                    let offset = (y * width + x) * 4
                    pixels[offset] = band.rgb.0
                    pixels[offset + 1] = band.rgb.1
                    pixels[offset + 2] = band.rgb.2
                    pixels[offset + 3] = UInt8(x)
                }
            }
        }
        return pixels
    }

    private static func sourcePixel() -> [UInt8] {
        let band = bands[samplePoint.y / bandHeight].rgb
        return [band.0, band.1, band.2, UInt8(samplePoint.x)]
    }

    private static func premultiply(_ pixel: [UInt8]) -> [UInt8] {
        let alpha = Int(pixel[3])
        return pixel.prefix(3).map { UInt8((Int($0) * alpha + 127) / 255) } + [255]
    }

    /// Reproduces `decodeCGImage` from 0.3.0 through 0.7.0.
    private static func legacyDecodeCGImage(_ webPData: Data, options: WebPDecoderOptions) throws -> CGImage {
        let decoded = try WebPDecoder().decode(webPData, options: options, format: .rgba)
        guard let provider = CGDataProvider(data: decoded as CFData),
              let image = CGImage(
                  width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                      | CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { throw SampleError.imageCreation }
        return image
    }

    /// Draws the image over opaque black with Core Graphics and reads back the sample pixel.
    private static func compositeOverBlack(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { throw SampleError.imageCreation }
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let offset = (samplePoint.y * width + samplePoint.x) * 4
        return Array(pixels[offset ..< offset + 4])
    }

    enum SampleError: Error {
        case imageCreation
    }
}

struct DecoderAlphaComparison {
    struct Output {
        let image: CGImage
        /// The sample pixel after Core Graphics composites the image over opaque black.
        let overBlack: [UInt8]
    }

    let before: Output
    let after: Output
    let sourcePixel: [UInt8]
    let expectedOverBlack: [UInt8]
}
