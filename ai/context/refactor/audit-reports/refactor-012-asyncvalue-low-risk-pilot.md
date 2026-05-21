# REFACTOR-012 AsyncValue Low-Risk Pilot

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 2  
Task: REFACTOR-012  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed

## Summary

REFACTOR-012 introduces the first explicit `AsyncValue` presentation-state pilot on the low-risk share command path. The pilot exposes share request loading/data state through `ShareNotifier.shareRequest` while preserving the existing ChangeNotifier provider shape and legacy getters used by current widgets.

The production behavior of share payload construction, share sheet launching, route handling, auth, and persistence remains unchanged.

## Changed Files

| File | Purpose |
|---|---|
| `mobile/lib/features/share/presentation/share_notifier.dart` | Adds `AsyncValue<ShareExecutionResult?> shareRequest` and derives `isSharing` from loading state |
| `mobile/test/features/share/share_notifier_test.dart` | Adds R012 focused test for AsyncValue loading/data states while retaining legacy getter assertions |
| `ai/architecture/async-value-pilot.md` | Documents pilot target rule, chosen surface, forbidden changes, and exit signal |
| `ai/context/refactor/refactor-tasks/refactor-task-012-asyncvalue-low-risk-pilot.md` | Records R012 task scope, acceptance criteria, and completion evidence |

## Behavior Preservation

- Existing `ShareNotifier.isSharing`, `canShare`, `lastShareStatus`, `message`, and `lastSharePhase` remain available.
- Duplicate share requests still reuse the in-flight future.
- Shared, cancelled, and failed share results keep their existing status and message mapping.
- Share repository payload generation is unchanged.
- `shareNotifierProvider` remains `ChangeNotifierProvider.autoDispose<ShareNotifier>`.

## Verification

| Command | Result |
|---|---|
| `flutter test test/features/share/share_notifier_test.dart` | Pass; 4 tests passed |
| `flutter analyze` from `mobile/` | Pass; no issues found |
| `flutter test` from `mobile/` | Pass; 215 tests passed |
| `flutter test --coverage` from `mobile/` | Pass; 215 tests passed |

## Coverage

| Metric | Value |
|---|---:|
| Lines hit | 7136 |
| Lines found | 10760 |
| Line coverage | 66.32% |

## Scope Check

- Account, mentor, household, onboarding, practice, routing, and app composition: unchanged.
- Share API payloads and share sheet behavior: unchanged.
- Generated Dart files: unchanged.
- AsyncNotifier/provider replacement: not introduced.

## Residual Notes

- A combined `flutter analyze; flutter test; flutter test --coverage` run passed analyze and normal tests, then the coverage phase stalled early in `account_repository_contract_test.dart`. A clean standalone coverage rerun passed with 215 tests and the LCOV summary above, so R012 is considered green.
- Full test runs still emit benign Isar inspector URLs and the pre-existing nonfatal onboarding tap warning for `onboarding-name-continue`; tests pass.

## Follow-Up

- REFACTOR-013 remains blocked until separately approved for local sensitive data lifecycle planning and tests.
- Future AsyncValue migration should use this pilot as the compatibility pattern: expose AsyncValue first, preserve legacy getters, then migrate widgets after characterization coverage exists.