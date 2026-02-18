#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MAX_SOURCE_DECODE_AVG_MS="${MAX_SOURCE_DECODE_AVG_MS:-40}"
MAX_ENCODE_AVG_MS="${MAX_ENCODE_AVG_MS:-120}"
MAX_DECODE_AVG_MS="${MAX_DECODE_AVG_MS:-80}"
MAX_PIPELINE_ENCODE_AVG_MS="${MAX_PIPELINE_ENCODE_AVG_MS:-160}"
MAX_ENCODE_P95_MS="${MAX_ENCODE_P95_MS:-180}"
MAX_DECODE_P95_MS="${MAX_DECODE_P95_MS:-120}"
MAX_STAGE_PEAK_RSS_MB="${MAX_STAGE_PEAK_RSS_MB:-700}"
MAX_PIPELINE_PEAK_RSS_MB="${MAX_PIPELINE_PEAK_RSS_MB:-700}"

run_mode() {
  local mode="$1"
  local source_decode_each_iteration="$2"
  MODE="${mode}" SOURCE_DECODE_PER_ITERATION="${source_decode_each_iteration}" "${REPO_ROOT}/Scripts/benchmark-resource.sh"
}

extract_value() {
  local output="$1"
  local key="$2"
  printf '%s\n' "${output}" | awk -F= -v k="$key" '$1==k { print $2 }' | tail -n1
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

validate_common() {
  local output="$1"
  local mode="$2"
  local valid
  valid="$(extract_value "${output}" valid)"
  if [[ "${valid}" != "true" ]]; then
    echo "Validation failed: mode=${mode} did not report valid=true" >&2
    exit 1
  fi

  local stage_peak
  stage_peak="$(extract_value "${output}" stage_peak_rss_mb)"
  if [[ -n "${stage_peak}" ]]; then
    assert_le "${mode}.stage_peak_rss_mb" "${stage_peak}" "${MAX_STAGE_PEAK_RSS_MB}"
  fi
}

SOURCE_OUTPUT="$(run_mode "source-decode-only" "on")"
printf '%s\n' "${SOURCE_OUTPUT}"
validate_common "${SOURCE_OUTPUT}" "source-decode-only"
assert_le "source_decode_only.source_decode_avg_ms" "$(extract_value "${SOURCE_OUTPUT}" source_decode_avg_ms)" "${MAX_SOURCE_DECODE_AVG_MS}"

ENCODE_OUTPUT="$(run_mode "encode-only" "off")"
printf '%s\n' "${ENCODE_OUTPUT}"
validate_common "${ENCODE_OUTPUT}" "encode-only"
assert_le "encode_only.encode_avg_ms" "$(extract_value "${ENCODE_OUTPUT}" encode_avg_ms)" "${MAX_ENCODE_AVG_MS}"
assert_le "encode_only.encode_p95_ms" "$(extract_value "${ENCODE_OUTPUT}" encode_p95_ms)" "${MAX_ENCODE_P95_MS}"

DECODE_OUTPUT="$(run_mode "decode-only" "off")"
printf '%s\n' "${DECODE_OUTPUT}"
validate_common "${DECODE_OUTPUT}" "decode-only"
assert_le "decode_only.decode_avg_ms" "$(extract_value "${DECODE_OUTPUT}" decode_avg_ms)" "${MAX_DECODE_AVG_MS}"
assert_le "decode_only.decode_p95_ms" "$(extract_value "${DECODE_OUTPUT}" decode_p95_ms)" "${MAX_DECODE_P95_MS}"

PIPELINE_OUTPUT="$(run_mode "pipeline" "on")"
printf '%s\n' "${PIPELINE_OUTPUT}"
validate_common "${PIPELINE_OUTPUT}" "pipeline"
assert_le "pipeline.encode_avg_ms" "$(extract_value "${PIPELINE_OUTPUT}" encode_avg_ms)" "${MAX_ENCODE_AVG_MS}"
assert_le "pipeline.decode_avg_ms" "$(extract_value "${PIPELINE_OUTPUT}" decode_avg_ms)" "${MAX_DECODE_AVG_MS}"
assert_le "pipeline.pipeline_encode_avg_ms" "$(extract_value "${PIPELINE_OUTPUT}" pipeline_encode_avg_ms)" "${MAX_PIPELINE_ENCODE_AVG_MS}"
assert_le "pipeline.encode_p95_ms" "$(extract_value "${PIPELINE_OUTPUT}" encode_p95_ms)" "${MAX_ENCODE_P95_MS}"
assert_le "pipeline.decode_p95_ms" "$(extract_value "${PIPELINE_OUTPUT}" decode_p95_ms)" "${MAX_DECODE_P95_MS}"
assert_le "pipeline.peak_rss_mb" "$(extract_value "${PIPELINE_OUTPUT}" peak_rss_mb)" "${MAX_PIPELINE_PEAK_RSS_MB}"

echo "Resource validation passed"
