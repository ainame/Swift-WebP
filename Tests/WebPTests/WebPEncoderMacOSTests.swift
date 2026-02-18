#if os(macOS)
import AppKit
import Foundation
import Testing
import WebP

struct WebPEncoderMacOSTests {
    @Test
    func example() throws {
        guard let imageURL = Bundle.module.url(forResource: "jiro", withExtension: "jpg") else {
            throw WebPError.unexpectedError(withMessage: "Image couldn't be loaded from test resources")
        }

        guard let nsImage = NSImage(contentsOf: imageURL) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't load NSImage")
        }
        let encoder = WebPEncoder()
        let data = try encoder.encode(nsImage, config: .preset(.photo, quality: 10))
        #expect(data.count > 0)

        let decoder = WebPDecoder()
        var options = WebPDecoderOptions()
        options.scaledWidth = Int(nsImage.size.width)
        options.scaledHeight = Int(nsImage.size.height)
        options.useScaling = true
        let decodedImage = try decoder.decodeCGImage(from: data, options: options)
        #expect(decodedImage.width == options.scaledWidth)
        #expect(decodedImage.height == options.scaledHeight)
    }

    @Test
    func encodeNSImagePreservesAlphaChannel() throws {
        let width = 2
        let height = 2
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't create CGContext")
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0.3).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))

        guard let cgImage = context.makeImage() else {
            throw WebPError.unexpectedError(withMessage: "Couldn't create CGImage")
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        let encoder = WebPEncoder()
        var config = WebPEncoderConfig.preset(.picture, quality: 100)
        config.lossless = 1
        let encoded = try encoder.encode(nsImage, config: config)

        let feature = try WebPImageInspector.inspect(encoded)
        #expect(feature.hasAlpha)
    }
}
#endif
