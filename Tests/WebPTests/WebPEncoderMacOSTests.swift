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

    func testExample() {
        let path = Bundle(for: self.classForCoder).resourcePath!.appendingFormat("/jiro.jpg")
        let nsimage = NSImage(contentsOfFile: path)!
        let encoder = WebPEncoder()
        let webPImage = try! encoder.encode(nsimage, config: .preset(.photo, quality: 10))
        XCTAssertNotNil(webPImage)
    }
}
#endif
