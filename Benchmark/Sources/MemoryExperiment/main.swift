#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation
import WebP

// One operation per process: avoid source decoding and cross-stage RSS carry-over.
let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "decode"
let width = args.count > 2 ? Int(args[2])! : 1920
let height = args.count > 3 ? Int(args[3])! : 1080
let iterations = args.count > 4 ? Int(args[4])! : 30
precondition(width > 0 && height > 0 && iterations > 0)
let encoder = WebPEncoder()
let decoder = WebPDecoder()
let config = WebPEncoderConfig.preset(.picture, quality: 75)
var options = WebPDecoderOptions()
options.useThreads = false
let pixels = (0 ..< width * height * 4).map { i -> UInt8 in
    if i % 4 == 3 { return 255 }
    let pixel = i / 4
    return UInt8(truncatingIfNeeded: (pixel % width) * 3 + (pixel / width) * 7 + (i % 4) * 53)
}
@MainActor
func encode() throws -> Data {
    #if EXPERIMENT_SPAN
    return try encoder.encode(pixels, format: .rgba, config: config,
                              originWidth: width, originHeight: height, stride: width * 4)
    #else
    return try pixels.withUnsafeBufferPointer { buffer in
        try encoder.encode(buffer, format: .rgba, config: config,
                           originWidth: width, originHeight: height, stride: width * 4)
    }
    #endif
}
let encoded = try encode()
let expected = try decoder.decode(encoded, options: options)
precondition(expected.count == pixels.count)
var output = [UInt8](repeating: 0, count: mode == "reuse" ? pixels.count : 0)
var checksum = 0
@MainActor
func operation() throws {
    switch mode {
    case "encode":
        let result = try encode()
        precondition(result == encoded)
        checksum &+= result.count
    case "decode":
        let result = try decoder.decode(encoded, options: options)
        precondition(result.count == expected.count && result.first == expected.first && result.last == expected.last)
        checksum &+= result.count
    case "reuse":
        let count = try decoder.decode(encoded, into: &output, options: options)
        precondition(count == expected.count)
        checksum &+= count
    case "inspect":
        let feature = try WebPImageInspector.inspect(encoded)
        precondition(feature.width == width && feature.height == height)
        checksum &+= feature.width
    default: fatalError("mode must be encode, decode, reuse or inspect")
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
if mode == "reuse" { precondition(Data(output) == expected) }
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
func hash(_ data: Data) -> String {
    var value: UInt64 = 14695981039346656037
    for byte in data { value = (value ^ UInt64(byte)) &* 1099511628211 }
    return String(value, radix: 16)
}
let sorted = samples.sorted()
let record: [String: Any] = [
    "mode": mode, "width": width, "height": height, "iterations": iterations,
    "mean_ms": samples.reduce(0, +) / Double(iterations), "median_ms": sorted[iterations / 2],
    "peak_rss_mib": peakRSS,
    "final_rss_mib": finalRSS,
    "encoded_bytes": encoded.count, "checksum": checksum,
    "encoded_hash": hash(encoded), "decoded_hash": hash(expected),
]
print(String(decoding: try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]), as: UTF8.self))
