# REFACTOR-032 Generated Code Hard Gate

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Goal

Convert the generated-code location policy from migration discipline into a Flutter test hard gate. Future co-located generated outputs under `mobile/lib/features/` must fail the test suite.

## Scope

In scope:

- Add a generated-code location test that rejects `*.freezed.dart` and `*.g.dart` under `mobile/lib/features/`.
- Add a generated-code part directive test that rejects feature source `part` directives pointing at co-located generated outputs.
- Prove the gate turns red with a temporary co-located generated file, then remove the temporary file.
- Run generated-code tests, analyzer, and full Flutter tests.
- Update governance artifacts and commit with a conventional commit message.

Out of scope:

- Any additional generated output migration.
- build_runner configuration changes unless the gate exposes a real issue.
- CI workflow changes outside the Flutter test suite.
- Coverage, lifecycle wiring, performance benchmarks, or platform replay.

## Regression Requirements

- [x] Temporary co-located generated output causes the gate test to fail.
- [x] With the temporary offender removed, generated-code tests pass.
- [x] No co-located Freezed outputs remain under `mobile/lib/features/`.
- [x] No co-located Isar/source_gen `.g.dart` outputs remain under `mobile/lib/features/`.
- [x] Feature source `part` directives for generated Dart outputs point to `lib/generated/`.
- [x] Full Flutter tests pass.

## Verification Log

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_location_gate_test.dart` with temporary offender | Failed as expected; reported `lib/features/generated_gate_temporary.freezed.dart` |
| `flutter test test/generated/generated_code_location_gate_test.dart` after temporary offender removal | Passed; 2 tests |
| `flutter test test/generated` | Passed; 12 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:10 +237: All tests passed!` |

## Generated Output Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 11 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 0 | 0 |

## Standard Git Commit Message

```text
test(mobile): add generated code location gate
```