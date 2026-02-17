# AGENTS.md

## Purpose

This repository is a Swift wrapper around `libwebp` for encoding, decoding, and inspecting WebP data.
Use this file as the execution guide for ongoing implementation and maintenance work.

## Current Baseline (2026-02-17)

- Swift tools: 6.2 (`swiftLanguageModes: [.v6]`)
- Deployment targets: iOS 17+, macOS 14+
- Dependency:
  - [`libwebp-Xcode`](https://github.com/SDWebImage/libwebp-Xcode.git) 1.5.0+
  - [`SwiftFormat`](https://github.com/nicklockwood/SwiftFormat.git) via SPM plugin
- CI:
  - macOS build + test
  - Linux build + test
  - iOS package build
- Current branch policy from user: perform modernization work on `major-bump`.

## Library Surface (Current)

- Explicit format-driven APIs:
  - `WebPEncoder.encode(_:format:config:originWidth:originHeight:stride:resizeWidth:resizeHeight:)`
  - `WebPDecoder.decode(_:options:format:)`
- Platform decode helpers:
  - `decodeCGImage(from:options:)`
  - `decodeUIImage(from:options:)`
  - `decodeNSImage(from:options:)`
- Internal ownership model uses `~Copyable`, `borrowing`/`consuming`, and `Span`.

## Working Rules For Agents

- Commit meaningful changes in small, reviewable units.
- Run verification commands when needed:
  - `swift build`
  - `swift test`
- Run formatting before final verification when Swift files change:
  - `make format`
- Update `CHANGELOG.md` for notable user-facing changes.
- Release tags must not use a `v` prefix (use `0.x.y`, not `v0.x.y`).
- Never use `swift-actions/setup-swift@v2` in GitHub Actions.

## Recommended Change Flow

1. Implement minimal focused change.
2. Run `make format`.
3. Run `swift build` and `swift test`.
4. Update docs/changelog for any API or behavior change.
5. Commit with clear message.
