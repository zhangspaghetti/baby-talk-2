# Refactor Task: REFACTOR-014 Token/I18n Behavior-Preserving Cleanup Pilot

Version: Flutter AI Software Factory v1.0.0
Stage: R3 / Phase 3
Created: 2026-05-18
Status: done

## Objective

Run a low-risk token cleanup pilot that extracts existing UI metric values into named constants while preserving rendered output, text, behavior, and test baselines.

## Scope

- Add token pilot documentation under `ai/architecture`.
- Expand `AppLayoutConstants` with behavior-preserving spacing, radius, size, input, banner, empty-state, and progress tokens.
- Replace selected app theme and shared widget literals with those tokens.
- Add smoke coverage proving token values match the previous rendered metrics.
- Leave i18n strings unchanged in this task.

## Forbidden Changes

- Do not change palette values.
- Do not change spacing, radius, size, duration, or typography output values.
- Do not rewrite product copy.
- Do not edit generated localization files.
- Do not change widget keys, semantics labels, callbacks, routes, or behavior.
- Do not extract shared components in this task.

## Acceptance Criteria

- [x] Token pilot documentation records scope and guardrails.
- [x] New `AppLayoutConstants` tokens preserve existing values.
- [x] App theme and selected shared app widgets use tokens instead of local literals.
- [x] Existing visual contracts remain covered by smoke tests.
- [x] `flutter analyze`, `flutter test`, and `flutter test --coverage` remain green.

## Regression Test Requirements

- [x] Theme smoke test asserts token values remain unchanged.
- [x] Full mobile test suite remains green.

## Authorizations

- Human selected `进入 REFACTOR-014` after REFACTOR-013 completion.

## Completion Evidence

- Focused theme smoke test: 24 passed.
- `flutter analyze`: pass.
- `flutter test`: 219 passed.
- `flutter test --coverage`: 219 passed.
- `LCOV_SUMMARY LH=7142 LF=10766 Coverage=66.34%`.

## Notes

- No ARB keys or generated localization files were changed.
- No product copy, semantics labels, widget keys, callbacks, routes, or behavior were changed.
- The existing onboarding tap warning around `onboarding-name-continue` still appears during full tests and remains nonfatal.