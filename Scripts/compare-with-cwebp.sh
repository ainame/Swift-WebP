#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

INPUT="${INPUT:-${REPO_ROOT}/Demo/SwiftWebPDemo/Assets.xcassets/jiro.imageset/jiro.jpg}"
ITERATIONS="${ITERATIONS:-30}"
WARMUP="${WARMUP:-3}"
QUALITY="${QUALITY:-10}"
THREADS_FLAG="${THREADS_FLAG:-on}"

if ! command -v cwebp >/dev/null 2>&1; then
  echo "cwebp not found in PATH" >&2
  exit 1
fi
if ! command -v dwebp >/dev/null 2>&1; then
  echo "dwebp not found in PATH" >&2
  exit 1
fi
if [[ ! -f "${INPUT}" ]]; then
  echo "Input file not found: ${INPUT}" >&2
  exit 1
fi

THREADS_BENCH=""
CWEBP_MT=""
DWEBP_MT=""
if [[ "${THREADS_FLAG}" == "off" ]]; then
  THREADS_BENCH="off"
else
  CWEBP_MT="-mt"
  DWEBP_MT="-mt"
fi

cd "${REPO_ROOT}"

BENCH_OUTPUT="$(
  WIDTH=1 HEIGHT=1 ITERATIONS="${ITERATIONS}" WARMUP="${WARMUP}" QUALITY="${QUALITY}" \
  THREADS_FLAG="${THREADS_BENCH}" INPUT="${INPUT}" SOURCE_DECODE_PER_ITERATION=on \
  Scripts/benchmark-resource.sh
)"

printf '%s\n' "${BENCH_OUTPUT}"

CWEBP_OUTPUT="$(
  INPUT="${INPUT}" QUALITY="${QUALITY}" ITERATIONS="${ITERATIONS}" WARMUP="${WARMUP}" CWEBP_MT="${CWEBP_MT}" DWEBP_MT="${DWEBP_MT}" \
  perl -MTime::HiRes=time -e '
    use strict;
    use warnings;
    my $in = $ENV{"INPUT"};
    my $quality = $ENV{"QUALITY"};
    my $iters = int($ENV{"ITERATIONS"});
    my $warm = int($ENV{"WARMUP"});
    my $cwebp_mt = $ENV{"CWEBP_MT"};
    my $dwebp_mt = $ENV{"DWEBP_MT"};
    my $webp = "/tmp/swift-webp-compare-q${quality}.webp";

    my (@enc, @dec);
    for (my $i = 0; $i < $iters + $warm; $i++) {
      my $start = time();
      my $enc_cmd = "cwebp -quiet -preset picture -q $quality $cwebp_mt $in -o $webp";
      system($enc_cmd) == 0 or die "cwebp failed";
      my $enc_ms = (time() - $start) * 1000;
      if ($i >= $warm) { push @enc, $enc_ms; }

      $start = time();
      my $dec_cmd = "dwebp -quiet $dwebp_mt $webp -ppm -o - >/dev/null";
      system($dec_cmd) == 0 or die "dwebp failed";
      my $dec_ms = (time() - $start) * 1000;
      if ($i >= $warm) { push @dec, $dec_ms; }
    }

    sub avg {
      my @vals = @_;
      my $sum = 0;
      $sum += $_ for @vals;
      return @vals ? $sum / scalar(@vals) : 0;
    }

    sub p95 {
      my @vals = sort { $a <=> $b } @_;
      return 0 unless @vals;
      my $idx = int((0.95 * (scalar(@vals) - 1)) + 0.5);
      return $vals[$idx];
    }

    my $size = -s $webp;
    printf("cwebp_webp_bytes=%d\n", $size);
    printf("cwebp_encode_avg_ms=%.3f\n", avg(@enc));
    printf("cwebp_encode_p95_ms=%.3f\n", p95(@enc));
    printf("dwebp_decode_avg_ms=%.3f\n", avg(@dec));
    printf("dwebp_decode_p95_ms=%.3f\n", p95(@dec));
  '
)"

printf '%s\n' "${CWEBP_OUTPUT}"

tmp_webp="/tmp/swift-webp-compare-rss-q${QUALITY}.webp"
tmp_ppm="/tmp/swift-webp-compare-rss-q${QUALITY}.ppm"

cwebp_rss_bytes="$(
  /usr/bin/time -lp cwebp -quiet -preset picture -q "${QUALITY}" ${CWEBP_MT} "${INPUT}" -o "${tmp_webp}" 2>&1 \
    | awk '/maximum resident set size/ { print $1 }'
)"

dwebp_rss_bytes="$(
  /usr/bin/time -lp dwebp -quiet ${DWEBP_MT} "${tmp_webp}" -ppm -o "${tmp_ppm}" 2>&1 \
    | awk '/maximum resident set size/ { print $1 }'
)"

if [[ -n "${cwebp_rss_bytes}" ]]; then
  cwebp_rss_mb="$(awk -v b="${cwebp_rss_bytes}" 'BEGIN { printf "%.3f", b / (1024 * 1024) }')"
  echo "cwebp_peak_rss_mb=${cwebp_rss_mb}"
fi

if [[ -n "${dwebp_rss_bytes}" ]]; then
  dwebp_rss_mb="$(awk -v b="${dwebp_rss_bytes}" 'BEGIN { printf "%.3f", b / (1024 * 1024) }')"
  echo "dwebp_peak_rss_mb=${dwebp_rss_mb}"
fi

echo "comparison_done=true"
