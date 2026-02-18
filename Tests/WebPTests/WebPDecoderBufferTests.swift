import Foundation
import Testing
import WebP

struct WebPDecoderBufferTests {
    @Test
    func decodeIntoExactSizedBuffer() throws {
        let webPData = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        let decoder = WebPDecoder()
        let options = WebPDecoderOptions()
        let required = try decoder.requiredOutputByteCount(for: webPData, options: options, format: .rgba)

        var output = [UInt8](repeating: 0, count: required)
        let written = try output.withUnsafeMutableBufferPointer { buffer in
            try decoder.decode(webPData, into: buffer, options: options, format: .rgba)
        }

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
        let written = try output.withUnsafeMutableBufferPointer { buffer in
            try decoder.decode(webPData, into: buffer, options: options, format: .rgba)
        }

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
            _ = try output.withUnsafeMutableBufferPointer { buffer in
                try decoder.decode(webPData, into: buffer, options: options, format: .rgba)
            }
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
            _ = try output.withUnsafeMutableBufferPointer { buffer in
                try decoder.decode(webPData, into: buffer, options: .init(), format: .yuv)
            }
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
