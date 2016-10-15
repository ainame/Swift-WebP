//
//  WebPTests.swift
//  WebPTests
//
//  Created by ainame on Jan 32, 2032.
//  Copyright © 2016 satoshi.namai. All rights reserved.
//

import XCTest
@testable import WebP

class WebPTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let image = #imageLiteral(resourceName: "jiro.jpg")
        let encoder = WebPEncoder()
        let webPImage = try! encoder.encode(image, config: WebPConfig.preset(.photo, quality: 10))
        XCTAssertNotNil(webPImage)
    }
    
}
