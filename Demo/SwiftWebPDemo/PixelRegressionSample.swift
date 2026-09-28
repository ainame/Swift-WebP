import CoreGraphics
import Foundation
import UIKit
import WebP

/// The legacy paths intentionally preserve the bugs so the Demo can show a real before/after round trip.
enum PixelRegressionSample: String, CaseIterable, Identifiable {
    case alpha = "Translucent colors"
    case channelOrder = "Red / blue order"
    case retina = "Retina resolution"

    var id: Self { self }

    var explanation: String {
        switch self {
        case .alpha:
            "50% transparent red and blue. Before: premultiplied colors are treated as straight alpha, making them darker."
        case .channelOrder:
            "Opaque BGRA pixels. Before: the old macOS NSImage path reads them as RGBA, swapping red and blue. This Demo reproduces that macOS path on iOS."
        case .retina:
            "A 360 × 160 pixel image with a 180 × 80 point size. Before: the old UIImage path downsamples to points, blurring the fine stripes."
        }
    }

    var legacyCode: String {
        switch self {
        case .alpha, .channelOrder:
            """
            // Old NSImage path: assumes RGBA without converting the source.
            try encoder.encode(cgImage, format: .rgba, config: config)
            """
        case .retina:
            """
            // Old UIImage path: creates a bitmap using point dimensions.
            let width = Int(image.size.width)
            let height = Int(image.size.height)
            let context = CGContext(data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cgImage, in: CGRect(x: 0, y: 0,
                width: width, height: height))
            try encoder.encode(context.makeImage()!,
                format: .rgba, config: config)
            """
        }
    }

    func makeComparison() throws -> PixelComparison {
        let source = try makeSource()
        let image = UIImage(cgImage: source, scale: 2, orientation: .up)
        var config = WebPEncoderConfig.preset(.picture, quality: 100)
        config.lossless = 1
        let encoder = WebPEncoder()
        let legacy = try legacyEncode(image, config: config)
        // This calls the actual fixed platform API, rather than a copy of its implementation.
        let fixed = try encoder.encode(image, config: config)
        return try PixelComparison(
            original: source,
            before: roundTrip(legacy),
            after: roundTrip(fixed)
        )
    }

    private func makeSource() throws -> CGImage {
        let bgra = self == .channelOrder
        let info = (bgra ? CGBitmapInfo.byteOrder32Little : .byteOrder32Big).rawValue
            | (bgra ? CGImageAlphaInfo.premultipliedFirst : .premultipliedLast).rawValue
        let context = try makeContext(width: 360, height: 160, bitmapInfo: info)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if self == .retina {
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 360, height: 160))
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            for x in stride(from: 0, to: 360, by: 2) {
                context.fill(CGRect(x: x, y: 0, width: 1, height: 160))
            }
        } else {
            let alpha: CGFloat = self == .alpha ? 0.5 : 1
            guard let red = CGColor(colorSpace: colorSpace, components: [1, 0, 0, alpha]),
                  let blue = CGColor(colorSpace: colorSpace, components: [0, 0, 1, alpha]) else {
                throw SampleError.bitmapCreation
            }
            context.setFillColor(red)
            context.fill(CGRect(x: 0, y: 0, width: 180, height: 160))
            context.setFillColor(blue)
            context.fill(CGRect(x: 180, y: 0, width: 180, height: 160))
        }
        guard let image = context.makeImage() else { throw SampleError.bitmapCreation }
        return image
    }

    private func legacyEncode(_ image: UIImage, config: WebPEncoderConfig) throws -> Data {
        guard let source = image.cgImage else { throw SampleError.bitmapCreation }
        if self != .retina {
            // Deliberately bypass normalization exactly as the old NSImage encoder did.
            return try WebPEncoder().encode(source, format: .rgba, config: config)
        }
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        let context = try makeContext(
            width: width, height: height,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let downsampled = context.makeImage() else { throw SampleError.bitmapCreation }
        return try WebPEncoder().encode(downsampled, format: .rgba, config: config)
    }

    private func roundTrip(_ data: Data) throws -> PixelComparison.Output {
        let info = try WebPImageInspector.inspect(data)
        let decoder = WebPDecoder()
        let straight = try decoder.decode(data, options: WebPDecoderOptions(), format: .rgba)
        // Explicit premultiplied output matches Core Graphics' bitmap declaration for display.
        let display = try decoder.decode(data, options: WebPDecoderOptions(), format: .rgbA)
        guard let provider = CGDataProvider(data: display as CFData),
              let image = CGImage(
                  width: info.width, height: info.height, bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: info.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                      | CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { throw SampleError.bitmapCreation }
        return PixelComparison.Output(image: image, firstPixel: Array(straight.prefix(4)))
    }

    private func makeContext(width: Int, height: Int, bitmapInfo: UInt32) throws -> CGContext {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo
        ) else { throw SampleError.bitmapCreation }
        return context
    }

    enum SampleError: Error {
        case bitmapCreation
    }
}

struct PixelComparison {
    struct Output {
        let image: CGImage
        let firstPixel: [UInt8]

        var pixelDescription: String {
            "RGBA: " + firstPixel.map(String.init).joined(separator: ", ")
        }
    }

    let original: CGImage
    let before: Output
    let after: Output
}
