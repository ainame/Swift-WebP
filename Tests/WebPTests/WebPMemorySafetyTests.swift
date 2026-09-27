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
                      (2, Int.max, 8, 16)])
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
