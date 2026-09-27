#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation
import WebP
import libwebp

// Decode processes load a pre-generated WebP and reference hash, avoiding encoder/source-decoder RSS carry-over.
let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "decode"
let width = args.count > 2 ? Int(args[2])! : 1920
let height = args.count > 3 ? Int(args[3])! : 1080
let iterations = args.count > 4 ? Int(args[4])! : 30
let fixturePath = args.count > 5 ? args[5] : nil
precondition(width > 0 && height > 0 && iterations > 0)
let encoder = WebPEncoder()
let decoder = WebPDecoder()
let config = WebPEncoderConfig.preset(.picture, quality: 75)
var options = WebP.WebPDecoderOptions()
options.useThreads = false
let pixels: [UInt8] = mode == "encode" || mode == "fixture" ? (0 ..< width * height * 4).map { i in
    if i % 4 == 3 { return 255 }
    let pixel = i / 4
    return UInt8(truncatingIfNeeded: (pixel % width) * 3 + (pixel / width) * 7 + (i % 4) * 53)
} : []
func hash(_ data: Data) -> String {
    var value: UInt64 = 14695981039346656037
    for byte in data { value = (value ^ UInt64(byte)) &* 1099511628211 }
    return String(value, radix: 16)
}
// Direct C variants deliberately use ordinary pointers, defer cleanup and Data.
// No Span, noncopyable owners, borrowing/consuming declarations or ownership transfer.
func cDecode(_ encoded: Data) throws -> Data {
    #if DIRECT_C_COPY
    return try encoded.withUnsafeBytes { input in
        var w: Int32 = 0
        var h: Int32 = 0
        guard let pointer = WebPDecodeRGBA(input.baseAddress!.assumingMemoryBound(to: UInt8.self), input.count, &w, &h) else {
            throw CocoaError(.coderReadCorrupt)
        }
        defer { WebPFree(pointer) }
        precondition(Int(w) == width && Int(h) == height)
        return Data(bytes: pointer, count: width * height * 4)
    }
    #else
    var result = Data(count: width * height * 4)
    try result.withUnsafeMutableBytes { output in
        try encoded.withUnsafeBytes { input in
            guard WebPDecodeRGBAInto(input.baseAddress!.assumingMemoryBound(to: UInt8.self), input.count,
                                     output.baseAddress!.assumingMemoryBound(to: UInt8.self), output.count, Int32(width * 4)) != nil else {
                throw CocoaError(.coderReadCorrupt)
            }
        }
    }
    return result
    #endif
}
func cReuse(_ encoded: Data, output: inout [UInt8]) throws -> Int {
    try output.withUnsafeMutableBufferPointer { buffer in
        try encoded.withUnsafeBytes { input in
            guard WebPDecodeRGBAInto(input.baseAddress!.assumingMemoryBound(to: UInt8.self), input.count,
                                     buffer.baseAddress!, buffer.count, Int32(width * 4)) != nil else {
                throw CocoaError(.coderReadCorrupt)
            }
        }
    }
    return width * height * 4
}
@MainActor
func cEncode() throws -> Data {
    var config = libwebp.WebPConfig()
    precondition(WebPConfigPreset(&config, WEBP_PRESET_PICTURE, 75) != 0)
    var picture = WebPPicture()
    precondition(WebPPictureInit(&picture) != 0)
    defer { WebPPictureFree(&picture) }
    picture.width = Int32(width)
    picture.height = Int32(height)
    try pixels.withUnsafeBufferPointer { input in
        guard WebPPictureImportRGBA(&picture, input.baseAddress!, Int32(width * 4)) != 0 else {
            throw CocoaError(.coderInvalidValue)
        }
    }
    var writer = WebPMemoryWriter()
    WebPMemoryWriterInit(&writer)
    defer { WebPMemoryWriterClear(&writer) }
    picture.writer = WebPMemoryWrite
    return try withUnsafeMutablePointer(to: &writer) { pointer in
        picture.custom_ptr = UnsafeMutableRawPointer(pointer)
        guard WebPEncode(&config, &picture) != 0 else { throw CocoaError(.coderInvalidValue) }
        return Data(bytes: pointer.pointee.mem!, count: pointer.pointee.size)
    }
}
@MainActor
func allocatedDecode(_ encoded: Data) throws -> Data {
    #if DIRECT_C_COPY || DIRECT_C_INTO
    return try cDecode(encoded)
    #else
    return try decoder.decode(encoded, options: options)
    #endif
}
@MainActor
func encode() throws -> Data {
    #if DIRECT_C_COPY || DIRECT_C_INTO
    return try cEncode()
    #elseif EXPERIMENT_SPAN
    return try encoder.encode(pixels, format: .rgba, config: config,
                              originWidth: width, originHeight: height, stride: width * 4)
    #else
    return try pixels.withUnsafeBufferPointer { buffer in
        unsafe try encoder.encode(buffer, format: .rgba, config: config,
                           originWidth: width, originHeight: height, stride: width * 4)
    }
    #endif
}
if mode == "fixture" {
    let destination = try { () throws -> String in
        guard let fixturePath else { throw CocoaError(.fileNoSuchFile) }
        return fixturePath
    }()
    let encoded = try encode()
    let decoded = try allocatedDecode(encoded)
    try encoded.write(to: URL(fileURLWithPath: destination))
    let metadata: [String: Any] = ["width": width, "height": height,
                                 "decoded_hash": hash(decoded), "encoded_hash": hash(encoded),
                                 "first": Int(decoded.first!), "last": Int(decoded.last!)]
    try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
        .write(to: URL(fileURLWithPath: destination + ".json"))
    exit(0)
}
let encoded: Data
let metadata: [String: Any]
if let fixturePath {
    encoded = try Data(contentsOf: URL(fileURLWithPath: fixturePath))
    metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: fixturePath + ".json"))) as! [String: Any]
    precondition(metadata["width"] as? Int == width && metadata["height"] as? Int == height)
    precondition(hash(encoded) == metadata["encoded_hash"] as? String)
} else {
    precondition(mode == "encode", "Decode, reuse, and inspect require a pre-generated fixture path")
    encoded = try encode()
    metadata = [:]
}
var output = [UInt8](repeating: 0, count: mode == "reuse" ? width * height * 4 : 0)
var checksum = 0
@MainActor
func operation() throws {
    switch mode {
    case "encode":
        let result = try encode()
        precondition(result == encoded)
        checksum &+= result.count
    case "decode":
        let result = try allocatedDecode(encoded)
        precondition(result.count == width * height * 4)
        precondition(Int(result.first!) == metadata["first"] as? Int && Int(result.last!) == metadata["last"] as? Int)
        checksum &+= result.count
    case "reuse":
        #if DIRECT_C_COPY || DIRECT_C_INTO
        let count = try cReuse(encoded, output: &output)
        #else
        let count = try decoder.decode(encoded, into: &output, options: options)
        #endif
        precondition(count == width * height * 4)
        checksum &+= count
    case "inspect":
        let feature = try WebPImageInspector.inspect(encoded)
        precondition(feature.width == width && feature.height == height)
        checksum &+= feature.width
    default: fatalError("mode must be encode, decode, reuse, inspect or fixture")
    }
}
func pool<Result>(_ body: () throws -> Result) rethrows -> Result {
    #if canImport(Darwin)
    return try autoreleasepool(invoking: body)
    #else
    return try body()
    #endif
}
for _ in 0 ..< 3 { try pool { try operation() } }
var samples = [Double]()
for _ in 0 ..< iterations {
    let start = DispatchTime.now().uptimeNanoseconds
    try pool { try operation() }
    samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
}
var usage = rusage()
#if canImport(Darwin)
getrusage(RUSAGE_SELF, &usage)
var info = mach_task_basic_info()
var infoCount = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
let status = withUnsafeMutablePointer(to: &info) { pointer in
    pointer.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &infoCount)
    }
}
let peakRSS = Double(usage.ru_maxrss) / 1_048_576
let finalRSS = status == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : -1
#else
getrusage(Int32(RUSAGE_SELF.rawValue), &usage)
let peakRSS = Double(usage.ru_maxrss) / 1024
let finalRSS = -1.0
#endif
// Full-byte validation runs after memory/timing capture so it cannot inflate reported peak RSS.
var decodedHash = metadata["decoded_hash"] as? String ?? ""
if mode == "decode" || mode == "reuse" {
    let result = mode == "reuse" ? Data(output) : try allocatedDecode(encoded)
    decodedHash = hash(result)
    precondition(decodedHash == metadata["decoded_hash"] as? String)
}
let sorted = samples.sorted()
let record: [String: Any] = [
    "mode": mode, "width": width, "height": height, "iterations": iterations,
    "mean_ms": samples.reduce(0, +) / Double(iterations), "median_ms": sorted[iterations / 2],
    "peak_rss_mib": peakRSS, "final_rss_mib": finalRSS,
    "encoded_bytes": encoded.count, "checksum": checksum,
    "encoded_hash": hash(encoded), "decoded_hash": decodedHash,
]
print(String(decoding: try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]), as: UTF8.self))
