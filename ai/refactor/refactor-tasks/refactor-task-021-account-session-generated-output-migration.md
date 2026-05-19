# Refactor Task: REFACTOR-021 AccountSession Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Objective

Continue the approved strict generated-code migration in a single-owner batch by moving `AccountSession.freezed.dart` from a feature-local output path into `mobile/lib/generated/` without changing account session behavior.

## Scope

- Add a focused generated-code canary test for `AccountSession.copyWith` and JWT helper behavior.
- Update `AccountSession` to point its `part` directive at `lib/generated/features/account/domain/models/account_session.freezed.dart`.
- Extend the scoped `mobile/build.yaml` Freezed include list with the `AccountSession` owner only.
- Regenerate output with build_runner and delete the old co-located generated file.
- Keep json_serializable and riverpod_generator disabled in the scoped canary configuration.

## Legacy Code Location

- Old generated output: `mobile/lib/features/account/domain/models/account_session.freezed.dart`
- New generated output: `mobile/lib/generated/features/account/domain/models/account_session.freezed.dart`
- Owner source: `mobile/lib/features/account/domain/models/account_session.dart`

## Original Functionality Description

`AccountSession` is a Freezed value model used by account repository and authenticated client paths. It must preserve validated constructor behavior, copy semantics, JWT token helper behavior, and JSON-map persistence compatibility.

## Refactoring Approach

1. Add a focused canary test proving `AccountSession.copyWith` preserves original session fields and token helper semantics.
2. Run the canary before migration to capture existing behavior.
3. Change only the owner source `part` path and scoped build configuration.
4. Run build_runner to generate the new output under `lib/generated/`.
5. Delete the old co-located output.
6. Run analyzer, focused tests, account tests, and full Flutter tests.

## Forbidden Changes

- Do not change `AccountSession` fields, constructor validation, JSON-map shape, token helper behavior, or persistence semantics.
- Do not expand generation to unrelated Freezed owners in this task.
- Do not enable unrestricted json_serializable or riverpod generation.
- Do not hand-edit generated Dart output.
- Do not introduce a generated-code hard gate yet.

## Acceptance Criteria

- [x] `AccountSession` generated output lives under `mobile/lib/generated/`.
- [x] Old co-located `account_session.freezed.dart` is removed.
- [x] Existing and new generated outputs do not coexist for this owner.
- [x] build_runner can reproduce the output with zero subsequent actions.
- [x] Account session behavior tests pass.
- [x] Full Flutter tests pass.

## Verification Evidence

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 3 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated new AccountSession output, with existing analyzer-version warning |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 3 tests |
| `flutter analyze` | Passed; no issues found |
| `runTests` for account repository, contract, and entry screen tests | Passed; 17 tests |
| Full `runTests` | Passed; 266 tests |
| `flutter test` | Passed; `01:10 +228: All tests passed!` |

## Generated File Counts After Task

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 2 | 1 |
| Remaining co-located under `mobile/lib/features/**` | 9 | 1 |

## Residual Risks

- `build_runner` still reports the known analyzer/SDK compatibility warning; it did not fail this scoped generation.
- The remaining migration still includes 9 co-located Freezed outputs and 1 co-located Isar/source_gen output.
- A generated-code placement hard gate is still not approved.

## Standard Git Commit Message

```text
refactor(mobile): migrate account session generated output
```