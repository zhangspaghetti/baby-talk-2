---
phase: "32"
plan: "01"
---

# T01: Moved the Home today-practice card to the top and upgraded it to a warmShadowMd container with widget-test coverage.

**Moved the Home today-practice card to the top and upgraded it to a warmShadowMd container with widget-test coverage.**

## What Happened

I made the requested visual-only change in `mobile/lib/features/practice/presentation/screens/home_screen.dart` by moving the existing `SizedBox(height: 20)` + `_TodaySceneCard(...)` block to the start of `ListView.children`, so the practice CTA is the first visible decision card in the common home path. I then replaced `_TodaySceneCard`’s outer `Card` wrapper with a `Container` using `colors.bgSurface`, `colors.outlineSoft`, `BorderRadius.circular(16)`, and `colors.warmShadowMd`, keeping the internal padding, content, semantics label, button key, and navigation behavior unchanged. To guard the visual contract, I also updated `mobile/test/features/practice/garden_growth_home_test.dart` with a focused widget test that verifies the Today card renders above the guest-mode hero content and that the surrounding shell uses the expected warm-shadow decoration tokens. No view models, banners, account cards, or household/shared-context logic were changed.

## Verification

Ran the task-plan verification commands from `mobile/`: `flutter analyze`, `flutter test test/smoke/`, and `flutter test -j 1 test/features/practice/garden_growth_home_test.dart`; all passed. Because the new widget regression test was not explicitly surfaced in the aggregated file run output, I formed the hypothesis that the test existed but the runner output had not expanded it, then verified that hypothesis by running the new case directly with `--plain-name`; it passed. Slice-level verification had no additional checks because the slice plan explicitly states none for this pure visual rebalance.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd mobile && flutter analyze` | 0 | ✅ pass | 24624ms |
| 2 | `cd mobile && flutter test test/smoke/` | 0 | ✅ pass | 19954ms |
| 3 | `cd mobile && flutter test -j 1 test/features/practice/garden_growth_home_test.dart` | 0 | ✅ pass | 9181ms |
| 4 | `cd mobile && flutter test -j 1 test/features/practice/garden_growth_home_test.dart --plain-name "首页将今日练习卡片置顶并使用 warmShadowMd 阴影"` | 0 | ✅ pass | 18129ms |

## Deviations

Extended the task with one targeted widget regression test in `garden_growth_home_test.dart` to prove the new ordering and `warmShadowMd` decoration. This was a minimal, task-aligned verification addition; the implementation scope in `home_screen.dart` remained exactly as planned.

## Known Issues

None.

## Files Created/Modified

- `mobile/lib/features/practice/presentation/screens/home_screen.dart`
- `mobile/test/features/practice/garden_growth_home_test.dart`
