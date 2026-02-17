# AGENTS.md

## Purpose

This repository is a Swift wrapper around `libwebp` for encoding, decoding, and inspecting WebP data.
Use this file as the execution guide for modernization and issue-fixing work.

## What The Project Offers Today (as-is)

- Swift Package named `WebP` (`swift-tools-version: 5.10`).
- Platforms: iOS 13+, macOS 11+.
- Dependency: [`libwebp-Xcode`](https://github.com/SDWebImage/libwebp-Xcode.git) (from `1.2.0`).
- Core APIs:
  - `WebPEncoder` for advanced encode paths (RGB/RGBA/etc + platform helpers).
  - `WebPDecoder` for advanced decode paths (multiple colorspaces + `CGImage`/`UIImage`/`NSImage` helpers).
  - `WebPImageInspector` for bitstream feature inspection.

## Current Baseline (checked on 2026-02-17)

- `swift build`: passes.
- `swift test`: fails.
  - Tests still reference legacy path `iOS Example/Resources/...`.
  - Package resources are now under `Tests/WebPTests/Resources`, so path logic is stale.
- Build warning: unhandled file `Sources/WebP/Info.plist`.
- Build warning: retroactive conformance extension in `WebPEncoderConfig.swift`:
  - `extension libwebp.WebPImageHint: ExpressibleByIntegerLiteral`.

## Modernization Priorities

1. Fix test infrastructure first.
   - Replace file-path-based fixtures with `Bundle.module` consistently.
   - Add missing `.webp` fixture to test resources or generate it during tests.
   - Ensure `swift test` is green on macOS runner.
2. Remove legacy/unsafe API patterns.
   - Replace `fatalError` in library code with thrown errors.
   - Remove force unwraps (`!`) in runtime paths where failure is possible.
   - Remove unsafe cast in `CGImage+Util.swift` (`as! CFMutableData`).
3. Resolve Swift 5.10+ compatibility warnings.
   - Address retroactive conformance warning (or avoid the conformance entirely).
   - Exclude or remove stale `Info.plist` in `Sources/WebP`.
4. Update and validate `libwebp-Xcode`.
   - Bump to the latest stable release supported by current Xcode/SPM toolchains.
   - Verify C API compatibility for `WebPConfig`, `WebPDecoderConfig`, and related structs.
   - Re-run `swift build` and `swift test` after bumping to catch ABI/API drift early.
5. Improve API ergonomics without breaking semver unexpectedly.
   - Keep old symbols with deprecation if renaming (for example typo-like names such as `decode(toUImage:)`).
   - Consider adding safer typed wrappers for pixel buffers and decode/encode options.
6. Raise quality gates.
   - Add/refresh GitHub Actions for build+test matrix (macOS, iOS where applicable).
   - Never use `swift-actions/setup-swift@v2`.
   - Enforce formatting/linting if introduced.

## Known Technical Debt Areas

- 2018-era naming and style mixed with modern package settings.
- Option/config structs rely on low-level C mappings with force unwraps.
- Some README/CONTRIBUTING references are stale (Travis, old examples).
- Tests have drifted from repository layout.

## Working Rules For Agents

- Commit meaningful changes in small, reviewable units.
- Run verification commands when needed:
  - `swift build`
  - `swift test`
- Update `CHANGELOG.md` for notable user-facing changes.
- Release tags must not use a `v` prefix (use `0.x.y`, not `v0.x.y`).
- Keep changes source-compatible where practical; deprecate before removing public APIs.

## Recommended Execution Order

1. Make tests green.
2. Eliminate warnings and unsafe crash paths.
3. Modernize API surface with deprecations/migrations.
4. Refresh docs and CI to match current behavior.
