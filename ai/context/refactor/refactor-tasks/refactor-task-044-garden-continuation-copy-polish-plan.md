# REFACTOR-044: Garden Continuation Copy Polish Plan

Status: done
Stage: Stage 3.3 implementation slice
Owner: mobile UI/UX
Created: 2026-05-21
Depends on: REFACTOR-043 practice C3 product polish

## Purpose

Make the Garden continuation surface feel like a visible cause-and-effect loop for parents instead of an implementation status surface, and keep the shared Home continuation entry from exposing the same internal vocabulary.

After onboarding and practice, the parent should understand: the phrase they just tried can continue, and the garden will remember it. This slice preserves all Garden projection, continuity, route, repository, and event behavior. It only changes visible labels/copy and focused widget coverage.

## Scope

Allowed:

- Replace visible `continuity`, `recommendation`, `activity`, `starter`, `safe fallback`, and projection-oriented copy on Garden continuation surfaces.
- Map existing `PracticeContinuityReason` values to parent-facing Chinese labels in Garden UI.
- Remove debug-only visible continuity status text from `GardenHeroCard`.
- Add focused widget tests proving parent-facing Garden continuation labels.
- Guard shared Home continuation banners/reason labels that can show the same recommendation state.

Not allowed:

- Changing `PracticeContinuitySnapshot` shape or repository logic.
- Changing Garden projection rules, Isar data, route pushes, account, backend, sync, or household behavior.
- Adding analytics or notifications.

## Acceptance Criteria

- Garden hero and continue card no longer expose raw continuation/recommendation vocabulary to parents.
- Home shared continuation entry no longer exposes raw warning, disabled, fallback, or reason-label text.
- Recent, unfinished, starter, and fallback recommendation reasons map to warm parent-facing labels.
- Empty/loading Garden copy describes visible preparation without implementation terms.
- Existing Garden refresh and continue behavior remains unchanged.

## Verification Plan

- `flutter test test/features/shell/garden_growth_combined_screen_test.dart`
- `flutter test test/features/practice/critical_ui_coverage_test.dart`
- `flutter test test/smoke/app_boot_test.dart`
- `dart analyze`
- production Garden copy scan for removed internal terms
- `git diff --check`
- `bash ci/mobile-r4-release-gates.sh`

## Implementation Evidence

- Garden continuation reasons are mapped in presentation to parent-facing labels for recent, unfinished, first-seed, and safe fallback paths.
- Garden continue fallback copy no longer renders raw repository fallback text.
- Garden warning and disabled states use product copy instead of raw notifier diagnostics.
- Garden hero no longer displays debug continuity status text.
- Home continuation reason labels, fallback banners, warning banners, and disabled states use localized parent-facing copy.
- Focused widget and boot smoke coverage verify reason labels, fallback copy, warning copy, and disabled copy do not expose raw internal terms.