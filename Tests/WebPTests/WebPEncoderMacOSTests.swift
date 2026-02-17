#if os(macOS)
import XCTest
import Foundation
import AppKit
@testable import WebP

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

        let nsImage = NSImage(contentsOf: imageURL)!
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
}
#endif
