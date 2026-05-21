# REFACTOR-014 Token/I18n Behavior-Preserving Cleanup Pilot

Version: Flutter AI Software Factory v1.0.0
Stage: R3 / Phase 3
Created: 2026-05-18
Status: completed

## Summary

REFACTOR-014 completed a low-risk design-token cleanup pilot. It expanded `AppLayoutConstants` with named spacing, radius, size, padding, progress, banner, and empty-state tokens, then replaced selected local literals in the app theme and shared app widgets without changing rendered values.

The i18n path remains planned only: no ARB keys, generated localization files, product copy, semantics labels, or visible strings were changed.

## Changes

- Added `ai/architecture/token-i18n-cleanup-pilot.md` to define the behavior-preserving token/i18n guardrails.
- Added metric tokens to `AppLayoutConstants` for spacing, touch targets, button/input padding, icon sizes, progress geometry, and progress duration.
- Updated `AppTheme.build()` and `AppTheme.buildDark()` to use the new metric tokens for selected radius, padding, and touch-target values.
- Updated `AppStepProgress`, `AppBanner`, and `AppEmptyState` to use the new tokens while preserving layout values.
- Extended `theme_dark_mode_test.dart` with a REFACTOR-014 token value contract test.

## Verification

| Command | Result |
|---|---|
| Focused theme smoke test | Passed; 24 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; 219 tests |
| `flutter test --coverage` | Passed; 219 tests |
| LCOV summary | `LH=7142 LF=10766 Coverage=66.34%` |

## Residual Risks

- The i18n hardcoded-text cleanup still needs a separate exact-copy ARB replacement pass.
- The broader design-token scale decision remains open for values outside this pilot; this task only names existing values.
- Shared component extraction remains deferred to REFACTOR-015.
- The existing onboarding tap warning around `onboarding-name-continue` remains nonfatal during full test runs.

## Non-Goals Confirmed

- No palette values were changed.
- No spacing, radius, size, duration, typography, or copy output values were changed.
- No generated localization files were edited.
- No shared component extraction was performed.