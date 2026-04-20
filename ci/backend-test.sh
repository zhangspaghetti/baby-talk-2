#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../backend"
echo '=== Backend Test ==='
mvn verify -B
echo '=== Backend Test PASSED ==='
