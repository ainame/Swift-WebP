import WebP
import XCTest

final class WebPBridgingTests: XCTestCase {
    func testLibwebpVersionIsSane() {
        let encoderVersion = WebPEncoder.libwebpVersion
        let decoderVersion = WebPDecoder.libwebpVersion

        XCTAssertGreaterThanOrEqual(encoderVersion.major, 1)
        XCTAssertGreaterThanOrEqual(decoderVersion.major, 1)
    }

    func testLosslessPresetAndValidation() throws {
        let config = try WebPEncoderConfig.losslessPreset(level: 6)
        XCTAssertEqual(config.lossless, 1)
        XCTAssertTrue(config.validate())
    }
}
