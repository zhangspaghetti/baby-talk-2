# REFACTOR-048 Growth Preview Sheet Plan

Status: done

## Context

REFACTOR-047 finished the app-wide product-facing copy scan. The next product UI/UX slice targets the Growth tab inside the combined Garden/Growth surface. Product guidance expects Growth to work as a diary and milestone review surface, but the existing `view all` actions only fire haptics and stay on the same page.

## Goal

Make Growth preview actions product-complete without adding new routes: tapping `view all` should open a focused bottom sheet for the full diary or milestone list. Diary cards should expose when an entry happened; milestone cards should expose whether the milestone is already lit.

## Scope

- Add localized labels for diary/milestone sheet titles, count summaries, diary kind, and milestone status.
- Implement reusable Growth preview bottom sheet in `GardenGrowthCombinedScreen`.
- Preserve existing preview limits on the main tab.
- Add widget coverage for the new bottom sheets and card status metadata.
- Keep changes local to Shell/Growth UI and l10n; no new routes or cross-feature imports.

## Verification

- `flutter gen-l10n`: completed
- `dart_format` on edited Dart test/source files: completed
- `flutter test test/features/shell/garden_growth_combined_screen_test.dart`: passed, 6/6 including compact phone sheet scroll coverage
- `dart analyze`: passed, no issues found
- `bash ci/mobile-r4-release-gates.sh`: passed
- `git diff --check`: passed
- staged credential scan before commit: pending at staging step