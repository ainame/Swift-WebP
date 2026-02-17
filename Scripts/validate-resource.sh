#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MAX_ENCODE_AVG_MS="${MAX_ENCODE_AVG_MS:-120}"
MAX_DECODE_AVG_MS="${MAX_DECODE_AVG_MS:-80}"
MAX_ENCODE_P95_MS="${MAX_ENCODE_P95_MS:-180}"
MAX_DECODE_P95_MS="${MAX_DECODE_P95_MS:-120}"
MAX_PEAK_RSS_MB="${MAX_PEAK_RSS_MB:-700}"

OUTPUT="$("${REPO_ROOT}/Scripts/benchmark-resource.sh")"
printf '%s\n' "${OUTPUT}"

extract_value() {
  local key="$1"
  printf '%s\n' "${OUTPUT}" | awk -F= -v k="$key" '$1==k { print $2 }'
}

assert_le() {
  local name="$1"
  local value="$2"
  local limit="$3"
  awk -v n="$name" -v v="$value" -v l="$limit" 'BEGIN {
    if (v+0 <= l+0) { exit 0 }
    printf("Validation failed: %s=%s exceeds limit=%s\n", n, v, l) > "/dev/stderr"
    exit 1
  }'
}

VALID="$(extract_value valid)"
if [[ "${VALID}" != "true" ]]; then
  echo "Validation failed: benchmark did not report valid=true" >&2
  exit 1
fi

ENCODE_AVG="$(extract_value encode_avg_ms)"
DECODE_AVG="$(extract_value decode_avg_ms)"
ENCODE_P95="$(extract_value encode_p95_ms)"
DECODE_P95="$(extract_value decode_p95_ms)"
PEAK_RSS="$(extract_value peak_rss_mb)"

assert_le "encode_avg_ms" "${ENCODE_AVG}" "${MAX_ENCODE_AVG_MS}"
assert_le "decode_avg_ms" "${DECODE_AVG}" "${MAX_DECODE_AVG_MS}"
assert_le "encode_p95_ms" "${ENCODE_P95}" "${MAX_ENCODE_P95_MS}"
assert_le "decode_p95_ms" "${DECODE_P95}" "${MAX_DECODE_P95_MS}"
assert_le "peak_rss_mb" "${PEAK_RSS}" "${MAX_PEAK_RSS_MB}"

echo "Resource validation passed"
