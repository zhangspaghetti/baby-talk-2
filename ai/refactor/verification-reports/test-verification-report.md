# Test Verification Report

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4
Task: REFACTOR-017
Created: 2026-05-19
Status: completed, coverage gate blocked; integration blockers remediated locally

## Summary

The standard mobile verification suite remains green for analyze, unit/widget tests, and coverage collection. LCOV line coverage is unchanged from REFACTOR-016 at 66.53%, which is below the Phase 4 target of 80%. The R1-documented integration checks originally failed during R017, then passed locally after REFACTOR-017A stabilization.

## Regression Evidence

| Command | Exit | Result |
|---|---:|---|
| `flutter analyze` | 0 | Pass; no issues found |
| `flutter test` | 0 | Pass; 220 tests passed |
| `flutter test --coverage` | 0 | Pass; 220 tests passed |
| `flutter test integration_test/s01_guest_practice_flow_test.dart` | 1 | Fail; timed out waiting for expected widget |
| `flutter test integration_test/s02_personalized_onboarding_flow_test.dart` | 1 | Fail; timed out waiting for expected widget |
| `flutter test integration_test/s03_account_sync_restore_flow_test.dart` | 1 | Fail; timed out waiting for expected widget |
| `flutter test integration_test/s06_full_chain_release_flow_test.dart` | 1 | Fail; two timeout failures, one passing malformed snapshot test |

## REFACTOR-017A Focused Integration Evidence

| Command | Exit | Result |
|---|---:|---|
| `..\flutter.cmd test integration_test/s01_guest_practice_flow_test.dart` | 0 | Pass; local-only offline practice restore verified |
| `..\flutter.cmd test integration_test/s02_personalized_onboarding_flow_test.dart` | 0 | Pass; onboarding, personalized shell, and cold-start restore verified |
| `..\flutter.cmd test integration_test/s03_account_sync_restore_flow_test.dart` | 0 | Pass; offline practice sync and logout/login restore verified |
| `..\flutter.cmd test integration_test/s06_full_chain_release_flow_test.dart` | 0 | Pass; 3 full-chain tests passed |
| `..\flutter.cmd analyze` | 0 | Pass; no issues found |

## Coverage Evidence

| Metric | Value |
|---|---:|
| Lines hit | 7172 |
| Lines found | 10780 |
| Line coverage | 66.53% |
| Phase 4 target | 80.00% |
| Gap to target | 13.47 percentage points |

## Target Assessment

| Phase 4 Test Criterion | Status | Evidence |
|---|---|---|
| Analyze green full run | Met | `flutter analyze` exit 0 |
| Full suite green | Met for unit/widget/smoke suite | `flutter test` exit 0, 220 passed |
| Coverage reaches 80% or approved exception exists | Not met | LCOV is 66.53%; no approved exception recorded |
| Widget coverage reaches 60% for critical UI surfaces | Not proven | No critical-UI-only coverage slice exists yet |
| All core flows pass or have documented blockers | Met locally, pending target replay | S01, S02, S03, and S06 focused integration checks exited 0 after REFACTOR-017A |

## Nonfatal Test Warning

The known onboarding tap warning around key `onboarding-name-continue` still appears during full test and coverage runs. It remains a warning, not a test failure, in the current Flutter test configuration.

## Test Exit Decision

The R017 report suite is complete and R017A restored local integration evidence. The Phase 4 test gate is still not passed because coverage remains below target and no explicit approved coverage exception or critical-UI coverage measurement exists.