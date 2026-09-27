# Swift-WebP

Swift-WebP provides Swift wrappers around `libwebp` for encoding, decoding, and bitstream inspection.

## Notice

**v0.6.0 tried modernising codebase and made minor breaking changes.**
**See details in [CHANGELOG.md](./CHANGELOG.md)**

## Support Versions

- Minimum Swift version: 6.2 (`swift-tools-version: 6.2` in `Package.swift`)
- Swift language mode: 6
- libwebp: 1.6.0+ (via `libwebp-Xcode`)
- iOS deployment target: 13.0+
- macOS deployment target: 11.0+

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

The local development toolchain is Swift 6.4.0, selected by `.swift-version`. This file does not define the minimum supported Swift version.

Common local commands:

```bash
make format
swift build
swift test
```

`make format` runs the SwiftFormat SPM plugin.

See the [benchmark guide](Benchmark/README.md) for reproducible version comparisons, pipeline benchmarks, metric definitions, and interpretation limits.

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
    rgbaBytes, // [UInt8], Data, or a borrowed Span<UInt8>
    format: .rgba,
    config: .preset(.picture, quality: 95),
    originWidth: width,
    originHeight: height,
    stride: width * 4
)
```

The encoder validates dimensions, stride, and input capacity before calling libwebp. Borrowed spans avoid copying the input storage; C interoperability remains internal.

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

Set either scaled dimension to `0` to infer it while preserving the aspect ratio (after cropping, if enabled). Invalid decoder options throw `WebPDecodingError.invalidParam`.

For configuration checks without decoding, use `WebPDecoderConfig.validate()`. Set its `input` to inspected bitstream features to also validate crop bounds. Validation does not check bitstream integrity or external buffer capacity.

### Decoding into caller-owned memory

```swift
import WebP

let decoder = WebPDecoder()
var options = WebPDecoderOptions()
let required = try decoder.requiredOutputByteCount(for: webPData, options: options, format: .rgba)
var output = [UInt8](repeating: 0, count: required)
let written = try decoder.decode(webPData, into: &output, options: options, format: .rgba)
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

## License

Swift-WebP is available under the MIT license. See [LICENSE](LICENSE).
