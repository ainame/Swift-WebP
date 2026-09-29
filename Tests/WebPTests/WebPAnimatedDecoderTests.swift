#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
import WebP

struct WebPAnimatedDecoderTests {
    static let width = 8
    static let height = 6
    static let red: [UInt8] = [255, 0, 0, 255]
    static let blue: [UInt8] = [0, 0, 255, 255]
    static let green: [UInt8] = [0, 255, 0, 255]

    /// Frame 1 is red. Frames 2 and 3 change only a small rectangle, so the encoder stores them
    /// as sub-frames that the decoder must composite onto the previous canvas.
    static let canvases: [[UInt8]] = [
        AnimatedWebPFixture.canvas(width: width, height: height, fill: red),
        AnimatedWebPFixture.canvas(width: width, height: height, fill: red, rect: (2, 1, 3, 2), rectColor: blue),
        AnimatedWebPFixture.canvas(width: width, height: height, fill: red, rect: (5, 3, 2, 3), rectColor: green),
    ]
    static let durations = [100, 40, 250]

    static func makeAnimation(loopCount: Int = 0, backgroundColor: UInt32 = 0xFFFF_FFFF) throws -> Data {
        try AnimatedWebPFixture.make(
            width: width,
            height: height,
            frames: zip(canvases, durations).map { .init(rgba: $0, durationMilliseconds: $1) },
            loopCount: loopCount,
            backgroundColor: backgroundColor,
        )
    }

    @Test
    func readsAnimationInfo() throws {
        let data = try Self.makeAnimation(loopCount: 3, backgroundColor: 0x8011_2233)
        #expect(try WebPImageInspector.inspect(data).hasAnimation)
        let decoder = try WebPAnimatedDecoder(data)
        let info = decoder.info
        #expect(info.canvasWidth == Self.width)
        #expect(info.canvasHeight == Self.height)
        #expect(info.loopCount == 3)
        #expect(info.backgroundColor == 0x8011_2233)
        #expect(info.frameCount == 3)
        let format = decoder.format
        let hasMoreFrames = decoder.hasMoreFrames
        #expect(format == .rgbA)
        #expect(hasMoreFrames)
    }

    @Test
    func decodesCompositedFramesWithTiming() throws {
        var decoder = try WebPAnimatedDecoder(try Self.makeAnimation(), format: .rgba)
        var starts = 0
        for index in 0 ..< 3 {
            let frame = try #require(try decoder.nextFrame())
            #expect(frame.timing.index == index)
            #expect(frame.timing.startTimeMilliseconds == starts)
            #expect(frame.timing.durationMilliseconds == Self.durations[index])
            #expect(frame.format == .rgba)
            #expect(frame.width == Self.width)
            #expect(frame.height == Self.height)
            #expect(frame.stride == Self.width * 4)
            #expect([UInt8](frame.pixels) == Self.canvases[index])
            starts += Self.durations[index]
        }
        let hasMoreFrames = decoder.hasMoreFrames
        #expect(!hasMoreFrames)
        #expect(try decoder.nextFrame() == nil)
    }

    @Test
    func resetRestartsFromFirstFrame() throws {
        var decoder = try WebPAnimatedDecoder(try Self.makeAnimation(), format: .rgba)
        let first = try #require(try decoder.nextFrame())
        while try decoder.nextFrame() != nil {}
        decoder.reset()
        let hasMoreFrames = decoder.hasMoreFrames
        #expect(hasMoreFrames)
        let replayed = try #require(try decoder.nextFrame())
        #expect(replayed.timing == first.timing)
        #expect(replayed.pixels == first.pixels)
    }

    @Test
    func withNextFrameLendsTheSameCanvas() throws {
        let data = try Self.makeAnimation()
        var copying = try WebPAnimatedDecoder(data, format: .rgba)
        var borrowing = try WebPAnimatedDecoder(data, format: .rgba)
        while let frame = try copying.nextFrame() {
            let lent = try #require(
                try borrowing.withNextFrame { pixels, timing in
                    #expect(timing == frame.timing)
                    return (0 ..< pixels.count).map { pixels[$0] }
                }
            )
            #expect(lent == [UInt8](frame.pixels))
        }
        #expect(try borrowing.withNextFrame { _, _ in true } == nil)
    }

    @Test
    func spanInputMatchesDataInput() throws {
        let data = try Self.makeAnimation()
        let expected = try WebPDecoder().decodeAnimation(data, format: .rgba)
        let bytes = [UInt8](data)
        var frames: [WebPAnimationFrame] = []
        var info: WebPAnimationInfo?
        try bytes.withUnsafeBufferPointer { buffer in
            var decoder = try WebPAnimatedDecoder(Span(_unsafeElements: buffer), format: .rgba)
            info = decoder.info
            while let frame = try decoder.nextFrame() {
                frames.append(frame)
            }
        }
        #expect(info == expected.info)
        #expect(frames.map(\.pixels) == expected.frames.map(\.pixels))
    }

    @Test
    func decodeAnimationReturnsEveryFrame() throws {
        let animation = try WebPDecoder().decodeAnimation(try Self.makeAnimation(), format: .rgba)
        #expect(animation.info.frameCount == 3)
        #expect(animation.frames.map(\.timing.durationMilliseconds) == Self.durations)
        #expect(animation.frames.map(\.timing.startTimeMilliseconds) == [0, 100, 140])
        #expect(animation.frames.map { [UInt8]($0.pixels) } == Self.canvases)
    }

    @Test(arguments: [
        (WebPAnimationPixelFormat.rgba, [UInt8]([255, 0, 0, 128])),
        (.bgra, [0, 0, 255, 128]),
        (.rgbA, [128, 0, 0, 128]),
        (.bgrA, [0, 0, 128, 128]),
    ])
    func pixelFormats(format: WebPAnimationPixelFormat, expected: [UInt8]) throws {
        let translucentRed: [UInt8] = [255, 0, 0, 128]
        let data = try AnimatedWebPFixture.make(
            width: 2,
            height: 2,
            frames: [
                .init(rgba: AnimatedWebPFixture.canvas(width: 2, height: 2, fill: translucentRed), durationMilliseconds: 50),
                .init(rgba: AnimatedWebPFixture.canvas(width: 2, height: 2, fill: [0, 0, 0, 0]), durationMilliseconds: 50),
            ],
        )
        var decoder = try WebPAnimatedDecoder(data, format: format)
        let frame = try #require(try decoder.nextFrame())
        #expect(frame.format == format)
        #expect(Array(frame.pixels.prefix(4)) == expected)
    }

    @Test
    func stillImageDecodesAsSingleFrame() throws {
        var config = WebPEncoderConfig.preset(.picture, quality: 100)
        config.lossless = 1
        let rgba = TestFixtures.makeRGBAFixture(width: 5, height: 4).enumerated().map { $0.offset % 4 == 3 ? 255 : $0.element }
        let data = try WebPEncoder().encode(rgba, format: .rgba, config: config, originWidth: 5, originHeight: 4, stride: 20)
        var decoder = try WebPAnimatedDecoder(data, format: .rgba)
        let info = decoder.info
        #expect(info.canvasWidth == 5)
        #expect(info.canvasHeight == 4)
        #expect(info.frameCount == 1)
        let frame = try #require(try decoder.nextFrame())
        #expect(frame.timing.index == 0)
        #expect([UInt8](frame.pixels) == rgba)
        #expect(try decoder.nextFrame() == nil)
    }

    @Test
    func stillDecoderRejectsAnimation() throws {
        let data = try Self.makeAnimation()
        #expect(throws: WebPDecodingError.unsupportedFeature) {
            try WebPDecoder().decode(data, options: WebPDecoderOptions(), format: .rgba)
        }
    }

    @Test
    func invalidInputThrows() throws {
        #expect(throws: WebPDecodingError.notEnoughData) {
            try WebPAnimatedDecoder(Data())
        }
        #expect(throws: WebPDecodingError.self) {
            try WebPAnimatedDecoder(Data("not a webp file".utf8))
        }
        let data = try Self.makeAnimation()
        #expect(throws: WebPDecodingError.self) {
            try WebPAnimatedDecoder(data.prefix(data.count / 2))
        }
    }
}
