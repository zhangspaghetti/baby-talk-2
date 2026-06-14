# S04 Research: Garden zoning and continuity emphasis

## Summary

`garden_screen.dart` (621 lines) — `_GardenContinueCard` (continuation CTA) is the **last child** of the ListView. `HouseholdSharedContextCard` and `ShareCalloutCard` appear as 2nd and 3rd children, immediately after `_GardenHeroCard`.

**Current zone order (wrong):**

1. `_GardenHeroCard`
2. `HouseholdSharedContextCard` ← household too early
3. `ShareCalloutCard` ← household too early
4. Growth error banner
5. Empty state / `_GardenPatchCard` list
6. `HouseholdSharedPracticeOverlayCard` + disabled banner
7. `_GardenContinueCard` ← **continuation CTA at the very bottom**

**Target zone order:**

- Zone A: `_GardenHeroCard` → `_GardenContinueCard` (move to position 2)
- Zone B: growth error banner → patch cards / empty state
- Zone C: `HouseholdSharedContextCard`, `ShareCalloutCard`, overlay / disabled banner

## Recommendation

Pure `ListView.children` reorder. No widget class definitions, view models, repositories, or data models change.

Move `_GardenContinueCard` + preceding `SizedBox(height:16)` from bottom to position 2 (after `_GardenHeroCard`). Move all household context widgets to after patch cards (Zone C).

## Implementation Landscape

**File:** `mobile/lib/features/shell/presentation/screens/garden_screen.dart`

`ListView.children` block (~line 66):

```
AFTER order:
  _GardenHeroCard              (Zone A)
  _GardenContinueCard          (Zone A — moved from bottom)
  growth error banner          (Zone B)
  empty state / patch cards    (Zone B)
  HouseholdSharedContextCard   (Zone C)
  ShareCalloutCard             (Zone C)
  HouseholdSharedPracticeOverlayCard / disabled banner  (Zone C)
```

## PracticeContinuitySnapshot Stability

`_GardenContinueCard` receives `practiceArgs`, `continuityViewModel`, `continuitySnapshot`, `continuityActivity` via constructor params — all from `context.watch<>()` calls at top of `build()`. Moving it in the list does not change data flow.

## Test Stability

- `garden_growth_shell_test.dart` and `garden_growth_home_test.dart` both use `scrollUntilVisible`/`find.byKey` — position-agnostic
- `garden-continue-practice` key on button inside `_GardenContinueCard` — moving to position 2 makes it **more accessible** (no scroll needed)
- `garden-hero-card` key on `_GardenHeroCard` Container — unaffected

## Constraints

- Do NOT change `PracticeContinuitySnapshot` ownership or data derivation
- Do NOT modify `_GardenContinueCard`, `_GardenHeroCard`, `_GardenPatchCard` widget class bodies
- Do NOT remove household context widgets — only move them to Zone C
- Git Bash: `cd /c/code/AI/baby-talk-2`

## Verification

```bash
cd /c/code/AI/baby-talk-2/mobile && flutter analyze
cd /c/code/AI/baby-talk-2/mobile && flutter test test/smoke/
cd /c/code/AI/baby-talk-2/mobile && flutter test -j 1 test/features/practice/garden_growth_shell_test.dart
cd /c/code/AI/baby-talk-2/mobile && flutter test -j 1 test/features/practice/garden_growth_home_test.dart
```

## Natural Seams

Single task, one file, pure children-list reorder. Lowest-risk change in the milestone.
