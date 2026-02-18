# Change Log

All notable changes to this project will be documented in this file.
`WebP` adheres to [Semantic Versioning](http://semver.org/).

## Unreleased

### Breaking

- Replaced `WebPDecBuffer.externalMemoryMode` integer semantics with a strongly typed enum:
  - `WebPDecBuffer.ExternalMemoryMode.internalMemory`
  - `WebPDecBuffer.ExternalMemoryMode.externalMemory`
  - `WebPDecBuffer.ExternalMemoryMode.externalMemorySlow`
- Removed `WebPDecBuffer.isExternalMemory`.
- Made `WebPDecBuffer.privateMemory` internal (no longer public API surface).
- Raised Swift toolchain to `6.2.3` (`.swift-version`) and Swift language mode to `v6` (`swift-tools-version: 6.2`).
- Raised platform baselines to iOS 17+ and macOS 14+.
- Removed old per-format encode/decode method families in favor of explicit format-based entrypoints.
- Renamed platform decoding helpers:
  - `decode(toUImage:options:)` -> `decodeUIImage(from:options:)`
  - `decode(toNSImage:options:)` -> `decodeNSImage(from:options:)`
  - `decode(_:options:)` (CGImage) -> `decodeCGImage(from:options:)`

### Added

- Added standalone `Benchmark` package with `WebPBench` executable for repeatable encode/decode CPU and memory benchmarking with built-in validity checks.
- Added `Scripts/benchmark-resource.sh` and `Scripts/validate-resource.sh` to measure and gate resource usage in local runs.
- Added image-input benchmark mode (`--input`, `--decode-source-each-iteration`) for fairer source-to-source comparisons.
- Added `Scripts/compare-with-cwebp.sh` for side-by-side runs against Homebrew `cwebp`/`dwebp`.
- Added decode buffer sizing and caller-owned decode APIs:
  - `WebPDecoder.requiredOutputByteCount(for:options:format:)`
  - `WebPDecoder.decode(_:into:options:format:)`
- Added `WebPError.outputBufferTooSmall(required:actual:)` to report decode output-capacity errors.
- Added benchmark execution modes (`pipeline`, `source-decode-only`, `encode-only`, `decode-only`) and stage RSS telemetry fields.
- Added decode buffer coverage tests (`WebPDecoderBufferTests`) for exact-size, oversized, undersized, and scaling scenarios.
- Added explicit `Sendable` conformances for core value-oriented public APIs and option/config enums used in concurrency-safe call sites.
- Added `WebPEncoder.encode(_:format:config:originWidth:originHeight:stride:resizeWidth:resizeHeight:)` overload for `UnsafeBufferPointer<UInt8>` inputs.
- Added `WebPDecoder.decode(_:into:options:format:)` overload for `inout [UInt8]` output buffers.
- Deprecated legacy pointer-based encode/decode entrypoints in favor of safer buffer/array overloads.
- `WebPEncodePixelFormat` and `WebPDecodePixelFormat` enums.
- Canonical APIs:
  - `WebPEncoder.encode(_:format:config:originWidth:originHeight:stride:resizeWidth:resizeHeight:)`
  - `WebPDecoder.decode(_:options:format:)`
- Bridging helpers:
  - `WebPEncoder.libwebpVersion`
  - `WebPDecoder.libwebpVersion`
  - `WebPEncoderConfig.losslessPreset(level:)`
  - `WebPEncoderConfig.validate()`
- Internal ownership model with `~Copyable` memory ownership and `Span`-based decode/inspect internals.
- GitHub Actions CI for macOS and Linux package tests.

### Changed

- Updated `WebPDecoder.decode(_:options:format:)` to decode into an exact-size Swift `Data` buffer via libwebp external-memory mode.
- Updated resource scripts to run and validate stage-isolated benchmark modes and stage RSS metrics.
- Updated `libwebp-Xcode` dependency to `1.5.0`.
- Modernized test resources to `Bundle.module` and deterministic fixture generation.
- Memory ownership now frees libwebp-allocated buffers via `WebPFree`.
- Migrated package tests from `XCTest` to Swift Testing (`import Testing`, `@Test`, `#expect`).
- Raw config bridging now uses non-failable contract-based initializers; invalid libwebp enum values are treated as programmer errors (`preconditionFailure`).
- Simplified status code mapping in encode/decode paths to non-optional conversion helpers (no force-unwrap/optional fallback at call sites).

### Fixed

- Fixed `WebPEncoder` cleanup paths to always call `WebPPictureFree` via `defer`, including failed rescale paths.
- Removed runtime `fatalError` paths in core decoding config conversions.
- Replaced unsafe cast in `CGImage` byte access path.
- Resolved retroactive conformance warning in encoder config mappings.
- Simplified CI to run only `swift test` on separate macOS and Linux jobs.
- Linux CI now installs the Swift toolchain via `vapor/swiftly-action`, sourced from `.swift-version`.

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
