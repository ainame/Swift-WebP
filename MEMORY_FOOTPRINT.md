# MEMORY_FOOTPRINT.md

## Goal

Reduce runtime memory footprint in the demo encode/decode pipeline without regressing correctness or throughput.

This document is for the next agent to continue memory optimization with clear baseline data and a concrete work plan.

## Current Baseline (measured on 2026-02-17)

Environment:
- macOS arm64
- Homebrew `webp` 1.6.0 (`cwebp`, `dwebp`)
- Input image: `Demo/SwiftWebPDemo/Assets.xcassets/jiro.imageset/jiro.jpg` (1210x907)

Command:

```bash
Scripts/compare-with-cwebp.sh
```

Observed metrics (representative run):
- WebPBench
  - `pipeline_encode_avg_ms=60.165`
  - `encode_avg_ms=48.657`
  - `decode_avg_ms=6.484`
  - `peak_rss_mb=170.547`
- cwebp/dwebp
  - `cwebp_encode_avg_ms=57.370`
  - `dwebp_decode_avg_ms=13.862`
  - `cwebp_peak_rss_mb=7.688`
  - `dwebp_peak_rss_mb=5.188`

## High-Level Verdict

- CPU: library encode/decode performance is competitive.
- Memory: process peak RSS is significantly higher than `cwebp`/`dwebp` single-command runs.

## Important Context

1. RSS is process-level and not perfectly apples-to-apples:
- `WebPBench` runs source decode + encode + decode in one process repeatedly.
- `cwebp` and `dwebp` are measured as separate short-lived processes.

2. Even with that caveat, there is still likely optimization headroom in temporary buffer allocation and lifetime management.

## Suspected Memory Hotspots

1. Repeated source image decode to RGBA in `WebPBench` input mode (`--decode-source-each-iteration`).
2. Large temporary allocations in ImageIO/CoreGraphics conversion path.
3. Buffer lifetime overlap between:
- source RGBA bytes
- encoded WebP `Data`
- decoded RGBA output `Data`
4. Potential autorelease accumulation on Apple frameworks in tight loops.

## Next-Agent Action Plan

1. Add per-stage memory telemetry in `Sources/WebPBench/main.swift`:
- report RSS after source decode
- report RSS after encode
- report RSS after decode
- report stage deltas

2. Isolate scenarios in benchmark script:
- source decode only
- encode only (preloaded RGBA)
- decode only (fixed WebP blob)
- full pipeline (current)

3. Tighten object lifetimes in benchmark loop:
- ensure large intermediates go out of scope ASAP
- add `autoreleasepool {}` around source decode on Apple platforms

4. Evaluate output buffer reuse options for decoder:
- investigate libwebp external-memory decode mode to reuse caller-owned buffers
- measure effect on RSS and throughput

5. Verify memory behavior in Demo path (`ContentView.swift`):
- avoid recreating queue/encoder/decoder per tap
- ensure conversion closure scope releases intermediates promptly

6. Add a memory guardrail command for CI/local regression checks:
- keep existing `Scripts/validate-resource.sh`
- add a separate profile preset focused on memory footprint at demo image size

## Acceptance Criteria for Memory Improvement Work

1. Keep correctness:
- benchmark must still print `valid=true`
- no decode dimension/size mismatches

2. Keep performance roughly stable:
- no >10% encode/decode regression versus current baseline on same machine

3. Reduce peak RSS materially:
- target at least 20% reduction in WebPBench full pipeline mode on demo image

## Commands for Next Agent

```bash
# Baseline full comparison
Scripts/compare-with-cwebp.sh

# Library-only benchmark with image source decode each iteration
INPUT="$(pwd)/Demo/SwiftWebPDemo/Assets.xcassets/jiro.imageset/jiro.jpg" \
SOURCE_DECODE_PER_ITERATION=on \
ITERATIONS=30 WARMUP=3 QUALITY=10 \
Scripts/benchmark-resource.sh

# Validation (override thresholds as needed)
MAX_PEAK_RSS_MB=170 Scripts/validate-resource.sh
```
