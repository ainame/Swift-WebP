import Foundation
import Testing
import WebP

struct WebPDecoderBufferTests {
    private func makeFixtureWebP(width: Int = 4, height: Int = 3) throws -> Data {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let base = (y * width + x) * 4
                rgba[base] = UInt8((x * 255) / max(width - 1, 1))
                rgba[base + 1] = UInt8((y * 255) / max(height - 1, 1))
                rgba[base + 2] = UInt8((x ^ y) & 0xFF)
                rgba[base + 3] = UInt8(64 + ((x + y) % 191))
            }
        }

        let encoder = WebPEncoder()
        return try rgba.withUnsafeMutableBufferPointer { pointer in
            guard let base = pointer.baseAddress else {
                throw WebPError.unexpectedPointerError
            }
            return try encoder.encode(
                base,
                format: .rgba,
                config: .preset(.picture, quality: 90),
                originWidth: width,
                originHeight: height,
                stride: width * 4
            )
        }
    }

    @Test
    func decodeIntoExactSizedBuffer() throws {
        let webPData = try makeFixtureWebP(width: 4, height: 3)
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
    func decodeIntoLargerBufferKeepsTailUntouched() throws {
        let webPData = try makeFixtureWebP(width: 4, height: 3)
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
        let webPData = try makeFixtureWebP(width: 4, height: 3)
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
    func requiredOutputByteCountReflectsScaling() throws {
        let webPData = try makeFixtureWebP(width: 4, height: 3)
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
}
