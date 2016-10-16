//
//  WebP.swift
//  WebP
//
//  Created by ainame on Oct 16, 2016.
//  Copyright © 2016 satoshi.namai. All rights reserved.
//

import Foundation
import CWebP
import CoreGraphics

public class WebPSimple {
    public static func decode(_ webPData: Data) throws -> CGImage {
        var config: WebPDecoderConfig = try webPData.withUnsafeBytes { (body: UnsafePointer<UInt8>) in
            var config = WebPDecoderConfig()
            if WebPInitDecoderConfig(&config) == 0 {
                fatalError("can't init decoder config")
            }
            
            var features = WebPBitstreamFeatures()
            if WebPGetFeatures(body, webPData.count, &features) != VP8_STATUS_OK {
                throw WebPError.brokenHeaderError
            }
            
            config.output.colorspace = MODE_RGBA
            
            if WebPDecode(body, webPData.count, &config) != VP8_STATUS_OK {
                throw WebPError.decodeError
            }
            return config
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: config.output.u.RGBA.rgba,
                                width: Int(config.input.width),
                                height: Int(config.input.height),
                                bitsPerComponent: 8,
                                bytesPerRow: Int(config.output.u.RGBA.stride),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        WebPFreeDecBuffer(&config.output)
        return context.makeImage()!
    }
}
