#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
import WebP

struct WebPDecoderBufferTests {
    @Test
    func oddCropOriginSnapsBeforeBoundsValidation() throws {
        let data = try TestFixtures.makeWebPFixture(width: 7, height: 5)
        var options = WebPDecoderOptions()
        options.useCropping = true
        options.cropLeft = 3
        options.cropTop = 3
        options.cropWidth = 5
        options.cropHeight = 3
        let decoder = WebPDecoder()
        #expect(try decoder.requiredOutputByteCount(for: data, options: options) == 5 * 3 * 4)
        #expect(try decoder.decode(data, options: options).count == 5 * 3 * 4)
    }

    @Test(arguments: [(3, 1, 5, 3), (1, 3, 3, 3)])
    func losslessOddEdgeCropFailsSizingAndDecode(
        left: Int,
        top: Int,
        width: Int,
        height: Int,
    ) throws {
        let data = try TestFixtures.makeWebPFixture(
            width: 7,
            height: 5,
            config: .losslessPreset(level: 6),
        )
        #expect(try WebPImageInspector.inspect(data).format == .lossless)
        var options = WebPDecoderOptions()
        options.useCropping = true
        options.cropLeft = left
        options.cropTop = top
        options.cropWidth = width
        options.cropHeight = height
        let decoder = WebPDecoder()
        #expect(throws: WebPDecodingError.invalidParam) {
            try decoder.requiredOutputByteCount(for: data, options: options)
        }
        #expect(throws: WebPDecodingError.invalidParam) {
            try decoder.decode(data, options: options)
        }
        var output = [UInt8](repeating: 0xCD, count: width * height * 4)
        #expect(throws: WebPDecodingError.invalidParam) {
            try decoder.decode(data, into: &output, options: options)
        }
        #expect(output.allSatisfy { $0 == 0xCD })
    }

    @Test
    func losslessValidOddCropPreservesExactOrigin() throws {
        let data = try TestFixtures.makeWebPFixture(
            width: 7,
            height: 5,
            config: .losslessPreset(level: 6),
        )
        var options = WebPDecoderOptions()
        options.useCropping = true
        options.cropLeft = 3
        options.cropTop = 1
        options.cropWidth = 3
        options.cropHeight = 3
        let decoder = WebPDecoder()
        #expect(try decoder.requiredOutputByteCount(for: data, options: options) == 3 * 3 * 4)
        let decoded = try decoder.decode(data, options: options)
        let source = TestFixtures.makeRGBAFixture(width: 7, height: 5)
        var expected: [UInt8] = []
        for y in 1 ..< 4 {
            let rowStart = (y * 7 + 3) * 4
            let rowEnd = (y * 7 + 6) * 4
            expected.append(contentsOf: source[rowStart ..< rowEnd])
        }
        #expect(Array(decoded) == expected)
    }

    @Test(arguments: [
        (0, 2, false, 3, 2), (2, 0, false, 2, 2),
        (0, 4, false, 6, 4), (4, 0, false, 4, 3),
        (0, 3, true, 6, 3), (3, 0, true, 3, 2),
    ])
    func inferredScalingMatchesDecodedBuffer(
        scaledWidth: Int,
        scaledHeight: Int,
        crop: Bool,
        width: Int,
        height: Int,
    ) throws {
        let data = try TestFixtures.makeWebPFixture(width: 7, height: 5)
        var options = WebPDecoderOptions()
        options.useCropping = crop
        options.cropWidth = 4
        options.cropHeight = 2
        options.useScaling = true
        options.scaledWidth = scaledWidth
        options.scaledHeight = scaledHeight
        let decoder = WebPDecoder()
        let expected = width * height * 4
        #expect(try decoder.requiredOutputByteCount(for: data, options: options) == expected)
        let decoded = try decoder.decode(data, options: options)
        #expect(decoded.count == expected)
        var output = [UInt8](repeating: 0xCD, count: expected + 16)
        #expect(try decoder.decode(data, into: &output, options: options) == expected)
        #expect(Array(output.prefix(expected)) == Array(decoded))
        #expect(output.suffix(16).allSatisfy { $0 == 0xCD })
        var undersized = [UInt8](repeating: 0xCD, count: expected - 1)
        expectWebPError {
            _ = try decoder.decode(data, into: &undersized, options: options)
        } matches: { error in
            if case let .outputBufferTooSmall(required, actual) = error {
                return required == expected && actual == expected - 1
            }
            return false
        }
        #expect(undersized.allSatisfy { $0 == 0xCD })
    }

    @Test(arguments: [0, 1, 2, 3, 4, 5])
    func invalidOptionsFailBeforeAllocation(caseIndex: Int) throws {
        let data = try TestFixtures.makeWebPFixture(width: 7, height: 5)
        var options = WebPDecoderOptions()
        switch caseIndex {
        case 0:
            options.useScaling = true // Both dimensions are zero.
        case 1:
            options.useScaling = true
            options.scaledWidth = -1
            options.scaledHeight = 2
        case 2:
            options.useCropping = true
            options.cropWidth = 8
            options.cropHeight = 2
        case 3:
            options.ditheringStrength = 101
        case 4:
            options.scaledWidth = Int.max // Must not trap during C bridging.
        default:
            options.useCropping = true // Empty crop.
        }
        let decoder = WebPDecoder()
        #expect(throws: WebPDecodingError.invalidParam) {
            try decoder.requiredOutputByteCount(for: data, options: options)
        }
        #expect(throws: WebPDecodingError.invalidParam) {
            try decoder.decode(data, options: options)
        }
    }

    @Test
    func decodeIntoExactSizedBuffer() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        let decoder = WebPDecoder()
        let options = WebPDecoderOptions()
        let required = try decoder.requiredOutputByteCount(for: webPData, options: options, format: .rgba)

        var output = [UInt8](repeating: 0, count: required)
        let written = try decoder.decode(webPData, into: &output, options: options, format: .rgba)

        #expect(written == required)
        #expect(output.contains { $0 != 0 })
    }

    @Test
    func decodeIntoExactSizedArrayViaInoutOverload() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        let decoder = WebPDecoder()
        let options = WebPDecoderOptions()
        let required = try decoder.requiredOutputByteCount(for: webPData, options: options, format: .rgba)
        var output = [UInt8](repeating: 0, count: required)

        let written = try decoder.decode(webPData, into: &output, options: options, format: .rgba)

        #expect(written == required)
        #expect(output.contains { $0 != 0 })
    }

    @Test
    func decodeIntoLargerBufferKeepsTailUntouched() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        let decoder = WebPDecoder()
        let options = WebPDecoderOptions()
        let required = try decoder.requiredOutputByteCount(for: webPData, options: options, format: .rgba)

        var output = [UInt8](repeating: 0xCD, count: required + 64)
        let written = try decoder.decode(webPData, into: &output, options: options, format: .rgba)

        #expect(written == required)
        let tail = output.suffix(64)
        #expect(tail.allSatisfy { $0 == 0xCD })
    }

    @Test
    func decodeIntoUndersizedBufferThrows() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        let decoder = WebPDecoder()
        let options = WebPDecoderOptions()
        let required = try decoder.requiredOutputByteCount(for: webPData, options: options, format: .rgba)

        var output = [UInt8](repeating: 0, count: max(0, required - 1))
        do {
            _ = try decoder.decode(webPData, into: &output, options: options, format: .rgba)
            #expect(Bool(false), "Expected outputBufferTooSmall error")
        } catch let error as WebPError {
            switch error {
            case let .outputBufferTooSmall(req, actual):
                #expect(req == required)
                #expect(actual == required - 1)
            default:
                #expect(Bool(false), "Unexpected WebPError: \(error)")
            }
        }
    }

    @Test
    func decodeIntoUndersizedArrayViaInoutOverloadThrows() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        let decoder = WebPDecoder()
        let options = WebPDecoderOptions()
        let required = try decoder.requiredOutputByteCount(for: webPData, options: options, format: .rgba)
        var output = [UInt8](repeating: 0, count: max(0, required - 1))

        do {
            _ = try decoder.decode(webPData, into: &output, options: options, format: .rgba)
            #expect(Bool(false), "Expected outputBufferTooSmall error")
        } catch let error as WebPError {
            switch error {
            case let .outputBufferTooSmall(req, actual):
                #expect(req == required)
                #expect(actual == required - 1)
            default:
                #expect(Bool(false), "Unexpected WebPError: \(error)")
            }
        }
    }

    @Test
    func requiredOutputByteCountReflectsScaling() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        let decoder = WebPDecoder()
        var options = WebPDecoderOptions()
        options.useScaling = true
        options.scaledWidth = 2
        options.scaledHeight = 2

        let required = try decoder.requiredOutputByteCount(for: webPData, options: options, format: .rgba)
        #expect(required == 2 * 2 * 4)

        let decoded = try decoder.decode(webPData, options: options, format: .rgba)
        #expect(decoded.count == required)
    }

    @Test
    func requiredOutputByteCount_respectsBytesPerPixel_rgb() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        let decoder = WebPDecoder()
        let required = try decoder.requiredOutputByteCount(for: webPData, options: .init(), format: .rgb)
        #expect(required == 4 * 3 * 3)
    }

    @Test
    func requiredOutputByteCount_respectsBytesPerPixel_rgba4444() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        let decoder = WebPDecoder()
        let required = try decoder.requiredOutputByteCount(for: webPData, options: .init(), format: .rgba4444)
        #expect(required == 4 * 3 * 2)
    }

    @Test
    func croppingThenScaling_layoutUsesScaledDimensions() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 6, height: 5)
        let decoder = WebPDecoder()
        var options = WebPDecoderOptions()
        options.useCropping = true
        options.cropWidth = 4
        options.cropHeight = 3
        options.useScaling = true
        options.scaledWidth = 2
        options.scaledHeight = 1

        let required = try decoder.requiredOutputByteCount(for: webPData, options: options, format: .rgba)
        #expect(required == 2 * 1 * 4)
    }

    @Test
    func decode_dataVariant_unsupportedFormatThrows() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        let decoder = WebPDecoder()

        expectWebPError {
            _ = try decoder.decode(webPData, options: .init(), format: .yuv)
        } matches: { error in
            if case .unsupportedDecodeFormat = error {
                return true
            }
            return false
        }
    }

    @Test
    func decode_bufferVariant_unsupportedFormatThrows() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        let decoder = WebPDecoder()
        var output = [UInt8](repeating: 0, count: 1)

        expectWebPError {
            _ = try decoder.decode(webPData, into: &output, options: .init(), format: .yuv)
        } matches: { error in
            if case .unsupportedDecodeFormat = error {
                return true
            }
            return false
        }
    }

    @Test
    func decode_invalidBitstreamThrowsDecodingError() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 8, height: 8)
        let truncated = Data(webPData.prefix(max(1, webPData.count / 2)))
        let decoder = WebPDecoder()

        do {
            _ = try decoder.decode(truncated, options: .init(), format: .rgba)
            #expect(Bool(false), "Expected WebPDecodingError")
        } catch let error as WebPDecodingError {
            #expect(error != .ok)
        }
    }
}
