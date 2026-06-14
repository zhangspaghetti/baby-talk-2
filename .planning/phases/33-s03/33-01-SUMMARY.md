---
phase: "33"
plan: "01"
---

# T01: Trimmed Discover hero and activity card chrome while preserving recoverable-issue visibility and stable CTA/progress keys.

**Trimmed Discover hero and activity card chrome while preserving recoverable-issue visibility and stable CTA/progress keys.**

## What Happened

Updated `mobile/lib/features/shell/presentation/screens/discover_screen.dart` with three surgical density reductions in the existing UI only. The hero card now stops at `discoverTitle` + `discoverSubtitle`, removing the extra note block. Activity cards now drop the `sceneTag`/`spaceTitle` chip row and render only the conditional recoverable-issue chip required for R008 visibility. The previous "latest progress" container, label, and secondary hint line were flattened into a single `footerText` line plus the preserved `warningMessage`, and the orphaned `_formatTime` helper was removed because nothing else referenced it. To keep the change regression-proof, `mobile/test/features/shell/discover_screen_test.dart` gained a widget test that asserts the removed chrome stays absent while the recoverable-issue chip, warning text, progress key, and recent-result footer line remain visible.

## Verification

Ran the task-plan verification commands from `mobile/` and all passed: `flutter analyze`, `flutter test test/features/shell/discover_screen_test.dart`, and `flutter test test/smoke/`. The new widget coverage specifically verifies that `discoverNote` and `discoverLatestProgress` no longer render in the activity view, that the activity metadata chips are gone, and that the R008 recoverable-issue chip/warning text still render alongside the unchanged progress and route-target keys. Slice-level verification added no extra commands beyond these checks because the slice plan declared no additional runtime boundary verification.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd mobile && flutter analyze` | 0 | ✅ pass | 9318ms |
| 2 | `cd mobile && flutter test test/features/shell/discover_screen_test.dart` | 0 | ✅ pass | 8266ms |
| 3 | `cd mobile && flutter test test/smoke/` | 0 | ✅ pass | 20085ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `mobile/lib/features/shell/presentation/screens/discover_screen.dart`
- `mobile/test/features/shell/discover_screen_test.dart`
