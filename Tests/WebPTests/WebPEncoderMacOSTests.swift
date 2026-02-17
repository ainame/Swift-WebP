#if os(macOS)
import AppKit
import Foundation
@testable import WebP
import XCTest

class WebPEncoderMacOSTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() throws {
        guard let imageURL = Bundle.module.url(forResource: "jiro", withExtension: "jpg") else {
            XCTFail("Image couldn't be loaded from test resources")
            return
        }

        let nsImage = try XCTUnwrap(NSImage(contentsOf: imageURL))
        let encoder = WebPEncoder()
        let data = try encoder.encode(nsImage, config: .preset(.photo, quality: 10))
        XCTAssertTrue(data.count > 0)

        let decoder = WebPDecoder()
        var options = WebPDecoderOptions()
        options.scaledWidth = Int(nsImage.size.width)
        options.scaledHeight = Int(nsImage.size.height)
        options.useScaling = true
        let decodedImage = try decoder.decodeCGImage(from: data, options: options)
        XCTAssertEqual(decodedImage.width, options.scaledWidth)
        XCTAssertEqual(decodedImage.height, options.scaledHeight)
    }

    func testEncodeNSImagePreservesAlphaChannel() throws {
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
            XCTFail("Couldn't create CGContext")
            return
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0.3).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))

        guard let cgImage = context.makeImage() else {
            XCTFail("Couldn't create CGImage")
            return
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        let encoder = WebPEncoder()
        var config = WebPEncoderConfig.preset(.picture, quality: 100)
        config.lossless = 1
        let encoded = try encoder.encode(nsImage, config: config)

        let feature = try WebPImageInspector.inspect(encoded)
        XCTAssertTrue(feature.hasAlpha)
    }
}
#endif
