---
id: REFACTOR-004
title: App Boot Router Provider Characterization
status: done
priority: high
phase: 1
assignee: AI
created: 2026-05-18
estimated: 1-2d
---

## Goal

Add characterization tests for app boot, route entry, onboarding/shell gate, and Provider/Riverpod lifecycle before changing app composition.

## Legacy Code Location

`mobile/lib/app/app.dart`, `mobile/lib/app/router/`, and `mobile/lib/app/providers/`

## Original Functionality Description

The current app composes routing, provider scopes, theme, localization, session bootstrap, onboarding, shell entry, and reentry behavior. All current behavior must remain unchanged.

## Refactoring Approach

1. Inventory app boot responsibilities and route entry behavior.
2. Add widget/characterization tests around initial app states.
3. Add provider override/lifecycle tests where feasible.
4. Record route and provider behavior before refactoring.

## Target Location

`mobile/test/app/`

## Allowed Changes

- New tests under `mobile/test/app/`
- Test fakes/helpers needed by those tests
- Documentation artifacts describing observed behavior

## Forbidden Changes

- Production `app.dart` changes during characterization.
- Route path or redirect changes.
- Provider ownership changes.

## Acceptance Criteria

- [x] Characterization tests cover boot and initial navigation behavior.
- [x] Tests pass before any app composition refactor.
- [x] Observed behavior is recorded for Phase 2.

## Regression Test Requirements

- [x] App boot widget test.
- [x] Router initial location and redirect tests where possible.
- [x] Provider override/lifecycle test for the central graph where possible.

## Completion Evidence

- Added `mobile/test/app/app_composition_characterization_test.dart`.
- Existing `mobile/test/smoke/app_boot_test.dart` already covers fresh install onboarding, completed snapshot shell route, recent activity continuity seed, malformed account snapshot fallback, and route-gate failure retry.
- New app composition characterization covers shell boot provider bridging between legacy Provider and nested Riverpod ProviderScope.
- Targeted test run for `mobile/test/app/app_composition_characterization_test.dart`: pass, 3 tests passed.
- Full `flutter analyze`: pass, exit 0.
- Full `flutter test`: pass, 201 tests passed, exit 0.
- Full `flutter test --coverage`: pass, 201 tests passed, exit 0.
- Line coverage after REFACTOR-004: 64.07%.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|-----|--------|-----|---------|
| Tests are brittle around async boot | Medium | Medium | Use stable fake repositories and controlled timers where possible |

## Review Checklist

- [x] Tests observe current behavior and do not encode a new design.
- [x] Production source remains unchanged.

## Observed Behavior

- Shell boot still enters through `boot-route-gate-ready` and `shell-ready` before provider graph assertions are valid.
- Externally supplied share and invite reentry coordinators are exposed through legacy Provider as the same object instances.
- Legacy Provider exposes `PracticeRepository`, `OnboardingRepository`, `AccountRepository`, and `HouseholdRepository` at shell scope.
- Nested Riverpod overrides currently expose the same `PracticeRepository` and `OnboardingRepository` instances.
- Direct reads of `accountRepositoryProvider.future` and `householdRepositoryProvider.future` from the current nested Riverpod container trigger the existing scoped dependency assertion. This is recorded as current behavior, not fixed in REFACTOR-004.

## Known Decisions

- Riverpod + GoRouter is the target, but old surfaces remain until tested replacements exist.

## Authorizations

- AR-R3-003.
- AI may add tests and test helpers only within approved test paths.

## Dependencies

- REFACTOR-002.