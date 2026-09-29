#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import libwebp

/// There's no definition of WebPDecodingError in libwebp.
/// We map VP8StatusCode enum as WebPDecodingError instead.
public enum WebPDecodingError: UInt32, Error, Sendable {
    case ok = 0 // shouldn't be used as this is the succseed case
    case outOfMemory
    case invalidParam
    case bitstreamError
    case unsupportedFeature
    case suspended
    case userAbort
    case notEnoughData
    case unknownError = 9999 // This is an own error to deal with internal problems

    init(vp8StatusCodeRawValue: UInt32) {
        self = WebPDecodingError(rawValue: vp8StatusCodeRawValue) ?? .unknownError
    }
}

public enum WebPDecodePixelFormat: Sendable {
    case rgb
    case rgba
    case bgr
    case bgra
    case argb
    case rgba4444
    case rgb565
    case rgbA
    case bgrA
    case Argb
    case rgbA4444
    case yuv
    case yuva

    var colorspace: ColorspaceMode {
        switch self {
        case .rgb:
            .RGB
        case .rgba:
            .RGBA
        case .bgr:
            .BGR
        case .bgra:
            .BGRA
        case .argb:
            .ARGB
        case .rgba4444:
            .RGBA4444
        case .rgb565:
            .RGB565
        case .rgbA:
            .rgbA
        case .bgrA:
            .bgrA
        case .Argb:
            .Argb
        case .rgbA4444:
            .rgbA4444
        case .yuv:
            .YUV
        case .yuva:
            .YUVA
        }
    }
}

public struct WebPDecoder: Sendable {
    public init() {}

    public func requiredOutputByteCount(
        for webPData: Data,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba,
    ) throws -> Int {
        try requiredOutputLayout(for: webPData, options: options, format: format).byteCount
    }

    /// Caller must keep the output allocation alive and exclusively writable throughout the call.
    @available(
        *,
        deprecated,
        message: "Use decode(_:into: inout [UInt8], options:format:) unless low-level interop requires UnsafeMutableBufferPointer."
    )
    @unsafe
    public func decode(
        _ webPData: Data,
        into output: UnsafeMutableBufferPointer<UInt8>,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba,
    ) throws -> Int {
        unsafe try decodeIntoBuffer(webPData, output: output, options: options, format: format)
    }

    private func decodeIntoBuffer(
        _ webPData: Data,
        output: UnsafeMutableBufferPointer<UInt8>,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat,
        layout resolvedLayout: OutputLayout? = nil,
    ) throws -> Int {
        guard format.colorspace.isRGBMode else {
            throw WebPError.unsupportedDecodeFormat
        }
        let layout = try resolvedLayout ?? requiredOutputLayout(for: webPData, options: options, format: format)
        guard output.count >= layout.byteCount else {
            throw WebPError.outputBufferTooSmall(required: layout.byteCount, actual: output.count)
        }
        guard let base = output.baseAddress else {
            throw WebPError.outputBufferTooSmall(required: layout.byteCount, actual: output.count)
        }

        var config = unsafe try makeConfig(options, format.colorspace)
        unsafe config.output.externalMemoryMode = .externalMemory
        unsafe config.output.width = layout.width
        unsafe config.output.height = layout.height
        // External output stays borrowed for this synchronous C call; the layout check bounds every write.
        let rgbaBuffer = unsafe WebPRGBABuffer(
            rgba: base,
            stride: Int32(layout.stride),
            size: layout.byteCount,
        )
        unsafe config.output.u = .RGBA(rgbaBuffer)
        unsafe try webPData.withUnsafeBytes { rawPtr in
            let span = unsafe Span<UInt8>(_unsafeBytes: rawPtr)
            unsafe try decode(span, config: &config)
        }
        return layout.byteCount
    }

    /// Mutates exclusively borrowed, initialized output storage without allocating a new image buffer.
    public func decode(
        _ webPData: Data,
        into output: inout MutableSpan<UInt8>,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba,
    ) throws -> Int {
        try withWebPMutablePixels(&output) { buffer in
            unsafe try decodeIntoBuffer(webPData, output: buffer, options: options, format: format)
        }
    }

    public func decode(
        _ webPData: Data,
        into output: inout [UInt8],
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba,
    ) throws -> Int {
        try output.withWebPMutablePixels { buffer in
            unsafe try decodeIntoBuffer(webPData, output: buffer, options: options, format: format)
        }
    }

    public func decode(
        _ webPData: Data,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba,
    ) throws -> Data {
        guard format.colorspace.isRGBMode else {
            throw WebPError.unsupportedDecodeFormat
        }
        let layout = try requiredOutputLayout(for: webPData, options: options, format: format)
        let storage = WebPByteStorage(byteCount: layout.byteCount)
        // UInt8 has no destructor. C may initialize only part of this allocation on failure;
        // the owner can free it without exposing or reading those bytes.
        unsafe _ = try decodeIntoBuffer(
            webPData,
            output: storage.buffer,
            options: options,
            format: format,
            layout: layout,
        )
        // Only a successful full decode can publish the initialized bytes as Data.
        return unsafe storage.takeData()
    }

    private func decode(_ webPData: borrowing Span<UInt8>, config: inout WebPDecoderConfig) throws {
        var rawConfig: libwebp.WebPDecoderConfig = unsafe config.rawValue

        try webPData.withWebPBytes { rawPtr in
            guard let bindedBasePtr = unsafe rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPDecodingError.unknownError
            }

            let status = unsafe WebPDecode(bindedBasePtr, webPData.count, &rawConfig)
            if status != VP8_STATUS_OK {
                throw WebPDecodingError(vp8StatusCodeRawValue: status.rawValue)
            }
        }

        switch unsafe config.output.u {
        case .RGBA:
            unsafe config.output.u = WebPDecBuffer.Colorspace.RGBA(rawConfig.output.u.RGBA)
        case .YUVA:
            unsafe config.output.u = WebPDecBuffer.Colorspace.YUVA(rawConfig.output.u.YUVA)
        }
    }

    private func makeConfig(
        _ options: WebPDecoderOptions,
        _ colorspace: ColorspaceMode,
    ) throws -> WebPDecoderConfig {
        var config = unsafe try WebPDecoderConfig()
        unsafe config.options = options
        unsafe config.output.colorspace = colorspace
        return unsafe config
    }

    func requiredOutputLayout(
        for webPData: Data,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat,
    ) throws -> OutputLayout {
        guard format.colorspace.isRGBMode else {
            throw WebPError.unsupportedDecodeFormat
        }
        let feature = try WebPImageInspector.inspect(webPData)
        var config = unsafe try makeConfig(options, format.colorspace)
        unsafe config.input = feature
        // Lossy (YUV420) decoding snaps crop origins down to even pixels.
        // Lossless decoding preserves the exact origin.
        // Normalize the validation copy so valid edge crops stay accepted.
        if feature.format == .lossy, options.useCropping, options.cropLeft >= 0, options.cropTop >= 0 {
            unsafe config.options.cropLeft &= ~1
            unsafe config.options.cropTop &= ~1
        }
        guard unsafe config.validate() else {
            throw WebPDecodingError.invalidParam
        }
        var width = options.useCropping ? options.cropWidth : feature.width
        var height = options.useCropping ? options.cropHeight : feature.height

        if options.useScaling {
            // libwebp infers a missing dimension from the cropped source,
            // rounding up to the next pixel.
            let sourceWidth = width
            let sourceHeight = height
            width = options.scaledWidth
            height = options.scaledHeight
            if width == 0 {
                width = (sourceWidth * height + sourceHeight - 1) / sourceHeight
            }
            if height == 0 {
                height = (sourceHeight * width + sourceWidth - 1) / sourceWidth
            }
            guard width > 0, height > 0,
                width <= Int(Int32.max) / 2, height <= Int(Int32.max) / 2
            else {
                throw WebPDecodingError.invalidParam
            }
        }

        let bytesPerPixel = format.bytesPerPixel
        let (stride, strideOverflow) = width.multipliedReportingOverflow(by: bytesPerPixel)
        let (byteCount, sizeOverflow) = stride.multipliedReportingOverflow(by: height)
        guard !strideOverflow, !sizeOverflow, Int32(exactly: stride) != nil else {
            throw WebPDecodingError.invalidParam
        }
        return OutputLayout(
            width: width,
            height: height,
            bytesPerPixel: bytesPerPixel,
            stride: stride,
            byteCount: byteCount,
        )
    }
}

struct OutputLayout {
    let width: Int
    let height: Int
    let bytesPerPixel: Int
    let stride: Int
    let byteCount: Int
}

private extension WebPDecodePixelFormat {
    var bytesPerPixel: Int {
        switch self {
        case .rgb, .bgr:
            3
        case .rgba4444, .rgb565, .rgbA4444:
            2
        default:
            4
        }
    }
}
