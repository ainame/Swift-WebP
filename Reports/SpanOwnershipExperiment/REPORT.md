# Swift-WebP span and ownership experiment

Date: 2026-09-27. Branch: `codex/span-ownership-experiment`.

## Decision

The experiment improves ownership and the public buffer interface, and establishes a concrete memory benefit for allocating decode. **Keep the safe input APIs, encoder validation/lifetime fixes, and noncopyable resource owners. The exact owned decode allocation is worth considering for its approximately 2 MiB HD / 8 MiB UHD saving here.**

There is no established codec throughput improvement. The final allocating decode is within about 0.3% of baseline, while reusable-array decode remains approximately 1.7–2.0% slower in local measurements. Keep this branch as an experiment and profile that difference before merging into a workload with a strict throughput budget. The memory benefit belongs to allocation policy, not to Span itself.

No experiment result justifies requiring Swift 6.4: the final library also builds and passes tests with Swift 6.2.3 and Swift 6.3.3. Older-than-6.2 compilers were already excluded by the merged baseline.

## What changed

The safety variant (`f9389ef`) adds public borrowed `Span<UInt8>` encoding and inspection, safe `[UInt8]`/`Data` encoding conveniences, and decoding into an exclusively borrowed `MutableSpan<UInt8>`. Existing pointer entry points remain for compatibility. Ordinary callers can encode and reuse decode buffers without unsafe operations.

Encoding now validates dimensions, row stride, overflow, and input capacity before passing a pointer to C. The minimum input capacity is `(height - 1) * stride + rowBytes`. Inputs omitting final-row padding are packed into temporary contiguous storage before import, honoring libwebp's documented `stride * height` contract. Fully padded inputs retain the zero-copy borrowing path. Compact inputs incur an additional allocation and copy; this fallback was not benchmarked. CoreGraphics byte access keeps the actual `CFData` owner alive through the entire encoding call, replacing a helper that returned a pointer detached from that local owner's lifetime.

An internal `~Copyable` memory-writer owner frees output on every failure path and uses a consuming operation to transfer successful output to `Data`. Pictures retain their existing `defer` cleanup; stateless encoder/decoder/configuration values remain copyable. Metadata inspection uses a local C structure instead of explicitly allocating one on the heap.

The efficiency variant (`fbf9436`) additionally decodes into a private, uninitialized byte allocation owned by a second noncopyable type. It transfers storage to `Data` only after a successful complete decode and calculates output layout once instead of twice. Partial output on failure is freed without being read or published. No span is constructed over uninitialized bytes: `MutableSpan` requires initialized storage. `OutputSpan` was not needed for this synchronous C byte-writing operation.

## Method

- Baseline library: merged `main` at `f911dc0`.
- All three variants use the same final benchmark driver, Swift 6.4 release optimization, pinned libwebp-Xcode 1.6.0 (revision `2b5256c29ff4e20f2a0d5ee863b62b1a22144434`), and generated fixtures.
- Apple M1 Max, 64 GiB RAM, macOS 27.2 / Darwin 27.2.0; Xcode 27.2 beta SDK. These are local measurements, not hosted CI or other platforms.
- Synthetic RGBA frames at 1920×1080 and 3840×2160, lossy picture preset quality 75, decoder threading disabled. This is a patterned image, not a representative photographic corpus.
- Five fresh processes per stage/variant/size. Order reverses each repetition. Three warmup operations precede measurement. Encode: 10 HD / 5 UHD iterations; decode and reuse: 30 HD / 20 UHD; inspection: 100,000 iterations on a 32×32 fixture.
- Decode, reuse, and inspection processes load pre-generated WebP files. They do not encode a fixture, decode a source JPEG, or retain a reference decoded image. Encoders retain their source pixels and reference encoded bitstream.
- Table times are the median of the five process means. RSS is the median process peak up to the end of measured runs (`getrusage`, bytes converted to MiB); post-measurement hash verification is excluded. Timed calls include result checks and autorelease-pool overhead. Full decoded-byte hash validation runs after memory/timing capture.
- All variants must produce identical encoded sizes and FNV-1a hashes and matching full decoded hashes. FNV is a reproducibility check, not a security hash.
- Builds, tests, and the allocator probe run outside measurement. Background desktop activity is uncontrolled; small timing/RSS differences should be treated as noise.

## Results

Initial three-variant comparison (before the reusable-array adapter refinement):

| Stage | Frame | Baseline ms | Safety ms | Owned decode ms |
|---|---|---:|---:|---:|
| encode | 1920×1080 | 178.025 | 177.241 | 178.662 |
| decode | 1920×1080 | 25.284 | 25.401 | 25.289 |
| reuse | 1920×1080 | 24.941 | 25.337 | 25.348 |
| encode | 3840×2160 | 707.013 | 702.507 | 703.498 |
| decode | 3840×2160 | 100.944 | 101.425 | 101.585 |
| reuse | 3840×2160 | 99.666 | 101.234 | 101.033 |

| Stage | Frame | Baseline peak MiB | Safety peak MiB | Owned decode peak MiB |
|---|---|---:|---:|---:|
| encode | 1920×1080 | 32.83 | 33.12 | 33.83 |
| decode | 1920×1080 | 17.64 | 17.61 | 15.67 |
| reuse | 1920×1080 | 15.67 | 15.64 | 15.66 |
| encode | 3840×2160 | 111.77 | 107.56 | 108.31 |
| decode | 3840×2160 | 49.09 | 49.06 | 41.17 |
| reuse | 3840×2160 | 41.17 | 41.16 | 41.17 |

The span/ownership-only variant does not reduce decoded-image memory: peak RSS remains about 17.6 MiB / 49.1 MiB. Codec timing changes are small; no codec speedup is established. The original array-through-span adapter shows a repeatable roughly 1.4–1.6% reuse slowdown and was subsequently simplified (follow-up below).

The owned decode variant reduces allocating-decode peak RSS by **1.97 MiB (11.2%) at 1080p** and **7.92 MiB (16.1%) at 4K**. These decreases match the allocator-capacity differences below. Its peak reaches the existing reused-buffer path, which was already efficient on baseline. Do not credit Span itself with this reduction.

Metadata inspection fell from a median process mean of 0.084 microseconds to 0.060 microseconds (about 24 ns per call). Removing an explicit heap allocation is useful simplification, but this is negligible next to codec work and includes timer/pool overhead. Encoder peak RSS varied substantially between processes (HD baseline 31.97–35.80 MiB vs owned variant 33.03–41.97 MiB; UHD 105.09–112.50 vs 106.63–108.67 MiB). These results do not establish an encoder-memory improvement.

### Allocation explanation

The separate `malloc_size` probe, run with the same Swift 6.4/Foundation environment after timing finished, reported:

| Requested pixels | `Data(count:)` backing allocation | Exact allocation transferred into `Data` | Difference |
|---:|---:|---:|---:|
| 8,294,400 bytes | 10,371,072 bytes | 8,306,688 bytes | 1.96875 MiB |
| 33,177,600 bytes | 41,484,288 bytes | 33,177,600 bytes | 7.921875 MiB |

Here `Data(count:)` reserves approximately 25% extra backing capacity. The exact allocation avoids that reserve, and also avoids initial zero-filling. The observed RSS differences exactly match these allocation differences for the median samples. This is evidence for an allocation-policy benefit on this environment, not a promise that every Foundation implementation reserves the same capacity. Removing zero-filling did not establish a throughput improvement.

The probe initializes the transferred allocation before exposing it as Data; it is testing backing capacity independently of the codec. Raw probe output is in [allocations.txt](allocations.txt).

### Reusable-array refinement

The final code at `291965c` keeps the public mutable-span API but routes the already-safe `inout [UInt8]` overload directly to the scoped C buffer helper. This removes a redundant array→span→pointer round trip. Five additional paired runs measured allocating decode and array reuse at both sizes:

| Stage | Frame | Baseline ms | Refined ms | Time change | Baseline peak MiB | Refined peak MiB |
|---|---|---:|---:|---:|---:|---:|
| decode | 1920×1080 | 25.258 | 25.320 | +0.25% | 17.66 | 15.67 |
| reuse | 1920×1080 | 24.970 | 25.467 | +1.99% | 15.66 | 15.64 |
| decode | 3840×2160 | 100.949 | 101.253 | +0.30% | 49.09 | 41.17 |
| reuse | 3840×2160 | 99.626 | 101.291 | +1.67% | 41.17 | 41.17 |

Positive time change means slower. The allocating decode memory benefit remains and its timing stays within about 0.3% of baseline. **Array reuse remains approximately 1.7–2.0% slower** in this follow-up. Removing the span round trip did not resolve that difference, so the round trip is not established as its cause. Link/code-layout effects or other generated-code changes need profiling before attributing it. Do not advertise a throughput improvement or assume the slowdown is absent.

Follow-up raw data is in [refined-results.json](refined-results.json). These measurements cover the final library code; the initial table deliberately preserves the separate safety-only and owned-storage experiments.

Raw per-process measurements are in [results.json](results.json). The earlier pilot used encoder-generated fixtures and retained decoded references; it was discarded for the final memory comparison because setup inflated peak RSS.

## Earlier experiment

The report removed by `1b761b11aec21e4efa975bbaea7740298cfec175` is available as `git show 1b761b1^:MEMORY_FOOTPRINT.md`. It measured a 1210×907 JPEG at quality 10 on 2026-02-17, reporting roughly 168 MiB source-decoding peak, 206.5 MiB pipeline peak, 29.5 MiB isolated encoding peak, and 31.7 MiB isolated decoding peak. It already introduced reusable decoder buffers, exact-size `Data` output, picture cleanup, and autorelease pools.

Those numbers are historical context, not a directly comparable baseline: image content, dimensions, quality, compiler, benchmark setup, and process lifetime differ. This experiment compares the merged current library against focused changes under one common harness. It does not repeat the CLI comparison: process-wide cwebp/dwebp RSS includes different loaders and runtimes and cannot isolate the cost of a Swift buffer interface.

The earlier conclusion about source-decoding/pipeline spikes remains relevant. These changes do not optimize ImageIO source decoding or benchmark CoreGraphics/Foundation bridging. The CoreGraphics lifetime correction is a safety improvement verified by existing platform tests, not a measured pipeline-memory reduction.

## Validation and limitations

- `make format`, `swift build`, `swift test`, and `git diff --check` passed on Swift 6.4.0. Formatting emitted a cache-write warning; source formatting completed.
- Swift 6.2.3 with Xcode 26.5: all 43 tests in eight suites passed, and a separate Swift 6.2 consumer package built in release mode and ran successfully. It exercises array/Data/Span encoding, span inspection, allocating decode, array reuse, MutableSpan output, and a lossless byte-for-byte round trip.
- Swift 6.3.3 with Xcode 26.5: all 43 tests in eight suites passed.
- Swift 6.4 Address Sanitizer: all 43 tests passed without sanitizer failures. Coverage includes each packed decode format, invalid/overflowing input layouts, padded rows, undersized output, trailing output preservation, ownership transfer, retained decoded data, and a truncated bitstream failing after successful header inspection/output allocation.
- Sanitizer success does not prove all inputs or allocations are safe. No leak-sanitizer proof or forced libwebp allocator-failure test is claimed; the writer failure-path fix follows its owned cleanup semantics and upstream allocation contract.
- An opt-in `swift build -Xswiftc -strict-memory-safety` audit of the initial owned-storage variant succeeded with warnings (108 distinct source diagnostic locations). This is not a warning-free strict-safety migration. C interop, imported buffer configuration types, legacy pointer APIs, and unsafe construction/extraction of views remain; further annotations and audit are separate work.
- No Linux build/runtime, iOS runtime, older macOS runtime, or photographic corpus benchmark was run.

## Compiler support

The experiment keeps the manifest minimum at Swift 6.2 and the development toolchain at 6.4.0. Span, MutableSpan, and the ownership machinery used here do not require 6.4-only features. The initial experiment checked only 6.3/6.4. A follow-up installed Swift 6.2.3 and verified both the full library test suite and a separate release consumer. Swiftly had a stale 6.2.4 installation record pointing at a missing directory; that record was not usable evidence. Swift 6.2.0, 6.2.1, and 6.2.2 were not tested. Existing iOS 13/macOS 11 deployment targets are preserved; using scoped pointer adapters avoids depending on newer OS-only container span accessors.

The result supports modern safe buffer APIs, but supplies no reason to raise the minimum to 6.4. Retaining the 6.2 manifest minimum is supported by the Swift 6.2.3 consumer and library checks; no minimum-version bump was needed for this implementation. Safe public APIs still need an audited C boundary; removing the word `Unsafe` from source cannot make libwebp itself memory safe.

References: [SE-0447 Span](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md), [SE-0467 MutableSpan](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0467-MutableSpan.md), [Span deployment guidance](https://forums.swift.org/t/supporting-span-in-packages/81667), [strict safety and C interoperability](https://www.swift.org/documentation/cxx-interop/safe-interop/).

## Reproduce

For general usage and future experiments, see the [benchmark guide](../../Benchmark/README.md).

Use Swift 6.4.0. The build helper extracts committed source archives into temporary directories and injects the same current harness and dependency lock, leaving the checkout state alone. Keep the output directory outside the repository.

```sh
mkdir -p /tmp/webp-span-repro/fixtures
python3 Scripts/build-memory-experiment.py f911dc0 --output /tmp/webp-span-repro/baseline
python3 Scripts/build-memory-experiment.py f9389ef --span --output /tmp/webp-span-repro/safety
python3 Scripts/build-memory-experiment.py fbf9436 --span --output /tmp/webp-span-repro/efficiency
python3 Scripts/build-memory-experiment.py 291965c --span --output /tmp/webp-span-repro/refined

/tmp/webp-span-repro/baseline fixture 1920 1080 1 /tmp/webp-span-repro/fixtures/1920x1080.webp
/tmp/webp-span-repro/baseline fixture 3840 2160 1 /tmp/webp-span-repro/fixtures/3840x2160.webp
/tmp/webp-span-repro/baseline fixture 32 32 1 /tmp/webp-span-repro/fixtures/32x32.webp

python3 Scripts/run-memory-experiment.py \
  --binary baseline=/tmp/webp-span-repro/baseline \
  --binary safety=/tmp/webp-span-repro/safety \
  --binary efficiency=/tmp/webp-span-repro/efficiency \
  --fixtures /tmp/webp-span-repro/fixtures --repeats 5 \
  --output /tmp/webp-span-repro/results.json

python3 Scripts/run-memory-experiment.py \
  --binary baseline=/tmp/webp-span-repro/baseline \
  --binary refined=/tmp/webp-span-repro/refined \
  --fixtures /tmp/webp-span-repro/fixtures --stages decode reuse --repeats 5 \
  --output /tmp/webp-span-repro/refined-results.json

swift Benchmark/AllocationProbe.swift
```

## Reproduce Swift 6.2 consumer compatibility

The fixture in [Swift62Consumer](Swift62Consumer/Package.swift) is a separate executable package with Swift tools version 6.2 and macOS 11 deployment target. It depends on the library by relative path. Dependency `.swift-version` files do not require the consumer to use 6.4; the selected compiler builds both packages.

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
  swiftly run swift run \
  --package-path Reports/SpanOwnershipExperiment/Swift62Consumer \
  --scratch-path /tmp/webp-consumer-62-repro \
  -c release +6.2.3

DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
  swiftly run swift test --scratch-path /tmp/webp-library-62-build +6.2.3
```

The consumer printed `Swift 6.2 consumer: array, Data, Span, MutableSpan, inspection and round-trip passed`. It ran on macOS 27.2. The linker warned that toolchain runtime dylibs were built for macOS 13 while the consumer targets macOS 11; this check does not validate execution on macOS 11. No compiler or SDK selection was changed globally.

Use a fresh scratch directory for the consumer fixture. Reusing a build directory from the earlier consumer at a different package path triggered a Clang module-cache assertion; rebuilding the same fixture in a fresh directory succeeded.
