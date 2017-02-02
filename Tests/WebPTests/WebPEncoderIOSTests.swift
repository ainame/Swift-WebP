//
//  WebPEncoderiOSTests.swift
//  WebP
//
//  Created by Namai Satoshi on 2016/11/12.
//  Copyright © 2016年 satoshi.namai. All rights reserved.
//

import XCTest
import Foundation
import UIKit
@testable import WebP

class WebPEncoderIOSTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testExample() {
        let encoder = WebPEncoder()

        let path = Bundle(for: self.classForCoder).bundlePath.appendingFormat("/jiro.jpg")
        let uiimage = UIImage(contentsOfFile: path)!
        let data = try? encoder.encode(uiimage, config: .preset(.photo, quality: 100))
        XCTAssert(data != nil)
    }

}
