//
//  WebPDecoder+Platform.swift
//  WebP
//
//  Created by Namai Satoshi on 2016/10/24.
//  Copyright © 2016年 satoshi.namai. All rights reserved.
//

import Foundation
import CWebP

#if os(macOS)
    import AppKit
    import CoreGraphics
    
    extension WebPDecoder {
        public func decode(_ image: NSImage, config: WebPDecoderConfig,
                           size: Int, width: Int, height: Int) -> Data {
            let webPData = image.tiffRepresentation!
            let bitmap = NSBitmapImageRep(data: webPData)!
            let status = decode(RGB: bitmap.bitmapData!, config: config, size: size, width: width, height: height)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(data: config.output.u.RGBA,
                                    width: Int(config.input.width),
                                    height: Int(config.input.height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: Int(config.output.u.RGBA.stride),
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            return context.makeImage()!
        }
    }
#endif

#if os(iOS)
    import UIKit
    import CoreGraphics
    
    extension WebPDecoder {
        public func decode(_ image: UIImage, size: Int, width: Int, height: Int) -> Data {
            return Data()
        }
    }
#endif
