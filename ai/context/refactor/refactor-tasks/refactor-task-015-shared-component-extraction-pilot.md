# Refactor Task: REFACTOR-015 Shared Component Extraction Pilot

Version: Flutter AI Software Factory v1.0.0
Stage: R3 / Phase 3
Created: 2026-05-18
Updated: 2026-05-19
Status: done

## Objective

Run a low-risk shared component extraction pilot by introducing a presentation-only `AppSurfaceCard` and migrating selected duplicate card shells without changing rendered output or behavior.

## Scope

- Add shared component extraction pilot documentation under `ai/architecture`.
- Add `AppSurfaceCard` under `mobile/lib/app/widgets`.
- Replace duplicated surface-card containers in `HomeGrowthSummaryCard`, `ShareCalloutCard`, and `DiscoverActivityCard`.
- Add focused widget coverage proving the extracted shell preserves visual defaults.

## Forbidden Changes

- Do not change product copy.
- Do not change widget keys, semantics labels, callbacks, routes, or behavior.
- Do not move feature-specific state, branching, or localization into app-level widgets.
- Do not normalize cards with different geometry in this task.
- Do not edit generated localization files.

## Acceptance Criteria

- [x] Shared component extraction pilot documentation records scope and guardrails.
- [x] `AppSurfaceCard` preserves the existing bgSurface/outlineSoft/warmShadowSm surface-card shell.
- [x] Selected feature widgets use `AppSurfaceCard` while preserving keys and content.
- [x] Focused widget tests cover the shared shell defaults.
- [x] `flutter analyze`, `flutter test`, and `flutter test --coverage` remain green.

## Regression Test Requirements

- [x] Focused widget test asserts `AppSurfaceCard` default decoration and padding.
- [x] Full mobile test suite remains green.

## Authorizations

- Human selected `进入 REFACTOR-015` after REFACTOR-014 completion.

## Completion Evidence

- Focused widget test: `flutter test test/app/widgets/app_surface_card_test.dart` passed, 1 test.
- `flutter analyze`: pass, no issues found.
- `flutter test`: pass, 220 tests.
- `flutter test --coverage`: pass, 220 tests.
- `LCOV_SUMMARY LH=7149 LF=10763 Coverage=66.42%`.

## Notes

- No product copy, localization keys, generated files, semantics labels, callbacks, routes, or state behavior were changed.
- The pilot intentionally migrated only three matching shells and left nearby cards with different geometry untouched.