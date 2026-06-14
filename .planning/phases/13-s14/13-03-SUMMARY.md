---
phase: "13"
plan: "03"
---

# T03: Locked S14 release-closure step banners to real rerun commands and revalidated the full repo-root release gate.

**Locked S14 release-closure step banners to real rerun commands and revalidated the full repo-root release gate.**

## What Happened

I first replayed the canonical repo-root verifier (`dart run tool/verify_m006_s14_release_closure.dart`) to validate the CI-equivalent release closure against local reality. The full chain passed through S07 → S08 `--helm` → S12 → S13, but that replay exposed an observability drift in the S14 truth owner: `_runChildGate` printed the literal `${gate.rerunCommand}` banner because the step line used a Dart raw string, even though `drill_down_verifier` itself was correct.

I fixed the drift in `tool/verify_m006_s14_release_closure.dart` with a surgical change only in the S14 aggregator. The displayed rerun command is now modeled as a pure `ChildGate.stepCommandLine` getter and `_runChildGate` writes that value, so the runtime banner, child rerun command, and drill-down semantics all stay aligned without changing child execution ownership, timeout budgets, or duplicating browser/Helm logic into S14.

I then extended `test/tool/verify_m006_s14_release_closure_test.dart` so the focused contract suite locks the emitted `$ dart run ...` banner for every child gate in addition to the existing child order, `--helm`, runbook, artifact, and fail-closed assertions. After that, I reran the focused test, the `--help` contract, and the full repo-root release gate. The final replay again finished green, preserved the drill-down hints and child pass markers, and emitted `All M006/S14 release-closure verification steps passed.` with the corrected step-command output visible in the captured log.

## Verification

Verified the focused S14 contract test with `flutter test test/tool/verify_m006_s14_release_closure_test.dart`, which passed after locking the new `ChildGate.stepCommandLine` helper. Verified the CLI usage surface with `dart run tool/verify_m006_s14_release_closure.dart --help`, which returned the usage-only contract without runtime markers. Replayed the full canonical release closure with `dart run tool/verify_m006_s14_release_closure.dart`; it completed successfully, reran the child gates in order, preserved drill-down verifier/runbook/artifact output, regenerated the Playwright report during the S12 child path, and ended with `All M006/S14 release-closure verification steps passed.`. The captured full-gate log also showed the corrected step-command lines for S07/S08/S12/S13 via explicit grep checks.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `flutter test test/tool/verify_m006_s14_release_closure_test.dart` | 0 | ✅ pass | 70300ms |
| 2 | `dart run tool/verify_m006_s14_release_closure.dart --help` | 0 | ✅ pass | 4574ms |
| 3 | `dart run tool/verify_m006_s14_release_closure.dart` | 0 | ✅ pass | 503184ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `tool/verify_m006_s14_release_closure.dart`
- `test/tool/verify_m006_s14_release_closure_test.dart`
