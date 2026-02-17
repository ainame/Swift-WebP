import Foundation
import libwebp

/// There's no definition of WebPDecodingError in libwebp.
/// We map VP8StatusCode enum as WebPDecodingError instead.
public enum WebPDecodingError: UInt32, Error {
    case ok = 0  // shouldn't be used as this is the succseed case
    case outOfMemory
    case invalidParam
    case bitstreamError
    case unsupportedFeature
    case suspended
    case userAbort
    case notEnoughData
    case unknownError = 9999 // This is an own error to deal with internal problems
}

public enum WebPDecodePixelFormat {
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
            return .RGB
        case .rgba:
            return .RGBA
        case .bgr:
            return .BGR
        case .bgra:
            return .BGRA
        case .argb:
            return .ARGB
        case .rgba4444:
            return .RGBA4444
        case .rgb565:
            return .RGB565
        case .rgbA:
            return .rgbA
        case .bgrA:
            return .bgrA
        case .Argb:
            return .Argb
        case .rgbA4444:
            return .rgbA4444
        case .yuv:
            return .YUV
        case .yuva:
            return .YUVA
        }
    }
}

public struct WebPDecoder {
    public init() {
    }

    public func decode(_ webPData: Data, options: WebPDecoderOptions, format: WebPDecodePixelFormat = .rgba) throws -> Data {
        guard format.colorspace.isRGBMode else {
            throw WebPError.unsupportedDecodeFormat
        }
        var config = try makeConfig(options, format.colorspace)
        try webPData.withUnsafeBytes { rawPtr in
            let span = Span<UInt8>(_unsafeBytes: rawPtr)
            try decode(span, config: &config)
        }

        guard let rgbaBuffer = config.output.u.rgba else {
            throw WebPError.unsupportedDecodeFormat
        }

        let owner = WebPMemoryOwner(
            pointer: rgbaBuffer.rgba,
            count: rgbaBuffer.size
        )
        return owner.takeData()
    }

    private func decode(_ webPData: borrowing Span<UInt8>, config: inout WebPDecoderConfig) throws {
        var rawConfig: libwebp.WebPDecoderConfig = config.rawValue

        try webPData.withUnsafeBytes { rawPtr in
            guard let bindedBasePtr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPDecodingError.unknownError
            }

            let status = WebPDecode(bindedBasePtr, webPData.count, &rawConfig)
            if status != VP8_STATUS_OK {
                throw WebPDecodingError(rawValue: status.rawValue) ?? .unknownError
            }
        }

        switch config.output.u {
        case .RGBA:
            config.output.u = WebPDecBuffer.Colorspace.RGBA(rawConfig.output.u.RGBA)
        case .YUVA:
            config.output.u = WebPDecBuffer.Colorspace.YUVA(rawConfig.output.u.YUVA)
        }
    }

    private func makeConfig(_ options: WebPDecoderOptions,
                            _ colorspace: ColorspaceMode) throws -> WebPDecoderConfig {
        var config = try WebPDecoderConfig()
        config.options = options
        config.output.colorspace = colorspace
        return config
    }
}
