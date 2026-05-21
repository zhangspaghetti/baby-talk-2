# Refactor Task: REFACTOR-023 Share Draft Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Objective

Continue strict generated-code isolation by moving `ShareLinkDraft.freezed.dart` into `mobile/lib/generated/` without changing share payload or share message behavior.

## Scope

- Add a focused generated-code canary test for `ShareLinkDraft.copyWith`, public payload detection, create-payload source mapping, and share message output.
- Update `ShareLinkDraft` to point its `part` directive at `lib/generated/features/share/domain/models/share_link_draft.freezed.dart`.
- Extend the scoped `mobile/build.yaml` Freezed include list with the share draft owner only.
- Regenerate output with build_runner and delete the old co-located Freezed file.
- Keep json_serializable and riverpod_generator disabled in the scoped canary configuration.

## Legacy Code Location

- Old generated output: `mobile/lib/features/share/domain/models/share_link_draft.freezed.dart`
- New generated output: `mobile/lib/generated/features/share/domain/models/share_link_draft.freezed.dart`
- Owner source: `mobile/lib/features/share/domain/models/share_link_draft.dart`

## Original Functionality Description

`ShareLinkDraft` is the share-domain Freezed value model used to create public share payloads and user-visible share messages. It must preserve copy semantics, source wire values, public payload checks, sanitization behavior, and share URL normalization behavior.

## Refactoring Approach

1. Add a focused canary test for `ShareLinkDraft.copyWith` and public payload behavior.
2. Run the canary before migration to capture existing behavior.
3. Change only the owner source `part` path and scoped Freezed generation include list.
4. Run build_runner to generate the new output under `lib/generated/`.
5. Delete the old co-located Freezed output.
6. Run analyzer, focused generated/share tests, and full Flutter tests.

## Forbidden Changes

- Do not change share payload keys, source wire values, sanitization, URL normalization, or message content behavior.
- Do not expand generation to unrelated Freezed owners in this task.
- Do not enable unrestricted json_serializable or riverpod generation.
- Do not hand-edit generated Dart output.
- Do not introduce a generated-code hard gate yet.

## Acceptance Criteria

- [x] `ShareLinkDraft` generated output lives under `mobile/lib/generated/`.
- [x] Old co-located `share_link_draft.freezed.dart` is removed.
- [x] Existing and new generated outputs do not coexist for this owner.
- [x] build_runner can reproduce the output with zero subsequent actions.
- [x] Share focused tests pass.
- [x] Full Flutter tests pass.

## Verification Evidence

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 5 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated share Freezed output, with existing analyzer-version warning |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 5 tests |
| `flutter analyze` | Passed; no issues found |
| Share focused tests via `runTests` | Passed; 10 tests |
| Full `runTests` | Passed; 268 tests |
| `flutter test` | Passed; `01:12 +230: All tests passed!` |

## Generated File Counts After Task

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 3 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 8 | 0 |

## Residual Risks

- `build_runner` still reports the known analyzer/SDK compatibility warning; it did not fail this scoped generation.
- The remaining generated-code migration now consists of 8 co-located Freezed outputs.
- A generated-code placement hard gate is still not approved.

## Standard Git Commit Message

```text
refactor(mobile): migrate share draft generated output
```