import Foundation
import CWebP

struct WebPImageInspector {

    static func inspect(_ webPData: Data) throws -> WebPBitstreamFeatures {
        var cFeature = UnsafeMutablePointer<CWebP.WebPBitstreamFeatures>.allocate(capacity: 1)
        defer { cFeature.deallocate() }

        try webPData.withUnsafeBytes { rawPtr in
            guard let bindedBasePtr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPError.unexpectedPointerError
            }

            WebPGetFeatures(bindedBasePtr, webPData.count, cFeature)
        }

        guard let feature = WebPBitstreamFeatures(rawValue: cFeature.pointee) else {
            throw WebPError.unexpectedPointerError
        }

        return feature
    }
}
