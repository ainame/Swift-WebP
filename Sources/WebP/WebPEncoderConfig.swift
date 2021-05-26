import Foundation
import CWebP

extension CWebP.WebPImageHint: ExpressibleByIntegerLiteral {
    /// Create an instance initialized to `value`.
    public init(integerLiteral value: Int) {
        switch UInt32(value) {
        case CWebP.WEBP_HINT_DEFAULT.rawValue:
            self = CWebP.WEBP_HINT_DEFAULT
        case CWebP.WEBP_HINT_PICTURE.rawValue:
            self = CWebP.WEBP_HINT_PICTURE
        case CWebP.WEBP_HINT_PHOTO.rawValue:
            self = CWebP.WEBP_HINT_PHOTO
        case CWebP.WEBP_HINT_GRAPH.rawValue:
            self = CWebP.WEBP_HINT_GRAPH
        default:
            fatalError()
        }
    }
}


// mapping from CWebP.WebPConfig
public struct WebPEncoderConfig: InternalRawRepresentable {
    public enum WebPImageHint: CWebP.WebPImageHint {
        case `default` = 0
        case picture = 1
        case photo = 2
        case graph = 3
    }

    // Lossless encoding (0=lossy(default), 1=lossless).
    public var lossless: Int = 0

    // between 0 (smallest file) and 100 (biggest)
    public var quality: Float

    // quality/speed trade-off (0=fast, 6=slower-better)
    public var method: Int

    // Hint for image type (lossless only for now).
    public var imageHint: WebPImageHint = .default

    // Parameters related to lossy compression only:

    // if non-zero, set the desired target size in bytes.
    // Takes precedence over the 'compression' parameter.
    public var targetSize: Int = 0

    // if non-zero, specifies the minimal distortion to
    // try to achieve. Takes precedence over target_size.
    public var targetPSNR: Float = 0

    // maximum number of segments to use, in [1..4]
    public var segments: Int

    // Spatial Noise Shaping. 0=off, 100=maximum.
    public var snsStrength: Int

    // range: [0 = off .. 100 = strongest]
    public var filterStrength: Int

    // range: [0 = off .. 7 = least sharp]
    public var filterSharpness: Int

    // filtering type: 0 = simple, 1 = strong (only used
    // if filter_strength > 0 or autofilter > 0)
    public var filterType: Int

    // Auto adjust filter's strength [0 = off, 1 = on]
    public var autofilter: Int

    // Algorithm for encoding the alpha plane (0 = none,
    // 1 = compressed with WebP lossless). Default is 1.
    public var alphaCompression: Int = 1

    // Predictive filtering method for alpha plane.
    // 0: none, 1: fast, 2: best. Default if 1.
    public var alphaFiltering: Int

    // Between 0 (smallest size) and 100 (lossless).
    // Default is 100.
    public var alphaQuality: Int = 100

    // number of entropy-analysis passes (in [1..10]).
    public var pass: Int

    // if true, export the compressed picture back.
    // In-loop filtering is not applied.
    public var showCompressed: Bool

    // preprocessing filter:
    // 0=none, 1=segment-smooth, 2=pseudo-random dithering
    public var preprocessing: Int

    // log2(number of token partitions) in [0..3]. Default
    // is set to 0 for easier progressive decoding.
    public var partitions: Int = 0

    // quality degradation allowed to fit the 512k limit
    // on prediction modes coding (0: no degradation,
    // 100: maximum possible degradation).
    public var partitionLimit: Int

    // If true, compression parameters will be remapped
    // to better match the expected output size from
    // JPEG compression. Generally, the output size will
    // be similar but the degradation will be lower.
    public var emulateJpegSize: Bool

    // If non-zero, try and use multi-threaded encoding.
    public var threadLevel: Int

    // If set, reduce memory usage (but increase CPU use).
    public var lowMemory: Bool

    // Near lossless encoding [0 = max loss .. 100 = off
    // Int(default)].
    public var nearLossless: Int = 100

    // if non-zero, preserve the exact RGB values under
    // transparent area. Otherwise, discard this invisible
    // RGB information for better compression. The default
    // value is 0.
    public var exact: Int

    public var qmin: Int = 0
    public var qmax: Int = 100

    // reserved for future lossless feature
    var useDeltaPalette: Bool
    // if needed, use sharp (and slow) RGB->YUV conversion
    var useSharpYUV: Bool

    static public func preset(_ preset: Preset, quality: Float) -> WebPEncoderConfig {
        let webPConfig = preset.webPConfig(quality: quality)
        return WebPEncoderConfig(rawValue: webPConfig)!
    }

    internal init?(rawValue: CWebP.WebPConfig) {
        lossless = Int(rawValue.lossless)
        quality = rawValue.quality
        method = Int(rawValue.method)
        imageHint = WebPImageHint(rawValue: rawValue.image_hint)!
        targetSize = Int(rawValue.target_size)
        targetPSNR = Float(rawValue.target_PSNR)
        segments = Int(rawValue.segments)
        snsStrength = Int(rawValue.sns_strength)
        filterStrength = Int(rawValue.filter_strength)
        filterSharpness = Int(rawValue.filter_sharpness)
        filterType = Int(rawValue.filter_type)
        autofilter = Int(rawValue.autofilter)
        alphaCompression = Int(rawValue.alpha_compression)
        alphaFiltering = Int(rawValue.alpha_filtering)
        alphaQuality = Int(rawValue.alpha_quality)
        pass = Int(rawValue.pass)
        showCompressed = rawValue.show_compressed != 0 ? true : false
        preprocessing = Int(rawValue.preprocessing)
        partitions = Int(rawValue.partitions)
        partitionLimit = Int(rawValue.partition_limit)
        emulateJpegSize = rawValue.emulate_jpeg_size != 0 ? true : false
        threadLevel = Int(rawValue.thread_level)
        lowMemory = rawValue.low_memory != 0 ? true : false
        nearLossless = Int(rawValue.near_lossless)
        exact = Int(rawValue.exact)
        useDeltaPalette = rawValue.use_delta_palette != 0 ? true : false
        useSharpYUV = rawValue.use_sharp_yuv != 0 ? true : false
        qmin = Int(rawValue.qmin)
        qmax = Int(rawValue.qmax)
    }

    internal var rawValue: CWebP.WebPConfig {
        let show_compressed = showCompressed ? Int32(1) : Int32(0)
        let emulate_jpeg_size = emulateJpegSize ? Int32(1) : Int32(0)
        let low_memory = lowMemory ? Int32(1) : Int32(0)
        let use_delta_palette = useDeltaPalette ? Int32(1) : Int32(0)
        let use_sharp_yuv = useSharpYUV ? Int32(1) : Int32(0)

        return CWebP.WebPConfig(
            lossless: Int32(lossless),
            quality: Float(quality),
            method: Int32(method),
            image_hint: imageHint.rawValue,
            target_size: Int32(targetSize),
            target_PSNR: Float(targetPSNR),
            segments: Int32(segments),
            sns_strength: Int32(snsStrength),
            filter_strength: Int32(filterStrength),
            filter_sharpness: Int32(filterSharpness),
            filter_type: Int32(filterType),
            autofilter: Int32(autofilter),
            alpha_compression: Int32(alphaCompression),
            alpha_filtering: Int32(alphaFiltering),
            alpha_quality: Int32(alphaQuality),
            pass: Int32(pass),
            show_compressed: show_compressed,
            preprocessing: Int32(preprocessing),
            partitions: Int32(partitions),
            partition_limit: Int32(partitionLimit),
            emulate_jpeg_size: emulate_jpeg_size,
            thread_level: Int32(threadLevel),
            low_memory: low_memory,
            near_lossless: Int32(nearLossless),
            exact: Int32(exact),
            use_delta_palette: Int32(use_delta_palette),
            use_sharp_yuv: Int32(use_sharp_yuv),
            qmin: Int32(qmin),
            qmax: Int32(qmax)
        )
    }

    public enum Preset {
        case `default`, picture, photo, drawing, icon, text

        func webPConfig(quality: Float) -> CWebP.WebPConfig {
            var config = CWebP.WebPConfig()

            switch self {
            case .default:
                WebPConfigPreset(&config, WEBP_PRESET_DEFAULT, quality)
            case .picture:
                WebPConfigPreset(&config, WEBP_PRESET_PICTURE, quality)
            case .photo:
                WebPConfigPreset(&config, WEBP_PRESET_PHOTO, quality)
            case .drawing:
                WebPConfigPreset(&config, WEBP_PRESET_DRAWING, quality)
            case .icon:
                WebPConfigPreset(&config, WEBP_PRESET_ICON, quality)
            case .text:
                WebPConfigPreset(&config, WEBP_PRESET_TEXT, quality)
            }

            return config
        }
    }

}
