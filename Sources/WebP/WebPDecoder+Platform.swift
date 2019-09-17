import Foundation
import CWebP

#if os(macOS) || os(iOS)
import CoreGraphics

extension WebPDecoder {

    public func decode(_ webPData: Data, options: WebPDecoderOptions) throws -> CGImage {

        let decodedData: Data = try decode(byrgbA: webPData, options: options)

        var cFeature = UnsafeMutablePointer<CWebP.WebPBitstreamFeatures>.allocate(capacity: 1)
        defer { cFeature.deallocate() }

        try webPData.withUnsafeBytes { rawPtr in
            guard let bindedBasePtr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPDecodingError.unknownError
            }

            WebPGetFeatures(bindedBasePtr, webPData.count, cFeature)
        }

        let feature = WebPBitstreamFeatures(rawValue: cFeature.pointee)
        let height: Int = options.useScaling ? options.scaledHeight : (feature?.height ?? 0)
        let width: Int = options.useScaling ? options.scaledWidth : (feature?.width ?? 0)

        return try decodedData.withUnsafeBytes { rawPtr in
            guard let bindedBasePtr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPDecodingError.unknownError
            }

            let provider = CGDataProvider(dataInfo: nil,
                                          data: bindedBasePtr,
                                          size: decodedData.count,
                                          releaseData: { (_, _, _) in  })!
            let bitmapInfo = CGBitmapInfo(
                rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            )
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let renderingIntent = CGColorRenderingIntent.defaultIntent
            let bytesPerPixel = 4
            
            return CGImage(width: width,
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
        }
    }
}
#endif
