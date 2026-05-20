# Test Verification Report

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4
Task: REFACTOR-017
Created: 2026-05-19
Status: completed, global coverage gate improved but blocked; integration blockers remediated locally; critical UI slice measured; REFACTOR-035 coverage slice complete

## Summary

The standard mobile verification suite remains green for analyze and unit/widget tests. REFACTOR-034 stabilized full-suite coverage on Windows with `--concurrency=1` and raised LCOV to 73.91%. REFACTOR-035 adds behavior-preserving widget coverage for the garden/growth combined screen and raises full LCOV to 75.32%, still below the Phase 4 target of 80%. REFACTOR-033 adds a focused critical UI coverage slice that reaches 70.77% across the selected surfaces. The R1-documented integration checks originally failed during R017, then passed locally after REFACTOR-017A stabilization.

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

## REFACTOR-033 Critical UI Coverage Evidence

| Command | Exit | Result |
|---|---:|---|
| `..\flutter.cmd test --coverage test/features/practice/critical_ui_coverage_test.dart` | 0 | Pass; 4 tests; produced focused LCOV |
| `dart run tool/critical_ui_coverage.dart coverage/lcov.info --min=60` | 0 | Pass; 8/8 selected files present; 397/561 lines hit; 70.77% vs 60.00% threshold |
| `..\flutter.cmd analyze` | 0 | Pass; no issues found |
| `..\flutter.cmd test` | 0 | Pass; 241 tests passed |

## REFACTOR-034 Global Coverage Evidence

| Command | Exit | Result |
|---|---:|---|
| `..\flutter.cmd test test/features/household/household_widget_coverage_test.dart` | 0 | Pass; 4 tests |
| `..\flutter.cmd test --coverage --concurrency=1` | 0 | Pass; 245 tests; LCOV 8070/10918 = 73.91% |
| `..\flutter.cmd analyze` | 0 | Pass; no issues found |

## REFACTOR-035 Garden Growth Coverage Evidence

| Command | Exit | Result |
|---|---:|---|
| Focused `runTests` for `mobile/test/features/shell/garden_growth_combined_screen_test.dart` | 0 | Pass; 4 tests |
| Focused coverage for `garden_growth_combined_screen.dart` | 0 | Pass; 222/245 lines, 90.60% in focused run |
| `get_errors` on edited files | 0 | No errors for root `pubspec.yaml`, screen file, or new test file |
| `..\flutter.cmd analyze` | 0 | Pass; no issues found |
| `..\flutter.cmd test --coverage --concurrency=1` | 0 | Pass; 249 tests; LCOV 8223/10918 = 75.32% |
| `flutter test test\smoke\delegate_test.dart` from repo root | 0 | Pass; root delegate smoke test and 59 delegated mobile smoke tests passed |

## Coverage Evidence

| Metric | Value |
|---|---:|
| Lines hit | 8223 |
| Lines found | 10918 |
| Line coverage | 75.32% |
| Phase 4 target | 80.00% |
| Gap to target | 4.68 percentage points |

## Critical UI Slice Evidence

| Metric | Value |
|---|---:|
| Selected critical UI files present | 8 / 8 |
| Lines hit | 397 |
| Lines found | 561 |
| Line coverage | 70.77% |
| Critical UI threshold | 60.00% |

## Target Assessment

| Phase 4 Test Criterion | Status | Evidence |
|---|---|---|
| Analyze green full run | Met | `flutter analyze` exit 0 |
| Full suite green | Met for unit/widget/smoke suite | Latest coverage full suite exit 0, 249 passed |
| Coverage reaches 80% or approved exception exists | Not met | Latest LCOV is 75.32%; no approved exception recorded |
| Widget coverage reaches 60% for critical UI surfaces | Met | REFACTOR-033 selected slice is 70.77% |
| All core flows pass or have documented blockers | Met locally, pending target replay | S01, S02, S03, and S06 focused integration checks exited 0 after REFACTOR-017A |

## Nonfatal Test Warning

The known onboarding tap warning around key `onboarding-name-continue` still appears during full test and coverage runs. It remains a warning, not a test failure, in the current Flutter test configuration.

## Test Exit Decision

The R017 report suite is complete, R017A restored local integration evidence, R033 measures the critical UI slice above the 60% threshold, R034 stabilizes full coverage collection at 73.91%, and R035 raises global LCOV to 75.32% with garden/growth combined screen coverage. The Phase 4 test gate is still not fully passed because global LCOV remains below target and no explicit approved coverage exception exists.