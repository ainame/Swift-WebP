# Swift-WebP

**Fast, memory-safe WebP encoding and decoding for Swift.**

Correct colors, full resolution, no unsafe pointers. From `UIImage`, `NSImage`, `CGImage`, or raw bytes.

[![CI](https://github.com/ainame/Swift-WebP/actions/workflows/ci.yml/badge.svg)](https://github.com/ainame/Swift-WebP/actions/workflows/ci.yml)
[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2013%2B%20%7C%20macOS%2011%2B%20%7C%20Linux-blue)](#requirements)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen)](#installation)
[![libwebp 1.6.0](https://img.shields.io/badge/libwebp-1.6.0-4285F4)](https://chromium.googlesource.com/webm/libwebp)
[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

[Quick start](#quick-start) •
[Why Swift-WebP?](#why-swift-webp) •
[Installation](#installation) •
[Usage](#usage) •
[FAQ](#faq) •
[Changelog](CHANGELOG.md)

---

## Quick start

```swift
import WebP

// Encode: UIImage / NSImage / CGImage → WebP
let webPData = try WebPEncoder().encode(image, config: .preset(.photo, quality: 80))

// Decode: WebP → UIImage / NSImage / CGImage
let decoded = try WebPDecoder().decodeUIImage(from: webPData, options: WebPDecoderOptions())
```

That's all you need. No pointers to manage, no buffers to free, and no color conversion code to write.

## Why Swift-WebP?

WebP files are often [25–34% smaller than JPEG](https://developers.google.com/speed/webp/docs/webp_study) and support transparency, so you save bandwidth, storage, and load time. Calling `libwebp` from Swift directly is error-prone, though. Swift-WebP takes care of the hard parts.

- 🛡️ **No unsafe code in your app.** Pass `[UInt8]`, `Data`, or `Span<UInt8>`. The library owns every C allocation and frees it, even on failure.
- 🎨 **Correct colors by default.** Premultiplied, BGRA, and 16-bit images from drawing, rendering, or screen capture are normalized before encoding.
- 🔍 **Full Retina resolution.** `@2x`/`@3x` `UIImage`s are encoded at their full pixel size.
- 🚦 **Fails fast with Swift errors.** Dimensions, stride, buffer capacity, and decoder options are checked before any memory is read or allocated.
- ⚡️ **Low allocation.** Output is written straight into the returned `Data` without an extra copy, and you can decode into your own reusable buffer.
- 📐 **Scale and crop while decoding.** libwebp resizes during decoding, so a thumbnail never needs a full-size bitmap.
- 🧵 **Built for Swift 6.** Uses Swift 6 language mode with strict memory-safety checking, and the public types are `Sendable`.
- 🐧 **Runs on Linux.** The core APIs work on Linux with a lightweight `FoundationEssentials` dependency.
- 🎛️ **Full libwebp control.** Presets, lossless levels 0–9, target size or PSNR, near-lossless, alpha quality, multithreading, and more.

### Is it the right fit?

Swift-WebP is a focused codec library. It converts between WebP and pixels or images, and leaves downloading, caching, and display to you. That makes it a good fit for image pipelines, upload processing, export features, and server-side conversion.

If you want WebP support inside an image-loading framework, or animated WebP playback, [SDWebImageWebPCoder](https://github.com/SDWebImage/SDWebImageWebPCoder) is a better fit.

## Requirements

| | Minimum |
|---|---|
| Swift | 6.2 (Swift 6 language mode) |
| iOS | 13.0 |
| macOS | 11.0 |
| Linux | Any platform supported by Swift 6.2 (core APIs) |
| libwebp | 1.6.0, via [`libwebp-Xcode`](https://github.com/SDWebImage/libwebp-Xcode) (resolved automatically) |

## Installation

### Swift Package Manager

Add Swift-WebP to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ainame/Swift-WebP.git", from: "0.7.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "WebP", package: "Swift-WebP")
    ])
]
```

### Xcode

**File → Add Package Dependencies…**, then paste:

```text
https://github.com/ainame/Swift-WebP.git
```

> [!IMPORTANT]
> **Upgrading to 0.7.0?** Encoder input validation is stricter, and `UIImage` encoding now outputs the full pixel size instead of the point size. See the [CHANGELOG](CHANGELOG.md#070) for migration details.

## Usage

### Encode a platform image

```swift
import WebP

let encoder = WebPEncoder()

// iOS: UIImage, macOS: NSImage
let data = try encoder.encode(image, config: .preset(.photo, quality: 80))

// Resize while encoding (set both width and height; 0 keeps the original size)
let thumb = try encoder.encode(image, config: .preset(.photo, quality: 80), width: 320, height: 240)
```

### Encode a `CGImage`

```swift
// Works with any bitmap layout: premultiplied, BGRA, and 16-bit images are converted first.
let data = try encoder.encode(normalizing: cgImage, config: .preset(.picture, quality: 95))

// Encodes the backing bytes as-is (no copy). `format` must match the image's layout with straight alpha.
let raw = try encoder.encode(cgImage, format: .rgba, config: .preset(.picture, quality: 95))
```

> [!TIP]
> If you're not sure which one to use, use `encode(normalizing:)`. Images from drawing or screen capture are premultiplied. The `UIImage` and `NSImage` encoders use `encode(normalizing:)` too.

### Encode raw pixels

```swift
let data = try encoder.encode(
    rgbaBytes, // [UInt8], Data, or a borrowed Span<UInt8>
    format: .rgba, // .rgb, .rgba, .rgbx, .bgr, .bgra, .bgrx
    config: .preset(.picture, quality: 95),
    originWidth: width,
    originHeight: height,
    stride: width * 4
)
```

The encoder validates dimensions, stride, and input capacity. Provide at least `stride * originHeight` bytes, including padding after the final row. Borrowed spans avoid copying the input storage.

### Choose a config

```swift
// Lossy, tuned for a type of content: .default, .picture, .photo, .drawing, .icon, .text
let lossy = WebPEncoderConfig.preset(.photo, quality: 80)

// Lossless, level 0 (fastest) to 9 (smallest)
let lossless = try WebPEncoderConfig.losslessPreset(level: 6)

// Or adjust individual libwebp options
var custom = WebPEncoderConfig.preset(.picture, quality: 90)
custom.method = 6 // slower encoding, smaller output
custom.alphaQuality = 80
custom.threadLevel = 1 // enable multithreaded encoding
```

### Decode to a platform image

```swift
let decoder = WebPDecoder()
let options = WebPDecoderOptions()

#if canImport(UIKit)
let image = try decoder.decodeUIImage(from: webPData, options: options)
#elseif canImport(AppKit)
let image = try decoder.decodeNSImage(from: webPData, options: options)
#endif

let cgImage = try decoder.decodeCGImage(from: webPData, options: options)
```

### Decode a thumbnail (scale and crop while decoding)

```swift
var options = WebPDecoderOptions()
options.useScaling = true
options.scaledWidth = 200
options.scaledHeight = 0 // 0 = infer from the aspect ratio

let thumbnail = try decoder.decodeCGImage(from: webPData, options: options)
```

Set either scaled dimension to `0` to infer it while preserving the aspect ratio (after cropping, if enabled). Enable `useCropping` and set `cropLeft`, `cropTop`, `cropWidth`, and `cropHeight` to crop before scaling. Invalid decoder options throw `WebPDecodingError.invalidParam`.

### Decode to raw pixel bytes

```swift
let rgbaData = try decoder.decode(webPData, options: options, format: .rgba)
```

### Decode into a reusable buffer

Allocate the buffer once and reuse it for every frame or tile:

```swift
let required = try decoder.requiredOutputByteCount(for: webPData, options: options, format: .rgba)
var output = [UInt8](repeating: 0, count: required)
let written = try decoder.decode(webPData, into: &output, options: options, format: .rgba)
```

`decode(_:into:)` also accepts an `inout MutableSpan<UInt8>`.

### Inspect before decoding

Read the dimensions and flags from the header without decoding any pixels. For example, you can reject large uploads before they use memory:

```swift
let info = try WebPImageInspector.inspect(webPData)
guard info.width * info.height <= 4096 * 4096 else { throw UploadError.tooLarge }
print(info.width, info.height, info.hasAlpha, info.hasAnimation, info.format) // format: .lossy / .lossless
```

### Handle errors

All APIs throw typed Swift errors, so a bad input doesn't crash your app:

```swift
do {
    let data = try encoder.encode(bytes, format: .rgba, config: config,
                                  originWidth: w, originHeight: h, stride: w * 4)
} catch WebPEncoderError.invalidParameter {
    // Buffer too small, bad stride, or bad dimensions
} catch let status as WebPEncodeStatusCode {
    // libwebp encoder error, e.g. .badDimension or .fileTooBig
}
```

## Feature matrix

| Feature | iOS | macOS | Linux |
|---|:-:|:-:|:-:|
| Encode `[UInt8]` / `Data` / `Span` | ✅ | ✅ | ✅ |
| Decode to `Data` / `[UInt8]` / `MutableSpan` | ✅ | ✅ | ✅ |
| Scale and crop while decoding | ✅ | ✅ | ✅ |
| Header inspection | ✅ | ✅ | ✅ |
| `CGImage` encode and decode | ✅ | ✅ | — |
| `UIImage` encode and decode | ✅ | — | — |
| `NSImage` encode and decode | — | ✅ | — |
| Animated WebP | Detection only (`hasAnimation`) | | |

## FAQ

<details>
<summary><b>My translucent pixels look darker, or red and blue are swapped.</b></summary>

You're probably passing a premultiplied or BGRA `CGImage` to `encode(_:format:)`. Use `encode(normalizing:)` instead, or the `UIImage`/`NSImage` overloads, which normalize the image for you. Upgrading to 0.7.0+ fixes this for platform images.
</details>

<details>
<summary><b>My encoded <code>UIImage</code> got bigger after upgrading to 0.7.0.</b></summary>

0.7.0 encodes the full pixel size (for example, 3× the point size on a `@3x` device). To keep the old size, pass `width` and `height` in points.
</details>

<details>
<summary><b>Why does encoding throw <code>invalidParameter</code> for my buffer?</b></summary>

The input must contain at least `stride * originHeight` bytes, including any padding after the last row, as libwebp requires. Earlier versions didn't check this and could read past the end of the buffer.
</details>

<details>
<summary><b>Which libwebp version am I running?</b></summary>

```swift
print(WebPEncoder.libwebpVersion, WebPDecoder.libwebpVersion) // e.g. 1.6.0
```
</details>

## Demo app

[`Demo/`](Demo/README.md) contains an iOS app that shows the library in action, including before/after comparisons of the color and resolution fixes. Open `Demo/SwiftWebPDemo.xcodeproj` and run the `SwiftWebPDemo` scheme.

## Development

```bash
make format   # toolchain-bundled swift-format
swift build
swift test
```

The local toolchain is Swift 6.4.0, selected by `.swift-version`. It doesn't define the minimum supported Swift version. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow.

The library enables strict memory-safety checking. Intentional C operations are marked with `unsafe` at the interoperability boundary. The pointer-based APIs and low-level buffer configuration remain unsafe interfaces. The Array, `Data`, and Span entry points handle those requirements internally.

<details>
<summary><b>Benchmarks</b></summary>

See the [benchmark guide](Benchmark/README.md) for reproducible version comparisons, pipeline benchmarks, metric definitions, and interpretation limits.

```bash
Scripts/benchmark-resource.sh
Scripts/validate-resource.sh
Scripts/compare-with-cwebp.sh
```

You can tune benchmark parameters with environment variables such as
`MODE=pipeline|source-decode-only|encode-only|decode-only`,
`WIDTH`, `HEIGHT`, `ITERATIONS`, `WARMUP`, `QUALITY`, `THREADS_FLAG=off`,
`INPUT=/absolute/path/to/image`, and `SOURCE_DECODE_PER_ITERATION=on`.

Tune validation thresholds with
`MAX_SOURCE_DECODE_AVG_MS`, `MAX_ENCODE_AVG_MS`, `MAX_DECODE_AVG_MS`,
`MAX_PIPELINE_ENCODE_AVG_MS`, `MAX_ENCODE_P95_MS`, `MAX_DECODE_P95_MS`,
`MAX_STAGE_PEAK_RSS_MB`, and `MAX_PIPELINE_PEAK_RSS_MB`.
</details>

## Contributing

Issues and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first, and add user-facing changes to [CHANGELOG.md](CHANGELOG.md).

## License

Swift-WebP is available under the MIT license. See [LICENSE](LICENSE).
