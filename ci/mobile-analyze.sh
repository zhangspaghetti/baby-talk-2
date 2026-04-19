#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../mobile"
echo '=== Mobile Analyze ==='
flutter pub get
flutter analyze
flutter test
echo '=== Mobile Analyze PASSED ==='
