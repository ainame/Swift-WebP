import Foundation
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
        format: WebPDecodePixelFormat = .rgba
    ) throws -> Int {
        try requiredOutputLayout(for: webPData, options: options, format: format).byteCount
    }

    @available(
        *,
        deprecated,
        message: "Use decode(_:into: inout [UInt8], options:format:) unless low-level interop requires UnsafeMutableBufferPointer."
    )
    public func decode(
        _ webPData: Data,
        into output: UnsafeMutableBufferPointer<UInt8>,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba
    ) throws -> Int {
        try decodeIntoBuffer(webPData, output: output, options: options, format: format)
    }

    private func decodeIntoBuffer(
        _ webPData: Data,
        output: UnsafeMutableBufferPointer<UInt8>,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat
    ) throws -> Int {
        guard format.colorspace.isRGBMode else {
            throw WebPError.unsupportedDecodeFormat
        }
        let layout = try requiredOutputLayout(for: webPData, options: options, format: format)
        guard output.count >= layout.byteCount else {
            throw WebPError.outputBufferTooSmall(required: layout.byteCount, actual: output.count)
        }
        guard let base = output.baseAddress else {
            throw WebPError.outputBufferTooSmall(required: layout.byteCount, actual: output.count)
        }

        var config = try makeConfig(options, format.colorspace)
        config.output.externalMemoryMode = .externalMemory
        config.output.width = layout.width
        config.output.height = layout.height
        let rgbaBuffer = WebPRGBABuffer(
            rgba: base,
            stride: Int32(layout.stride),
            size: layout.byteCount
        )
        config.output.u = .RGBA(rgbaBuffer)
        try webPData.withUnsafeBytes { rawPtr in
            let span = Span<UInt8>(_unsafeBytes: rawPtr)
            try decode(span, config: &config)
        }
        return layout.byteCount
    }

    public func decode(
        _ webPData: Data,
        into output: inout [UInt8],
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba
    ) throws -> Int {
        try output.withUnsafeMutableBufferPointer { buffer in
            try decodeIntoBuffer(webPData, output: buffer, options: options, format: format)
        }
    }

    public func decode(
        _ webPData: Data,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat = .rgba
    ) throws -> Data {
        guard format.colorspace.isRGBMode else {
            throw WebPError.unsupportedDecodeFormat
        }
        let requiredByteCount = try requiredOutputByteCount(
            for: webPData,
            options: options,
            format: format
        )
        var output = Data(count: requiredByteCount)
        let written = try output.withUnsafeMutableBytes { rawPtr -> Int in
            guard let baseAddress = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPError.outputBufferTooSmall(required: requiredByteCount, actual: 0)
            }
            let buffer = UnsafeMutableBufferPointer(start: baseAddress, count: rawPtr.count)
            return try decodeIntoBuffer(webPData, output: buffer, options: options, format: format)
        }
        if written == output.count {
            return output
        }
        return output.prefix(written)
    }

    private func decode(_ webPData: borrowing Span<UInt8>, config: inout WebPDecoderConfig) throws {
        var rawConfig: libwebp.WebPDecoderConfig = config.rawValue

        try webPData.withUnsafeBytes { rawPtr in
            guard let bindedBasePtr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPDecodingError.unknownError
            }

            let status = WebPDecode(bindedBasePtr, webPData.count, &rawConfig)
            if status != VP8_STATUS_OK {
                throw WebPDecodingError(vp8StatusCodeRawValue: status.rawValue)
            }
        }

        switch config.output.u {
        case .RGBA:
            config.output.u = WebPDecBuffer.Colorspace.RGBA(rawConfig.output.u.RGBA)
        case .YUVA:
            config.output.u = WebPDecBuffer.Colorspace.YUVA(rawConfig.output.u.YUVA)
        }
    }

    private func makeConfig(
        _ options: WebPDecoderOptions,
        _ colorspace: ColorspaceMode
    ) throws -> WebPDecoderConfig {
        var config = try WebPDecoderConfig()
        config.options = options
        config.output.colorspace = colorspace
        return config
    }

    private func requiredOutputLayout(
        for webPData: Data,
        options: WebPDecoderOptions,
        format: WebPDecodePixelFormat
    ) throws -> OutputLayout {
        let feature = try WebPImageInspector.inspect(webPData)
        var width = feature.width
        var height = feature.height

        if options.useCropping {
            if options.cropWidth > 0 {
                width = options.cropWidth
            }
            if options.cropHeight > 0 {
                height = options.cropHeight
            }
        }
        if options.useScaling {
            if options.scaledWidth > 0 {
                width = options.scaledWidth
            }
            if options.scaledHeight > 0 {
                height = options.scaledHeight
            }
        }

        let bytesPerPixel = format.bytesPerPixel
        let stride = width * bytesPerPixel
        let byteCount = stride * height
        return OutputLayout(
            width: width,
            height: height,
            bytesPerPixel: bytesPerPixel,
            stride: stride,
            byteCount: byteCount
        )
    }
}

private struct OutputLayout {
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
