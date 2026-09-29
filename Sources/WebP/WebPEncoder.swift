#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import libwebp

/// This is customised error that describes the pattern of error causes.
/// However, the error is unlikely to happen normally but it's still better to handle with throw-catch than fatal error.
public enum WebPEncoderError: Error, Sendable {
    case invalidParameter
    case versionMismatched
}

/// This is the mapped error codes that CWebP.WebPEncode returns
public enum WebPEncodeStatusCode: Int, Error, Sendable {
    case ok = 0
    case outOfMemory // memory error allocating objects
    case bitstreamOutOfMemory // memory error while flushing bits
    case nullParameter // a pointer parameter is NULL
    case invalidConfiguration // configuration is invalid
    case badDimension // picture has invalid width/height
    case partition0Overflow // partition is bigger than 512k
    case partitionOverflow // partition is bigger than 16M
    case badWrite // error while flushing bytes
    case fileTooBig // file is bigger than 4G
    case userAbort // abort request by user
    case last // list terminator. always last.

    init(libwebpRawValue: Int) {
        guard let status = WebPEncodeStatusCode(rawValue: libwebpRawValue) else {
            preconditionFailure("Unexpected WebP encode status code: \(libwebpRawValue)")
        }
        self = status
    }
}

public enum WebPEncodePixelFormat: Sendable {
    case rgb
    case rgba
    case rgbx
    case bgr
    case bgra
    case bgrx
}

public struct WebPEncoder: Sendable {
    public init() {}

    /// Requires live, initialized pixel storage for the entire call with at least
    /// `stride * originHeight` bytes, including padding after the final row.
    @unsafe
    public func encode(
        _ data: UnsafeBufferPointer<UInt8>,
        format: WebPEncodePixelFormat,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0,
    ) throws -> Data {
        guard unsafe data.baseAddress != nil else {
            throw WebPError.unexpectedPointerError
        }
        return unsafe try encode(
            Span(_unsafeElements: data),
            format: format,
            config: config,
            originWidth: originWidth,
            originHeight: originHeight,
            stride: stride,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
        )
    }

    /// Borrows pixels without copying their storage. Validates the complete row layout before calling C.
    /// Requires at least `stride * originHeight` bytes, including padding after the final row.
    public func encode(
        _ data: borrowing Span<UInt8>,
        format: WebPEncodePixelFormat,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0,
    ) throws -> Data {
        let (rowBytes, rowOverflow) = originWidth.multipliedReportingOverflow(by: format.bytesPerPixel)
        let (required, sizeOverflow) = stride.multipliedReportingOverflow(by: originHeight)
        guard originWidth > 0, originHeight > 0,
            originWidth <= Int(WEBP_MAX_DIMENSION), originHeight <= Int(WEBP_MAX_DIMENSION),
            !rowOverflow, !sizeOverflow, stride >= rowBytes, Int32(exactly: stride) != nil,
            data.count >= required
        else { throw WebPEncoderError.invalidParameter }
        return try data.withWebPPixels { buffer in
            unsafe try encode(
                buffer.baseAddress!,
                format: format,
                config: config,
                originWidth: originWidth,
                originHeight: originHeight,
                stride: stride,
                resizeWidth: resizeWidth,
                resizeHeight: resizeHeight,
            )
        }
    }

    /// Convenience entry point requiring no unsafe operations at the call site.
    public func encode(
        _ data: [UInt8],
        format: WebPEncodePixelFormat,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0,
    ) throws -> Data {
        try data.withWebPPixels { buffer in
            unsafe try encode(
                Span(_unsafeElements: buffer),
                format: format,
                config: config,
                originWidth: originWidth,
                originHeight: originHeight,
                stride: stride,
                resizeWidth: resizeWidth,
                resizeHeight: resizeHeight,
            )
        }
    }

    /// Encodes contiguous Foundation storage without constructing an intermediate pixel array.
    public func encode(
        _ data: Data,
        format: WebPEncodePixelFormat,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0,
    ) throws -> Data {
        unsafe try data.withUnsafeBytes { bytes in
            unsafe try encode(
                Span<UInt8>(_unsafeBytes: bytes),
                format: format,
                config: config,
                originWidth: originWidth,
                originHeight: originHeight,
                stride: stride,
                resizeWidth: resizeWidth,
                resizeHeight: resizeHeight,
            )
        }
    }

    /// Caller must provide live, initialized storage for the full strided image throughout this call.
    @available(
        *,
        deprecated,
        message:
            "Use encode(_: UnsafeBufferPointer<UInt8>, format:config:originWidth:originHeight:stride:resizeWidth:resizeHeight:) unless low-level interop requires mutable pointers."
    )
    @unsafe
    public func encode(
        _ dataPtr: UnsafeMutablePointer<UInt8>,
        format: WebPEncodePixelFormat,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0,
    ) throws -> Data {
        return unsafe try encode(
            UnsafePointer(dataPtr),
            format: format,
            config: config,
            originWidth: originWidth,
            originHeight: originHeight,
            stride: stride,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
        )
    }

    private func encode(
        _ dataPtr: UnsafePointer<UInt8>,
        format: WebPEncodePixelFormat,
        config: WebPEncoderConfig,
        originWidth: Int,
        originHeight: Int,
        stride: Int,
        resizeWidth: Int = 0,
        resizeHeight: Int = 0,
    ) throws -> Data {
        let (rowBytes, rowOverflow) = originWidth.multipliedReportingOverflow(by: format.bytesPerPixel)
        guard originWidth > 0, originHeight > 0,
            originWidth <= Int(WEBP_MAX_DIMENSION), originHeight <= Int(WEBP_MAX_DIMENSION),
            !rowOverflow, stride >= rowBytes, Int32(exactly: stride) != nil,
            resizeWidth >= 0, resizeHeight >= 0,
            resizeWidth <= Int(WEBP_MAX_DIMENSION), resizeHeight <= Int(WEBP_MAX_DIMENSION)
        else { throw WebPEncoderError.invalidParameter }
        var config = config.rawValue
        if unsafe WebPValidateConfig(&config) == 0 {
            throw WebPEncoderError.invalidParameter
        }

        var picture = try WebPPictureOwner(width: originWidth, height: originHeight, useARGB: config.lossless != 0)
        unsafe try picture.importPixels(dataPtr, format: format, stride: stride)
        if resizeHeight > 0, resizeWidth > 0 {
            try picture.rescale(width: resizeWidth, height: resizeHeight)
        }
        return try picture.encode(config: config)
    }
}
