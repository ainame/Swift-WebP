import Foundation
import WebP

let pixels: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255]
let encoder = WebPEncoder()
let config = try WebPEncoderConfig.losslessPreset(level: 6)
let encoded = try encoder.encode(pixels, format: .rgba, config: config,
                                 originWidth: 2, originHeight: 1, stride: 8)
let fromData = try encoder.encode(Data(pixels), format: .rgba, config: config,
                                  originWidth: 2, originHeight: 1, stride: 8)
let fromSpan = try pixels.withUnsafeBufferPointer { buffer in
    try encoder.encode(Span(_unsafeElements: buffer), format: .rgba, config: config,
                       originWidth: 2, originHeight: 1, stride: 8)
}
precondition(encoded == fromData && encoded == fromSpan)
let features = try encoded.withUnsafeBytes { bytes in
    try WebPImageInspector.inspect(Span<UInt8>(_unsafeBytes: bytes))
}
precondition(features.width == 2 && features.height == 1)
let decoder = WebPDecoder()
let options = WebPDecoderOptions()
let decoded = try decoder.decode(encoded, options: options)
precondition(decoded == Data(pixels))
var output = [UInt8](repeating: 0, count: 8)
_ = try decoder.decode(encoded, into: &output, options: options)
precondition(output == pixels)
try output.withUnsafeMutableBufferPointer { buffer in
    var span = MutableSpan(_unsafeElements: buffer)
    _ = try decoder.decode(encoded, into: &span, options: options)
}
precondition(output == pixels)
print("Swift 6.2 consumer: array, Data, Span, MutableSpan, inspection and round-trip passed")
