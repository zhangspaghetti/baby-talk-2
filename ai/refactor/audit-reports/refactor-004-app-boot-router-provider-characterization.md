# REFACTOR-004 App Boot Router Provider Characterization

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 1  
Task: REFACTOR-004  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed

## Summary

REFACTOR-004 added a test-only characterization for the current `BabyTalkApp` app composition surface. No production Flutter source was changed.

The existing smoke coverage already characterizes the main boot/router paths: fresh install to onboarding, completed snapshot to shell, recent activity continuity seeding, malformed account snapshot fallback, and route-gate failure retry. The new test focuses on the Provider/Riverpod bridge that must be understood before app composition refactors.

## Added Test

| File | Coverage |
|---|---|
| `mobile/test/app/app_composition_characterization_test.dart` | Shell boot provider bridge, external reentry coordinator injection, legacy Provider repository exposure, selected Riverpod repository override identity, current scoped dependency assertion for account/household Riverpod providers |

## Observed Behavior

| Surface | Current Behavior |
|---|---|
| Shell readiness | Provider graph assertions are stable after `shell-ready` is present |
| Share reentry coordinator | A caller-supplied coordinator is exposed through legacy Provider as the same instance |
| Invite reentry coordinator | A caller-supplied coordinator is exposed through legacy Provider as the same instance |
| Legacy Provider repositories | `PracticeRepository`, `OnboardingRepository`, `AccountRepository`, and `HouseholdRepository` are exposed at shell scope |
| Riverpod practice repository | `practiceRepositoryProvider.future` resolves to the same `PracticeRepository` instance as legacy Provider |
| Riverpod onboarding repository | `onboardingRepositoryProvider.future` resolves to the same `OnboardingRepository` instance as legacy Provider |
| Riverpod account/household repositories | Direct reads currently trigger Riverpod scoped dependency assertions; this is current behavior to preserve until an explicit provider graph migration task changes it |

## Verification

| Command | Result |
|---|---|
| Targeted diagnostics for `mobile/test/app/app_composition_characterization_test.dart` | No errors found |
| `flutter test mobile/test/app/app_composition_characterization_test.dart` | Pass; 3 tests passed |
| `flutter analyze` | Pass; exit 0 |
| `flutter test` | Pass; 201 tests passed; exit 0 |
| `flutter test --coverage` | Pass; 201 tests passed; exit 0 |

## Coverage

| Metric | Value |
|---|---:|
| Lines hit | 6871 |
| Lines found | 10724 |
| Line coverage | 64.07% |

## Phase 2 Notes

- Any Provider/Riverpod unification task must decide whether `accountRepositoryProvider` and `householdRepositoryProvider` should become directly readable from the nested app ProviderScope.
- Do not remove the legacy Provider repository surface until consumers of `Provider.of<T>` have been inventoried or migrated.
- Reentry coordinator ownership should remain explicit: externally supplied coordinators are part of the observable app composition contract.

## Scope Check

- Production Flutter source: unchanged.
- New runtime behavior: none.
- New coverage type: characterization-only widget test.