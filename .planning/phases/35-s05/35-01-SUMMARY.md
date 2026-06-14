---
phase: "35"
plan: "01"
---

# T01: Extracted Discover browse widgets into dedicated shell widget files while preserving behavior and passing analysis/tests.

**Extracted Discover browse widgets into dedicated shell widget files while preserving behavior and passing analysis/tests.**

## What Happened

- Created `mobile/lib/features/shell/presentation/widgets/discover_view_toggle.dart` and moved `DiscoverBrowseView`, `DiscoverViewToggle`, and `DiscoverTogglePill` out of `discover_screen.dart` with the original toggle behavior, labels, icons, and keys preserved.
- Created `mobile/lib/features/shell/presentation/widgets/discover_activity_card.dart` with `DiscoverActivityCard` plus the private `_reactionLabel` helper, keeping the activity-card layout, progress, warning, and route-target behavior unchanged.
- Created `mobile/lib/features/shell/presentation/widgets/discover_space_section.dart` with `DiscoverSpaceSection` and `DiscoverSpaceGridItem`, preserving the existing space-grid layout, keys, semantics, and open-activity callbacks.
- Updated `mobile/lib/features/shell/presentation/screens/discover_screen.dart` to import the extracted widget files, remove the duplicated local enum/classes/helper, switch the three call sites to the new public widget names, and drop the now-unused `interaction_event_payload.dart` import.
- Added optional `super.key` parameters to the newly public widget constructors so the extraction stays analyzer-clean without changing runtime behavior.

## Verification

Ran `cd mobile && flutter analyze` and `cd mobile && flutter test test/features/shell/discover_screen_test.dart`.

- `flutter analyze` reported `No issues found!` after the extraction.
- `discover_screen_test.dart` passed 5/5 tests, confirming the Discover activity cards still render with stable keys, activity/space toggle still switches views without reloading the catalog, error and empty states still render correctly, and malformed route-target cards still surface the UI navigation error instead of opening.
- The slice plan did not provide additional slice-level verification beyond these task commands, so these task checks also served as the slice verification gate for T01.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd mobile && flutter analyze` | 0 | ✅ pass | 13900ms |
| 2 | `cd mobile && flutter test test/features/shell/discover_screen_test.dart` | 0 | ✅ pass | 13900ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `mobile/lib/features/shell/presentation/screens/discover_screen.dart`
- `mobile/lib/features/shell/presentation/widgets/discover_view_toggle.dart`
- `mobile/lib/features/shell/presentation/widgets/discover_activity_card.dart`
- `mobile/lib/features/shell/presentation/widgets/discover_space_section.dart`
