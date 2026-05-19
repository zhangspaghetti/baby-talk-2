# REFACTOR-033 Critical UI Coverage Slice

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 coverage blocker reduction
Created: 2026-05-19
Status: completed

## Goal

Reduce the Phase 4 coverage blind spot by adding a focused critical-UI widget coverage slice and a report-only LCOV measurement tool.

## Scope

In scope:

- Add widget tests for high-risk user-facing practice/share/garden UI surfaces that were previously unmeasured or near-zero in LCOV.
- Add a small LCOV parser for the critical UI slice.
- Run the focused slice with coverage and record line coverage for the selected surfaces.
- Run analyzer and the full Flutter test suite.
- Update governance artifacts and commit with a conventional commit message.

Out of scope:

- Product copy, route, repository, or visual behavior changes.
- Full LCOV 80% hard gate escalation.
- CI workflow changes.
- Lifecycle, performance, or target-platform replay work.

## Critical UI Slice

The slice targets the current LCOV low points that are user-visible and high value:

- `lib/features/practice/presentation/screens/practice_session_screen.dart`
- `lib/features/practice/presentation/widgets/activation_frame.dart`
- `lib/app/widgets/app_celebration_overlay.dart`
- `lib/features/shell/presentation/widgets/garden_patch_card.dart`
- `lib/features/practice/presentation/widgets/home_garden_mini_entry.dart`
- `lib/features/practice/presentation/widgets/home_growth_summary_card.dart`
- `lib/features/practice/presentation/widgets/home_recent_result_card.dart`
- `lib/features/share/presentation/widgets/share_callout_card.dart`

## Regression Requirements

- [x] Focused critical UI widget tests pass.
- [x] Critical UI LCOV slice is measurable from `coverage/lcov.info`.
- [x] Critical UI LCOV slice reaches at least 60% for the selected surfaces.
- [x] Analyzer passes.
- [x] Full Flutter tests pass.
- [x] Full LCOV 80% remains truthfully tracked as unresolved unless separately proven or excepted.

## Verification Log

| Command | Result |
|---|---|
| `..\flutter.cmd test test/features/practice/critical_ui_coverage_test.dart` | Passed; `00:04 +4: All tests passed!` |
| `..\flutter.cmd test --coverage test/features/practice/critical_ui_coverage_test.dart` | Passed; 4 tests; produced focused `coverage/lcov.info` |
| `dart run tool/critical_ui_coverage.dart coverage/lcov.info --min=60` | Passed; 8/8 selected files present; 397/561 lines hit; 70.77% vs 60.00% threshold |
| `..\flutter.cmd analyze` | Passed; no issues found |
| `..\flutter.cmd test` | Passed; `01:07 +241: All tests passed!` |

## Coverage Decision

REFACTOR-033 reduces the critical UI coverage measurement blocker only. It does not satisfy the Phase 4 global LCOV target. At the time of this task, a full `flutter test --coverage` attempt on this Windows run failed with a temporary compiler `output.dill` `PathNotFoundException`, and the older LCOV value remained about 66.54%; no 80% coverage success or exception is claimed by this task. REFACTOR-034 later stabilizes full coverage collection with `--concurrency=1`.

## Critical UI LCOV Detail

| File | Lines Hit | Lines Found | Coverage |
|---|---:|---:|---:|
| `lib/features/practice/presentation/screens/practice_session_screen.dart` | 32 | 164 | 19.51% |
| `lib/features/practice/presentation/widgets/activation_frame.dart` | 31 | 31 | 100.00% |
| `lib/app/widgets/app_celebration_overlay.dart` | 38 | 39 | 97.44% |
| `lib/features/shell/presentation/widgets/garden_patch_card.dart` | 78 | 78 | 100.00% |
| `lib/features/practice/presentation/widgets/home_garden_mini_entry.dart` | 44 | 58 | 75.86% |
| `lib/features/practice/presentation/widgets/home_growth_summary_card.dart` | 34 | 36 | 94.44% |
| `lib/features/practice/presentation/widgets/home_recent_result_card.dart` | 40 | 44 | 90.91% |
| `lib/features/share/presentation/widgets/share_callout_card.dart` | 100 | 111 | 90.09% |
| Total | 397 | 561 | 70.77% |

## Standard Git Commit Message

```text
test(mobile): add critical ui coverage slice
```