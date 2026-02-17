#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

WIDTH="${WIDTH:-1920}"
HEIGHT="${HEIGHT:-1080}"
ITERATIONS="${ITERATIONS:-30}"
WARMUP="${WARMUP:-3}"
QUALITY="${QUALITY:-10}"
THREADS_FLAG="${THREADS_FLAG:-}"

cd "${REPO_ROOT}"

if [[ "${THREADS_FLAG}" == "off" ]]; then
  swift run -c release WebPBench \
    --width "${WIDTH}" \
    --height "${HEIGHT}" \
    --iterations "${ITERATIONS}" \
    --warmup "${WARMUP}" \
    --quality "${QUALITY}" \
    --no-threads
else
  swift run -c release WebPBench \
    --width "${WIDTH}" \
    --height "${HEIGHT}" \
    --iterations "${ITERATIONS}" \
    --warmup "${WARMUP}" \
    --quality "${QUALITY}"
fi
