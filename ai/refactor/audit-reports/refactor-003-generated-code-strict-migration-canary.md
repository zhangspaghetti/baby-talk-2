# REFACTOR-003 Generated Code Strict Migration Canary

Version: Flutter AI Software Factory v1.0.0
Stage: R1 / Phase 1 backfill
Task: REFACTOR-003
Project: Baby Talk 2 mobile Flutter app
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-003 proves a narrow generated-code migration can move one Freezed output and one Isar output from feature-local `part` files into `mobile/lib/generated/` without changing runtime behavior.

This is a canary only. It does not complete the full generated-code migration and does not approve a generated-code hard gate.

## Canary Owners

| Generator | Owner Source | Old Output | New Output |
|---|---|---|---|
| Freezed | `mobile/lib/features/household/domain/models/household_invite_link.dart` | `mobile/lib/features/household/domain/models/household_invite_link.freezed.dart` | `mobile/lib/generated/features/household/domain/models/household_invite_link.freezed.dart` |
| Isar | `mobile/lib/features/mentor/data/local/mentor_fact_event_entity.dart` | `mobile/lib/features/mentor/data/local/mentor_fact_event_entity.g.dart` | `mobile/lib/generated/features/mentor/data/local/mentor_fact_event_entity.g.dart` |

## Build Configuration

`mobile/build.yaml` scopes the canary build to the selected owners:

- Freezed is limited to `household_invite_link.dart` and writes to `lib/generated/features/.../*.freezed.dart`.
- Isar generation is limited to `mentor_fact_event_entity.dart`.
- `source_gen|combining_builder` writes selected `.g.dart` output to `lib/generated/features/.../*.g.dart`.
- `json_serializable` and `riverpod_generator` are disabled for this canary because the first unrestricted build attempt hit existing build_runner parser failures in unrelated API service files while `flutter analyze` remained green.

## Verification

| Command | Result |
|---|---|
| `flutter pub run build_runner build --delete-conflicting-outputs` from `mobile/` | Pass after scoped canary config; reproducible rerun produced `0 outputs (0 actions)` |
| Targeted canary and owner tests | Pass; generated canary, household repository/notifier, and mentor repository tests passed |
| `flutter analyze` from `mobile/` | Pass; no issues found |
| `flutter test` from `mobile/` | Pass; 222 tests passed |
| `flutter test --coverage` from `mobile/` | Pass; 222 tests passed |

## Coverage

| Metric | Value |
|---|---:|
| Lines hit | 7173 |
| Lines found | 10780 |
| Line coverage | 66.54% |

## Generated File Counts After Canary

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 1 | 1 |
| Remaining co-located under `mobile/lib/features/**` | 10 | 1 |

## Scope Check

- Business logic: unchanged.
- Route, API payload, persistence semantics, copy, and visuals: unchanged.
- Generated files: produced by build_runner, not hand-edited.
- Old and new generated outputs: do not coexist for the two canary owners.
- Full generated migration: still pending.
- Hard CI gate: not introduced.

## Rollback Path

1. Restore the two canary source `part` directives to their original feature-local paths.
2. Restore the two old generated outputs or rerun generation with feature-local output configuration.
3. Remove `mobile/build.yaml` if the canary-specific build configuration is no longer desired.
4. Delete the two `mobile/lib/generated/features/...` canary outputs.
5. Re-run build_runner, analyzer, targeted owner tests, and full Flutter tests.

## Follow-Up

- Decide whether to expand the generated-code migration in small batches or first resolve the build_runner/analyzer incompatibility exposed by unrestricted json_serializable and riverpod_generator scans.
- Do not convert generated-code placement into a hard gate until the remaining 10 Freezed files and 1 Isar/source_gen file are migrated or explicitly excepted.