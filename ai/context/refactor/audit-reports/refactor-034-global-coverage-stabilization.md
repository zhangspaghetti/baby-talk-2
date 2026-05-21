# REFACTOR-034 Global Coverage Stabilization

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 coverage blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-034 stabilizes full-suite LCOV collection on Windows by running Flutter coverage with `--concurrency=1`, then adds a focused household widget coverage slice for the largest remaining user-visible UI gap.

Global LCOV improved from 70.84% to 73.91%. This does not satisfy the Phase 4 80% target and no coverage exception is approved.

## Implementation

| Area | Evidence |
|---|---|
| Full coverage stabilization | `..\flutter.cmd test --coverage --concurrency=1` succeeds where an earlier default-concurrency Windows run hit a temporary compiler `output.dill` error |
| Household shared context coverage | `mobile/test/features/household/household_widget_coverage_test.dart` covers helper labels, safe/invalid route args, missing provider, ready shared context, retry/refresh, and overlay disabled/ready states |
| Household invite coverage | The same widget test covers missing provider, primary invite creation, latest invite link rendering, caregiver read-only/retry, and busy create states |

## LCOV Result

| Metric | Before Household Slice | After Household Slice |
|---|---:|---:|
| Lines hit | 7734 | 8070 |
| Lines found | 10918 | 10918 |
| Global line coverage | 70.84% | 73.91% |
| Phase 4 target | 80.00% | 80.00% |

## Targeted File Detail

| File | Before | After |
|---|---:|---:|
| `lib/features/household/presentation/widgets/household_shared_context_card.dart` | 145/425, 34.12% | 396/425, 93.18% |
| `lib/features/household/presentation/widgets/household_invite_card.dart` | 71/143, 49.65% | 139/143, 97.20% |

## Verification

| Command | Result |
|---|---|
| `..\flutter.cmd test --coverage --concurrency=1` before new household slice | Passed; `02:09 +241: All tests passed!`; 70.84% LCOV |
| `dart format test/features/household/household_widget_coverage_test.dart` | Passed |
| `..\flutter.cmd test test/features/household/household_widget_coverage_test.dart` | Passed; `00:04 +4: All tests passed!` |
| `..\flutter.cmd test --coverage --concurrency=1` after new household slice | Passed; `02:31 +245: All tests passed!`; 73.91% LCOV |
| `..\flutter.cmd analyze` | Passed; no issues found |

## Residual Risks

- Global LCOV remains below 80%; roughly 665 additional currently-uncovered lines would need to become hit at the current denominator to reach the target.
- The next largest LCOV item is generated localization output, which should not be used as a cosmetic-only path to the metric without a clear test value.
- Account repository/service and shell/home/practice screen gaps remain meaningful coverage candidates.

## Standard Git Commit Message

```text
test(mobile): stabilize global coverage baseline
```