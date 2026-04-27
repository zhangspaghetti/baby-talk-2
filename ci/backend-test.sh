#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"

echo '=== Backend Reactor Test ==='
"$BACKEND_DIR/mvnw" -f "$BACKEND_DIR/pom.xml" -B test

echo '=== Backend Test PASSED ==='
