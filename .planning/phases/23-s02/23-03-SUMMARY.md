---
phase: "23"
plan: "03"
---

# T03: Added Step 10 smoke boundary checks and an offline Dart verifier to lock the babytalk-infra vs babytalk-app release contract.

**Added Step 10 smoke boundary checks and an offline Dart verifier to lock the babytalk-infra vs babytalk-app release contract.**

## What Happened

Updated `ci/k8s-smoke.sh` with a new Step 10 that checks the schema compatibility matrix exists, verifies the runbook still names both `babytalk-infra` and `babytalk-app`, asserts the infra chart renders zero `Job` resources, and confirms the app chart still keeps the db-migration `hook-delete-policy`. Added `SCHEMA_MATRIX` alongside the existing runbook path and used `grep -c ... || true` for the zero-Job assertion so the smoke script stays correct under `set -euo pipefail`. Created `tool/verify_m007_s02_release_boundaries.dart` as a cluster-free verifier modeled on the existing staged pattern: it runs preflight (`helm version`, `dart --version`), verifies the infra chart contains no `Job`, verifies the app chart still contains `before-hook-creation,hook-succeeded` and `pre-install,pre-upgrade`, verifies the runbook mentions both release names and the schema matrix exists, and appends JSONL telemetry to `tmp/m007-s02-boundary-metrics.jsonl`. During verification I hit one implementation bug in the Dart regex (`(?m)` inline flag is invalid in Dart); I replaced it with `multiLine: true` and added a generic stage-exception fallback so unexpected verifier errors still get surfaced with stage context and telemetry.

## Verification

Verified the new verifier with `dart analyze tool/verify_m007_s02_release_boundaries.dart` and `dart run tool/verify_m007_s02_release_boundaries.dart`; the offline verifier passed all 4 stages and wrote `tmp/m007-s02-boundary-metrics.jsonl` with `mode=offline`, `stages_run=4`, `stages_passed=4`, and `first_failure_stage=null`. Verified the slice smoke contract with `bash ci/k8s-smoke.sh`; the script passed all 57 assertions, including the new Step 10 checks for schema matrix existence, runbook references, zero infra `Job` resources, and app hook-delete-policy retention. Confirmed the documentation conditions behind the auto-fix prompt are satisfied locally: `docs/schema-compatibility-matrix.md` exists and is 122 lines, and `docs/runbooks/k8s-deploy.md` is 532 lines.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `dart analyze tool/verify_m007_s02_release_boundaries.dart` | 0 | ✅ pass | 1558ms |
| 2 | `dart run tool/verify_m007_s02_release_boundaries.dart` | 0 | ✅ pass | 2890ms |
| 3 | `bash ci/k8s-smoke.sh` | 0 | ✅ pass | 5510ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `ci/k8s-smoke.sh`
- `tool/verify_m007_s02_release_boundaries.dart`
