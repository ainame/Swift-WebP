#if os(iOS)
import Foundation
import Testing
import UIKit
import WebP

struct WebPEncoderIOSTests {
    @Test
    func example() throws {
        let encoder = WebPEncoder()

        guard let path = Bundle.module.url(forResource: "jiro", withExtension: "jpg") else {
            throw WebPError.unexpectedError(withMessage: "Image couldn't be loaded from test resources")
        }
        guard let uiimage = UIImage(contentsOfFile: path.path) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't create UIImage from test file")
        }
        let data = try encoder.encode(uiimage, config: .preset(.photo, quality: 100))
        #expect(data.count > 0)

        let decoder = WebPDecoder()
        var options = WebPDecoderOptions()
        options.useScaling = true
        options.scaledWidth = Int(uiimage.size.width)
        options.scaledHeight = Int(uiimage.size.height)
        let decodedImage = try decoder.decodeCGImage(from: data, options: options)
        #expect(decodedImage.width == options.scaledWidth)
        #expect(decodedImage.height == options.scaledHeight)
    }

    @Test(arguments: [false, true])
    func platformEncodingPreservesPixelDimensionsAndTranslucentColors(bgra: Bool) throws {
        let bitmapInfo = (bgra ? CGBitmapInfo.byteOrder32Little : .byteOrder32Big).rawValue
            | (bgra ? CGImageAlphaInfo.premultipliedFirst : .premultipliedLast).rawValue
        let context = try #require(CGContext(
            data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 16,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo
        ))
        try context.setFillColor(#require(CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [1, 0, 0, 0.5]
        )))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 2))
        let cgImage = try #require(context.makeImage())
        let image = UIImage(cgImage: cgImage, scale: 2, orientation: .up)
        var config = WebPEncoderConfig.preset(.picture, quality: 100)
        config.lossless = 1
        let encoded = try WebPEncoder().encode(image, config: config)
        let info = try WebPImageInspector.inspect(encoded)
        #expect(info.width == 4)
        #expect(info.height == 2)
        let pixels = try WebPDecoder().decode(encoded, options: WebPDecoderOptions(), format: .rgba)
        #expect(pixels[0] == 255)
        #expect(pixels[1] == 0)
        #expect(pixels[2] == 0)
        #expect(abs(Int(pixels[3]) - 128) <= 1)
        let resized = try WebPEncoder().encode(image, config: config, width: 2, height: 1)
        let resizedInfo = try WebPImageInspector.inspect(resized)
        #expect(resizedInfo.width == 2)
        #expect(resizedInfo.height == 1)
    }
}
#endif
