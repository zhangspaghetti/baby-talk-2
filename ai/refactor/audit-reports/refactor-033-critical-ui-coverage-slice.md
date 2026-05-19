# REFACTOR-033 Critical UI Coverage Slice

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 coverage blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-033 adds focused widget tests for high-risk practice, garden, home, and share UI surfaces, plus a report-only LCOV parser for the selected critical UI slice.

The slice now reaches 70.77% line coverage across 8 selected files, exceeding the 60% critical UI threshold. This does not satisfy the global Phase 4 LCOV target of 80%; global coverage remains unresolved until a successful full coverage run reaches the target or an approved exception is recorded.

## Implementation

| Area | Evidence |
|---|---|
| Widget coverage | `mobile/test/features/practice/critical_ui_coverage_test.dart` covers fallback practice activation, celebration overlay, garden ready/warning states, home empty/recent/retry states, and share disabled/ready/loading/error states |
| Slice measurement | `mobile/tool/critical_ui_coverage.dart` parses LCOV `SF` and `DA` records for the selected critical UI files |
| Threshold | Report-only default is 60.00%; CLI supports `--min=` override |

## Critical UI LCOV Result

| Metric | Value |
|---|---:|
| Selected files present | 8 / 8 |
| Lines hit | 397 |
| Lines found | 561 |
| Line coverage | 70.77% |
| Threshold | 60.00% |

## File Detail

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

## Verification

| Command | Result |
|---|---|
| `..\flutter.cmd test test/features/practice/critical_ui_coverage_test.dart` | Passed; `00:04 +4: All tests passed!` |
| `..\flutter.cmd test --coverage test/features/practice/critical_ui_coverage_test.dart` | Passed; 4 tests; generated focused LCOV |
| `dart run tool/critical_ui_coverage.dart coverage/lcov.info --min=60` | Passed; 70.77% vs 60.00% threshold |
| `..\flutter.cmd analyze` | Passed; no issues found |
| `..\flutter.cmd test` | Passed; `01:07 +241: All tests passed!` |

## Residual Risks

- The global Phase 4 LCOV target remains blocked. At the time of REFACTOR-033, the full coverage attempt in this Windows session failed with a temporary compiler `output.dill` `PathNotFoundException`; no full-suite 80% LCOV success is claimed by this task. REFACTOR-034 later stabilizes full coverage collection with `--concurrency=1`.
- `PracticeSessionScreen` now has fallback-route coverage but still has low line coverage for deeper session interactions.
- The critical UI parser is report-only and is not wired as a separate CI workflow gate.

## Standard Git Commit Message

```text
test(mobile): add critical ui coverage slice
```