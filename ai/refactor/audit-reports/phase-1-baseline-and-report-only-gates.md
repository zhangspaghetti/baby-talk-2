# Phase 1 Baseline And Report-Only Gates

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 1  
Tasks: REFACTOR-001, REFACTOR-002, REFACTOR-002A, REFACTOR-004, REFACTOR-005, REFACTOR-006  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed through REFACTOR-006; baseline restored and remains green

## Summary

REFACTOR-001 and REFACTOR-002 are complete. This pass synchronized governance decisions, ran the approved read-only verification baseline, and captured report-only scan metrics. No runtime Flutter source files were intentionally modified.

The initial baseline was not green: `flutter analyze` passed, but `flutter test` and `flutter test --coverage` both failed on one existing tool/handoff test. That failure is preserved below as original baseline evidence. After human approval to handle the baseline failure, REFACTOR-002A updated the stale repo-root handoff test expectation to match the current CI workflow, where checkstyle is now part of fail aggregation. The restored baseline is green.

After REFACTOR-004 and REFACTOR-005, Phase 1 characterization remained test-only. App composition, Mentor auth/header behavior, and Mentor consent preflight behavior were captured without production source changes. REFACTOR-006 then made the approved Bearer JWT header change for protected API requests.

## Verification Baseline

Commands were run from `mobile/` on 2026-05-18.

| Command | Exit | Result |
|---|---:|---|
| `flutter analyze` | 0 | Pass; no issues found |
| `flutter test` | 1 | Fail; 199 passed, 1 failed |
| `flutter test --coverage` | 1 | Fail; 199 passed, 1 failed |

## Post-Recovery Baseline

REFACTOR-002A changed only the stale repo-root handoff test assertion in `test/tool/verify_m006_s14_release_closure_test.dart`. The assertion now looks for the current CI step title: `Fail when backend tests, checkstyle, or Helm smoke fail`.

Commands were rerun from `mobile/` after the fix.

| Command | Exit | Result |
|---|---:|---|
| `flutter analyze` | 0 | Pass; no issues found |
| `flutter test mobile/test/tool/verify_m006_s14_release_closure_test.dart` | 0 | Pass; 9 tests passed |
| `flutter test` | 0 | Pass; 200 tests passed |
| `flutter test --coverage` | 0 | Pass; 200 tests passed |

## Post-Characterization Baseline

REFACTOR-004 and REFACTOR-005 added characterization-only tests. REFACTOR-006 added the protected Bearer header implementation and tests. Commands were rerun from `mobile/` after REFACTOR-006.

| Command | Exit | Result |
|---|---:|---|
| `flutter analyze` | 0 | Pass; no issues found |
| `flutter test` | 0 | Pass; 207 tests passed |
| `flutter test --coverage` | 0 | Pass; 207 tests passed |

## Failure Detail

| Test File | Test | Failure |
|---|---|---|
| `mobile/test/tool/verify_m006_s14_release_closure_test.dart` | `M006 S14 repo-root handoff surfaces workflow scopes relay to backend tests, installs Helm smoke, and preserves artifacts` | Expected a value greater than `3295`; actual was `-1` at line 194 |

## Nonfatal Warning

| File | Warning |
|---|---|
| `mobile/test/features/onboarding/onboarding_screen_test.dart` | A tap on key `onboarding-name-continue` resolved outside the 800x600 test viewport. This is currently a warning, not a failure. |

## Coverage Baseline

| Metric | Value |
|---|---:|
| Lines hit | 6862 |
| Lines found | 10724 |
| Line coverage | 63.99% |

## Latest Coverage

| Metric | Value |
|---|---:|
| Lines hit | 7093 |
| Lines found | 10737 |
| Line coverage | 66.06% |

## Report-Only Scan Metrics

These scans are informational only. They do not add hard CI failures yet.

| Scan | Count |
|---|---:|
| Dart files under `mobile/lib` | 128 |
| Handwritten Dart files under `mobile/lib` | 115 |
| Co-located generated files outside `lib/generated` | 13 |
| Handwritten files over 500 lines | 13 |
| Handwritten files over 200 lines | 42 |
| Cross-feature import candidates | 97 |
| Direct infra import candidates | 79 |
| UI literal candidates | 646 |
| Hardcoded `Text(...)` literal candidates | 13 |

## Largest Files Over 500 Lines

| Lines | File |
|---:|---|
| 2064 | `mobile/lib/l10n/app_localizations.dart` |
| 1056 | `mobile/lib/features/practice/data/repositories/practice_repository.dart` |
| 930 | `mobile/lib/l10n/app_localizations_zh.dart` |
| 872 | `mobile/lib/features/household/presentation/widgets/household_shared_context_card.dart` |
| 861 | `mobile/lib/features/mentor/presentation/mentor_notifier.dart` |
| 853 | `mobile/lib/features/account/data/repositories/account_repository.dart` |
| 751 | `mobile/lib/app/app.dart` |
| 716 | `mobile/lib/app/theme/app_theme.dart` |
| 709 | `mobile/lib/features/account/presentation/screens/account_entry_screen.dart` |
| 661 | `mobile/lib/features/mentor/data/repositories/mentor_repository.dart` |
| 656 | `mobile/lib/features/onboarding/presentation/screens/onboarding_screen.dart` |
| 595 | `mobile/lib/features/practice/presentation/screens/home_screen.dart` |
| 585 | `mobile/lib/features/shell/presentation/screens/garden_growth_combined_screen.dart` |

## Interpretation

- Mobile analyze/test/coverage can now be treated as green for the captured local baseline.
- Phase 1 should keep scans report-only until hardening is separately approved.
- REFACTOR-003 remains blocked because strict generated-code migration needs a canary design and allowed file approval.
- REFACTOR-004, REFACTOR-005, REFACTOR-006, and REFACTOR-007 are complete; REFACTOR-008 remains blocked until route contract inventory and GoRouter canonicalization are explicitly approved.

## Worktree Scope Check

Latest `git status --short` after REFACTOR-006 showed test/artifact changes plus the approved auth header implementation files. Production code touched by REFACTOR-006 is limited to `mobile/lib/core/network/auth_headers.dart`, `mobile/lib/features/account/data/services/account_api_service.dart`, `mobile/lib/features/household/data/services/household_api_service.dart`, and `mobile/lib/features/mentor/data/services/mentor_api_service.dart`. No `mobile/pubspec.yaml` or `mobile/analysis_options.yaml` changes were made by this pass. An existing `.gitignore` modification is present in the worktree and was not touched by this pass.