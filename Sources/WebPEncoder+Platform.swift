//
//  WebPEncoder+Platform.swift
//  WebP
//
//  Created by Namai Satoshi on 2016/10/23.
//  Copyright © 2016年 satoshi.namai. All rights reserved.
//

import Foundation
import CoreGraphics

#if os(macOS)
    import AppKit
    extension WebPEncoder {
        public func encode(_ image: NSImage, config: WebPConfig, width: Int = 0, height: Int = 0) throws -> Data {
            let data = image.tiffRepresentation!
            let stride = Int(image.size.width) * MemoryLayout<UInt8>.size * 3 // RGB = 3byte
            let bitmap = NSBitmapImageRep(data: data)!
            let webPData = try encode(RGB: bitmap.bitmapData!, config: config,
                                      originWidth: Int(image.size.width), originHeight: Int(image.size.height), stride: stride,
                                      resizeWidth: width, resizeHeight: height)
            return webPData
        }
    }
#endif

#if os(iOS)
    import UIKit

    extension WebPEncoder {
        public func encode(_ image: UIImage, config: WebPConfig, width: Int = 0, height: Int = 0) throws -> Data {
            let cgImage = image.cgImage!
            let stride = cgImage.bytesPerRow
            let dataPtr = CFDataGetMutableBytePtr(cgImage.dataProvider!.data as! CFMutableData)!
            let webPData = try encode(RGBA: dataPtr, config: config,
                                      originWidth: Int(image.size.width), originHeight: Int(image.size.height), stride: stride,
                                      resizeWidth: width, resizeHeight: height)
            return webPData
        }
    }

#endif
