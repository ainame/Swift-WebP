import Foundation
import libwebp

public struct WebPDecoderConfig: InternalRawRepresentable {
    public var input: WebPBitstreamFeatures? // Immutable bitstream features (optional)
    public var output: WebPDecBuffer // Output buffer (can point to external mem)
    public var options: WebPDecoderOptions // Decoding options

    public init() throws {
        var originConfig = libwebp.WebPDecoderConfig()
        if libwebp.WebPInitDecoderConfig(&originConfig) == 0 {
            throw WebPError.decoderConfigInitializationFailed
        }
        self = WebPDecoderConfig(rawValue: originConfig)
    }

    init(rawValue: libwebp.WebPDecoderConfig) {
        input = WebP.WebPBitstreamFeatures(rawValue: rawValue.input)
        output = WebP.WebPDecBuffer(rawValue: rawValue.output)
        options = WebP.WebPDecoderOptions(rawValue: rawValue.options)
    }

    var rawValue: libwebp.WebPDecoderConfig {
        let inputValue = input?.rawValue ?? libwebp.WebPBitstreamFeatures(
            width: 0,
            height: 0,
            has_alpha: 0,
            has_animation: 0,
            format: 0,
            pad: (0, 0, 0, 0, 0)
        )
        return libwebp.WebPDecoderConfig(input: inputValue, output: output.rawValue, options: options.rawValue)
    }
}

public struct WebPBitstreamFeatures: InternalRawRepresentable, Sendable {
    public enum Format: Int, Sendable {
        case undefined = 0
        case lossy
        case lossless
    }

    public var width: Int // Width in pixels, as read from the bitstream.

    public var height: Int // Height in pixels, as read from the bitstream.

    public var hasAlpha: Bool // True if the bitstream contains an alpha channel.

    public var hasAnimation: Bool // True if the bitstream is an animation.

    public var format: Format // 0 = undefined (/mixed), 1 = lossy, 2 = lossless

    public var pad: (Int, Int, Int, Int, Int) // padding for later use

    var rawValue: libwebp.WebPBitstreamFeatures {
        let has_alpha = hasAlpha ? 1 : 0
        let has_animation = hasAnimation ? 1 : 0

        return libwebp.WebPBitstreamFeatures(
            width: Int32(width),
            height: Int32(height),
            has_alpha: Int32(has_alpha),
            has_animation: Int32(has_animation),
            format: Int32(format.rawValue),
            pad: (UInt32(pad.0), UInt32(pad.1), UInt32(pad.2), UInt32(pad.3), UInt32(pad.4))
        )
    }

    init(rawValue: libwebp.WebPBitstreamFeatures) {
        width = Int(rawValue.width)
        height = Int(rawValue.height)
        hasAlpha = rawValue.has_alpha != 0
        hasAnimation = rawValue.has_animation != 0
        guard let format = Format(rawValue: Int(rawValue.format)) else {
            preconditionFailure("Unexpected WebP bitstream format value: \(rawValue.format)")
        }
        self.format = format
        pad = (Int(rawValue.pad.0), Int(rawValue.pad.1), Int(rawValue.pad.2), Int(rawValue.pad.3), Int(rawValue.pad.4))
    }
}

// Colorspaces
// Note: the naming describes the byte-ordering of packed samples in memory.
// For instance, MODE_BGRA relates to samples ordered as B,G,R,A,B,G,R,A,...
// Non-capital names (e.g.:MODE_Argb) relates to pre-multiplied RGB channels.
// RGBA-4444 and RGB-565 colorspaces are represented by following byte-order:
// RGBA-4444: [r3 r2 r1 r0 g3 g2 g1 g0], [b3 b2 b1 b0 a3 a2 a1 a0], ...
// RGB-565: [r4 r3 r2 r1 r0 g5 g4 g3], [g2 g1 g0 b4 b3 b2 b1 b0], ...
// In the case WEBP_SWAP_16BITS_CSP is defined, the bytes are swapped for
// these two modes:
// RGBA-4444: [b3 b2 b1 b0 a3 a2 a1 a0], [r3 r2 r1 r0 g3 g2 g1 g0], ...
// RGB-565: [g2 g1 g0 b4 b3 b2 b1 b0], [r4 r3 r2 r1 r0 g5 g4 g3], ...
public enum ColorspaceMode: Int, Sendable {
    case RGB = 0
    case RGBA = 1
    case BGR = 2
    case BGRA = 3
    case ARGB = 4
    case RGBA4444 = 5
    case RGB565 = 6

    // RGB-premultiplied transparent modes (alpha value is preserved)
    case rgbA = 7
    case bgrA = 8
    case Argb = 9
    case rgbA4444 = 10

    // YUV modes must come after RGB ones.
    case YUV = 11
    case YUVA = 12
    case LAST = 13

    public var isPremultipliedMode: Bool {
        if self == .rgbA || self == .bgrA || self == .Argb || self == .rgbA4444 {
            return true
        }
        return false
    }

    public var isAlphaMode: Bool {
        if self == .RGBA || self == .BGRA || self == .ARGB ||
            self == .RGBA4444 || self == .YUVA || isPremultipliedMode
        {
            return true
        }
        return false
    }

    public var isRGBMode: Bool {
        rawValue < ColorspaceMode.YUV.rawValue
    }
}

public struct WebPDecBuffer: InternalRawRepresentable {
    public enum ExternalMemoryMode: Equatable, Sendable {
        case internalMemory
        case externalMemory
        case externalMemorySlow

        var libwebpValue: Int32 {
            switch self {
            case .internalMemory:
                0
            case .externalMemory:
                1
            case .externalMemorySlow:
                2
            }
        }

        init(libwebpValue: Int32) {
            switch libwebpValue {
            case 0:
                self = .internalMemory
            case 1:
                self = .externalMemory
            default:
                self = .externalMemorySlow
            }
        }
    }

    public enum Colorspace {
        case RGBA(WebPRGBABuffer)
        case YUVA(WebPYUVABuffer)

        var rgba: WebPRGBABuffer? {
            if case let .RGBA(buffer) = self {
                return buffer
            }
            return nil
        }

        var yuva: WebPYUVABuffer? {
            if case let .YUVA(buffer) = self {
                return buffer
            }
            return nil
        }
    }

    /// Colorspace.
    public var colorspace: ColorspaceMode

    // Dimensions.
    public var width: Int
    public var height: Int

    public var externalMemoryMode: ExternalMemoryMode

    public var u: Colorspace

    /// Nameless union of buffer parameters.
    public var pad: (Int, Int, Int, Int) // padding for later use

    var privateMemory: UnsafeMutablePointer<UInt8>? // Internally allocated memory (only when

    var rawValue: libwebp.WebPDecBuffer {
        let originU = switch u {
        case let .RGBA(buffer):
            libwebp.WebPDecBuffer.__Unnamed_union_u(RGBA: buffer)
        case let .YUVA(buffer):
            libwebp.WebPDecBuffer.__Unnamed_union_u(YUVA: buffer)
        }
        // let u = colorspace.isRGBMode ? libwebp.WebPDecBuffer.__Unnamed_union_u(RGBA: u.RGBA) :
        // libwebp.WebPDecBuffer.__Unnamed_union_u(YUVA: u.YUVA)
        return libwebp.WebPDecBuffer(
            colorspace: WEBP_CSP_MODE(rawValue: UInt32(colorspace.rawValue)),
            width: Int32(width),
            height: Int32(height),
            is_external_memory: externalMemoryMode.libwebpValue,
            u: originU,
            pad: (UInt32(pad.0), UInt32(pad.1), UInt32(pad.2), UInt32(pad.3)),
            private_memory: privateMemory
        )
    }

    init(rawValue: libwebp.WebPDecBuffer) {
        guard let colorspace = ColorspaceMode(rawValue: Int(rawValue.colorspace.rawValue)) else {
            preconditionFailure("Unexpected WebP colorspace value: \(rawValue.colorspace.rawValue)")
        }
        self.colorspace = colorspace
        width = Int(rawValue.width)
        height = Int(rawValue.height)
        externalMemoryMode = ExternalMemoryMode(libwebpValue: rawValue.is_external_memory)
        u = colorspace.isRGBMode ? Colorspace.RGBA(rawValue.u.RGBA) : Colorspace.YUVA(rawValue.u.YUVA)
        pad = (Int(rawValue.pad.0), Int(rawValue.pad.1), Int(rawValue.pad.2), Int(rawValue.pad.3))
        privateMemory = rawValue.private_memory
    }
}

public struct WebPDecoderOptions: InternalRawRepresentable, Sendable {
    public var bypassFiltering: Int // if true, skip the in-loop filtering

    public var noFancyUpsampling: Int // if true, use faster pointwise upsampler

    public var useCropping: Bool // if true, cropping is applied _first_

    public var cropLeft: Int // top-left position for cropping.

    public var cropTop: Int

    /// Will be snapped to even values.
    public var cropWidth: Int // dimension of the cropping area

    public var cropHeight: Int

    public var useScaling: Bool // if true, scaling is applied _afterward_

    public var scaledWidth: Int // final resolution

    public var scaledHeight: Int

    public var useThreads: Bool // if true, use multi-threaded decoding

    public var ditheringStrength: Int // dithering strength (0=Off, 100=full)

    public var flip: Int // flip output vertically

    public var alphaDitheringStrength: Int // alpha dithering strength in [0..100]

    public var pad: (Int, Int, Int, Int, Int) // padding for later use

    var rawValue: libwebp.WebPDecoderOptions {
        let useCropping = useCropping ? 1 : 0
        let useScaling = useScaling ? 1 : 0
        let useThreads = useThreads ? 1 : 0

        return libwebp.WebPDecoderOptions(
            bypass_filtering: Int32(bypassFiltering),
            no_fancy_upsampling: Int32(noFancyUpsampling),
            use_cropping: Int32(useCropping),
            crop_left: Int32(cropLeft),
            crop_top: Int32(cropTop),
            crop_width: Int32(cropWidth),
            crop_height: Int32(cropHeight),
            use_scaling: Int32(useScaling),
            scaled_width: Int32(scaledWidth),
            scaled_height: Int32(scaledHeight),
            use_threads: Int32(useThreads),
            dithering_strength: Int32(ditheringStrength),
            flip: Int32(flip),
            alpha_dithering_strength: Int32(alphaDitheringStrength),
            pad: (UInt32(pad.0), UInt32(pad.1), UInt32(pad.2), UInt32(pad.3), UInt32(pad.4))
        )
    }

    init(rawValue: libwebp.WebPDecoderOptions) {
        bypassFiltering = Int(rawValue.bypass_filtering)
        noFancyUpsampling = Int(rawValue.no_fancy_upsampling)
        useCropping = rawValue.use_cropping != 0
        cropLeft = Int(rawValue.crop_left)
        cropTop = Int(rawValue.crop_top)
        cropWidth = Int(rawValue.crop_width)
        cropHeight = Int(rawValue.crop_height)
        useScaling = rawValue.use_scaling != 0
        scaledWidth = Int(rawValue.scaled_width)
        scaledHeight = Int(rawValue.scaled_height)
        useThreads = rawValue.use_threads != 0
        ditheringStrength = Int(rawValue.dithering_strength)
        flip = Int(rawValue.flip)
        alphaDitheringStrength = Int(rawValue.alpha_dithering_strength)
        pad = (Int(rawValue.pad.0), Int(rawValue.pad.1), Int(rawValue.pad.2), Int(rawValue.pad.3), Int(rawValue.pad.4))
    }

    public init() {
        bypassFiltering = 0
        noFancyUpsampling = 0
        useCropping = false
        cropLeft = 0
        cropTop = 0
        cropWidth = 0
        cropHeight = 0
        useScaling = false
        scaledWidth = 0
        scaledHeight = 0
        useThreads = false
        ditheringStrength = 0
        flip = 0
        alphaDitheringStrength = 0
        pad = (0, 0, 0, 0, 0)
    }
}
