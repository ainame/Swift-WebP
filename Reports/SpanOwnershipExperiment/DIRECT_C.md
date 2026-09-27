# Swift-WebP versus direct libwebp from Swift

## Question and setup

Does the ownership work make Swift-WebP competitive with ordinary direct C interop, particularly in memory usage?

Measured on Apple M1 Max, macOS 27.2 (26B5091g), Swift 6.4 release, libwebp-Xcode 1.6.0. Library snapshot: `f26184708aafdc01f513ffd3d7f75eef547be477`. The common driver and direct-C implementations are in `Benchmark/Sources/MemoryExperiment/main.swift`. This follow-up changes benchmark code and documentation only.

All variants use the same synthetic opaque RGBA HD/4K fixtures, quality 75 picture preset, output format, and pre-generated bitstreams. Decoder threading is disabled/default off. No cropping or resizing. Every encode is checked against the fixture bitstream; full decode hashes are checked after timing/RSS capture. Five process repetitions alternate forward/reverse order, with three warmups per process; each process times 10/5 encodes or 30/20 decodes for HD/4K. Raw results: [direct-c-results.json](direct-c-results.json). Toolchain, binary hashes and fixture metadata: [direct-c-metadata.json](direct-c-metadata.json).

## Implementations

- **Wrapper:** safe array encoder, allocating Data decoder, reusable-array decoder.
- **C-copy:** ordinary Swift pointers and `defer` cleanup. Picture/config encoding with WebPMemoryWriter, copy encoded output to Data, clear writer. WebPDecodeRGBA allocation, copy pixels to Data, WebPFree. No Span, noncopyable owners, explicit borrowing/consuming, or no-copy ownership transfer.
- **C-into:** same C encoder; WebPDecodeRGBAInto writes into Data(count:) for allocating decode. Both direct-C variants decode reused output with WebPDecodeRGBAInto into an array.

The C encoder uses the advanced picture API because WebPEncodeRGBA uses a different preset. This keeps the codec work and encoded bytes equivalent. Direct-C implementations specialize for trusted RGBA dimensions and do not reproduce the wrapper's validation/options. Both binaries still link Swift-WebP and share driver setup, so this is an operation comparison, not a comparison of standalone application footprint. Identical C encode/reuse paths provide a noise cross-check.

## Results

Median of five process mean times and peak RSS values. Parentheses show min–max across those processes.

| Stage | Size | Variant | Time ms (range) | Peak RSS MiB (range) |
|---|---|---|---:|---:|
| encode | HD | wrapper | 177.43 (173.69–179.25) | 30.97 (30.28–38.34) |
| encode | HD | c-copy | 178.29 (174.02–179.56) | 30.77 (30.17–42.28) |
| encode | HD | c-into | 177.95 (174.99–178.46) | 31.80 (29.92–39.06) |
| encode | 4K | wrapper | 707.15 (684.43–711.31) | 102.72 (101.52–112.50) |
| encode | 4K | c-copy | 710.89 (683.44–721.49) | 105.83 (103.02–119.58) |
| encode | 4K | c-into | 697.27 (685.87–839.45) | 105.88 (104.69–129.66) |
| decode | HD | wrapper | 25.40 (24.37–25.51) | 15.50 (15.50–15.72) |
| decode | HD | c-copy | 26.32 (25.22–26.76) | 23.53 (23.33–23.56) |
| decode | HD | c-into | 25.20 (25.01–25.87) | 17.44 (17.42–17.66) |
| decode | 4K | wrapper | 100.50 (98.60–101.17) | 41.19 (40.84–41.22) |
| decode | 4K | c-copy | 103.91 (101.96–106.76) | 72.41 (72.41–72.75) |
| decode | 4K | c-into | 100.62 (99.08–104.39) | 49.08 (48.73–49.09) |
| reuse | HD | wrapper | 25.37 (24.68–27.21) | 15.48 (15.47–15.66) |
| reuse | HD | c-copy | 25.26 (24.52–26.95) | 15.59 (15.39–15.62) |
| reuse | HD | c-into | 25.30 (24.41–25.43) | 15.45 (15.44–15.64) |
| reuse | 4K | wrapper | 100.28 (99.60–105.37) | 41.19 (40.84–41.20) |
| reuse | 4K | c-copy | 99.81 (97.67–103.81) | 40.77 (40.77–41.12) |
| reuse | 4K | c-into | 100.16 (97.78–103.99) | 40.81 (40.81–41.16) |

## Verdict

Swift-WebP is close to these specialized direct-C implementations in codec timing and improves allocating-decode memory efficiency when the caller needs Data:

- Versus direct decode into Data(count:), allocating decode saves **1.94 MiB at HD (11.1%)** and **7.89 MiB at 4K (16.1%)**. Wrapper timing is 0.78% slower at HD and 0.12% faster at 4K; this does not establish a throughput advantage.
- Versus C allocation followed by a Data copy, it saves **8.03 MiB at HD (34.1%)** and **31.22 MiB at 4K (43.1%)**. Median time is 3.51% and 3.29% lower, consistent with avoiding a large copy.
- Encoder median time differences range from 0.53% faster to 1.42% slower against the two identical C implementations. Their variation, including a 4K outlier, prevents a speed claim. HD encoder RSS has no consistent benefit; 4K median savings are around 3 MiB but RSS ranges overlap substantially, so no robust encoder-memory improvement is established.
- Reusable decode is within 0.5% in median time. RSS differs by less than 0.5 MiB with overlapping ranges, so treat it as approximately equivalent.

This supports retaining the allocation owner for safe cleanup and efficient Data production. It does not show that ownership language features beat an equally optimized manual implementation. If a C consumer can keep the raw decoded allocation rather than return Data, the output contract changes and the copy-based savings comparison no longer applies.

## Interpretation and limits

The ownership wrapper itself does not make libwebp's codec faster. Its allocating decoder avoids the simultaneous C-output-plus-Data-copy allocation, and avoids Data(count:)'s excess capacity observed on this Foundation implementation. The more elaborate owner allows deterministic error cleanup and successful allocation transfer; the memory benefit comes from the chosen allocation and transfer policy, not from noncopyability alone. Direct C can achieve the same policy with carefully managed no-copy transfer, which was deliberately excluded from the naive variants requested here.

RSS is a whole-process high-water mark including setup, warmups and allocator retention. It is not live-byte accounting or a leak test. Encoder memory variation cannot be attributed solely to the encoded-output copy. These synthetic opaque fixtures do not establish results for photographic input, alpha-heavy images, lossless encoding, other operating systems or older runtimes. Full hashes run after capture; timed edge/count/bitstream checks and autorelease-pool overhead are shared. The five process means are summarized by their median; ranges show process variation rather than confidence intervals.

## Reproduction

Follow the direct-libwebp section in [the benchmark guide](../../Benchmark/README.md), using all three binaries and stages encode/decode/reuse. Finish all builds before measurement. The current driver is injected into each committed library snapshot by the helper. No library code was modified for this comparison.
