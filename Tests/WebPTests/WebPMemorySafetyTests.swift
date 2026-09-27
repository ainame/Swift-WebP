import Foundation
import libwebp
import Testing
@testable import WebP

struct WebPMemorySafetyTests {
    @Test(arguments: [WebPEncodePixelFormat.rgb, .rgba, .rgbx, .bgr, .bgra, .bgrx])
    func safeInputsProduceIdenticalBitstreams(format: WebPEncodePixelFormat) throws {
        let bytesPerPixel = (format == .rgb || format == .bgr) ? 3 : 4
        let bytes = [UInt8](repeating: 128, count: 3 * 2 * bytesPerPixel)
        let encoder = WebPEncoder()
        let config = WebPEncoderConfig.preset(.picture, quality: 75)
        let arrayResult = try encoder.encode(
            bytes,
            format: format,
            config: config,
            originWidth: 3,
            originHeight: 2,
            stride: 3 * bytesPerPixel
        )
        let dataResult = try encoder.encode(
            Data(bytes),
            format: format,
            config: config,
            originWidth: 3,
            originHeight: 2,
            stride: 3 * bytesPerPixel
        )
        let spanResult = try bytes.withUnsafeBufferPointer { buffer in
            try encoder.encode(
                Span(_unsafeElements: buffer),
                format: format,
                config: config,
                originWidth: 3,
                originHeight: 2,
                stride: 3 * bytesPerPixel
            )
        }
        #expect(arrayResult == dataResult)
        #expect(arrayResult == spanResult)
    }

    @Test(arguments: [(0, 2, 8, 16), (-1, 2, 8, 16), (2, 2, 7, 16),
                      (2, 2, 8, 15), (2, 2, Int.max, 16), (Int.max, 2, 8, 16),
                      (2, Int.max, 8, 16), (2, 2, 12, 19)])
    func invalidLayoutsThrowBeforeReadingPixels(layout: (Int, Int, Int, Int)) {
        let (width, height, stride, count) = layout
        #expect(throws: WebPEncoderError.invalidParameter) {
            try WebPEncoder().encode(
                [UInt8](repeating: 0, count: count),
                format: .rgba,
                config: .preset(.picture, quality: 75),
                originWidth: width,
                originHeight: height,
                stride: stride
            )
        }
    }

    @Test
    func paddedRowsAreAccepted() throws {
        let encoded = try WebPEncoder().encode(
            [UInt8](repeating: 128, count: 24),
            format: .rgba,
            config: .preset(.picture, quality: 75),
            originWidth: 2,
            originHeight: 2,
            stride: 12
        )
        let features = try WebPImageInspector.inspect(encoded)
        #expect(features.width == 2 && features.height == 2)
    }

    @Test(arguments: [WebPEncodePixelFormat.rgb, .rgba, .rgbx, .bgr, .bgra, .bgrx])
    func missingFinalRowPaddingIsRejected(format: WebPEncodePixelFormat) {
        let rowBytes = (format == .rgb || format == .bgr) ? 6 : 8
        let stride = rowBytes + 4
        let compact = [UInt8](repeating: 128, count: stride + rowBytes)
        let encoder = WebPEncoder()
        let config = WebPEncoderConfig.preset(.picture, quality: 75)
        #expect(throws: WebPEncoderError.invalidParameter) {
            try compact.withUnsafeBufferPointer { buffer in
                try encoder.encode(
                    buffer,
                    format: format,
                    config: config,
                    originWidth: 2,
                    originHeight: 2,
                    stride: stride
                )
            }
        }
        #expect(throws: WebPEncoderError.invalidParameter) {
            try encoder.encode(
                compact,
                format: format,
                config: config,
                originWidth: 2,
                originHeight: 2,
                stride: stride
            )
        }
    }

    @Test
    func mutableSpanDecodePreservesTrailingStorageAndRejectsUndersizedOutput() throws {
        let encoded = try TestFixtures.makeWebPFixture()
        let decoder = WebPDecoder()
        let options = WebP.WebPDecoderOptions()
        let expected = try decoder.decode(encoded, options: options)
        var bytes = [UInt8](repeating: 0xAB, count: expected.count + 8)
        try bytes.withUnsafeMutableBufferPointer { buffer in
            var span = MutableSpan(_unsafeElements: buffer)
            let count = try decoder.decode(encoded, into: &span, options: options)
            #expect(count == expected.count)
        }
        #expect(Data(bytes.prefix(expected.count)) == expected)
        #expect(bytes.suffix(8).allSatisfy { $0 == 0xAB })
        var small = [UInt8](repeating: 0xAB, count: expected.count - 1)
        try small.withUnsafeMutableBufferPointer { buffer in
            var span = MutableSpan(_unsafeElements: buffer)
            do {
                _ = try decoder.decode(encoded, into: &span, options: options)
                Issue.record("Expected outputBufferTooSmall")
            } catch let WebPError.outputBufferTooSmall(required, actual) {
                #expect(required == expected.count && actual == expected.count - 1)
            }
        }
        #expect(small.allSatisfy { $0 == 0xAB })
    }

    @Test(arguments: [WebPDecodePixelFormat.rgb, .rgba, .bgr, .bgra, .argb,
                      .rgba4444, .rgb565, .rgbA, .bgrA, .Argb, .rgbA4444])
    func allocatedAndReusedDecodeMatchForEveryPackedFormat(format: WebPDecodePixelFormat) throws {
        let encoded = try TestFixtures.makeWebPFixture(width: 7, height: 5)
        let decoder = WebPDecoder()
        let options = WebP.WebPDecoderOptions()
        let count = try decoder.requiredOutputByteCount(for: encoded, options: options, format: format)
        var reused = [UInt8](repeating: 0xAB, count: count)
        _ = try decoder.decode(encoded, into: &reused, options: options, format: format)
        let allocated = try decoder.decode(encoded, options: options, format: format)
        #expect(allocated == Data(reused))
    }

    @Test
    func decodedDataOwnsStorageAndSurvivesLaterDecodes() throws {
        let pixels = TestFixtures.makeRGBAFixture(width: 16, height: 12)
        let encoded = try WebPEncoder().encode(
            pixels, format: .rgba, config: .losslessPreset(level: 6),
            originWidth: 16, originHeight: 12, stride: 64
        )
        let decoder = WebPDecoder()
        let options = WebP.WebPDecoderOptions()
        let first = try decoder.decode(encoded, options: options)
        for _ in 0 ..< 10 {
            let next = try decoder.decode(encoded, options: options)
            #expect(next == Data(pixels))
        }
        #expect(first == Data(pixels))
    }

    @Test
    func truncatedBitstreamFailsAfterSuccessfulLayoutInspection() throws {
        let encoded = try TestFixtures.makeWebPFixture(width: 64, height: 48)
        let truncated = Data(encoded.prefix(encoded.count / 2))
        let decoder = WebPDecoder()
        let options = WebP.WebPDecoderOptions()
        // Ensure the failure occurs after output allocation, not in the header preflight.
        #expect(try decoder.requiredOutputByteCount(for: truncated, options: options) == 64 * 48 * 4)
        #expect(throws: (any Error).self) {
            try decoder.decode(truncated, options: options)
        }
    }

    @Test
    func writerOwnershipTransfersToData() {
        var owner = WebPMemoryWriterOwner()
        let payload = [UInt8](0 ..< 128)
        payload.withUnsafeBufferPointer { buffer in
            withUnsafeMutablePointer(to: &owner.rawValue) { writer in
                var picture = WebPPicture()
                picture.custom_ptr = UnsafeMutableRawPointer(writer)
                let status = WebPMemoryWrite(buffer.baseAddress, buffer.count, &picture)
                #expect(status != 0)
            }
        }
        let result = owner.takeData()
        // Access after the consumed owner was destroyed detects a premature free under ASan.
        #expect(result == Data(payload))
    }
}
