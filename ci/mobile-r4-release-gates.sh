#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/ci/download-sources.sh"

echo '=== Mobile R4 Release Gates ==='
cd "$repo_root"
dart tool/verify_refactor_011_feature_boundaries.dart
dart tool/verify_refactor_013_sensitive_lifecycle.dart
dart tool/verify_m2_11_custom_scene_gates.dart
flutter test test/tool/verify_m2_11_custom_scene_gates_test.dart

cd "$repo_root/mobile"
flutter pub get
flutter test \
  test/generated/generated_code_location_gate_test.dart \
  test/tool/r4_release_gate_policy_test.dart \
  test/features/account/account_entry_screen_test.dart \
  test/core/local_data_lifecycle/local_sensitive_data_backup_posture_test.dart \
  test/core/local_data_lifecycle/local_sensitive_data_backup_protection_test.dart \
  test/app/local_sensitive_data_clearance_registry_test.dart

if [[ "${BABY_TALK_RUN_R4_FULL_PERF:-0}" == '1' ]]; then
  flutter test integration_test/r4_performance_benchmark_test.dart \
    --dart-define=R4_PERF_EVENT_COUNTS=0,100,1000,10000
else
  echo 'Skipping R4 full performance profile; set BABY_TALK_RUN_R4_FULL_PERF=1 on an approved target runner.'
fi

echo '=== Mobile R4 Release Gates PASSED ==='
