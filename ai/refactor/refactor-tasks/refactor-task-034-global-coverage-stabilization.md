# REFACTOR-034 Global Coverage Stabilization

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 coverage blocker reduction
Created: 2026-05-19
Status: completed

## Goal

Stabilize the full-suite coverage baseline after REFACTOR-033 and identify the next highest-value global LCOV gaps without claiming the 80% Phase 4 target prematurely.

## Scope

In scope:

- Retry full `flutter test --coverage` with a conservative Windows-friendly configuration.
- Parse the resulting full LCOV if available and record the current global coverage number.
- Identify top uncovered or low-covered files that are realistic candidates for incremental, behavior-preserving tests.
- Add a focused follow-up test slice only if a safe high-yield target is clear from the LCOV evidence.
- Run analyzer and the relevant Flutter tests before committing.

Out of scope:

- Product behavior changes.
- Any hard 80% gate claim unless a successful full coverage run proves it.
- Coverage exception approval without an explicit human decision artifact.
- Lifecycle, performance, target-platform replay, or unrelated generated-code work.

## Regression Requirements

- [x] Full coverage either succeeds with a recorded LCOV number or fails with a documented environment blocker.
- [x] Any added tests are behavior-preserving and pass in focused runs.
- [x] Analyzer passes if code or tests change.
- [x] Full Flutter tests pass if code or tests change.
- [x] Global 80% LCOV remains truthfully tracked as unresolved unless separately proven or excepted.

## Verification Log

| Command | Result |
|---|---|
| `..\flutter.cmd test --coverage --concurrency=1` before new household slice | Passed; `02:09 +241: All tests passed!`; LCOV 7734/10918 = 70.84% |
| `dart format test/features/household/household_widget_coverage_test.dart` | Passed |
| `..\flutter.cmd test test/features/household/household_widget_coverage_test.dart` | Passed; `00:04 +4: All tests passed!` |
| `..\flutter.cmd test --coverage --concurrency=1` after new household slice | Passed; `02:31 +245: All tests passed!`; LCOV 8070/10918 = 73.91% |
| `..\flutter.cmd analyze` | Passed; no issues found |

## Coverage Result

REFACTOR-034 stabilizes full coverage collection on Windows by running the full suite with `--concurrency=1`, avoiding the prior temporary compiler `output.dill` failure seen in the earlier default-concurrency coverage attempt.

The added household widget slice closes the largest user-visible UI LCOV gap found after REFACTOR-033:

| File | Before | After |
|---|---:|---:|
| `lib/features/household/presentation/widgets/household_shared_context_card.dart` | 145/425, 34.12% | 396/425, 93.18% |
| `lib/features/household/presentation/widgets/household_invite_card.dart` | 71/143, 49.65% | 139/143, 97.20% |

Global LCOV improved from 70.84% to 73.91%, but the Phase 4 80% target remains unresolved and no exception is approved.

## Remaining Top LCOV Gaps

| File | Lines Hit | Lines Found | Coverage | Missed |
|---|---:|---:|---:|---:|
| `lib/l10n/app_localizations_zh.dart` | 200 | 447 | 44.74% | 247 |
| `lib/features/account/data/repositories/account_repository.dart` | 167 | 373 | 44.77% | 206 |
| `lib/features/shell/presentation/screens/garden_growth_combined_screen.dart` | 107 | 244 | 43.85% | 137 |
| `lib/features/practice/presentation/screens/home_screen.dart` | 148 | 282 | 52.48% | 134 |
| `lib/features/practice/presentation/screens/practice_session_screen.dart` | 32 | 164 | 19.51% | 132 |
| `lib/features/practice/presentation/practice_session_notifier.dart` | 113 | 230 | 49.13% | 117 |
| `lib/features/shell/presentation/app_shell_screen.dart` | 73 | 188 | 38.83% | 115 |
| `lib/app/providers/repository_providers.dart` | 19 | 117 | 16.24% | 98 |
| `lib/features/account/data/services/account_api_service.dart` | 105 | 201 | 52.24% | 96 |
| `lib/app/app.dart` | 248 | 337 | 73.59% | 89 |

## Coverage Decision

This task is a meaningful coverage reduction step, not a release gate closure. The next coverage work should target account repository/service behavior or shell/home/practice screen states; generated localization coverage should be treated carefully because it may inflate the metric without adding equivalent behavioral confidence.

## Standard Git Commit Message

```text
test(mobile): stabilize global coverage baseline
```