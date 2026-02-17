import Testing
import WebP

struct WebPBridgingTests {
    @Test
    func libwebpVersionIsSane() {
        let encoderVersion = WebPEncoder.libwebpVersion
        let decoderVersion = WebPDecoder.libwebpVersion

        #expect(encoderVersion.major >= 1)
        #expect(decoderVersion.major >= 1)
    }

    @Test
    func losslessPresetAndValidation() throws {
        let config = try WebPEncoderConfig.losslessPreset(level: 6)
        #expect(config.lossless == 1)
        #expect(config.validate())
    }
}
