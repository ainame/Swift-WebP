import Foundation
import CWebP

#if os(macOS) || os(iOS)
import CoreGraphics

extension WebPDecoder {

    public func decode(_ webPData: Data, options: WebPDecoderOptions) throws -> CGImage {

        let decodedData: Data = try decode(byrgbA: webPData, options: options)
        
        return decodedData.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> CGImage in
            let provider = CGDataProvider(dataInfo: nil,
                                          data: ptr,
                                          size: decodedData.count,
                                          releaseData: { (_, _, _) in  })!
            let bitmapInfo = CGBitmapInfo(
                rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            )
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let renderingIntent = CGColorRenderingIntent.defaultIntent
            let bytesPerPixel = 4
            
            return CGImage(width: options.scaledWidth,
                           height: options.scaledHeight,
                           bitsPerComponent: 8,
                           bitsPerPixel: 8 * bytesPerPixel,
                           bytesPerRow: bytesPerPixel * options.scaledWidth,
                           space: colorSpace,
                           bitmapInfo: bitmapInfo,
                           provider: provider,
                           decode: nil,
                           shouldInterpolate: false,
                           intent: renderingIntent)!
        }
    }
}
#endif
