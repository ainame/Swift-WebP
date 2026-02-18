import Foundation
import Testing

#if canImport(CoreGraphics) && canImport(CoreImage)
import CoreGraphics
import CoreImage
import WebP

struct WebPEncoderCGImageTests {
    @Test
    func rgbaImageFromCGImage() throws {
        guard let inputURL = Bundle.module.url(forResource: "jiro", withExtension: "jpg") else {
            throw WebPError.unexpectedError(withMessage: "Image couldn't be loaded from test resources")
        }

        let cgSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil)
        guard let cgSource else {
            throw WebPError.unexpectedError(withMessage: "Couldn't create CGImageSource")
        }
        guard let inputCGImage = CGImageSourceCreateImageAtIndex(cgSource, 0, nil) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't decode test image")
        }
        let ciImage = CIImage(cgImage: inputCGImage)
        let context = CIContext()
        guard let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't initialize color space")
        }
        guard let cgImage = context.createCGImage(
            ciImage,
            from: ciImage.extent,
            format: CIFormat.RGBA8,
            colorSpace: colorSpace
        ) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't create CGImage")
        }

        let encoder = WebPEncoder()
        let data = try encoder.encode(cgImage, format: .rgba, config: .preset(.photo, quality: 90))
        #expect(data.count > 0)

        let decoder = WebPDecoder()
        var options = WebPDecoderOptions()
        options.scaledWidth = Int(cgImage.width)
        options.scaledHeight = Int(cgImage.height)
        options.useScaling = true
        let decodedImage = try decoder.decodeCGImage(from: data, options: options)
        #expect(decodedImage.width == options.scaledWidth)
        #expect(decodedImage.height == options.scaledHeight)
    }
}

#endif
