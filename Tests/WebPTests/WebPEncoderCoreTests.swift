import Foundation
import Testing
import WebP

struct WebPEncoderCoreTests {
    @Test
    func encode_unsafeBufferPointerOverloadProducesWebPData() throws {
        let encoder = WebPEncoder()
        let config = WebPEncoderConfig.preset(.picture, quality: 90)
        let width = 2
        let height = 2
        let rgba = TestFixtures.makeRGBAFixture(width: width, height: height)

        let encoded = try rgba.withUnsafeBufferPointer { buffer in
            try encoder.encode(
                buffer,
                format: .rgba,
                config: config,
                originWidth: width,
                originHeight: height,
                stride: width * 4
            )
        }

        let feature = try WebPImageInspector.inspect(encoded)
        #expect(feature.width == width)
        #expect(feature.height == height)
    }

    @Test
    func encode_unsafeBufferPointerOverloadEmptyBufferThrowsUnexpectedPointerError() throws {
        let encoder = WebPEncoder()
        let config = WebPEncoderConfig.preset(.picture, quality: 90)
        let empty = UnsafeBufferPointer<UInt8>(start: nil, count: 0)

        do {
            _ = try encoder.encode(
                empty,
                format: .rgba,
                config: config,
                originWidth: 1,
                originHeight: 1,
                stride: 4
            )
            #expect(Bool(false), "Expected unexpectedPointerError")
        } catch let error as WebPError {
            switch error {
            case .unexpectedPointerError:
                #expect(Bool(true))
            default:
                #expect(Bool(false), "Unexpected WebPError: \(error)")
            }
        }
    }

    @Test
    func encode_invalidConfigThrowsInvalidParameter() throws {
        let encoder = WebPEncoder()
        var config = WebPEncoderConfig.preset(.photo, quality: 90)
        config.quality = 101
        #expect(!config.validate())

        var rgba = TestFixtures.makeRGBAFixture(width: 2, height: 2)
        do {
            _ = try rgba.withUnsafeMutableBufferPointer { buffer in
                guard let base = buffer.baseAddress else {
                    throw WebPError.unexpectedPointerError
                }
                return try encoder.encode(
                    base,
                    format: .rgba,
                    config: config,
                    originWidth: 2,
                    originHeight: 2,
                    stride: 2 * 4
                )
            }
            #expect(Bool(false), "Expected invalidParameter")
        } catch let error as WebPEncoderError {
            switch error {
            case .invalidParameter:
                #expect(Bool(true))
            default:
                #expect(Bool(false), "Unexpected WebPEncoderError: \(error)")
            }
        }
    }

    @Test
    func losslessPreset_invalidLevelThrows() throws {
        do {
            _ = try WebPEncoderConfig.losslessPreset(level: 10)
            #expect(Bool(false), "Expected invalidWebPConfig")
        } catch let error as WebPError {
            switch error {
            case .invalidWebPConfig:
                #expect(Bool(true))
            default:
                #expect(Bool(false), "Unexpected WebPError: \(error)")
            }
        }
    }
}
