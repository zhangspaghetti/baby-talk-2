---
phase: "34"
plan: "01"
---

# T01: Reordered Garden zones so the continue CTA appears directly after the hero and locked the priority with a shell scroll-order test.

**Reordered Garden zones so the continue CTA appears directly after the hero and locked the priority with a shell scroll-order test.**

## What Happened

I made a surgical reorder in `mobile/lib/features/shell/presentation/screens/garden_screen.dart` by replacing only the `ListView.children` block. `_GardenContinueCard` now sits immediately after `_GardenHeroCard` in Zone A, the existing error banner plus patch cards remain the personal-progress content in Zone B, and `HouseholdSharedContextCard`, `ShareCalloutCard`, and the shared overlay states now live together in Zone C below the patch list. I kept all widget class bodies, constructor arguments, bindings, and continuity snapshot ownership unchanged as required.

Because the original task plan only verified source order plus existing suites, I also tightened `mobile/test/features/practice/garden_growth_shell_test.dart` with a minimal regression assertion. The test constrains the viewport, proves the continue CTA requires zero initial scroll on Garden, and then proves the household shared-context card requires additional downward scrolling, which locks the intended visual priority in user-visible behavior instead of relying only on source inspection.

No blocker was discovered. The slice plan did not define any additional slice-level verification section beyond the task checks, so I executed the task-level verification set in full.

## Verification

Verified the reordered source directly with `grep`, which showed `_GardenContinueCard` at line 76 and `HouseholdSharedContextCard` at line 101 in `mobile/lib/features/shell/presentation/screens/garden_screen.dart`, confirming the CTA now appears earlier in the `ListView`.

Ran `cd mobile && flutter analyze` with no issues found.

Ran `cd mobile && flutter test test/smoke/` and all smoke tests passed.

Ran `cd mobile && flutter test -j 1 test/features/practice/garden_growth_shell_test.dart`; the updated Garden shell suite passed, including the new scroll-order assertion.

Ran `cd mobile && flutter test -j 1 test/features/practice/garden_growth_home_test.dart`; the home continuity/growth suite passed unchanged.

The slice plan excerpt did not provide extra slice-level verification commands, so the full available verification set for this task passed.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `grep -n '_GardenContinueCard\|HouseholdSharedContextCard' mobile/lib/features/shell/presentation/screens/garden_screen.dart | head -6` | 0 | ✅ pass | 58ms |
| 2 | `cd mobile && flutter analyze` | 0 | ✅ pass | 14767ms |
| 3 | `cd mobile && flutter test test/smoke/` | 0 | ✅ pass | 18067ms |
| 4 | `cd mobile && flutter test -j 1 test/features/practice/garden_growth_shell_test.dart` | 0 | ✅ pass | 18925ms |
| 5 | `cd mobile && flutter test -j 1 test/features/practice/garden_growth_home_test.dart` | 0 | ✅ pass | 9150ms |

## Deviations

Added a minimal regression assertion to `mobile/test/features/practice/garden_growth_shell_test.dart` so the zoning change is verified in a constrained-viewport runtime scenario; the written plan only called for running existing tests.

## Known Issues

None.

## Files Created/Modified

- `mobile/lib/features/shell/presentation/screens/garden_screen.dart`
- `mobile/test/features/practice/garden_growth_shell_test.dart`
