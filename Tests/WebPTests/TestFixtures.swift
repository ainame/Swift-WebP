import Foundation
import Testing
import WebP

enum TestFixtures {
    static func makeRGBAFixture(width: Int, height: Int) -> [UInt8] {
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
        return rgba
    }

    static func makeWebPFixture(
        width: Int = 4,
        height: Int = 3,
        config: WebPEncoderConfig = .preset(.picture, quality: 90)
    ) throws -> Data {
        let encoder = WebPEncoder()
        var rgba = makeRGBAFixture(width: width, height: height)
        return try rgba.withUnsafeMutableBufferPointer { pointer in
            guard let base = pointer.baseAddress else {
                throw WebPError.unexpectedPointerError
            }
            return try encoder.encode(
                base,
                format: .rgba,
                config: config,
                originWidth: width,
                originHeight: height,
                stride: width * 4
            )
        }
    }
}

func expectWebPError(
    _ body: () throws -> Void,
    matches matcher: (WebPError) -> Bool
) {
    do {
        try body()
        #expect(Bool(false), "Expected WebPError to be thrown")
    } catch let error as WebPError {
        #expect(matcher(error))
    } catch {
        #expect(Bool(false), "Unexpected error type: \(error)")
    }
}
