import libwebp
import Testing
@testable import WebP

struct WebPBridgingTests {
    @Test
    func decoderConfigValidation() throws {
        var config = try WebP.WebPDecoderConfig()
        #expect(config.validate())
        config.options.useScaling = true
        #expect(!config.validate())
        config.options.scaledWidth = 2
        #expect(config.validate())
        config.options.alphaDitheringStrength = -1
        #expect(!config.validate())
        config.options.alphaDitheringStrength = 0
        config.output.colorspace = .LAST
        #expect(!config.validate())
    }

    @Test
    func decoderValidationUsesInputFeatures() throws {
        let data = try TestFixtures.makeWebPFixture(width: 4, height: 3)
        var config = try WebP.WebPDecoderConfig()
        config.options.useCropping = true
        config.options.cropWidth = 5
        config.options.cropHeight = 3
        #expect(config.validate()) // Source dimensions are not known yet.
        config.input = try WebPImageInspector.inspect(data)
        #expect(!config.validate())
    }

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

    @Test
    func decBufferExternalMemoryModeSemantics() throws {
        var config = try WebP.WebPDecoderConfig()
        config.output.externalMemoryMode = .internalMemory
        #expect(config.output.externalMemoryMode == .internalMemory)
        #expect(config.output.rawValue.is_external_memory == 0)

        config.output.externalMemoryMode = .externalMemory
        #expect(config.output.externalMemoryMode == .externalMemory)
        #expect(config.output.rawValue.is_external_memory == 1)

        config.output.externalMemoryMode = .externalMemorySlow
        #expect(config.output.externalMemoryMode == .externalMemorySlow)
        #expect(config.output.rawValue.is_external_memory == 2)
    }

    @Test
    func decBufferExternalMemoryModeMapsValuesGreaterThanTwoToSlow() {
        let rawBuffer = libwebp.WebPDecBuffer(
            colorspace: WEBP_CSP_MODE(rawValue: UInt32(WebP.ColorspaceMode.RGBA.rawValue)),
            width: 1,
            height: 1,
            is_external_memory: 3,
            u: libwebp.WebPDecBuffer.__Unnamed_union_u(
                RGBA: libwebp.WebPRGBABuffer(
                    rgba: nil,
                    stride: 4,
                    size: 4
                )
            ),
            pad: (0, 0, 0, 0),
            private_memory: nil
        )
        let buffer = WebP.WebPDecBuffer(rawValue: rawBuffer)
        #expect(buffer.externalMemoryMode == .externalMemorySlow)
    }
}
