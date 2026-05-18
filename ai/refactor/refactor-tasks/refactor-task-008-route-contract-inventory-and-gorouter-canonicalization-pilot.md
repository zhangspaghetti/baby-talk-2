---
id: REFACTOR-008
title: Route Contract Inventory And GoRouter Canonicalization Pilot
status: done
priority: high
phase: 2
assignee: AI
created: 2026-05-18
estimated: 1d
---

## Goal

Create a single canonical route contract for the mobile app and wire the lowest-risk route call sites to it. This task is a behavior-preserving pilot, not a full router migration.

## Legacy Code Location

`mobile/lib/app/app.dart`, `mobile/lib/app/router/app_router.dart`, `mobile/lib/app/router/app_go_router.dart`, `mobile/lib/app/app_reentry_orchestrator.dart`, and `mobile/lib/features/practice/presentation/practice_route_args.dart`.

## Original Functionality Description

The app had route path strings duplicated across the inline production GoRouter, an alternate Riverpod GoRouter provider, the legacy named route factory, re-entry drain logic, and practice route helpers. The effective routes were `/`, `/onboarding`, `/practice`, and `/account`.

## Refactoring Approach

1. Add `AppRouteNames` as the canonical route path contract.
2. Re-export the route contract from the legacy `app_router.dart` compatibility surface.
3. Replace duplicated literal paths in existing GoRouter builders and route dispatch helpers.
4. Add route contract characterization tests for path stability and legacy named route fallback behavior.
5. Preserve every existing route path and navigation destination.

## Target Location

`mobile/lib/app/router/app_route_contract.dart`, existing app router files, re-entry orchestration, practice route args, and app route contract tests.

## Allowed Changes

- Add route path constants.
- Replace duplicated route path literals with constants.
- Add tests proving the canonical path contract and legacy route factory compatibility.
- Documentation artifacts describing the completed behavior.

## Forbidden Changes

- Changing route path values.
- Removing the legacy named route factory.
- Migrating app composition from the inline GoRouter to the alternate provider.
- Changing onboarding, account, practice, share, or invite navigation behavior.
- Changing route argument payloads.

## Acceptance Criteria

- [x] Canonical route constants exist for shell, home, onboarding, practice, and account paths.
- [x] Inline production GoRouter uses the canonical route contract.
- [x] Alternate Riverpod GoRouter provider uses the canonical route contract.
- [x] Legacy named route factory re-exports and uses the canonical route contract.
- [x] Share and invite re-entry dispatch use canonical shell/practice route constants.
- [x] `PracticeRouteArgs.push` uses the canonical practice route constant.
- [x] Route contract tests assert path stability and legacy fallback behavior.
- [x] Full mobile analyze/test/coverage baseline remains green.

## Regression Test Requirements

- [x] Unit test for canonical route path values.
- [x] Unit test for legacy named route factory compatibility and fallback behavior.
- [x] Existing app composition characterization remains green.
- [x] Existing re-entry orchestrator tests remain green.
- [x] Full mobile test suite remains green.

## Completion Evidence

- Added `AppRouteNames` in `mobile/lib/app/router/app_route_contract.dart`.
- Reused the contract from the inline GoRouter, alternate GoRouter provider, legacy route factory, re-entry orchestrator, and `PracticeRouteArgs.push`.
- Added `mobile/test/app/app_route_contract_test.dart`.
- Full `flutter analyze`: pass, no issues found.
- Full `flutter test`: pass, 209 tests passed.
- Full `flutter test --coverage`: pass, 209 tests passed.
- Line coverage after REFACTOR-008: 66.17%.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|-----|--------|-----|---------|
| Route constant typo changes a production path | Low | High | Tests assert exact path values for the canonical contract |
| Legacy named route users lose access to constants | Low | Medium | `app_router.dart` re-exports `AppRouteNames` |
| Re-entry dispatch changes destination behavior | Low | High | Only literal strings were replaced with equal constants; re-entry tests remain green |
| Future router migration assumes this completed full canonicalization | Medium | Medium | Task explicitly records this as a pilot and keeps legacy surfaces intact |

## Review Checklist

- [x] Route path values are unchanged.
- [x] Navigation destinations are unchanged.
- [x] Route argument payloads are unchanged.
- [x] Legacy named route compatibility remains present.
- [x] Full verification gates are green after implementation.

## Known Decisions

- Riverpod + GoRouter is the canonical app composition target.
- Legacy named routing remains a compatibility layer until a separate migration task removes it.
- Route changes must be behavior-preserving unless separately approved.

## Authorizations

- AR-R3-007.

## Dependencies

- REFACTOR-004.