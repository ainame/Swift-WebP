import Foundation
import CWebP

/// There's no definition of WebPDecodingError in libwebp.
/// We map VP8StatusCode enum as WebPDecodingError instead.
public enum WebPDecodingError : UInt32, Error {
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

public struct WebPDecoder {
    public init() {
    }

    public func decode(byRGB webPData: Data, options: WebPDecoderOptions) throws -> Data {

        var config = makeConfig(options, .RGB)
        try decode(webPData, config: &config)

        return Data(bytesNoCopy: config.output.u.RGBA.rgba,
                    count: config.output.u.RGBA.size,
                    deallocator: .free)
    }

    public func decode(byRGBA webPData: Data, options: WebPDecoderOptions) throws -> Data {

        var config = makeConfig(options, .RGBA)
        try decode(webPData, config: &config)

        return Data(bytesNoCopy: config.output.u.RGBA.rgba,
                    count: config.output.u.RGBA.size,
                    deallocator: .free)
    }

    public func decode(byBGR webPData: Data, options: WebPDecoderOptions,
                       width: Int, height: Int) throws -> Data {

        var config = makeConfig(options, .BGR)
        try decode(webPData, config: &config)

        return Data(bytesNoCopy: config.output.u.RGBA.rgba,
                    count: config.output.u.RGBA.size,
                    deallocator: .free)
    }

    public func decode(byBGRA webPData: Data, options: WebPDecoderOptions) throws -> Data {

        var config = makeConfig(options, .BGRA)
        try decode(webPData, config: &config)

        return Data(bytesNoCopy: config.output.u.RGBA.rgba,
                    count: config.output.u.RGBA.size,
                    deallocator: .free)
    }

    public func decode(byARGB webPData: Data, options: WebPDecoderOptions) throws -> Data {

        var config = makeConfig(options, .ARGB)
        try decode(webPData, config: &config)

        return Data(bytesNoCopy: config.output.u.RGBA.rgba,
                    count: config.output.u.RGBA.size,
                    deallocator: .free)
    }

    public func decode(byRGBA4444 webPData: Data, options: WebPDecoderOptions) throws -> Data {

        var config = makeConfig(options, .RGBA4444)
        try decode(webPData, config: &config)

        return Data(bytesNoCopy: config.output.u.RGBA.rgba,
                    count: config.output.u.RGBA.size,
                    deallocator: .free)
    }

    public func decode(byRGB565 webPData: Data, options: WebPDecoderOptions) throws -> Data {

        var config = makeConfig(options, .RGB565)
        try decode(webPData, config: &config)

        return Data(bytesNoCopy: config.output.u.RGBA.rgba,
                    count: config.output.u.RGBA.size,
                    deallocator: .free)
    }

    public func decode(byrgbA webPData: Data, options: WebPDecoderOptions) throws -> Data {

        var config = makeConfig(options, .rgbA)
        try decode(webPData, config: &config)

        return Data(bytesNoCopy: config.output.u.RGBA.rgba,
                    count: config.output.u.RGBA.size,
                    deallocator: .free)
    }

    public func decode(bybgrA webPData: Data, options: WebPDecoderOptions) throws -> Data {

        var config = makeConfig(options, .bgrA)
        try decode(webPData, config: &config)

        return Data(bytesNoCopy: config.output.u.RGBA.rgba,
                    count: config.output.u.RGBA.size,
                    deallocator: .free)
    }

    public func decode(byArgb webPData: Data, options: WebPDecoderOptions) throws -> Data {

        var config = makeConfig(options, .Argb)
        try decode(webPData, config: &config)

        return Data(bytesNoCopy: config.output.u.RGBA.rgba,
                    count: config.output.u.RGBA.size,
                    deallocator: .free)
    }

    public func decode(byrgbA4444 webPData: Data, options: WebPDecoderOptions) throws -> Data {

        var config = makeConfig(options, .rgbA4444)
        try decode(webPData, config: &config)

        return Data(bytesNoCopy: config.output.u.RGBA.rgba,
                    count: config.output.u.RGBA.size,
                    deallocator: .free)
    }

    public func decode(byYUV webPData: Data, options: WebPDecoderOptions) throws -> Data {

        fatalError("didn't implement this yet")
    }

    public func decode(byYUVA webPData: Data, options: WebPDecoderOptions) throws -> Data {

        fatalError("didn't implement this yet")
    }

    private func decode(_ webPData: Data, config: inout WebPDecoderConfig) throws {

        var mutableWebPData = webPData
        var rawConfig: CWebP.WebPDecoderConfig = config.rawValue

        try mutableWebPData.withUnsafeMutableBytes { rawPtr in

            guard let bindedBasePtr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw WebPDecodingError.unknownError
            }

            let status = WebPDecode(bindedBasePtr, webPData.count, &rawConfig)
            if status != VP8_STATUS_OK {
                throw WebPDecodingError(rawValue: status.rawValue)!
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
                            _ colorspace: ColorspaceMode) -> WebPDecoderConfig {

        var config = WebPDecoderConfig()
        config.options = options
        config.output.colorspace = colorspace
        return config
    }
}
