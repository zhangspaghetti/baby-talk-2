# REFACTOR-032 Generated Code Hard Gate

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-032 adds a Flutter test hard gate for generated-code location policy. The gate fails if generated Dart outputs reappear under `mobile/lib/features/` or if feature source files use `part` directives that point at co-located `*.freezed.dart` or `*.g.dart` outputs instead of the generated tree.

The gate is implemented in `mobile/test/generated/generated_code_location_gate_test.dart` so it runs with the regular Flutter test suite.

## Gate Coverage

| Policy | Enforcement |
|---|---|
| No co-located Freezed output under `lib/features` | Scans `lib/features` recursively for `*.freezed.dart` |
| No co-located Isar/source_gen output under `lib/features` | Scans `lib/features` recursively for `*.g.dart` |
| Generated part directives point to `lib/generated` | Scans feature source files for generated `part` directives that omit `/generated/` |

## RED/GREEN Proof

| Step | Result |
|---|---|
| Add temporary `lib/features/generated_gate_temporary.freezed.dart` offender | Gate failed as expected and reported the offender path |
| Remove temporary offender | Gate passed |

## Verification

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_location_gate_test.dart` with temporary offender | Failed as expected; reported `lib/features/generated_gate_temporary.freezed.dart` |
| `flutter test test/generated/generated_code_location_gate_test.dart` after temporary offender removal | Passed; 2 tests |
| `flutter test test/generated` | Passed; 12 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:10 +237: All tests passed!` |

## Generated File Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 11 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 0 | 0 |

## Residual Risks

- This gate runs through Flutter tests; it does not add separate CI workflow wiring.
- Production readiness remains blocked by coverage, lifecycle wiring, backup/encryption proof, performance benchmark, target-platform/CI replay, and final human release confirmation items tracked elsewhere.

## Standard Git Commit Message

```text
test(mobile): add generated code location gate
```