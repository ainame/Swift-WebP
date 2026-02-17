import Foundation
import libwebp

public enum WebPImageInspector {
    public static func inspect(_ webPData: Data) throws -> WebPBitstreamFeatures {
        try webPData.withUnsafeBytes { rawPtr in
            let span = Span<UInt8>(_unsafeBytes: rawPtr)
            return try inspect(span)
        }
    }

    static func inspect(_ webPData: borrowing Span<UInt8>) throws -> WebPBitstreamFeatures {
        let cFeature = UnsafeMutablePointer<libwebp.WebPBitstreamFeatures>.allocate(capacity: 1)
        defer { cFeature.deallocate() }

        let status = try webPData.withUnsafeBytes { rawPtr -> VP8StatusCode in
            guard let bindedBasePtr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPError.unexpectedPointerError
            }
            return WebPGetFeatures(bindedBasePtr, webPData.count, cFeature)
        }

        guard status == VP8_STATUS_OK else {
            throw WebPError.unexpectedError(withMessage: "Error VP8StatusCode=\(status.rawValue)")
        }

        guard let feature = WebPBitstreamFeatures(rawValue: cFeature.pointee) else {
            throw WebPError.unexpectedPointerError
        }

        return feature
    }
}
