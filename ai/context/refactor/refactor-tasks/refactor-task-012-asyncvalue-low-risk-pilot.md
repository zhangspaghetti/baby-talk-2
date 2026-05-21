# Refactor Task: REFACTOR-012 AsyncValue Low-Risk Pilot

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 / Phase 2  
Created: 2026-05-18  
Status: done

## Objective

Introduce the first explicit `AsyncValue` presentation state pilot on a low-risk async UI command while preserving existing user-visible behavior and legacy getter compatibility.

## Scope

- Document the selected AsyncValue pilot surface under `ai/architecture`.
- Add an `AsyncValue` request state to `ShareNotifier.shareCurrent()`.
- Keep existing share notifier getters and provider shape available for current widgets.
- Add focused tests proving the AsyncValue loading/data state and legacy getter behavior.
- Update R2 governance artifacts after validation.

## Forbidden Changes

- Do not migrate account, mentor, household, onboarding, practice, routing, or app composition in this task.
- Do not replace `ShareNotifier` or `shareNotifierProvider` with `AsyncNotifier`.
- Do not change share API payloads, share sheet behavior, or user-facing share copy.
- Do not touch generated Dart files.

## Acceptance Criteria

- [x] Pilot surface is documented with target rule, chosen scope, and forbidden changes.
- [x] `ShareNotifier` exposes a read-only `AsyncValue<ShareExecutionResult?>` for the share request.
- [x] Existing share notifier getters remain compatible.
- [x] Focused tests cover loading/data AsyncValue states and legacy getter behavior.
- [x] `flutter analyze`, `flutter test`, and `flutter test --coverage` remain green.

## Regression Test Requirements

- [x] Focused share notifier test passes.
- [x] Full mobile test suite remains green.

## Completion Evidence

- Added `ai/architecture/async-value-pilot.md` documenting the target AsyncValue rule and the selected low-risk ShareNotifier surface.
- Added `ShareNotifier.shareRequest` as `AsyncValue<ShareExecutionResult?>` and derived `isSharing` from the AsyncValue loading state.
- Preserved existing `canShare`, `lastShareStatus`, `message`, `lastSharePhase`, and share result mapping semantics.
- Added `REFACTOR-012: 分享请求通过 AsyncValue 暴露 loading 和完成态` to `mobile/test/features/share/share_notifier_test.dart`.
- Focused validation: `flutter test test/features/share/share_notifier_test.dart` passed, 4 tests passed.
- Full `flutter analyze`: pass, no issues found.
- Full `flutter test`: pass, 215 tests passed.
- Full `flutter test --coverage`: pass, 215 tests passed.
- Line coverage after REFACTOR-012: 66.32%.

## Authorizations

- AR-R3-011.