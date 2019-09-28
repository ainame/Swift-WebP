//
//  WebPEncoderTests.swift
//  WebP
//
//  Created by Namai Satoshi on 2016/11/12.
//  Copyright © 2016年 satoshi.namai. All rights reserved.
//

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
        let imagePath = ResourceAccessHelper.getExamplImagePath()

        guard FileManager.default.fileExists(atPath: imagePath) else {
            XCTFail("Image couldn't be found at \(imagePath)")
            return
        }

        let nsImage = NSImage(contentsOfFile: imagePath)!
        let encoder = WebPEncoder()
        let data = try encoder.encode(nsImage, config: .preset(.photo, quality: 10))
        XCTAssertTrue(data.count > 0)

        let decoder = WebPDecoder()
        var options = WebPDecoderOptions()
        options.scaledWidth = Int(nsImage.size.width)
        options.scaledHeight = Int(nsImage.size.height)
        options.useScaling = true
        let decodedImage = try decoder.decode(data, options: options)
        XCTAssertEqual(decodedImage.width, options.scaledWidth)
        XCTAssertEqual(decodedImage.height, options.scaledHeight)
    }
}
#endif
