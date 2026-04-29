#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"
export BABY_TALK_FRONT_DOOR_SHELL=posix

if ! command -v dart >/dev/null 2>&1; then
  echo "demo_status=failed"
  echo "tthw_seconds=0"
  echo "first_failure_stage=preflight"
  echo "likely_cause=dart_missing"
  echo "next_action=Install Dart or Flutter, then rerun ./scripts/dev-verify-helm-demo.sh"
  echo "gateway_url=http://127.0.0.1:8090/"
  echo "telemetry_path=tmp/m007-s01-helm-metrics.jsonl"
  exit 127
fi

# Strip "Running build hooks..." noise that dart run writes to stdout before
# our program starts (transitive native-assets side effect from Flutter SDK).
dart run tool/verify_m007_s01_helm_baseline.dart smoke "$@" | grep -v '^Running build hooks' | grep -v '^$'
