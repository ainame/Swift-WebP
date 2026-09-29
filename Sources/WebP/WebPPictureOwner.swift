#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import libwebp

/// Owns a `WebPPicture` and the pixel memory libwebp allocates for it.
/// Safety invariant: this is the sole owner; the picture is freed exactly once, in `deinit`.
@safe
struct WebPPictureOwner: ~Copyable {
    private var rawValue = unsafe WebPPicture()

    /// `useARGB` selects libwebp's ARGB storage, which lossless and animation encoding require.
    init(width: Int, height: Int, useARGB: Bool) throws {
        if unsafe WebPPictureInit(&rawValue) == 0 {
            throw WebPEncoderError.invalidParameter
        }
        unsafe rawValue.use_argb = useARGB ? 1 : 0
        unsafe rawValue.width = Int32(width)
        unsafe rawValue.height = Int32(height)
    }

    deinit {
        var picture = unsafe rawValue
        unsafe WebPPictureFree(&picture)
    }

    /// Copies pixels into libwebp-owned memory synchronously; the source pointer is not retained.
    /// Requires `pixels` to hold `stride * height` readable bytes for the call's duration.
    @unsafe
    mutating func importPixels(_ pixels: UnsafePointer<UInt8>, format: WebPEncodePixelFormat, stride: Int) throws {
        let imported: Int32
        switch format {
        case .rgb: imported = unsafe WebPPictureImportRGB(&rawValue, pixels, Int32(stride))
        case .rgba: imported = unsafe WebPPictureImportRGBA(&rawValue, pixels, Int32(stride))
        case .rgbx: imported = unsafe WebPPictureImportRGBX(&rawValue, pixels, Int32(stride))
        case .bgr: imported = unsafe WebPPictureImportBGR(&rawValue, pixels, Int32(stride))
        case .bgra: imported = unsafe WebPPictureImportBGRA(&rawValue, pixels, Int32(stride))
        case .bgrx: imported = unsafe WebPPictureImportBGRX(&rawValue, pixels, Int32(stride))
        }
        if imported == 0 {
            throw WebPEncoderError.versionMismatched
        }
    }

    mutating func rescale(width: Int, height: Int) throws {
        if unsafe WebPPictureRescale(&rawValue, Int32(width), Int32(height)) == 0 {
            throw WebPEncodeStatusCode.outOfMemory
        }
    }

    /// Encodes the picture as a still image. `config` must already be validated.
    mutating func encode(config: libwebp.WebPConfig) throws -> Data {
        var config = config
        var writer = WebPMemoryWriterOwner()
        let writeWebP: @convention(c) (UnsafePointer<UInt8>?, Int, UnsafePointer<WebPPicture>?) -> Int32 = { data, size, picture -> Int32 in
            return unsafe WebPMemoryWrite(data, size, picture)
        }
        unsafe rawValue.writer = writeWebP

        unsafe try withUnsafeMutablePointer(to: &writer.rawValue) { ptr in
            // custom_ptr is only read by WebPMemoryWrite during WebPEncode; clear it before the writer can move.
            unsafe rawValue.custom_ptr = UnsafeMutableRawPointer(ptr)
            defer { unsafe rawValue.custom_ptr = nil }

            if unsafe WebPEncode(&config, &rawValue) == 0 {
                throw unsafe WebPEncodeStatusCode(libwebpRawValue: Int(rawValue.error_code.rawValue))
            }
        }

        return writer.takeData()
    }
}

extension WebPEncodePixelFormat {
    var bytesPerPixel: Int {
        switch self {
        case .rgb, .bgr: 3
        case .rgba, .rgbx, .bgra, .bgrx: 4
        }
    }
}
