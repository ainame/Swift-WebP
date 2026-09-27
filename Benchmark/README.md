# Benchmarking Swift-WebP

Use the isolated comparison harness to evaluate library changes. Use `WebPBench` to examine image loading and the application pipeline. Their memory measurements cover different work and should not be compared directly.

Run commands below from the repository root. Use one explicit Swift toolchain, SDK, dependency lock, image/settings, and machine throughout a comparison. The benchmark package targets macOS 14+; this does not change the library's deployment targets. Core synthetic workloads have Linux code paths, but this experiment was validated on macOS. ImageIO input loading, the allocation probe, and the CLI RSS comparison require macOS. Python 3 is needed for the comparison helpers.

## Choose a tool

| Tool | Use it for | Main limitation |
|---|---|---|
| `MemoryExperiment` + comparison helpers | Comparing committed library versions, allocating vs reused decode, inspection | Fixed synthetic workloads; not a photographic or application benchmark |
| `Scripts/benchmark-resource.sh` (`WebPBench`) | Exploring source-image loading, encoding, decoding, and pipeline costs | Process peak RSS includes fixture setup and previous allocations |
| `Scripts/validate-resource.sh` | Checking machine-specific timing/RSS budgets | Defaults are loose guardrails, not evidence of improvement |
| `Scripts/compare-with-cwebp.sh` | Comparing the complete Swift and CLI workflows | Includes different loaders, runtimes, process startup, and output handling |
| `Benchmark/AllocationProbe.swift` | Understanding `Data` backing-allocation capacity | Measures allocation size, not RSS, leaks, or codec speed |

## Compare two committed versions

The build helper extracts each git ref into a temporary source archive and injects the **same current driver and benchmark dependency lock**. It builds release executables without switching branches or changing the checkout. Commit candidate code first: uncommitted library changes are not included. Refs must be available locally and implement the APIs used by the driver; this is not a harness for arbitrary older releases.

```sh
# Use the toolchain selected by .swift-version, or explicitly select one
# with `swiftly run ... +6.4.0` for every build command.
swift --version

task_dir=$(mktemp -d "${TMPDIR:-/tmp}/swift-webp-bench.XXXXXX")
git fetch origin main
base_ref=$(git merge-base origin/main HEAD)
candidate_ref=$(git rev-parse HEAD)
mkdir -p "$task_dir/fixtures"

python3 Scripts/build-memory-experiment.py "$base_ref" \
  --output "$task_dir/baseline"
python3 Scripts/build-memory-experiment.py "$candidate_ref" \
  --output "$task_dir/candidate"

# Generate once with the baseline. Each file gets a .json reference sidecar.
"$task_dir/baseline" fixture 1920 1080 1 "$task_dir/fixtures/1920x1080.webp"
"$task_dir/baseline" fixture 3840 2160 1 "$task_dir/fixtures/3840x2160.webp"
"$task_dir/baseline" fixture 32 32 1 "$task_dir/fixtures/32x32.webp"

# All builds must finish before measurement starts.
python3 Scripts/run-memory-experiment.py \
  --binary "baseline=$task_dir/baseline" \
  --binary "candidate=$task_dir/candidate" \
  --fixtures "$task_dir/fixtures" --repeats 5 \
  --output "$task_dir/results.json"
```

The default build uses the unsafe-buffer encoder entry point in both versions to keep the entry point constant. Add `--span` to a build command to exercise safe `[UInt8]` encoding; the selected library ref must provide that overload. To isolate an implementation change, use the same entry point for both versions. Comparing an old pointer API against a new safe API is also useful, but measures the combined API/implementation change. `--span` affects encoder calls; the `reuse` stage still uses `inout [UInt8]`, not direct MutableSpan output.

After this PR is merged, a future candidate's merge base may already include these changes. To reproduce the original experiment instead, use the explicit refs in the [experiment report](../Reports/SpanOwnershipExperiment/REPORT.md).

For a short smoke check, use `--stages inspect --repeats 1`. For a focused decode comparison, use `--stages decode reuse`. Smoke results are not a performance conclusion. The runner accepts multiple `--binary NAME=PATH` arguments, starts fresh processes, reverses variant order every other repetition, saves each completed record, and fails on output mismatches. A partially written results file from an interrupted/failed run is not a completed comparison.

### Workloads and expected output

| Stage | Timed operation | Sizes / iterations per process |
|---|---|---|
| `encode` | Encode generated RGBA pixels; compare encoded bytes to the baseline fixture | 1920×1080 / 10; 3840×2160 / 5 |
| `decode` | Allocate and decode a pre-generated WebP | 1920×1080 / 30; 3840×2160 / 20 |
| `reuse` | Decode into one preallocated `[UInt8]` buffer | 1920×1080 / 30; 3840×2160 / 20 |
| `inspect` | Read bitstream dimensions/features | 32×32 / 100,000 |

Each process performs three warmup operations. The fixed workload uses picture preset quality 75 and disables decoder threading. Change the driver deliberately if investigating other qualities, image content, formats, options, or dimensions, then rebuild **every** variant with that changed driver and regenerate matching baseline fixtures. The runner currently expects the three fixture names above.

A complete default comparison produces 35 records per binary (seven cases × five repetitions), prints `Finished paired repetition ...`, and exits successfully after checking encoded sizes/hashes and decoded reference hashes. Exact encoded equality is expected for wrapper/allocation changes. If a deliberate codec/configuration change alters output, this harness will reject it; design an appropriate correctness/fidelity check rather than interpreting that failure as a performance regression. FNV-1a hashes are reproducibility checks, not cryptographic checks.

## Read the JSON results

| Field | Meaning |
|---|---|
| `mean_ms`, `median_ms` | Mean/median measured call time within one process, in milliseconds |
| `peak_rss_mib` | Process high-water resident memory through the end of measured runs, in MiB |
| `final_rss_mib` | Resident memory sampled at the end of measured runs; `-1` when unavailable (including the current Linux path) |
| `variant`, `repeat`, `mode`, `width`, `height`, `iterations` | Identify which process/workload produced a record |
| `encoded_bytes`, `encoded_hash`, `decoded_hash`, `checksum` | Output/reference and execution checks; not performance metrics |

Timed calls include result checks and, on macOS, autorelease-pool overhead. Full decoded-byte hash validation happens after timing/RSS capture, so its extra decode/copy cannot inflate these metrics. Inspection reports the fixture's reference decoded hash without decoding an image. RSS includes process/runtime/input/setup memory and allocator retention; it is not the output buffer's size or a direct count of live library allocations. The encoded fixture generation is a separate process, preventing encoder/source-decoder memory from contaminating the decode high-water mark.

Summarize multiple process runs rather than selecting the best result. This prints the median of process means and peak RSS, plus the range of process means:

```sh
python3 - "$task_dir/results.json" <<'PY'
import json, statistics, sys
records = json.load(open(sys.argv[1]))
keys = sorted({(r['mode'], r['width'], r['height'], r['variant']) for r in records})
for mode, width, height, variant in keys:
    rows = [r for r in records if (r['mode'], r['width'], r['height'], r['variant'])
            == (mode, width, height, variant)]
    times = [r['mean_ms'] for r in rows]
    rss = [r['peak_rss_mib'] for r in rows]
    print(f'{mode} {width}x{height} {variant}: n={len(rows)} '
          f'mean_ms_median={statistics.median(times):.6f} '
          f'mean_ms_range={min(times):.6f}..{max(times):.6f} '
          f'peak_rss_mib_median={statistics.median(rss):.3f}')
PY
```

For time, `(candidate / baseline - 1) * 100` is the percentage change: positive means slower. For memory, `baseline - candidate` is the saving. Confirm equal repetition counts and successful validation before interpreting either.

### What conclusions are supported?

- Lower repeated peak RSS with equal output supports a memory improvement for that workload/environment. It does not prove leak freedom or equal savings on another Foundation implementation.
- Lower repeated call time supports a throughput improvement for that stage. Small changes need repeated runs, ranges, and profiling before assigning a cause. Tiny inspection timings include substantial timer/pool overhead.
- Faster inspection does not establish faster encoding/decoding. A safe API does not automatically save memory or improve speed.
- Reusable-buffer performance and allocating-decode performance are separate results; report both. Keep the machine idle during measurement and avoid builds, tests, other benchmarks, or thermal/load changes.
- Record commit refs, driver revision, compiler, SDK, dependency revision, hardware/OS, workload settings, and raw results. Run relevant correctness tests separately; do not use sanitizer/debug builds for release-performance claims.

The [2026-09-27 report](../Reports/SpanOwnershipExperiment/REPORT.md) is a worked example: allocating decode saved approximately 2 MiB at HD and 8 MiB at UHD on one M1 Max/Foundation environment, but did not establish a codec speedup and showed a small reuse-path slowdown. These are historical measurements, not future thresholds or guaranteed savings.

## Explore image loading and the pipeline

```sh
# Synthetic encode workload. The script builds/runs release mode.
MODE=encode-only WIDTH=1920 HEIGHT=1080 ITERATIONS=30 WARMUP=3 \
  QUALITY=75 THREADS_FLAG=off Scripts/benchmark-resource.sh

# Real source image, decode/load once for codec stages.
MODE=decode-only INPUT="$PWD/Tests/WebPTests/Resources/jiro.jpg" \
  QUALITY=75 THREADS_FLAG=off Scripts/benchmark-resource.sh

# Source loading alone, or repeatedly load during the pipeline.
MODE=source-decode-only INPUT="$PWD/Tests/WebPTests/Resources/jiro.jpg" \
  Scripts/benchmark-resource.sh
MODE=pipeline INPUT="$PWD/Tests/WebPTests/Resources/jiro.jpg" \
  SOURCE_DECODE_PER_ITERATION=on Scripts/benchmark-resource.sh
```

The wrapper accepts `MODE`, `WIDTH`, `HEIGHT`, `ITERATIONS`, `WARMUP`, `QUALITY`, `THREADS_FLAG`, `INPUT`, and `SOURCE_DECODE_PER_ITERATION`. Defaults are pipeline, 1920×1080, 30 measured iterations, three warmups, quality **10**, decoder threading on, and source reuse. Direct `WebPBench` defaults quality to **75**, so set it explicitly when comparing runs. With `INPUT`, the loaded image determines dimensions. `source-decode-only` requires `INPUT`; image loading uses ImageIO/CoreGraphics on macOS. Repeated loading applies to encode/pipeline modes, while source-decode-only always loads on each operation.

Output is `key=value`: stage average/p95 times, sampled RSS, process peak RSS, and `valid=true` after dimensions/byte-count checks. The `_mb` RSS fields are calculated in MiB despite their names. `stage_peak_rss_mb` is the largest stage-end sample, while `peak_rss_mb` is a process high-water mark. Neither isolates the memory of a codec call: even decode-only prepares an encoded fixture first. `pipeline_encode_avg_ms` adds source-load and encode averages; it is not an independently timed full encode/decode pipeline. Use the isolated harness for allocation claims.

### Budget checks and CLI comparison

```sh
INPUT="$PWD/Tests/WebPTests/Resources/jiro.jpg" \
  QUALITY=75 THREADS_FLAG=off Scripts/validate-resource.sh

INPUT="$PWD/Tests/WebPTests/Resources/jiro.jpg" \
  QUALITY=75 THREADS_FLAG=off Scripts/compare-with-cwebp.sh
```

Validation runs source, encode, decode, and pipeline modes and fails when configured limits are exceeded. Tune `MAX_SOURCE_DECODE_AVG_MS`, `MAX_ENCODE_AVG_MS`, `MAX_DECODE_AVG_MS`, `MAX_PIPELINE_ENCODE_AVG_MS`, `MAX_ENCODE_P95_MS`, `MAX_DECODE_P95_MS`, `MAX_STAGE_PEAK_RSS_MB`, and `MAX_PIPELINE_PEAK_RSS_MB` against an established baseline on the target machine. Pass `INPUT`: the validation script always runs source-decode-only, which cannot run without an image. Passing the default thresholds does not demonstrate an optimization.

The CLI comparison requires `cwebp`, `dwebp`, and macOS `/usr/bin/time -lp`. Record the CLI libwebp version too. CLI times include process startup and source/output handling, and their RSS includes a different runtime and loader. Use this as workflow context, not proof of Swift wrapper overhead. Its quality-keyed files in `/tmp` are shared, so avoid concurrent CLI comparisons.

## Diagnose allocation capacity

```sh
swift Benchmark/AllocationProbe.swift
```

On macOS, this prints the requested pixel count, allocator backing size for `Data(count:)`, and backing size for exact storage transferred into `Data`. It initializes the transferred storage before publishing it. Compare allocation capacity to explain RSS results, but do not treat `malloc_size` as resident memory or assume its capacity policy is portable. Run it separately from timed comparisons.

## Troubleshooting and artifacts

Use a compiler/SDK combination that can build the selected versions. Select a toolchain per command rather than changing global configuration midway through a comparison. Use a fresh scratch directory when moving a consumer package or switching incompatible compiler/SDK environments; stale Clang module caches can cause assertions unrelated to library source compatibility.

The snapshot helper prints retained temporary source directories. Executables, generated fixtures/sidecars, and JSON results remain in your chosen output directory. Keep the results and environment notes with the experiment report before removing temporary build artifacts. Keep reusable usage instructions here; put dated measurements under `Reports/` so future runs do not inherit old numbers as expectations.

## Direct libwebp comparison

The same driver can compare the wrapper with two ordinary-pointer Swift implementations. Neither direct-C path uses Span, noncopyable owners, explicit borrowing/consuming, or a no-copy ownership transfer:

- `--direct-c copy`: encode with the picture/config API and memory writer, copy its output into Data, then clear the writer. Decode with `WebPDecodeRGBA`, copy pixels into Data, then `WebPFree` the C buffer.
- `--direct-c into`: the same encoding implementation; decode with `WebPDecodeRGBAInto` into `Data(count:)`. Both variants reuse an array through `WebPDecodeRGBAInto` for the reuse stage.

```sh
python3 Scripts/build-memory-experiment.py HEAD --span --output /tmp/webp-wrapper
python3 Scripts/build-memory-experiment.py HEAD --direct-c copy --output /tmp/webp-c-copy
python3 Scripts/build-memory-experiment.py HEAD --direct-c into --output /tmp/webp-c-into
python3 Scripts/run-memory-experiment.py \
  --binary wrapper=/tmp/webp-wrapper \
  --binary c-copy=/tmp/webp-c-copy \
  --binary c-into=/tmp/webp-c-into \
  --fixtures "$task_dir/fixtures" --stages encode decode reuse --repeats 5 \
  --output "$task_dir/direct-c-results.json"
```

Use fixtures prepared as described above. This compares equivalent RGBA/Data results at the picture preset, quality 75, without resizing, cropping, or decoder threading. The simple `WebPEncodeRGBA` function uses a different preset, so comparing it directly would change codec work. The direct-C variants are specialized for trusted dimensions and RGBA; the wrapper also validates input and supports more options. Both executables share the driver, linked libraries, validation and fixture setup. The two C encode and reuse implementations are identical and provide a useful estimate of run-to-run noise.

See the [direct-C comparison report](../Reports/SpanOwnershipExperiment/DIRECT_C.md) for measured results and limits. A copy-heavy baseline alone cannot establish superiority over well-written C interop.
