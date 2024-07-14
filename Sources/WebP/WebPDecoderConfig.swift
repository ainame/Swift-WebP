import Foundation
import libwebp

public struct WebPDecoderConfig: InternalRawRepresentable {
    public var input: WebPBitstreamFeatures?  // Immutable bitstream features (optional)
    public var output: WebPDecBuffer          // Output buffer (can point to external mem)
    public var options: WebPDecoderOptions    // Decoding options

    public init() {
        var originConfig = libwebp.WebPDecoderConfig()
        if (libwebp.WebPInitDecoderConfig(&originConfig) == 0) {
            fatalError("can't init decoder config")
        }
        self.init(rawValue: originConfig)!
    }

    internal init?(rawValue: libwebp.WebPDecoderConfig) {
        self.input = WebP.WebPBitstreamFeatures(rawValue: rawValue.input)
        self.output = WebP.WebPDecBuffer(rawValue: rawValue.output)!
        self.options = WebP.WebPDecoderOptions(rawValue: rawValue.options)!
    }

    internal var rawValue: libwebp.WebPDecoderConfig {
        return libwebp.WebPDecoderConfig(input: (input?.rawValue)!, output: output.rawValue, options: options.rawValue)
    }
}

public struct WebPBitstreamFeatures: InternalRawRepresentable {
    public enum Format: Int {
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

    internal var rawValue: libwebp.WebPBitstreamFeatures {
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

    internal init?(rawValue: libwebp.WebPBitstreamFeatures) {
        width = Int(rawValue.width)
        height = Int(rawValue.height)
        hasAlpha = rawValue.has_alpha != 0
        hasAnimation = rawValue.has_animation != 0
        format = Format(rawValue: Int(rawValue.format))!
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
public enum ColorspaceMode: Int {
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

    public var isPremultipliedMode: Bool {
        if self == .rgbA || self == .bgrA || self == .Argb || self == .rgbA4444 {
            return true
        }
        return false
    }

    public var isAlphaMode: Bool {
        if self == .RGBA || self == .BGRA || self == .ARGB ||
            self == .RGBA4444 || self == .YUVA || isPremultipliedMode {
            return true
        }
        return false
    }

    public var isRGBMode: Bool {
        return rawValue < ColorspaceMode.YUV.rawValue;
    }
}

public struct WebPDecBuffer: InternalRawRepresentable {
    public enum Colorspace {
        case RGBA(WebPRGBABuffer)
        case YUVA(WebPYUVABuffer)

        var RGBA: WebPRGBABuffer {
            if case .RGBA(let buffer) = self  {
                return buffer
            }
            fatalError("please use yuva")
        }

        var YUVA: WebPYUVABuffer {
            if case .YUVA(let buffer) = self {
                return buffer
            }
            fatalError("please use rgba")
        }
    }

    // Colorspace.
    public var colorspace: ColorspaceMode

    // Dimensions.
    public var width: Int
    public var height: Int

    // If non-zero, 'internal_memory' pointer is not
    // used. If value is '2' or more, the external
    // memory is considered 'slow' and multiple
    // read/write will be avoided.
    public var isExternalMemory: Bool

    public var u: Colorspace

    // Nameless union of buffer parameters.
    public var pad: (Int, Int, Int, Int) // padding for later use


    public var privateMemory: UnsafeMutablePointer<UInt8>? // Internally allocated memory (only when


    internal var rawValue: libwebp.WebPDecBuffer {
        let originU: libwebp.WebPDecBuffer.__Unnamed_union_u
        switch u {
        case .RGBA(let buffer):
            originU = libwebp.WebPDecBuffer.__Unnamed_union_u(RGBA: buffer)
        case .YUVA(let buffer):
            originU = libwebp.WebPDecBuffer.__Unnamed_union_u(YUVA: buffer)
        }
        // let u = colorspace.isRGBMode ? libwebp.WebPDecBuffer.__Unnamed_union_u(RGBA: u.RGBA) : libwebp.WebPDecBuffer.__Unnamed_union_u(YUVA: u.YUVA)
        return libwebp.WebPDecBuffer(
            colorspace: WEBP_CSP_MODE(rawValue: UInt32(colorspace.rawValue)),
            width: Int32(width),
            height: Int32(height),
            is_external_memory: Int32(isExternalMemory ? 1 : 0),
            u: originU,
            pad: (UInt32(pad.0), UInt32(pad.1), UInt32(pad.2), UInt32(pad.3)),
            private_memory: privateMemory
        )
    }

    internal init?(rawValue: libwebp.WebPDecBuffer) {
        colorspace = ColorspaceMode(rawValue: Int(rawValue.colorspace.rawValue))!
        width = Int(rawValue.width)
        height = Int(rawValue.height)
        isExternalMemory = rawValue.is_external_memory != 0
        u = colorspace.isRGBMode ? Colorspace.RGBA(rawValue.u.RGBA) : Colorspace.YUVA(rawValue.u.YUVA)
        pad = (Int(rawValue.pad.0), Int(rawValue.pad.1), Int(rawValue.pad.2), Int(rawValue.pad.3))
        privateMemory = rawValue.private_memory
    }
}

public struct WebPDecoderOptions: InternalRawRepresentable {
    public var bypassFiltering: Int // if true, skip the in-loop filtering

    public var noFancyUpsampling: Int // if true, use faster pointwise upsampler

    public var useCropping: Bool // if true, cropping is applied _first_

    public var cropLeft: Int // top-left position for cropping.

    public var cropTop: Int

    // Will be snapped to even values.
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

    internal var rawValue: libwebp.WebPDecoderOptions {
        let useCropping = self.useCropping ? 1 : 0
        let useScaling = self.useScaling ? 1 : 0
        let useThreads = self.useThreads ? 1 : 0

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

    internal init?(rawValue: libwebp.WebPDecoderOptions) {
        self.bypassFiltering = Int(rawValue.bypass_filtering)
        self.noFancyUpsampling = Int(rawValue.no_fancy_upsampling)
        self.useCropping = rawValue.use_cropping != 0
        self.cropLeft = Int(rawValue.crop_left)
        self.cropTop = Int(rawValue.crop_top)
        self.cropWidth = Int(rawValue.crop_width)
        self.cropHeight = Int(rawValue.crop_height)
        self.useScaling = rawValue.use_scaling != 0
        self.scaledWidth = Int(rawValue.scaled_width)
        self.scaledHeight = Int(rawValue.scaled_height)
        self.useThreads = rawValue.use_threads != 0
        self.ditheringStrength = Int(rawValue.dithering_strength)
        self.flip = Int(rawValue.flip)
        self.alphaDitheringStrength = Int(rawValue.alpha_dithering_strength)
        self.pad = (Int(rawValue.pad.0), Int(rawValue.pad.1), Int(rawValue.pad.2), Int(rawValue.pad.3), Int(rawValue.pad.4))
    }

    public init() {
        self = WebPDecoderConfig().options
    }
}
