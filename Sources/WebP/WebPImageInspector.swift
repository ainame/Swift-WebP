#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import libwebp

public enum WebPImageInspector {
    public static func inspect(_ webPData: Data) throws -> WebPBitstreamFeatures {
        unsafe try webPData.withUnsafeBytes { rawPtr in
            let span = unsafe Span<UInt8>(_unsafeBytes: rawPtr)
            return try inspect(span)
        }
    }

    public static func inspect(_ webPData: borrowing Span<UInt8>) throws -> WebPBitstreamFeatures {
        var cFeature = libwebp.WebPBitstreamFeatures()

        let status = try webPData.withWebPBytes { rawPtr -> VP8StatusCode in
            guard let bindedBasePtr = unsafe rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPError.unexpectedPointerError
            }
            return unsafe WebPGetFeatures(bindedBasePtr, webPData.count, &cFeature)
        }

        guard status == VP8_STATUS_OK else {
            throw WebPError.unexpectedError(withMessage: "Error VP8StatusCode=\(status.rawValue)")
        }

        return WebPBitstreamFeatures(rawValue: cFeature)
    }
}
