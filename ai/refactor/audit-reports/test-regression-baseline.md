# Stage R1 Test And Regression Baseline

Version: Flutter AI Software Factory v1.0.0  
Stage: R1 - Test Baseline  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed, verification rerun pending

Test maturity score: 6.5 / 10.

## Summary

The project has meaningful test assets: 40 Dart files under `mobile/test` and `mobile/integration_test`, historical all-pass logs, and coverage data around 64%. This is enough to start R2 planning, but not enough to begin high-risk R3 refactors without additional characterization tests.

## Current Evidence

- `mobile/pubspec.yaml` includes Flutter test and integration test dependencies.
- Existing historical logs show a passing unit/widget test run.
- Existing `mobile/coverage/lcov.info` indicates roughly 64% line coverage.
- Integration tests cover guest practice, onboarding, account sync/restore, and full-chain release flows.

## Gaps

| Gap | Risk | Required Before Refactor |
|---|---|---|
| `app.dart` boot/router/provider behavior not fully characterized | Startup and route regressions | Boot and route widget tests |
| `repository_providers.dart` low coverage | DI lifecycle regressions | Provider override/lifecycle tests |
| Practice repository slicing | Sync/event behavior regressions | Isar temp DB tests and payload snapshots |
| Router consolidation | Navigation behavior drift | Route contract tests |
| UI token extraction | Visual/semantic drift | Widget tests and semantics checks |
| Auth/consent fixes | Security regressions | Fail-closed tests for auth headers and consent gates |
| Performance work | Invisible latency regressions | Profile benchmark plan |

## Verification Commands

Run from `mobile/` when local Flutter dependencies are available:

```powershell
flutter pub get
flutter analyze
flutter test
flutter test --coverage
```

Targeted integration checks:

```powershell
flutter test integration_test/s01_guest_practice_flow_test.dart
flutter test integration_test/s02_personalized_onboarding_flow_test.dart
flutter test integration_test/s03_account_sync_restore_flow_test.dart
flutter test integration_test/s06_full_chain_release_flow_test.dart
```

Real-backend E2E requires configured backend and explicit dart defines.