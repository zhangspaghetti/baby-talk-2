#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_root/ci/download-sources.sh"
cd "$repo_root/mobile"
echo '=== Mobile Analyze ==='
flutter pub get
flutter analyze
flutter test
echo '=== Mobile Analyze PASSED ==='
