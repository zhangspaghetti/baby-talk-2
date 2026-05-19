# Refactor Task: REFACTOR-025 Mentor Fact Event Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Objective

Continue strict generated-code isolation by moving `MentorFactEvent.freezed.dart` into `mobile/lib/generated/` without changing mentor telemetry fact behavior.

## Scope

- Extend the existing generated-code canary with focused `MentorFactEvent.copyWith` and metadata assertions.
- Update `MentorFactEvent` to point its `part` directive at `lib/generated/features/mentor/domain/models/mentor_fact_event.freezed.dart`.
- Extend the scoped `mobile/build.yaml` Freezed include list with the mentor fact event owner only.
- Regenerate output with build_runner and delete the old co-located Freezed file.
- Keep json_serializable and riverpod_generator disabled in the scoped canary configuration.

## Legacy Code Location

- Old generated output: `mobile/lib/features/mentor/domain/models/mentor_fact_event.freezed.dart`
- New generated output: `mobile/lib/generated/features/mentor/domain/models/mentor_fact_event.freezed.dart`
- Owner source: `mobile/lib/features/mentor/domain/models/mentor_fact_event.dart`

## Original Functionality Description

`MentorFactEvent` is the local Mentor telemetry fact value model. It must preserve validated construction, event key derivation, wire-value parsing, copy semantics, redacted metadata output, visible metadata output, and Isar entity conversion behavior.

## Refactoring Approach

1. Run the generated-code canary before migration to capture existing behavior.
2. Add `copyWith` and metadata assertions for `MentorFactEvent` to the existing canary.
3. Change only the owner source `part` path and scoped Freezed generation include list.
4. Run build_runner to generate the new output under `lib/generated/`.
5. Delete the old co-located Freezed output.
6. Run analyzer, focused generated/mentor tests, and full Flutter tests.

## Forbidden Changes

- Do not change mentor fact fields, validation, parsing, event-key derivation, wire values, or metadata map shapes.
- Do not expand generation to unrelated Freezed owners in this task.
- Do not enable unrestricted json_serializable or riverpod generation.
- Do not hand-edit generated Dart output.
- Do not introduce a generated-code hard gate yet.

## Acceptance Criteria

- [x] `MentorFactEvent` generated output lives under `mobile/lib/generated/`.
- [x] Old co-located `mentor_fact_event.freezed.dart` is removed.
- [x] Existing and new generated outputs do not coexist for this owner.
- [x] build_runner can reproduce the output with zero subsequent actions.
- [x] Generated-code canary tests pass.
- [x] Mentor focused tests pass.
- [x] Full Flutter tests pass.

## Verification Evidence

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 6 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated mentor fact event Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 6 tests |
| `flutter test test/features/mentor` | Passed; 39 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:03 +231: All tests passed!` |

## Generated File Counts After Task

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 5 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 6 | 0 |

## Residual Risks

- The remaining generated-code migration now consists of 6 co-located Freezed outputs.
- A generated-code placement hard gate is still not approved.

## Standard Git Commit Message

```text
refactor(mobile): migrate mentor fact generated output
```