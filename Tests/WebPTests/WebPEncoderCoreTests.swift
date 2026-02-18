import Foundation
import Testing
import WebP

struct WebPEncoderCoreTests {
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
