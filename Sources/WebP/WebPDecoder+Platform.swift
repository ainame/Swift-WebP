import Foundation
import libwebp

#if os(macOS) || os(iOS)
import CoreGraphics

public extension WebPDecoder {
    func decodeCGImage(from webPData: Data, options: WebPDecoderOptions) throws -> CGImage {
        let layout = try requiredOutputLayout(for: webPData, options: options, format: .rgba)

        let decodedData: CFData = try decode(webPData, options: options, format: .rgba) as CFData
        guard let provider = CGDataProvider(data: decodedData) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't initialize CGDataProvider")
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo
            .premultipliedLast.rawValue)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let renderingIntent = CGColorRenderingIntent.defaultIntent
        let bytesPerPixel = 4

        // The provider retains decodedData; nil decode means no caller-supplied decode table.
        if let cgImage = unsafe CGImage(
            width: layout.width,
            height: layout.height,
            bitsPerComponent: 8,
            bitsPerPixel: 8 * bytesPerPixel,
            bytesPerRow: layout.stride,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: renderingIntent
        ) {
            return cgImage
        }

        throw WebPError.unexpectedError(withMessage: "Couldn't initialize CGImage")
    }
}
#endif

#if os(iOS)
import UIKit

public extension WebPDecoder {
    func decodeUIImage(from webPData: Data, options: WebPDecoderOptions) throws -> UIImage {
        let cgImage: CGImage = try decodeCGImage(from: webPData, options: options)
        return UIImage(cgImage: cgImage)
    }
}
#endif

#if os(macOS)
import AppKit

public extension WebPDecoder {
    func decodeNSImage(from webPData: Data, options: WebPDecoderOptions) throws -> NSImage {
        let cgImage: CGImage = try decodeCGImage(from: webPData, options: options)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
#endif
