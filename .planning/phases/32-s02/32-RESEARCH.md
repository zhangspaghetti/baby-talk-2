# S02 Research: Home priority rebalance

## Summary

`home_screen.dart` (1203 lines) — `_TodaySceneCard` (primary practice CTA) is the 5th–6th child in the ListView, after `_LocalOnlyBanner` → `_PersonalizedHero` → `_RecentResultCard` in the onboarding path. First screenful ends at the hero; CTA is off-screen.

Fix: **two surgical moves in one file, no state or logic changes.**

## Recommendation

1. **Reorder** (~lines 228–431): Move `_TodaySceneCard` + preceding `SizedBox(height: 20)` to the **first two children** of the ListView, before the `if (widget.onboardingSnapshot != null) ... else ...` block.

2. **Visual elevation** (`_TodaySceneCard` widget ~lines 724–790): swap `warmShadowSm` → `warmShadowMd` on `boxShadow`. Token-only.

`AccountStatusCard` and `HouseholdSharedContextCard` are already after `_TodaySceneCard` in current order — no move needed. All `_HomeBanner` variants stay below the CTA zone. Recovery state safe: `disabledReason` is a prop on `_TodaySceneCard`.

## Implementation Landscape

**File:** `mobile/lib/features/practice/presentation/screens/home_screen.dart`

| Location | What changes |
|---|---|
| `ListView.children: [` (~line 228) | Insert `SizedBox(height:20)` + `_TodaySceneCard(...)` as first two children |
| Existing `_TodaySceneCard(...)` + preceding `SizedBox(height:20)` (~lines 314–327) | Remove (moved to top) |
| `_TodaySceneCard` `boxShadow` (~line 763) | `warmShadowSm` → `warmShadowMd` |

No changes to: `PracticeContinuityViewModel`, `PracticeContinuitySnapshot`, `AccountStatusCard`, `HouseholdSharedContextCard`, banners, view models, repositories.

## Test Stability

- `home-start-practice` key on button inside `_TodaySceneCard` — key-based, position-agnostic
- `garden_growth_home_test.dart` reads from `GardenGrowthViewModel`, not ListView order

## Constraints

- Do NOT touch `PracticeContinuitySnapshot` ownership
- Do NOT remove any banner/error widget — reorder only
- `app_theme.dart` token system only; no literals
- Git Bash: `cd /c/code/AI/baby-talk-2`

## Verification

```bash
cd /c/code/AI/baby-talk-2/mobile && flutter analyze
cd /c/code/AI/baby-talk-2/mobile && flutter test test/smoke/
cd /c/code/AI/baby-talk-2/mobile && flutter test -j 1 test/features/practice/garden_growth_home_test.dart
```
