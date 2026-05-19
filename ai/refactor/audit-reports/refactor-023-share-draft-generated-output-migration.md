# REFACTOR-023 Share Draft Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-023 moves `ShareLinkDraft.freezed.dart` into `mobile/lib/generated/features/share/domain/models/`. The task preserves share payload and message behavior, and adds canary coverage for copy semantics, source wire mapping, public payload checks, and visible share message output.

This task does not change runtime behavior, share payload shape, message copy, or generated-code hard-gate policy.

## Migrated Owner

| Generator | Owner Source | Old Output | New Output |
|---|---|---|---|
| Freezed | `mobile/lib/features/share/domain/models/share_link_draft.dart` | `mobile/lib/features/share/domain/models/share_link_draft.freezed.dart` | `mobile/lib/generated/features/share/domain/models/share_link_draft.freezed.dart` |

## Build Configuration

`mobile/build.yaml` now includes `share_link_draft.dart` in the scoped Freezed generation list. json_serializable and riverpod_generator remain disabled for this scoped migration path.

## Verification

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 5 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated share Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 5 tests |
| `flutter analyze` | Passed; no issues found |
| Share focused tests via `runTests` | Passed; 10 tests |
| Full `runTests` | Passed; 268 tests |
| `flutter test` | Passed; `01:12 +230: All tests passed!` |

## Generated File Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 3 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 8 | 0 |

## Residual Risks

- The known analyzer/SDK compatibility warning remains during scoped build_runner generation.
- Remaining generated-code migration is now limited to 8 Freezed outputs.
- No hard generated-code gate is introduced in this task.

## Standard Git Commit Message

```text
refactor(mobile): migrate share draft generated output
```