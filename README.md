# Swift-WebP

Swift-WebP provides Swift wrappers around `libwebp` for encoding, decoding, and bitstream inspection.

## Support Versions

- Swift toolchain: 6.2.3 (`.swift-version`)
- Swift language mode: 6
- libwebp-Xcode: 1.5.0+
- iOS deployment target: 17.0+
- macOS deployment target: 14.0+

## Features

- Swift Package Manager support
- Advanced encoding via `WebPEncoder` + `WebPEncoderConfig`
- Advanced decoding via `WebPDecoder` + `WebPDecoderOptions`
- WebP bitstream inspection via `WebPImageInspector`
- Cross-platform core APIs (Apple platforms + Linux)

## Installation

Add Swift-WebP in your `Package.swift`:

```swift
.package(url: "https://github.com/ainame/Swift-WebP.git", from: "0.6.0")
```

## Development

Common local commands:

```bash
make format
swift build
swift test
```

`make format` runs the SwiftFormat SPM plugin.

Resource benchmark + validation:

```bash
Scripts/benchmark-resource.sh
Scripts/validate-resource.sh
Scripts/compare-with-cwebp.sh
```

You can tune benchmark parameters with env vars such as:
`MODE=pipeline|source-decode-only|encode-only|decode-only`,
`WIDTH`, `HEIGHT`, `ITERATIONS`, `WARMUP`, `QUALITY`, `THREADS_FLAG=off`,
`INPUT=/absolute/path/to/image`, `SOURCE_DECODE_PER_ITERATION=on`.
Validation thresholds can be tuned with:
`MAX_SOURCE_DECODE_AVG_MS`, `MAX_ENCODE_AVG_MS`, `MAX_DECODE_AVG_MS`,
`MAX_PIPELINE_ENCODE_AVG_MS`, `MAX_ENCODE_P95_MS`, `MAX_DECODE_P95_MS`,
`MAX_STAGE_PEAK_RSS_MB`, `MAX_PIPELINE_PEAK_RSS_MB`.

## Usage

### Encoding

```swift
import WebP

let encoder = WebPEncoder()
let data = try encoder.encode(
    rgbaPointer,
    format: .rgba,
    config: .preset(.picture, quality: 95),
    originWidth: width,
    originHeight: height,
    stride: width * 4
)
```

### Decoding to raw pixel bytes

```swift
import WebP

let decoder = WebPDecoder()
var options = WebPDecoderOptions()
options.useScaling = true
options.scaledWidth = targetWidth
options.scaledHeight = targetHeight

let rgbaData = try decoder.decode(webPData, options: options, format: .rgba)
```

### Decoding into caller-owned memory

```swift
import WebP

let decoder = WebPDecoder()
var options = WebPDecoderOptions()
let required = try decoder.requiredOutputByteCount(for: webPData, options: options, format: .rgba)
var output = [UInt8](repeating: 0, count: required)
let written = try output.withUnsafeMutableBufferPointer { buffer in
    try decoder.decode(webPData, into: buffer, options: options, format: .rgba)
}
print("decoded bytes:", written)
```

### Decoding to platform images

```swift
#if canImport(CoreGraphics)
let cgImage = try decoder.decodeCGImage(from: webPData, options: options)
#endif

#if canImport(UIKit)
let image = try decoder.decodeUIImage(from: webPData, options: options)
#endif

#if canImport(AppKit)
let image = try decoder.decodeNSImage(from: webPData, options: options)
#endif
```

### Inspecting WebP metadata

```swift
let feature = try WebPImageInspector.inspect(webPData)
print(feature.width, feature.height, feature.hasAlpha, feature.hasAnimation)
```

## Ownership Model (Internals)

Public APIs are intentionally `Data`-centric for ergonomics.
Internally, the package uses Swift ownership features (`~Copyable`, `borrowing`, `consuming`) and `Span` to safely manage C-allocated buffers and reduce copying across hot decode/inspect paths.

## License

Swift-WebP is available under the MIT license. See [LICENSE](LICENSE).
