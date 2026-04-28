#!/usr/bin/env bash
# Helm-first alias since M007 — was compose-based M006 front door.
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

exec ./scripts/dev-verify-helm-demo.sh "$@"
