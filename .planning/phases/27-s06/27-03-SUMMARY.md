---
phase: "27"
plan: "03"
---

# T03: Created tool/verify_m007_s06_docs_coherence.dart (4-stage offline Dart verifier, JSONL telemetry) and added ci/k8s-smoke.sh Step 12 (5 docs-coherence assertions)

**Created tool/verify_m007_s06_docs_coherence.dart (4-stage offline Dart verifier, JSONL telemetry) and added ci/k8s-smoke.sh Step 12 (5 docs-coherence assertions)**

## What Happened

Wrote verify_m007_s06_docs_coherence.dart following the exact S02 verifier pattern: 4 stages (preflight, readme-truth, contributing-truth, runbook-truth), file-content assertions for both presence and absence of stale/required strings, JSONL telemetry to tmp/m007-s06-docs-metrics.jsonl. Added Step 12 to ci/k8s-smoke.sh with 5 assertions (no nginx:alpine in README, no gateway stub in runbook, no admin-api:8081 in CONTRIBUTING, MyBatisPlus present in CONTRIBUTING, Spring Cloud Gateway present in runbook) using || true for absence grep counts to survive set -euo pipefail.

## Verification

dart analyze tool/verify_m007_s06_docs_coherence.dart → No issues found (exit 0); dart run tool/verify_m007_s06_docs_coherence.dart → all 4 stages PASS, exit 0, JSONL written; bash ci/k8s-smoke.sh → 68 PASS / 0 FAIL / 0 SKIP (Step 12 all 5 assertions green)

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `dart analyze tool/verify_m007_s06_docs_coherence.dart` | 0 | ✅ pass | 17400ms |
| 2 | `dart run tool/verify_m007_s06_docs_coherence.dart` | 0 | ✅ pass — 4/4 stages | 2000ms |
| 3 | `bash ci/k8s-smoke.sh` | 0 | ✅ pass — 68 PASS / 0 FAIL / 0 SKIP | 6900ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `tool/verify_m007_s06_docs_coherence.dart`
- `ci/k8s-smoke.sh`
