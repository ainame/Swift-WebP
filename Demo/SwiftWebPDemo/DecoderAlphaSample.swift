import CoreGraphics
import Foundation
import UIKit
import WebP

/// Round-trips a translucent overlay through WebP and decodes it with the old and current platform decoders.
/// The legacy path intentionally preserves the bug so the Demo can show a real before/after comparison.
enum DecoderAlphaSample {
    static let size = CGSize(width: 400, height: 300)
    /// The panel lets 70% of the photo show through.
    static let panelOpacity: CGFloat = 0.3

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
        // The platform encoder converts the renderer's premultiplied pixels to straight alpha.
        let webPData = try WebPEncoder().encode(makeOverlay(), config: config)
        let options = WebPDecoderOptions()
        // This calls the actual platform API, rather than a copy of its implementation.
        guard let after = try WebPDecoder().decodeUIImage(from: webPData, options: options).cgImage else {
            throw SampleError.imageCreation
        }
        return try DecoderAlphaComparison(before: legacyDecodeCGImage(webPData, options: options), after: after)
    }

    /// A translucent white panel, labeled with opaque black text.
    private static func makeOverlay() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let panel = CGRect(origin: .zero, size: size).insetBy(dx: 40, dy: 60)
            UIColor.white.withAlphaComponent(panelOpacity).setFill()
            UIBezierPath(roundedRect: panel, cornerRadius: 24).fill()

            let label = "Frosted glass"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            let textSize = label.size(withAttributes: attributes)
            label.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
    }

    /// Reproduces `decodeCGImage` from 0.3.0 through 0.7.0.
    private static func legacyDecodeCGImage(_ webPData: Data, options: WebPDecoderOptions) throws -> CGImage {
        let info = try WebPImageInspector.inspect(webPData)
        let decoded = try WebPDecoder().decode(webPData, options: options, format: .rgba)
        guard let provider = CGDataProvider(data: decoded as CFData),
              let image = CGImage(
                  width: info.width, height: info.height, bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: info.width * 4, space: CGColorSpaceCreateDeviceRGB(),
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
