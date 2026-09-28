# Change Log

All notable changes to this project will be documented in this file.
`WebP` adheres to [Semantic Versioning](http://semver.org/).

## Unreleased


### Changed

- **Consumers no longer fetch SwiftFormat.** The SwiftFormat SPM plugin dependency was removed from `Package.swift`; formatting now uses the toolchain-bundled `swift format` (`.swift-format`). Contributors run `make format` / `make lint` as before.

### Fixed

- `decodeCGImage(from:options:)`, `decodeUIImage(from:options:)`, and `decodeNSImage(from:options:)` now decode with premultiplied alpha (`.rgbA`) to match the `CGImage`'s `.premultipliedLast` bitmap info. From 0.3.0 through 0.7.0, semi-transparent pixels were drawn too bright. The image's backing bytes now hold premultiplied RGBA.

## 0.7.0

### Highlights

- **Platform images now encode with correct colors at full resolution.** `UIImage`/`NSImage` encoding handles premultiplied, BGRA, and 16-bit images, and `UIImage` output keeps its full pixel size. ([#68](https://github.com/ainame/Swift-WebP/pull/68))
- **Encode and decode without unsafe pointers.** New overloads take `[UInt8]`, `Data`, `Span`, and `MutableSpan`. ([#66](https://github.com/ainame/Swift-WebP/pull/66))
- **Invalid input fails fast.** Encoder buffers and decoder settings are validated before any memory is read or allocated. ([#65](https://github.com/ainame/Swift-WebP/pull/65), [#66](https://github.com/ainame/Swift-WebP/pull/66))
- **libwebp 1.6.0**, with upstream lossless compression improvements and bug fixes. ([#65](https://github.com/ainame/Swift-WebP/pull/65))

### Breaking

Source-compatible, but some calls now behave differently at runtime:

- Encoder inputs must contain `stride * originHeight` bytes, including final-row padding, matching libwebp's documented contract. Compact padded buffers that the unchecked pointer API previously accepted now throw `invalidParameter`. ([#66](https://github.com/ainame/Swift-WebP/pull/66))
- `UIImage` encoding no longer downscales `@2x`/`@3x` images to their point size; output now has the image's full pixel dimensions. To keep the previous size, pass `width`/`height` in points. ([#68](https://github.com/ainame/Swift-WebP/pull/68))

### Added

- **`CGImage` layout normalization:** `WebPEncoder.encode(normalizing:config:resizeWidth:resizeHeight:)` converts premultiplied, BGRA, 16-bit, and other layouts to straight-alpha RGBA before encoding. The existing `encode(_:format:config:resizeWidth:resizeHeight:)` still encodes the backing bytes as-is. ([#68](https://github.com/ainame/Swift-WebP/pull/68))
- **Safe buffer APIs** ([#66](https://github.com/ainame/Swift-WebP/pull/66)):
  - Encoding from `[UInt8]`, `Data`, or a borrowed `Span<UInt8>`.
  - Decoding into a caller-provided `MutableSpan<UInt8>`.
  - `WebPImageInspector.inspect(_:)` for a borrowed `Span<UInt8>`.
- **Decoder config validation:** `WebPDecoderConfig.validate()`, backed by libwebp's decoder configuration validation. ([#65](https://github.com/ainame/Swift-WebP/pull/65))

### Changed

- **Dependency:** raised the `libwebp-Xcode` minimum to `1.6.0`. Projects that pin `libwebp-Xcode` below `1.6.0` need to relax that pin. ([#65](https://github.com/ainame/Swift-WebP/pull/65))
- **Decoder errors:** invalid decoder settings are now rejected up front with `WebPDecodingError.invalidParam`, before any output buffer is allocated. ([#65](https://github.com/ainame/Swift-WebP/pull/65))

### Fixed

- **Platform image colors:** `NSImage` and `UIImage` encoding no longer assumes straight RGBA, fixing darkened translucent colors and swapped red/blue channels for premultiplied, BGRA, or 16-bit images (e.g. from drawing or screen capture). Straight 8-bit layouts such as decoded PNGs and JPEGs are still encoded from their backing bytes without a copy. Thanks to [macshot](https://github.com/sw33tLie/macshot) for documenting the workaround that exposed this issue. ([#68](https://github.com/ainame/Swift-WebP/pull/68))
- **Encoder memory safety** ([#66](https://github.com/ainame/Swift-WebP/pull/66)):
  - Input capacity, row stride, and dimensions are validated before pixel memory is read, including in the deprecated raw-pointer encoder.
  - CoreGraphics pixel storage is retained for the whole duration of encoding.
  - Partially written encoder output is freed on failure.
- **Decoder cropping and scaling** ([#65](https://github.com/ainame/Swift-WebP/pull/65)):
  - Output buffers are sized correctly when one scaled dimension is zero, including scaling after cropping and rounding up inferred dimensions.
  - Crop origins stay exact for lossless images and snap to even pixels only for lossy images.
  - Platform image helpers use the resolved output dimensions for cropping and inferred scaling.

### Performance

- **Fewer allocations when decoding** ([#66](https://github.com/ainame/Swift-WebP/pull/66)):
  - Output is written into an uninitialized allocation handed directly to `Data` on success, avoiding zero-filling and a duplicate layout inspection.
  - Bitstream feature inspection uses a stack-local C structure instead of a heap allocation.
- **Lighter Foundation dependency on Linux:** core `Data` APIs come from `FoundationEssentials` when available, and unused Foundation imports were removed. ([#67](https://github.com/ainame/Swift-WebP/pull/67))

### Demo

- Added a visual comparison of the old platform image encoding bugs against the corrected WebP output. ([#68](https://github.com/ainame/Swift-WebP/pull/68))

## 0.6.1

### Changed

- Lowered the minimum deployment targets back to iOS 13+ and macOS 11+, reverting the iOS 17+ / macOS 14+ baseline introduced in 0.6.0. This only widens platform support and is not breaking. ([#64](https://github.com/ainame/Swift-WebP/pull/64))

### Demo

- Added the missing shared `SwiftWebPDemo` scheme.

## 0.6.0

Git tag naming convention now removes `v` prefix. ([#62](https://github.com/ainame/Swift-WebP/pull/62))

### Breaking

- Replaced `WebPDecBuffer.externalMemoryMode` integer semantics with a strongly typed enum ([#62](https://github.com/ainame/Swift-WebP/pull/62)):
  - `WebPDecBuffer.ExternalMemoryMode.internalMemory`
  - `WebPDecBuffer.ExternalMemoryMode.externalMemory`
  - `WebPDecBuffer.ExternalMemoryMode.externalMemorySlow`
- Removed `WebPDecBuffer.isExternalMemory`. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Made `WebPDecBuffer.privateMemory` internal (no longer public API surface). ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Raised Swift toolchain to `6.2.3` (`.swift-version`) and Swift language mode to `v6` (`swift-tools-version: 6.2`). ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Raised platform baselines to iOS 17+ and macOS 14+. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Removed old per-format encode/decode method families in favor of explicit format-based entrypoints. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Renamed platform decoding helpers ([#62](https://github.com/ainame/Swift-WebP/pull/62)):
  - `decode(toUImage:options:)` -> `decodeUIImage(from:options:)`
  - `decode(toNSImage:options:)` -> `decodeNSImage(from:options:)`
  - `decode(_:options:)` (CGImage) -> `decodeCGImage(from:options:)`

### Added

- Added standalone `Benchmark` package with `WebPBench` executable for repeatable encode/decode CPU and memory benchmarking with built-in validity checks. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Added `Scripts/benchmark-resource.sh` and `Scripts/validate-resource.sh` to measure and gate resource usage in local runs. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Added image-input benchmark mode (`--input`, `--decode-source-each-iteration`) for fairer source-to-source comparisons. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Added `Scripts/compare-with-cwebp.sh` for side-by-side runs against Homebrew `cwebp`/`dwebp`. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Added decode buffer sizing and caller-owned decode APIs ([#62](https://github.com/ainame/Swift-WebP/pull/62)):
  - `WebPDecoder.requiredOutputByteCount(for:options:format:)`
  - `WebPDecoder.decode(_:into:options:format:)`
- Added `WebPError.outputBufferTooSmall(required:actual:)` to report decode output-capacity errors. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Added benchmark execution modes (`pipeline`, `source-decode-only`, `encode-only`, `decode-only`) and stage RSS telemetry fields. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Added decode buffer coverage tests (`WebPDecoderBufferTests`) for exact-size, oversized, undersized, and scaling scenarios. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Added explicit `Sendable` conformances for core value-oriented public APIs and option/config enums used in concurrency-safe call sites. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Added `WebPEncoder.encode(_:format:config:originWidth:originHeight:stride:resizeWidth:resizeHeight:)` overload for `UnsafeBufferPointer<UInt8>` inputs. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Added `WebPDecoder.decode(_:into:options:format:)` overload for `inout [UInt8]` output buffers. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Deprecated legacy pointer-based encode/decode entrypoints in favor of safer buffer/array overloads. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- `WebPEncodePixelFormat` and `WebPDecodePixelFormat` enums. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Canonical APIs ([#62](https://github.com/ainame/Swift-WebP/pull/62)):
  - `WebPEncoder.encode(_:format:config:originWidth:originHeight:stride:resizeWidth:resizeHeight:)`
  - `WebPDecoder.decode(_:options:format:)`
- Bridging helpers ([#62](https://github.com/ainame/Swift-WebP/pull/62)):
  - `WebPEncoder.libwebpVersion`
  - `WebPDecoder.libwebpVersion`
  - `WebPEncoderConfig.losslessPreset(level:)`
  - `WebPEncoderConfig.validate()`
- Internal decode/inspect implementation uses `Span`-based internals. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- GitHub Actions CI for macOS and Linux package tests. ([#62](https://github.com/ainame/Swift-WebP/pull/62))

### Changed

- Updated `WebPDecoder.decode(_:options:format:)` to decode into an exact-size Swift `Data` buffer via libwebp external-memory mode. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Updated resource scripts to run and validate stage-isolated benchmark modes and stage RSS metrics. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Updated `libwebp-Xcode` dependency to `1.5.0`. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Modernized test resources to `Bundle.module` and deterministic fixture generation. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Memory ownership now frees libwebp-allocated buffers via `WebPFree`. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Migrated package tests from `XCTest` to Swift Testing (`import Testing`, `@Test`, `#expect`). ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Raw config bridging now uses non-failable contract-based initializers; invalid libwebp enum values are treated as programmer errors (`preconditionFailure`). ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Simplified status code mapping in encode/decode paths to non-optional conversion helpers (no force-unwrap/optional fallback at call sites). ([#62](https://github.com/ainame/Swift-WebP/pull/62))

### Fixed

- Fixed `WebPEncoder` cleanup paths to always call `WebPPictureFree` via `defer`, including failed rescale paths. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Removed runtime `fatalError` paths in core decoding config conversions. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Replaced unsafe cast in `CGImage` byte access path. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Resolved retroactive conformance warning in encoder config mappings. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Simplified CI to run only `swift test` on separate macOS and Linux jobs. ([#62](https://github.com/ainame/Swift-WebP/pull/62))
- Linux CI now installs the Swift toolchain via `vapor/swiftly-action`, sourced from `.swift-version`. ([#62](https://github.com/ainame/Swift-WebP/pull/62))

### Migration Guide

- Encoding (old): `encode(RGBA:ptr, config:..., originWidth:..., originHeight:..., stride:...)`
- Encoding (new): `encode(ptr, format: .rgba, config:..., originWidth:..., originHeight:..., stride:...)`
- Decoding bytes (old): `decode(byRGBA:data, options:...)`
- Decoding bytes (new): `decode(data, options:..., format: .rgba)`
- Decoding `CGImage` (old): `decode(data, options:...)`
- Decoding `CGImage` (new): `decodeCGImage(from: data, options:...)`

## v0.5.0

### Enhanced

- Bumped libwebp version to v1.2.0 or newer depending on libwebp-Xcode via SPM

### Changed

- Switched the source of libwebp from git submodule to libwebp-Xcode
- Demo app is updated in SwiftUI

## v0.4.0

### Enhanced

- Bump embeded libwebp version to v1.1.0 (was v1.0.3)

## v0.3.0

- Added `WebPDecoder.encode(RGBA cgImage: CGImage, ...)` and so on for ainame/Swift-WebP#40

## v0.2.0

### Enhanced

- Make WebPImageInspector publicly exposed
- Added `WebPDecoder.decode(toUIImage:, options:)` and `WebPDecoder.decode(toNSImage:, options:)`
- Bump embeded libwebp version to v1.0.3 (was v1.0.0)
- Add -fembed-bitcode flag to CFLAGS when compiling libwebp for iOS

## v0.1.0

### Changed

- Add WebPImageInspector internally

### Bug fix

- Fixed a memory issue in WebPDecoder+Platform.swift

## v0.0.10

### Changed

- Support swift-tools-version 5.0 to build with swift package manager

## v0.0.9

### Changed

- Support Xcode 10.2's build and Swift 5

## v0.0.8

### Bug fix

Fixed wrong file paths of WebPDecoder

## v0.0.7

### Changed

- Added WebPDecoder

### Removed

- WebPSimple.decode

## v0.0.7

### Changed

Support Xcode10 and Swift4.2 (nothing changed at all)

## v0.0.5

### Changed

- Update libwebp v0.60 -> v1.0.0
- Now WebPEncoder supports iOS platform

### Bug fix

- Handle use_argb flag properly

### Removed

- WebPSimple.encode
