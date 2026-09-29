#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import libwebp

/// Builds animated WebP files with libwebp's WebPAnimEncoder, which Swift-WebP does not wrap yet.
enum AnimatedWebPFixture {
    struct Frame {
        /// Straight RGBA, `width * 4` bytes per row.
        var rgba: [UInt8]
        var durationMilliseconds: Int
    }

    struct EncodingError: Error {
        let message: String
    }

    static func make(
        width: Int,
        height: Int,
        frames: [Frame],
        loopCount: Int = 0,
        backgroundColor: UInt32 = 0xFFFF_FFFF,
        lossless: Bool = true,
    ) throws -> Data {
        var options = WebPAnimEncoderOptions()
        guard WebPAnimEncoderOptionsInit(&options) != 0 else { throw EncodingError(message: "options") }
        options.anim_params.loop_count = Int32(loopCount)
        options.anim_params.bgcolor = backgroundColor
        guard let encoder = WebPAnimEncoderNew(Int32(width), Int32(height), &options) else {
            throw EncodingError(message: "encoder")
        }
        defer { WebPAnimEncoderDelete(encoder) }

        var config = WebPConfig()
        guard WebPConfigInit(&config) != 0 else { throw EncodingError(message: "config") }
        config.lossless = lossless ? 1 : 0
        // Keep RGB under fully transparent pixels so decoded frames compare exactly.
        config.exact = 1

        var timestamp: Int32 = 0
        for frame in frames {
            var picture = WebPPicture()
            guard WebPPictureInit(&picture) != 0 else { throw EncodingError(message: "picture") }
            defer { WebPPictureFree(&picture) }
            picture.use_argb = 1
            picture.width = Int32(width)
            picture.height = Int32(height)
            let imported = frame.rgba.withUnsafeBufferPointer { pixels in
                WebPPictureImportRGBA(&picture, pixels.baseAddress, Int32(width * 4))
            }
            guard imported != 0, WebPAnimEncoderAdd(encoder, &picture, timestamp, &config) != 0 else {
                throw EncodingError(message: String(cString: WebPAnimEncoderGetError(encoder)))
            }
            timestamp += Int32(frame.durationMilliseconds)
        }
        guard WebPAnimEncoderAdd(encoder, nil, timestamp, nil) != 0 else {
            throw EncodingError(message: String(cString: WebPAnimEncoderGetError(encoder)))
        }

        var output = WebPData()
        WebPDataInit(&output)
        defer { WebPDataClear(&output) }
        guard WebPAnimEncoderAssemble(encoder, &output) != 0 else {
            throw EncodingError(message: String(cString: WebPAnimEncoderGetError(encoder)))
        }
        return Data(bytes: output.bytes, count: output.size)
    }

    /// A solid canvas with an optional rectangle of another color.
    static func canvas(
        width: Int,
        height: Int,
        fill: [UInt8],
        rect: (x: Int, y: Int, width: Int, height: Int)? = nil,
        rectColor: [UInt8] = [],
    ) -> [UInt8] {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let inRect = rect.map { x >= $0.x && x < $0.x + $0.width && y >= $0.y && y < $0.y + $0.height } ?? false
                let color = inRect ? rectColor : fill
                let base = (y * width + x) * 4
                rgba[base ..< base + 4] = color[0 ..< 4]
            }
        }
        return rgba
    }
}
