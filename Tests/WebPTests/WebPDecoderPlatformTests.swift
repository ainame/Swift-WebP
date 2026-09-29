import Foundation
import Testing
import WebP

#if os(macOS) || os(iOS)
import CoreGraphics

struct WebPDecoderPlatformTests {
    @Test(arguments: [
        (0, 2, false, 3, 2), (2, 0, false, 2, 2),
        (0, 4, false, 6, 4), (4, 0, false, 4, 3),
        (0, 3, true, 6, 3), (3, 0, true, 3, 2),
        (0, 0, true, 4, 2),
    ])
    func platformImageUsesResolvedDimensions(
        scaledWidth: Int,
        scaledHeight: Int,
        crop: Bool,
        width: Int,
        height: Int,
    ) throws {
        let data = try TestFixtures.makeWebPFixture(width: 7, height: 5)
        var options = WebPDecoderOptions()
        options.useCropping = crop
        options.cropWidth = 4
        options.cropHeight = 2
        options.useScaling = scaledWidth != 0 || scaledHeight != 0
        options.scaledWidth = scaledWidth
        options.scaledHeight = scaledHeight
        let decoder = WebPDecoder()
        let image = try decoder.decodeCGImage(from: data, options: options)
        #expect(image.width == width)
        #expect(image.height == height)
        #expect(image.bytesPerRow == width * 4)
        let provider = try #require(image.dataProvider)
        let pixels = try #require(provider.data)
        let decoded = try decoder.decode(data, options: options, format: .rgbA)
        #expect(pixels as Data == decoded)
        #if os(macOS)
        let platformImage = try decoder.decodeNSImage(from: data, options: options)
        #expect(platformImage.size.width == CGFloat(width))
        #expect(platformImage.size.height == CGFloat(height))
        #elseif os(iOS)
        let platformImage = try decoder.decodeUIImage(from: data, options: options)
        #expect(platformImage.cgImage?.width == width)
        #expect(platformImage.cgImage?.height == height)
        #endif
    }

    @Test
    func cgImageDrawsSemiTransparentPixelsWithCorrectColor() throws {
        // Half-transparent red (255, 0, 0, 128) drawn over transparent black should be stored
        // as premultiplied (128, 0, 0, 128), not (255, 0, 0, 128).
        var config = WebPEncoderConfig.preset(.picture, quality: 100)
        config.lossless = 1
        let rgba: [UInt8] = [255, 0, 0, 128]
        let data = try WebPEncoder().encode(
            rgba,
            format: .rgba,
            config: config,
            originWidth: 1,
            originHeight: 1,
            stride: 4,
        )
        let image = try WebPDecoder().decodeCGImage(from: data, options: WebPDecoderOptions())

        var pixel = [UInt8](repeating: 0, count: 4)
        try pixel.withUnsafeMutableBytes { buffer in
            let context = try #require(
                unsafe CGContext(
                    data: buffer.baseAddress,
                    width: 1,
                    height: 1,
                    bitsPerComponent: 8,
                    bytesPerRow: 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue,
                )
            )
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        #expect(abs(Int(pixel[0]) - 128) <= 1)
        #expect(pixel[1] == 0)
        #expect(pixel[2] == 0)
        #expect(pixel[3] == 128)
    }

    @Test(arguments: [WebPAnimationPixelFormat.rgba, .bgra, .rgbA, .bgrA])
    func animationFrameCGImageDrawsCorrectColor(format: WebPAnimationPixelFormat) throws {
        // Half-transparent red drawn over transparent black should be (128, 0, 0, 128) in every format.
        let translucentRed: [UInt8] = [255, 0, 0, 128]
        let data = try AnimatedWebPFixture.make(
            width: 3,
            height: 2,
            frames: [
                .init(rgba: AnimatedWebPFixture.canvas(width: 3, height: 2, fill: translucentRed), durationMilliseconds: 50),
                .init(rgba: AnimatedWebPFixture.canvas(width: 3, height: 2, fill: [0, 0, 0, 0]), durationMilliseconds: 50),
            ],
        )
        let animation = try WebPDecoder().decodeAnimation(data, format: format)
        let image = try animation.frames[0].makeCGImage()
        #expect(image.width == 3)
        #expect(image.height == 2)

        var pixel = [UInt8](repeating: 0, count: 4)
        try pixel.withUnsafeMutableBytes { buffer in
            let context = try #require(
                unsafe CGContext(
                    data: buffer.baseAddress,
                    width: 1,
                    height: 1,
                    bitsPerComponent: 8,
                    bytesPerRow: 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue,
                )
            )
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        #expect(abs(Int(pixel[0]) - 128) <= 1)
        #expect(pixel[1] == 0)
        #expect(pixel[2] == 0)
        #expect(pixel[3] == 128)
    }
}
#endif
