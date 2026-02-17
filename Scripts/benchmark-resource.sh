#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="${MODE:-pipeline}"
WIDTH="${WIDTH:-1920}"
HEIGHT="${HEIGHT:-1080}"
ITERATIONS="${ITERATIONS:-30}"
WARMUP="${WARMUP:-3}"
QUALITY="${QUALITY:-10}"
THREADS_FLAG="${THREADS_FLAG:-}"
INPUT="${INPUT:-}"
SOURCE_DECODE_PER_ITERATION="${SOURCE_DECODE_PER_ITERATION:-off}"

cd "${REPO_ROOT}"

args=(
  --mode "${MODE}"
  --width "${WIDTH}"
  --height "${HEIGHT}"
  --iterations "${ITERATIONS}"
  --warmup "${WARMUP}"
  --quality "${QUALITY}"
)

if [[ "${THREADS_FLAG}" == "off" ]]; then
  args+=(--no-threads)
fi

if [[ -n "${INPUT}" ]]; then
  args+=(--input "${INPUT}")
fi

if [[ "${SOURCE_DECODE_PER_ITERATION}" == "on" ]]; then
  args+=(--decode-source-each-iteration)
fi

swift run -c release WebPBench "${args[@]}"
