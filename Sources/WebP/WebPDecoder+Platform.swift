#if os(macOS) || os(iOS)
import CoreGraphics
import Foundation

public extension WebPDecoder {
    func decodeCGImage(from webPData: Data, options: WebPDecoderOptions) throws -> CGImage {
        // Core Graphics draws premultiplied alpha natively, so decode with libwebp's premultiplied
        // MODE_rgbA to match the `.premultipliedLast` bitmap info below. Straight `.rgba` bytes
        // tagged as premultiplied would draw semi-transparent pixels too bright.
        let layout = try requiredOutputLayout(for: webPData, options: options, format: .rgbA)

        let decodedData = try decode(webPData, options: options, format: .rgbA)
        return try CGImage.makeWebPImage(
            pixels: decodedData,
            width: layout.width,
            height: layout.height,
            stride: layout.stride,
            bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
        )
    }
}

public extension WebPAnimationFrame {
    /// Wraps the frame's pixels in a `CGImage` without copying them. Every pixel format is supported;
    /// the default `.rgbA` matches Core Graphics' native layout.
    func makeCGImage() throws -> CGImage {
        let bitmapInfo: CGBitmapInfo =
            switch format {
            case .rgba: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.last.rawValue)
            case .rgbA: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
            // A little-endian A R G B word is stored as B G R A.
            case .bgra: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.first.rawValue)
            case .bgrA: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
            }
        return try CGImage.makeWebPImage(pixels: pixels, width: width, height: height, stride: stride, bitmapInfo: bitmapInfo)
    }
}

extension CGImage {
    /// Wraps decoded 32-bit pixels in a device-RGB image without copying them.
    static func makeWebPImage(pixels: Data, width: Int, height: Int, stride: Int, bitmapInfo: CGBitmapInfo) throws -> CGImage {
        guard let provider = CGDataProvider(data: pixels as CFData) else {
            throw WebPError.unexpectedError(withMessage: "Couldn't initialize CGDataProvider")
        }

        // The provider retains the pixels; nil decode means no caller-supplied decode table.
        if let cgImage = unsafe CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: stride,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent,
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
