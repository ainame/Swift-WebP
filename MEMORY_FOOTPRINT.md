# MEMORY_FOOTPRINT.md

## Goal

Reduce runtime memory footprint in the demo encode/decode pipeline without regressing correctness or throughput.

## Current Status (measured on 2026-02-17)

Environment:
- macOS arm64
- Homebrew `webp` 1.6.0 (`cwebp`, `dwebp`)
- Input image: `Demo/SwiftWebPDemo/Assets.xcassets/jiro.imageset/jiro.jpg` (1210x907)

Command:

```bash
INPUT="$(pwd)/Demo/SwiftWebPDemo/Assets.xcassets/jiro.imageset/jiro.jpg" \
ITERATIONS=30 WARMUP=3 QUALITY=10 \
Scripts/compare-with-cwebp.sh
```

Observed metrics (representative run):
- Swift-WebP (`WebPBench`)
  - `source-decode-only`
    - `source_decode_avg_ms=8.316`
    - `stage_peak_rss_mb=162.297`
    - `peak_rss_mb=168.031`
  - `encode-only`
    - `encode_avg_ms=52.724`
    - `stage_peak_rss_mb=28.766`
    - `peak_rss_mb=29.484`
  - `decode-only`
    - `decode_avg_ms=3.113`
    - `stage_peak_rss_mb=31.688`
    - `peak_rss_mb=31.734`
  - `pipeline`
    - `pipeline_encode_avg_ms=63.088`
    - `encode_avg_ms=52.711`
    - `decode_avg_ms=3.562`
    - `stage_peak_rss_mb=201.812`
    - `peak_rss_mb=206.516`
- `cwebp`/`dwebp`
  - `cwebp_encode_avg_ms=57.378`
  - `dwebp_decode_avg_ms=13.453`
  - `cwebp_peak_rss_mb=7.688`
  - `dwebp_peak_rss_mb=5.188`

## What Was Implemented

1. Stage-isolated benchmark modes + telemetry in `WebPBench`:
- `--mode pipeline|source-decode-only|encode-only|decode-only`
- stage RSS outputs:
  - `rss_after_source_decode_mb`
  - `rss_after_encode_mb`
  - `rss_after_decode_mb`
  - `stage_peak_rss_mb`
  - `peak_rss_mb`

2. Benchmark script updates:
- `Scripts/benchmark-resource.sh`: forwards `MODE` to `WebPBench`
- `Scripts/compare-with-cwebp.sh`: runs all Swift stage modes before CLI comparison
- `Scripts/validate-resource.sh`: validates each mode with separate thresholds

3. Lifetime tightening:
- Added autorelease pool wrappers in `WebPBench` source decode/encode/decode paths.
- Tightened Demo conversion path (`ContentView.swift`) by reusing queue/encoder/decoder and avoiding `try!`.

4. Low-memory decode APIs:
- `WebPDecoder.requiredOutputByteCount(for:options:format:)`
- `WebPDecoder.decode(_:into:options:format:)`
- `WebPDecoder.decode(_:options:format:)` now decodes into exact-size caller-owned `Data` storage.

5. Encoder cleanup safety:
- `WebPPictureFree` now runs via `defer` in `WebPEncoder.encode`, including failed rescale paths.

## High-Level Verdict

- Decode throughput improved materially versus prior baseline in this environment.
- Stage-isolated encode/decode RSS remains above CLI tools, but the largest memory spikes are still in source decode and full pipeline mode.
- Full pipeline peak RSS is currently **not yet near** `cwebp`/`dwebp` levels because pipeline/source-decode modes still retain high process-level RSS under repeated ImageIO/CoreGraphics decode.

## Next Work To Reach cwebp/dwebp Closer

1. Add explicit source decode output buffer reuse in `WebPBench` input path (replace per-iteration fresh `[UInt8]` allocations).
2. Add benchmark option to decode source once and reuse preallocated frame while still measuring pure encode/decode stages.
3. Add optional low-memory platform decode helpers that avoid extra `CFData` bridging copies when creating `CGImage`.
4. Split source decode benchmark into a separate process from encode/decode to avoid process-wide RSS carry-over when comparing with CLI process metrics.

## Commands

```bash
# Full stage + CLI comparison
Scripts/compare-with-cwebp.sh

# Single mode benchmark
MODE=decode-only INPUT="$(pwd)/Demo/SwiftWebPDemo/Assets.xcassets/jiro.imageset/jiro.jpg" \
ITERATIONS=30 WARMUP=3 QUALITY=10 Scripts/benchmark-resource.sh

# Validation with mode-aware thresholds
MAX_STAGE_PEAK_RSS_MB=300 MAX_PIPELINE_PEAK_RSS_MB=300 Scripts/validate-resource.sh
```
