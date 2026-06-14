---
phase: "22"
plan: "03"
---

# T03: Added the M007 Helm baseline verifier plus POSIX/CMD demo-smoke wrappers and bounded telemetry-backed contract tests.

**Added the M007 Helm baseline verifier plus POSIX/CMD demo-smoke wrappers and bounded telemetry-backed contract tests.**

## What Happened

Implemented `tool/verify_m007_s01_helm_baseline.dart` as the single source of truth for the local Helm front door. `demo` mode now runs the planned `preflight -> cluster -> infra -> app -> gateway -> smoke` sequence, while `smoke` mode reuses the lighter `preflight -> gateway -> smoke` path. The verifier checks required CLIs, creates the `babytalk-local` kind cluster when needed, installs/upgrades `babytalk-infra` and `babytalk-app` with their kind overrides, starts a temporary `kubectl port-forward` to `service/babytalk-app-gateway`, probes `http://127.0.0.1:8090/`, and always tears the port-forward down before exit. It also appends bounded JSONL telemetry to `tmp/m007-s01-helm-metrics.jsonl` with mode/shell/success/tthw/failure-stage metadata. Added thin POSIX and CMD wrappers for both up/smoke entry points and a pure-Dart test file covering CLI parsing, shell parity, and telemetry retention.

## Verification

Verified the verifier compiles cleanly with `dart analyze`, the new contract tests pass under `dart test`, and the required wrapper/verifier files plus stage markers exist. I also ran `dart run tool/verify_m007_s01_helm_baseline.dart smoke` in this executor environment to exercise the real stdout/telemetry contract: it failed fast at `first_failure_stage=preflight` with `likely_cause=kind_missing`, and appended a fresh entry to `tmp/m007-s01-helm-metrics.jsonl`, which confirms the failure-path observability works even without a live kind install on this machine.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `dart analyze tool/verify_m007_s01_helm_baseline.dart` | 0 | ✅ pass | 1675ms |
| 2 | `dart test test/tool/verify_m007_s01_helm_baseline_test.dart` | 0 | ✅ pass | 5655ms |
| 3 | `bash -lc "test -f scripts/dev-up-helm-demo.sh && test -f scripts/dev-verify-helm-demo.sh && grep -q 'preflight' tool/verify_m007_s01_helm_baseline.dart && grep -q 'cluster' tool/verify_m007_s01_helm_baseline.dart && grep -q 'gateway' tool/verify_m007_s01_helm_baseline.dart"` | 0 | ✅ pass | 643ms |
| 4 | `dart run tool/verify_m007_s01_helm_baseline.dart smoke` | 2 | ✅ pass (expected preflight contract in env without kind) | 2109ms |

## Deviations

Added `test/tool/verify_m007_s01_helm_baseline_test.dart` even though the plan only listed runtime artifacts, so the new verifier contract is covered by an executable test. Telemetry records also emit both `timestamp` and `timestamp_iso8601` to satisfy the slice-level history wording and the T03 plan wording without changing the bounded JSONL shape.

## Known Issues

The current executor environment does not have `kind` on PATH, so a live end-to-end `demo`/successful `smoke` run against a real cluster could not be completed here. The verifier’s preflight failure path, stdout contract, and telemetry append were verified instead.

## Files Created/Modified

- `tool/verify_m007_s01_helm_baseline.dart`
- `scripts/dev-up-helm-demo.sh`
- `scripts/dev-up-helm-demo.cmd`
- `scripts/dev-verify-helm-demo.sh`
- `scripts/dev-verify-helm-demo.cmd`
- `test/tool/verify_m007_s01_helm_baseline_test.dart`
- `tmp/m007-s01-helm-metrics.jsonl`
