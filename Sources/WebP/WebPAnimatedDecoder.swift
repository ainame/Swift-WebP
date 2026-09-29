#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import libwebp

/// Pixel layouts supported by libwebp's animation decoder. All are 4 bytes per pixel.
/// Lowercase letters mark premultiplied color channels, as in `WebPDecodePixelFormat`.
public enum WebPAnimationPixelFormat: Sendable {
    /// Straight alpha, R G B A in memory.
    case rgba
    /// Straight alpha, B G R A in memory.
    case bgra
    /// Premultiplied alpha, R G B A in memory. Core Graphics' native layout.
    case rgbA
    /// Premultiplied alpha, B G R A in memory.
    case bgrA

    var colorspace: WEBP_CSP_MODE {
        switch self {
        case .rgba: MODE_RGBA
        case .bgra: MODE_BGRA
        case .rgbA: MODE_rgbA
        case .bgrA: MODE_bgrA
        }
    }
}

/// Global properties of an animated (or still) WebP image.
public struct WebPAnimationInfo: Sendable, Equatable {
    public let canvasWidth: Int
    public let canvasHeight: Int
    /// Number of times to play the animation. `0` means loop forever.
    public let loopCount: Int
    /// Background color hint from the file, packed as `0xAARRGGBB`.
    /// The decoder does not apply it: disposed areas become transparent, as the WebP spec recommends.
    public let backgroundColor: UInt32
    public let frameCount: Int
}

/// When a frame is shown, in milliseconds from the start of the animation.
public struct WebPAnimationFrameTiming: Sendable, Equatable {
    /// Zero-based position of the frame in the animation.
    public let index: Int
    public let startTimeMilliseconds: Int
    /// Display duration as stored in the file. It may be `0`; players often substitute a minimum.
    public let durationMilliseconds: Int
}

/// A fully composited canvas for one animation frame.
public struct WebPAnimationFrame: Sendable {
    public let timing: WebPAnimationFrameTiming
    public let format: WebPAnimationPixelFormat
    public let width: Int
    public let height: Int
    /// Bytes per row: always `width * 4`.
    public let stride: Int
    /// `stride * height` bytes in `format`.
    public let pixels: Data
}

/// Every frame of an animation, decoded up front.
public struct WebPAnimation: Sendable {
    public let info: WebPAnimationInfo
    public let frames: [WebPAnimationFrame]
}

/// Decodes animated WebP frames one at a time, composited onto the full canvas.
///
/// libwebp applies each frame's offset, blending, and disposal, so every frame you receive is
/// ready to display. Still WebP images decode as a one-frame animation.
///
/// The decoder copies the encoded bytes once, because libwebp keeps reading them while frames
/// are decoded. It also owns one canvas (`canvasWidth * canvasHeight * 4` bytes) that it
/// overwrites for each frame.
///
/// ```swift
/// var decoder = try WebPAnimatedDecoder(data)
/// while let frame = try decoder.nextFrame() {
///     show(frame.pixels, for: frame.timing.durationMilliseconds)
/// }
/// decoder.reset() // Play again.
/// ```
@safe
public struct WebPAnimatedDecoder: ~Copyable {
    public let info: WebPAnimationInfo
    public let format: WebPAnimationPixelFormat

    // Deleted in deinit before `input` is freed; the decoder reads `input` until then.
    private let decoder: OpaquePointer
    private let input: WebPByteStorage
    private var nextIndex = 0
    private var previousEndTime = 0

    /// Parses the animation header. Throws `WebPDecodingError` if the data is not a valid WebP image.
    /// - Parameter useThreads: Lets libwebp decode each frame with an extra thread.
    public init(_ webPData: Data, format: WebPAnimationPixelFormat = .rgbA, useThreads: Bool = false) throws {
        guard !webPData.isEmpty else { throw WebPDecodingError.notEnoughData }
        try self.init(input: WebPByteStorage(copying: webPData), format: format, useThreads: useThreads)
    }

    /// Parses the animation header. Throws `WebPDecodingError` if the data is not a valid WebP image.
    /// - Parameter useThreads: Lets libwebp decode each frame with an extra thread.
    public init(_ webPData: borrowing Span<UInt8>, format: WebPAnimationPixelFormat = .rgbA, useThreads: Bool = false) throws {
        guard !webPData.isEmpty else { throw WebPDecodingError.notEnoughData }
        try self.init(input: WebPByteStorage(copying: webPData), format: format, useThreads: useThreads)
    }

    private init(input: consuming WebPByteStorage, format: WebPAnimationPixelFormat, useThreads: Bool) throws {
        let bytes = unsafe input.buffer
        // Report header problems with libwebp's status instead of the bare failure from WebPAnimDecoderNew.
        var features = libwebp.WebPBitstreamFeatures()
        let status = unsafe WebPGetFeatures(bytes.baseAddress, bytes.count, &features)
        guard status == VP8_STATUS_OK else {
            throw WebPDecodingError(vp8StatusCodeRawValue: status.rawValue)
        }

        var options = WebPAnimDecoderOptions()
        guard unsafe WebPAnimDecoderOptionsInit(&options) != 0 else {
            throw WebPError.decoderConfigInitializationFailed
        }
        options.color_mode = format.colorspace
        options.use_threads = useThreads ? 1 : 0

        var webPData = unsafe WebPData(bytes: bytes.baseAddress, size: bytes.count)
        guard let decoder = unsafe WebPAnimDecoderNew(&webPData, &options) else {
            throw WebPDecodingError.bitstreamError
        }
        var rawInfo = WebPAnimInfo()
        guard unsafe WebPAnimDecoderGetInfo(decoder, &rawInfo) != 0 else {
            unsafe WebPAnimDecoderDelete(decoder)
            throw WebPDecodingError.bitstreamError
        }

        unsafe self.decoder = decoder
        self.input = input
        self.format = format
        info = WebPAnimationInfo(
            canvasWidth: Int(rawInfo.canvas_width),
            canvasHeight: Int(rawInfo.canvas_height),
            loopCount: Int(rawInfo.loop_count),
            backgroundColor: rawInfo.bgcolor,
            frameCount: Int(rawInfo.frame_count),
        )
    }

    deinit {
        unsafe WebPAnimDecoderDelete(decoder)
    }

    /// `true` until every frame has been returned since the start or the last `reset()`.
    public var hasMoreFrames: Bool {
        unsafe WebPAnimDecoderHasMoreFrames(decoder) != 0
    }

    /// Decodes the next frame and copies its canvas into a new `Data`.
    /// Returns `nil` after the last frame. Throws `WebPDecodingError.bitstreamError` for corrupt frames.
    public mutating func nextFrame() throws -> WebPAnimationFrame? {
        let format = format
        let info = info
        return try withNextFrame { pixels, timing in
            let data = pixels.withWebPBytes { bytes in
                unsafe Data(bytes: bytes.baseAddress!, count: bytes.count)
            }
            return WebPAnimationFrame(
                timing: timing,
                format: format,
                width: info.canvasWidth,
                height: info.canvasHeight,
                stride: info.canvasWidth * 4,
                pixels: data,
            )
        }
    }

    /// Decodes the next frame and lends its canvas to `body` without copying.
    /// The pixels are `canvasWidth * 4` bytes per row in `format` and are only valid inside `body`;
    /// the decoder overwrites them for the next frame.
    /// Returns `nil` after the last frame. Throws `WebPDecodingError.bitstreamError` for corrupt frames.
    public mutating func withNextFrame<Result>(
        _ body: (_ pixels: Span<UInt8>, _ timing: WebPAnimationFrameTiming) throws -> Result
    ) throws -> Result? {
        guard hasMoreFrames else { return nil }
        var canvas: UnsafeMutablePointer<UInt8>?
        var endTime: Int32 = 0
        guard unsafe WebPAnimDecoderGetNext(decoder, &canvas, &endTime) != 0, let canvas = unsafe canvas else {
            throw WebPDecodingError.bitstreamError
        }
        // libwebp reports when the frame ends: the previous end time plus this frame's duration.
        let timing = WebPAnimationFrameTiming(
            index: nextIndex,
            startTimeMilliseconds: previousEndTime,
            durationMilliseconds: Int(endTime) - previousEndTime,
        )
        nextIndex += 1
        previousEndTime = Int(endTime)
        // The canvas belongs to the decoder and stays valid until the next GetNext, Reset, or Delete,
        // none of which can run while `self` is exclusively borrowed by this call.
        let pixels = unsafe Span(_unsafeStart: canvas, count: info.canvasWidth * 4 * info.canvasHeight)
        return try body(pixels, timing)
    }

    /// Rewinds to the first frame, for example to play the animation again.
    public mutating func reset() {
        unsafe WebPAnimDecoderReset(decoder)
        nextIndex = 0
        previousEndTime = 0
    }
}

public extension WebPDecoder {
    /// Decodes every frame of an animated (or still) WebP image.
    /// Memory: holds `canvasWidth * canvasHeight * 4` bytes per frame. Use `WebPAnimatedDecoder`
    /// to process frames one at a time instead.
    func decodeAnimation(
        _ webPData: Data,
        format: WebPAnimationPixelFormat = .rgbA,
        useThreads: Bool = false,
    ) throws -> WebPAnimation {
        var decoder = try WebPAnimatedDecoder(webPData, format: format, useThreads: useThreads)
        var frames: [WebPAnimationFrame] = []
        frames.reserveCapacity(decoder.info.frameCount)
        while let frame = try decoder.nextFrame() {
            frames.append(frame)
        }
        return WebPAnimation(info: decoder.info, frames: frames)
    }
}
