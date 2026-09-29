import Foundation
import Testing

#if canImport(CoreGraphics) && canImport(CoreImage)
import CoreGraphics
import CoreImage
@testable import WebP

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
        // swift-format-ignore
        guard let cgImage = context.createCGImage(
            ciImage,
            from: ciImage.extent,
            format: CIFormat.RGBA8,
            colorSpace: colorSpace,
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

    @Test(arguments: [false, true])
    func normalizingEncodeHandlesPremultipliedLayouts(bgra: Bool) throws {
        // Raw bytes in either layout would swap or darken colors; encode(normalizing:) redraws them.
        let bitmapInfo =
            (bgra ? CGBitmapInfo.byteOrder32Little : .byteOrder32Big).rawValue
            | (bgra ? CGImageAlphaInfo.premultipliedFirst : .premultipliedLast).rawValue
        let context = try #require(
            CGContext(
                data: nil,
                width: 4,
                height: 2,
                bitsPerComponent: 8,
                bytesPerRow: 16,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo,
            )
        )
        let translucentRed = try #require(
            CGColor(
                colorSpace: CGColorSpaceCreateDeviceRGB(),
                components: [1, 0, 0, 0.5],
            )
        )
        context.setFillColor(translucentRed)
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 2))
        let cgImage = try #require(context.makeImage())
        var config = WebPEncoderConfig.preset(.picture, quality: 100)
        config.lossless = 1

        let encoded = try WebPEncoder().encode(normalizing: cgImage, config: config)
        let pixels = try WebPDecoder().decode(encoded, options: WebPDecoderOptions(), format: .rgba)
        #expect(pixels[0] == 255)
        #expect(pixels[1] == 0)
        #expect(pixels[2] == 0)
        #expect(abs(Int(pixels[3]) - 128) <= 1)
        #expect(cgImage.webPStraightPixelFormat == nil)
    }

    /// Caller-declared layouts: (format, bytes per pixel, bitmap info, one straight-alpha red pixel).
    static let directLayouts: [(WebPEncodePixelFormat, Int, UInt32, [UInt8])] = [
        (.rgba, 4, CGImageAlphaInfo.last.rawValue, [255, 0, 0, 128]),
        (.rgbx, 4, CGImageAlphaInfo.noneSkipLast.rawValue, [255, 0, 0, 0]),
        (.bgra, 4, CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.first.rawValue, [0, 0, 255, 128]),
        (.bgrx, 4, CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue, [0, 0, 255, 0]),
        (.rgb, 3, CGImageAlphaInfo.none.rawValue, [255, 0, 0]),
    ]

    @Test(arguments: 0 ..< directLayouts.count)
    func explicitFormatEncodesBackingBytesAsIs(index: Int) throws {
        let (format, bytesPerPixel, bitmapInfo, pixel) = Self.directLayouts[index]
        let width = 4, height = 2
        // Pad each row to also exercise a stride wider than the pixels.
        let bytesPerRow = width * bytesPerPixel + 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                bytes.replaceSubrange(offset ..< offset + bytesPerPixel, with: pixel)
            }
        }
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        let cgImage = try #require(
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: bytesPerPixel * 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent,
            )
        )
        #expect(cgImage.webPStraightPixelFormat == format)

        var config = WebPEncoderConfig.preset(.picture, quality: 100)
        config.lossless = 1
        let encoded = try WebPEncoder().encode(cgImage, format: format, config: config)
        let decoded = try WebPDecoder().decode(encoded, options: WebPDecoderOptions(), format: .rgba)
        let hasAlpha = format == .rgba || format == .bgra
        #expect(Array(decoded.prefix(4)) == [255, 0, 0, hasAlpha ? 128 : 255])
    }

    @Test
    func decodedJPEGBytesMatchNormalizedPixels() throws {
        // Skipping webPStraightRGBA() for a direct layout must not change colors.
        guard let inputURL = Bundle.module.url(forResource: "jiro", withExtension: "jpg"),
            let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil)
        else {
            throw WebPError.unexpectedError(withMessage: "Image couldn't be loaded from test resources")
        }
        let cgImage = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(cgImage.webPStraightPixelFormat == .rgbx)

        let normalized = try cgImage.webPStraightRGBA()
        let data = try [UInt8](#require(cgImage.dataProvider?.data) as Data)
        var mismatches = 0
        for y in 0 ..< cgImage.height {
            for x in 0 ..< cgImage.width {
                let direct = y * cgImage.bytesPerRow + x * 4
                let converted = (y * cgImage.width + x) * 4
                if Array(data[direct ..< direct + 3]) != Array(normalized[converted ..< converted + 3]) {
                    mismatches += 1
                }
            }
        }
        #expect(mismatches == 0)
    }

    @Test
    func normalizingEncodeHandlesSixteenBitImages() throws {
        let context = try #require(
            CGContext(
                data: nil,
                width: 2,
                height: 2,
                bitsPerComponent: 16,
                bytesPerRow: 16,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder16Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue,
            )
        )
        try context.setFillColor(
            #require(
                CGColor(
                    colorSpace: CGColorSpaceCreateDeviceRGB(),
                    components: [1, 0, 0, 1],
                )
            )
        )
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        let cgImage = try #require(context.makeImage())
        #expect(cgImage.webPStraightPixelFormat == nil)
        var config = WebPEncoderConfig.preset(.picture, quality: 100)
        config.lossless = 1
        let encoded = try WebPEncoder().encode(normalizing: cgImage, config: config)
        let decoded = try WebPDecoder().decode(encoded, options: WebPDecoderOptions(), format: .rgba)
        #expect(Array(decoded.prefix(4)) == [255, 0, 0, 255])
    }
}

#endif
