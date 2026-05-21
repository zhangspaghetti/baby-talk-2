# Refactor Task: REFACTOR-026 Practice Phrase Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Objective

Continue strict generated-code isolation by moving `PracticePhrase.freezed.dart` into `mobile/lib/generated/` without changing practice phrase model behavior.

## Scope

- Add a focused generated-code canary for `PracticePhrase.copyWith` and `audioPlayerAsset` path normalization.
- Update `PracticePhrase` to point its `part` directive at `lib/generated/features/practice/domain/models/practice_phrase.freezed.dart`.
- Extend the scoped `mobile/build.yaml` Freezed include list with the practice phrase owner only.
- Regenerate output with build_runner and delete the old co-located Freezed file.
- Keep json_serializable and riverpod_generator disabled in the scoped canary configuration.

## Legacy Code Location

- Old generated output: `mobile/lib/features/practice/domain/models/practice_phrase.freezed.dart`
- New generated output: `mobile/lib/generated/features/practice/domain/models/practice_phrase.freezed.dart`
- Owner source: `mobile/lib/features/practice/domain/models/practice_phrase.dart`

## Original Functionality Description

`PracticePhrase` is the practice phrase value model used by catalog loading, session rendering, and phrase audio playback. It must preserve field values, copy semantics, and `audioPlayerAsset` normalization for both `assets/...` and already-relative asset paths.

## Refactoring Approach

1. Add a focused canary for `PracticePhrase.copyWith` and audio asset normalization.
2. Run the generated-code canary before migration to capture existing behavior.
3. Change only the owner source `part` path and scoped Freezed generation include list.
4. Run build_runner to generate the new output under `lib/generated/`.
5. Delete the old co-located Freezed output.
6. Run analyzer, focused generated/practice tests, and full Flutter tests.

## Forbidden Changes

- Do not change practice phrase fields, audio path normalization, catalog semantics, or UI rendering behavior.
- Do not expand generation to unrelated Freezed owners in this task.
- Do not enable unrestricted json_serializable or riverpod generation.
- Do not hand-edit generated Dart output.
- Do not introduce a generated-code hard gate yet.

## Acceptance Criteria

- [x] `PracticePhrase` generated output lives under `mobile/lib/generated/`.
- [x] Old co-located `practice_phrase.freezed.dart` is removed.
- [x] Existing and new generated outputs do not coexist for this owner.
- [x] build_runner can reproduce the output with zero subsequent actions.
- [x] Generated-code canary tests pass.
- [x] Practice focused tests pass.
- [x] Full Flutter tests pass.

## Verification Evidence

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 7 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated practice phrase Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 7 tests |
| `flutter test test/features/practice` | Passed; 27 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:09 +232: All tests passed!` |

## Generated File Counts After Task

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 6 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 5 | 0 |

## Residual Risks

- The remaining generated-code migration now consists of 5 co-located Freezed outputs.
- A generated-code placement hard gate is still not approved.

## Standard Git Commit Message

```text
refactor(mobile): migrate practice phrase generated output
```