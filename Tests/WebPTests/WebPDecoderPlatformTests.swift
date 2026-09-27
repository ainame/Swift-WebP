import Foundation
import Testing
import WebP

#if os(macOS) || os(iOS)
import CoreGraphics

struct WebPDecoderPlatformTests {
    @Test(arguments: [(0, 2, false, 3, 2), (2, 0, false, 2, 2),
                      (0, 4, false, 6, 4), (4, 0, false, 4, 3),
                      (0, 3, true, 6, 3), (3, 0, true, 3, 2),
                      (0, 0, true, 4, 2)])
    func platformImageUsesResolvedDimensions(
        scaledWidth: Int, scaledHeight: Int, crop: Bool, width: Int, height: Int
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
        let decoded = try decoder.decode(data, options: options)
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
}
#endif
