//
//  WebP.swift
//  WebP
//
//  Created by ainame on Oct 16, 2016.
//  Copyright © 2016 satoshi.namai. All rights reserved.
//

import Foundation
import CWebP

#if os(iOS) || os(macOS)
import CoreGraphics

private func webp_freeWebPData(info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> Void {
    if let info = info {
        var config = info.assumingMemoryBound(to: CWebP.WebPDecoderConfig.self).pointee
        WebPFreeDecBuffer(&config.output)
    }
    free(UnsafeMutableRawPointer(mutating: data))
}

// WebPSimple class is temporary implementation until v0.1"
@available(*, deprecated: 0.1)
public struct WebPSimple {

    public static func decode(_ webPData: Data) throws -> CGImage {
        var config: CWebP.WebPDecoderConfig = try webPData.withUnsafeBytes { (body: UnsafePointer<UInt8>) in
            var config = CWebP.WebPDecoderConfig()
            if WebPInitDecoderConfig(&config) == 0 {
                fatalError("can't init decoder config")
            }

            var features = CWebP.WebPBitstreamFeatures()
            if WebPGetFeatures(body, webPData.count, &features) != VP8_STATUS_OK {
                fatalError("broken header")
            }

            config.output.colorspace = MODE_RGBA

            if WebPDecode(body, webPData.count, &config) != VP8_STATUS_OK {
                fatalError("failure decode")
            }
            return config
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let provider = CGDataProvider(dataInfo: &config,
                                      data: config.output.u.RGBA.rgba,
                                      size: (Int(config.input.width) * Int(config.input.height) * 4),
                                      releaseData: webp_freeWebPData)!
        let cgImage = CGImage(
            width: Int(config.input.width),
            height: Int(config.input.height),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: Int(config.output.u.RGBA.stride),
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: CGColorRenderingIntent.defaultIntent)!

        return cgImage
    }
}

#endif
