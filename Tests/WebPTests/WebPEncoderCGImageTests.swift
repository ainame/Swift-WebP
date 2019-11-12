import Foundation
import XCTest

#if canImport(CoreGraphics) && canImport(CoreImage)
import CoreGraphics
import CoreImage

@testable import WebP

class WebPEncoderCGImageTests: XCTestCase {
    func testRGBAImageFromCGImage() throws {
        let imagePath = ResourceAccessHelper.getExamplImagePath()

        guard FileManager.default.fileExists(atPath: imagePath) else {
            XCTFail("Image couldn't be found at \(imagePath)")
            return
        }

        let inputURL = URL(fileURLWithPath: imagePath)
        let cgSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil)
        let inputCGImage = CGImageSourceCreateImageAtIndex(cgSource!, 0, nil)
        let ciImage = CIImage(cgImage: inputCGImage!)
        let context = CIContext()
        let cgImage = context.createCGImage(
            ciImage,
            from: ciImage.extent,
            format: CIFormat.RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)!
        )!

        let encoder = WebPEncoder()
        let data = try encoder.encode(RGBA: cgImage, config: .preset(.photo, quality: 90))
        XCTAssertTrue(data.count > 0)

        let decoder = WebPDecoder()
        var options = WebPDecoderOptions()
        options.scaledWidth = Int(cgImage.width)
        options.scaledHeight = Int(cgImage.height)
        options.useScaling = true
        let decodedImage = try decoder.decode(data, options: options)
        XCTAssertEqual(decodedImage.width, options.scaledWidth)
        XCTAssertEqual(decodedImage.height, options.scaledHeight)
    }
}

#endif
