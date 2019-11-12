import Foundation
import CWebP

#if os(macOS) || os(iOS)
import CoreGraphics

extension WebPDecoder {
    public func decode(_ webPData: Data, options: WebPDecoderOptions) throws -> CGImage {
        let feature = try WebPImageInspector.inspect(webPData)
        let height: Int = options.useScaling ? options.scaledHeight : feature.height
        let width: Int = options.useScaling ? options.scaledWidth : feature.width

        let decodedData: CFData = try decode(byrgbA: webPData, options: options) as CFData
        let provider = CGDataProvider(data: decodedData)!

        let bitmapInfo = CGBitmapInfo(
            rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        )
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let renderingIntent = CGColorRenderingIntent.defaultIntent
        let bytesPerPixel = 4

        let cgImage = CGImage(width: width,
                              height: height,
                              bitsPerComponent: 8,
                              bitsPerPixel: 8 * bytesPerPixel,
                              bytesPerRow: bytesPerPixel * width,
                              space: colorSpace,
                              bitmapInfo: bitmapInfo,
                              provider: provider,
                              decode: nil,
                              shouldInterpolate: false,
                              intent: renderingIntent)!
        return cgImage
    }
}
#endif

#if os(iOS)
import UIKit

extension WebPDecoder {
    public func decode(toUImage webPData: Data, options: WebPDecoderOptions) throws -> UIImage {
        let cgImage: CGImage = try decode(webPData, options: options)
        return UIImage(cgImage: cgImage)
    }
}
#endif

#if os(macOS)
import AppKit

extension WebPDecoder {
    public func decode(toNSImage webPData: Data, options: WebPDecoderOptions) throws -> NSImage {
        let cgImage: CGImage = try decode(webPData, options: options)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
#endif
