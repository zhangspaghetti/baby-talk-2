# REFACTOR-036 Account And Practice Coverage Closure

---
id: REFACTOR-036
title: Account, practice session, and home coverage closure
status: done
priority: high
phase: 4
assignee: AI
created: 2026-05-20
estimated: 0.5-1 day
---

## Goal

Close the R4 global coverage blocker by adding behavior-preserving regression tests for the largest remaining non-generated coverage gaps after REFACTOR-035.

## Target Locations

- `mobile/lib/features/account/data/repositories/account_repository.dart`
- `mobile/lib/features/practice/presentation/practice_session_notifier.dart`
- `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart`
- `mobile/lib/features/practice/presentation/screens/home_screen.dart`

## Approach

1. Extend existing account repository tests with local fallback, remote revoke/delete, token refresh persistence, sanitized API failure, and sync failure branches.
2. Extend existing practice session notifier tests with playback, dynamic mode, retry, and save-failure branches.
3. Extend the existing critical UI coverage test with `PracticeSessionScreen` provider states and a controlled `HomeScreen` resolved-continuity path.
4. Run focused regression tests, analyzer, and the full `flutter test --coverage --concurrency=1` suite.
5. Update R4 verification reports with the new LCOV result.

## Allowed Changes

- Add or extend tests and test fixtures/fakes.
- Update R4 verification reports and task index/timeline.

## Forbidden Changes

- Do not change product behavior, routes, copy, persisted schema, API payloads, or feature requirements.
- Do not wire destructive local-data lifecycle flows.
- Do not add a coverage exception; prove the target with LCOV instead.
- Do not delete or move legacy code.

## Acceptance Criteria

- [x] Focused regression tests pass.
- [x] `flutter analyze` passes.
- [x] Full `flutter test --coverage --concurrency=1` passes.
- [x] Global LCOV reaches at least 80%.
- [x] R4 verification reports are updated truthfully.

## Verification Evidence

| Command | Exit | Result |
|---|---:|---|
| Focused account/practice/home coverage tests | 0 | 31 tests passed |
| `flutter analyze` from `mobile/` | 0 | No issues found |
| `flutter test --coverage --concurrency=1` from `mobile/` | 0 | 264 tests passed |
| LCOV parse from `mobile/coverage/lcov.info` | 0 | 8766/10918 = 80.29% |

## Coverage Decision

The R4 global coverage criterion is now met without an exception. Production readiness remains blocked by non-coverage gates: target-platform/CI replay, destructive sensitive-data lifecycle approval and real-store wiring, performance benchmark evidence, remaining hard-gate policy decisions, and final human release approval.
