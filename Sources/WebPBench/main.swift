import Foundation
import WebP

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import ImageIO
#endif

struct Config {
    var width = 1920
    var height = 1080
    var iterations = 30
    var warmup = 3
    var quality: Float = 75
    var threads = true
    var inputPath: String?
    var decodeSourceEachIteration = false
}

struct InputFrame {
    var rgba: [UInt8]
    var width: Int
    var height: Int

    var stride: Int {
        width * 4
    }
}

enum BenchError: Error {
    case invalidArgument(String)
    case validationFailed(String)
    case unsupported(String)
}

func parseArgs() throws -> Config {
    var config = Config()
    var index = 1
    let args = CommandLine.arguments

    func readValue(_ flag: String) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < args.count else {
            throw BenchError.invalidArgument("Missing value for \(flag)")
        }
        index += 2
        return args[valueIndex]
    }

    while index < args.count {
        switch args[index] {
        case "--width":
            config.width = try Int(readValue("--width")).unwrap(or: "--width must be Int")
        case "--height":
            config.height = try Int(readValue("--height")).unwrap(or: "--height must be Int")
        case "--iterations":
            config.iterations = try Int(readValue("--iterations")).unwrap(or: "--iterations must be Int")
        case "--warmup":
            config.warmup = try Int(readValue("--warmup")).unwrap(or: "--warmup must be Int")
        case "--quality":
            config.quality = try Float(readValue("--quality")).unwrap(or: "--quality must be Float")
        case "--input":
            config.inputPath = try readValue("--input")
        case "--decode-source-each-iteration":
            config.decodeSourceEachIteration = true
            index += 1
        case "--no-threads":
            config.threads = false
            index += 1
        case "--help":
            printHelp()
            exit(0)
        default:
            throw BenchError.invalidArgument("Unknown argument: \(args[index])")
        }
    }

    guard config.width > 0, config.height > 0 else {
        throw BenchError.invalidArgument("width/height must be > 0")
    }
    guard config.iterations > 0, config.warmup >= 0 else {
        throw BenchError.invalidArgument("iterations > 0 and warmup >= 0 are required")
    }
    guard (0 ... 100).contains(config.quality) else {
        throw BenchError.invalidArgument("quality must be in 0...100")
    }
    if config.decodeSourceEachIteration, config.inputPath == nil {
        throw BenchError.invalidArgument("--decode-source-each-iteration requires --input")
    }
    return config
}

func printHelp() {
    print(
        """
        WebPBench usage:
          WebPBench [--width N] [--height N] [--iterations N] [--warmup N] [--quality Q] [--no-threads]
                    [--input /path/to/image] [--decode-source-each-iteration]
        """
    )
}

func makeRGBA(width: Int, height: Int) -> [UInt8] {
    var buffer = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0 ..< height {
        for x in 0 ..< width {
            let base = (y * width + x) * 4
            buffer[base] = UInt8((x * 255) / max(width - 1, 1))
            buffer[base + 1] = UInt8((y * 255) / max(height - 1, 1))
            buffer[base + 2] = UInt8((x ^ y) & 0xFF)
            buffer[base + 3] = 255
        }
    }
    return buffer
}

#if canImport(CoreGraphics) && canImport(ImageIO)
func loadImageRGBA(path: String) throws -> InputFrame {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        throw BenchError.validationFailed("Failed to open input image: \(path)")
    }
    guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw BenchError.validationFailed("Failed to decode input image: \(path)")
    }

    let width = image.width
    let height = image.height
    let stride = width * 4
    var rgba = [UInt8](repeating: 0, count: stride * height)

    let rendered = rgba.withUnsafeMutableBytes { rawPtr -> Bool in
        guard let base = rawPtr.baseAddress else {
            return false
        }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ??
            CGColorSpace(name: CGColorSpace.genericRGBLinear)
        else {
            return false
        }
        guard let context = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: stride,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }

    guard rendered else {
        throw BenchError.validationFailed("Failed to render input image into RGBA buffer: \(path)")
    }

    return InputFrame(rgba: rgba, width: width, height: height)
}
#else
func loadImageRGBA(path _: String) throws -> InputFrame {
    throw BenchError.unsupported("--input is only supported on platforms with CoreGraphics + ImageIO")
}
#endif

func now() -> Double {
    Date().timeIntervalSince1970
}

func elapsedMS(_ start: Double, _ end: Double) -> Double {
    (end - start) * 1000
}

func percentile(_ values: [Double], _ p: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let rank = Int((p * Double(sorted.count - 1)).rounded())
    return sorted[min(max(rank, 0), sorted.count - 1)]
}

func maxRSSMB() -> Double {
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else { return -1 }
    #if os(macOS)
    return Double(usage.ru_maxrss) / (1024 * 1024)
    #else
    return Double(usage.ru_maxrss) / 1024
    #endif
}

func run() throws {
    let config = try parseArgs()
    let encoder = WebPEncoder()
    let decoder = WebPDecoder()

    let staticFrame: InputFrame? = if let inputPath = config.inputPath {
        try loadImageRGBA(path: inputPath)
    } else {
        InputFrame(
            rgba: makeRGBA(width: config.width, height: config.height),
            width: config.width,
            height: config.height
        )
    }

    guard let seedFrame = staticFrame else {
        throw BenchError.validationFailed("Failed to initialize input frame")
    }

    let totalRuns = config.warmup + config.iterations
    var encodedLast = Data()

    var decodeOptions = WebPDecoderOptions()
    decodeOptions.useThreads = config.threads
    decodeOptions.useScaling = true
    decodeOptions.scaledWidth = seedFrame.width
    decodeOptions.scaledHeight = seedFrame.height

    var sourceDecodeMS = [Double]()
    var encodeMS = [Double]()
    var decodeMS = [Double]()
    sourceDecodeMS.reserveCapacity(config.iterations)
    encodeMS.reserveCapacity(config.iterations)
    decodeMS.reserveCapacity(config.iterations)

    for runIndex in 0 ..< totalRuns {
        let frame: InputFrame
        if config.decodeSourceEachIteration {
            guard let inputPath = config.inputPath else {
                throw BenchError.invalidArgument("--decode-source-each-iteration requires --input")
            }
            let sourceStart = now()
            frame = try loadImageRGBA(path: inputPath)
            let sourceEnd = now()
            if runIndex >= config.warmup {
                sourceDecodeMS.append(elapsedMS(sourceStart, sourceEnd))
            }
        } else {
            frame = seedFrame
        }

        let encoded: Data = try frame.rgba.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else {
                throw BenchError.validationFailed("Unable to get source buffer pointer")
            }
            let mutable = UnsafeMutablePointer(mutating: base)
            let start = now()
            let data = try encoder.encode(
                mutable,
                format: .rgba,
                config: .preset(.picture, quality: config.quality),
                originWidth: frame.width,
                originHeight: frame.height,
                stride: frame.stride
            )
            let end = now()
            if runIndex >= config.warmup {
                encodeMS.append(elapsedMS(start, end))
            }
            return data
        }

        let decodeStart = now()
        let decoded = try decoder.decode(encoded, options: decodeOptions, format: .rgba)
        let decodeEnd = now()
        if runIndex >= config.warmup {
            decodeMS.append(elapsedMS(decodeStart, decodeEnd))
        }
        let expectedBytes = frame.width * frame.height * 4
        guard decoded.count == expectedBytes else {
            throw BenchError.validationFailed(
                "Decoded size mismatch. expected=\(expectedBytes), actual=\(decoded.count)"
            )
        }
        encodedLast = encoded
    }

    let features = try WebPImageInspector.inspect(encodedLast)
    guard features.width == seedFrame.width, features.height == seedFrame.height else {
        throw BenchError.validationFailed(
            "Bitstream dimensions mismatch. expected=\(seedFrame.width)x\(seedFrame.height), actual=\(features.width)x\(features.height)"
        )
    }

    let sourceDecodeAverage = sourceDecodeMS.reduce(0, +) / Double(max(sourceDecodeMS.count, 1))
    let encodeAverage = encodeMS.reduce(0, +) / Double(max(encodeMS.count, 1))
    let decodeAverage = decodeMS.reduce(0, +) / Double(max(decodeMS.count, 1))

    print("source_mode=\(config.inputPath == nil ? "synthetic" : "image")")
    print("source_path=\(config.inputPath ?? "")")
    print("source_decode_each_iteration=\(config.decodeSourceEachIteration)")
    print("width=\(seedFrame.width)")
    print("height=\(seedFrame.height)")
    print("iterations=\(config.iterations)")
    print("warmup=\(config.warmup)")
    print("quality=\(config.quality)")
    print("threads=\(config.threads)")
    print("webp_bytes=\(encodedLast.count)")
    if !sourceDecodeMS.isEmpty {
        print("source_decode_avg_ms=\(String(format: "%.3f", sourceDecodeAverage))")
        print("source_decode_p95_ms=\(String(format: "%.3f", percentile(sourceDecodeMS, 0.95)))")
        print("pipeline_encode_avg_ms=\(String(format: "%.3f", sourceDecodeAverage + encodeAverage))")
        print(
            "pipeline_encode_p95_ms=\(String(format: "%.3f", percentile(sourceDecodeMS, 0.95) + percentile(encodeMS, 0.95)))"
        )
    }
    print("encode_avg_ms=\(String(format: "%.3f", encodeAverage))")
    print("encode_p95_ms=\(String(format: "%.3f", percentile(encodeMS, 0.95)))")
    print("decode_avg_ms=\(String(format: "%.3f", decodeAverage))")
    print("decode_p95_ms=\(String(format: "%.3f", percentile(decodeMS, 0.95)))")
    print("peak_rss_mb=\(String(format: "%.3f", maxRSSMB()))")
    print("valid=true")
}

do {
    try run()
} catch let error as BenchError {
    fputs("WebPBench error: \(error)\n", stderr)
    exit(1)
} catch {
    fputs("WebPBench error: \(error)\n", stderr)
    exit(1)
}

private extension Optional {
    func unwrap(or message: String) throws -> Wrapped {
        guard let value = self else {
            throw BenchError.invalidArgument(message)
        }
        return value
    }
}
