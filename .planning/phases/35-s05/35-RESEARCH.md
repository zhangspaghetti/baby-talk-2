# S05 Research: Mobile Ownership Extraction

**Depth:** Light-to-targeted — S02/S03/S04 are complete, layouts are stable. The work is pure structural Dart refactoring with no state, no behavior, and no new abstraction. The primary risk is getting import paths and class renames correct.

---

## Summary

All three screens already decompose their UI into private widget classes (`_Widget...`) defined within the same file. S05 extracts the large, self-contained display widgets into dedicated files under `widgets/` subdirectories, reducing per-screen file ownership without touching any behavior.

**Extraction net effect:**
| File | Before | After est. |
|---|---|---|
| `home_screen.dart` | 1209 lines | ~670 lines |
| `discover_screen.dart` | 823 lines | ~440 lines |
| `garden_screen.dart` | 622 lines | ~210 lines |

---

## Active Requirements This Slice Supports

- **R034** — S05 is a structural step; the layouts locked in S02/S04 (`_TodaySceneCard` first, `_GardenContinueCard` in Zone A) must be preserved byte-for-byte in the extracted widgets.
- **R001** — `home-start-practice` key in `_TodaySceneCard` must not move or change.
- **R008** — R008 recoverable-issue chip in `_DiscoverActivityCard` must remain intact in the extracted `DiscoverActivityCard`.
- **D124** — Hard constraint: no new state containers permitted regardless of whether extraction would be easier with them. All classes remain `StatelessWidget`.

---

## What Exists in the Three Screen Files

### home_screen.dart (1209 lines)

- **`_HomeScreenState`** (lines 42–563, ~522 lines): StatefulWidget with RouteAware mixin, lifecycle methods, AccountViewModel listener, `didPopNext` refresh logic, and 7 helper methods. **Do not extract** — tightly coupled to `context.read/watch` tree.
- **Build method** (lines 173–563, ~370 lines): Reads 6 ViewModels, builds a long ListView with conditional blocks.
- **Private widget classes:**

| Class | Lines | Lines count | Extract? |
|---|---|---|---|
| `_LocalOnlyBanner` | 564–604 | 41 | No — single-use, 41 lines |
| `_PersonalizedHero` | 605–697 | 93 | Yes |
| `_TodaySceneCard` | 698–796 | 99 | Yes — primary CTA |
| `_WeekStatsCard` | 797–847 | 51 | Yes (bundle with `_StatCell`) |
| `_StatCell` | 848–884 | 37 | Yes (part of WeekStatsCard file) |
| `_GardenMiniEntry` | 885–991 | 107 | Yes |
| `_GrowthSummaryCard` | 992–1060 | 69 | Yes |
| `_RecentResultCard` | 1061–1142 | 82 | Yes |
| `_HomeLoadingState` | 1143–1165 | 23 | No — too small |
| `_HomeBanner` | 1166–1209 | 44 | No — single-file utility |

### discover_screen.dart (823 lines)

- **`_DiscoverScreenState`** (lines 26–170, ~145 lines): StatefulWidget with `AutomaticKeepAliveClientMixin`, owns `_catalogFuture` (Future), `_selectedView` (enum), `_navigationError` (String?). **Do not extract**.
- **Private widget classes:**

| Class | Lines | Lines count | Extract? |
|---|---|---|---|
| `_DiscoverHero` | 171–201 | 31 | No — trivial |
| `_DiscoverViewToggle` | 202–248 | 47 | Yes (bundle with `_DiscoverTogglePill`) |
| `_DiscoverTogglePill` | 249–298 | 50 | Yes (part of ViewToggle file) |
| `_DiscoverLoadingState` | 299–340 | 42 | No — small |
| `_DiscoverErrorState` | 341–386 | 46 | No — small |
| `_DiscoverEmptyState` | 387–425 | 39 | No — small |
| `_DiscoverActivityList` | 426–463 | 38 | No — thin wrapper |
| `_DiscoverActivityCard` | 464–588 | 125 | Yes — largest card |
| `_DiscoverSpaceList` | 589–623 | 35 | No — thin wrapper |
| `_DiscoverSpaceSection` | 624–685 | 62 | Yes (bundle with `_DiscoverSpaceGridItem`) |
| `_DiscoverSpaceGridItem` | 686–779 | 94 | Yes (part of SpaceSection file) |
| `_DiscoverBanner` | 780–822 | 43 | No — single-file utility |
| `_reactionLabel` (fn) | 823+ | small | Move with `DiscoverActivityCard` |

### garden_screen.dart (622 lines)

- **`GardenScreen`** is already a `StatelessWidget` — the simplest of the three. The build method (lines 17–144, ~128 lines) reads 6 ViewModels and produces a ListView.
- **Private widget classes:**

| Class | Lines | Lines count | Extract? |
|---|---|---|---|
| `_GardenHeroCard` | 145–276 | 132 | Yes — large, uses kDebugMode |
| `_GardenEmptyState` | 277–308 | 32 | No — trivial |
| `_GardenPatchCard` | 309–390 | 82 | Yes (bundle with Flower+MetaChip) |
| `_GardenFlowerCard` | 391–454 | 64 | Yes (part of PatchCard file) |
| `_GardenContinueCard` | 455–572 | 118 | Yes — primary CTA |
| `_GardenMetaChip` | 573–591 | 19 | Yes (part of PatchCard file) |
| `_GardenBanner` | 592–622 | 31 | No — trivial |

---

## Target Widget Files

### New directory: `mobile/lib/features/shell/presentation/widgets/` (does not yet exist)

1. **`discover_view_toggle.dart`** — `DiscoverViewToggle` + `DiscoverTogglePill` (~97 lines)
   - Also move `DiscoverBrowseView` enum here (currently top-level in discover_screen.dart, referenced by the toggle)
   - `discover_screen.dart` imports this file; `DiscoverBrowseView` still accessible via this import
2. **`discover_activity_card.dart`** — `DiscoverActivityCard` (~125 lines) + `_reactionLabel` private helper
3. **`discover_space_section.dart`** — `DiscoverSpaceSection` + `DiscoverSpaceGridItem` (~156 lines)
4. **`garden_hero_card.dart`** — `GardenHeroCard` (~132 lines)
   - **Important**: imports `package:flutter/foundation.dart` for `kDebugMode`
5. **`garden_continue_card.dart`** — `GardenContinueCard` (~118 lines)
6. **`garden_patch_card.dart`** — `GardenPatchCard` + `GardenFlowerCard` + `GardenMetaChip` (~165 lines)

### Existing directory: `mobile/lib/features/practice/presentation/widgets/`

7. **`home_today_scene_card.dart`** — `HomeTodaySceneCard` (~99 lines)
8. **`home_week_stats_card.dart`** — `HomeWeekStatsCard` + `HomeStatCell` (~88 lines)
9. **`home_garden_mini_entry.dart`** — `HomeGardenMiniEntry` (~107 lines)
10. **`home_growth_summary_card.dart`** — `HomeGrowthSummaryCard` (~69 lines)
11. **`home_personalized_hero.dart`** — `HomePersonalizedHero` (~93 lines)
12. **`home_recent_result_card.dart`** — `HomeRecentResultCard` (~82 lines)

---

## Implementation Landscape

### Extraction mechanics

All private widget classes are `StatelessWidget` with only final fields (no mutable state). The extraction procedure for each widget is:

1. Copy the class body verbatim into a new `.dart` file
2. Rename: remove `_` prefix (e.g. `_TodaySceneCard` → `HomeTodaySceneCard`)
3. Copy the exact `import` lines the class depends on from the screen file
4. In the screen file: replace all usages of `_OriginalName` with `PublicName`
5. Add the new file's import to the screen file

No constructor signature changes. No field changes. No widget key changes.

### DiscoverBrowseView enum handling (critical detail)

`DiscoverBrowseView` enum is defined at the top of `discover_screen.dart` (line 10) and is used by both the state class and `_DiscoverViewToggle`. **Solution:** Move the enum into `discover_view_toggle.dart`. `discover_screen.dart` will import `discover_view_toggle.dart` to get the widget + enum, with no circular dependency. The `DiscoverBrowseView` type remains publicly accessible to `_DiscoverScreenState` via that import.

### `_reactionLabel` function handling

Currently a top-level file-private function at the bottom of `discover_screen.dart`. It is only used by `_DiscoverActivityCard`. Move it to `discover_activity_card.dart` as a file-private function (keep `_reactionLabel` name unchanged). It will not be accessible from `discover_screen.dart` after this move, but since `discover_screen.dart` never calls it directly, that is correct.

### `kDebugMode` in GardenHeroCard

`_GardenHeroCard` uses `kDebugMode` from `package:flutter/foundation.dart`. This import must be included in `garden_hero_card.dart`.

### No new state, no new abstractions

Per D124, all extracted classes remain pure `StatelessWidget` display nodes. `_HomeBanner`, `_GardenBanner`, and `_DiscoverBanner` are structurally similar but **must NOT be merged into a shared widget** — that would be a new abstraction. Leave them in their respective screen files.

### No test file changes expected

All three test files import only the top-level screen classes (`HomeScreen`, `DiscoverScreen`, `AppShellScreen`) by package path, and interact with widgets entirely through `Key()` values. Extraction does not change any key. No test imports need updating.

---

## Import Reference for Extracted Widgets

Each new widget file needs the subset of these imports relevant to its types:

```dart
import 'package:flutter/foundation.dart';  // kDebugMode — GardenHeroCard only
import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';  // PracticeActivityCatalog subtypes
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';  // BabyReactionType
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';  // PersonalizedHero only
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';  // PersonalizedHero only
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';  // PersonalizedHero only
import 'package:mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';  // only if widget calls context.watch/read
```

**Note:** Most extracted widgets only need `material.dart`, `app_theme.dart`, `app_localizations.dart`, and the specific domain model they consume. The executor should trim imports to exactly what the class uses.

---

## Recommended Task Decomposition

### T01 — Discover widget extraction (~2-3 files)

**Files created:**

- `mobile/lib/features/shell/presentation/widgets/discover_view_toggle.dart` — `DiscoverViewToggle`, `DiscoverTogglePill`, move `DiscoverBrowseView` enum here
- `mobile/lib/features/shell/presentation/widgets/discover_activity_card.dart` — `DiscoverActivityCard` + `_reactionLabel`
- `mobile/lib/features/shell/presentation/widgets/discover_space_section.dart` — `DiscoverSpaceSection`, `DiscoverSpaceGridItem`

**Files modified:**

- `mobile/lib/features/shell/presentation/screens/discover_screen.dart` — remove extracted classes, add 3 imports, update class name references (e.g. `_DiscoverViewToggle` → `DiscoverViewToggle`)

**Verify:**

```bash
cd mobile && flutter analyze
cd mobile && flutter test test/features/shell/discover_screen_test.dart
```

### T02 — Garden widget extraction (~3 files)

**Files created:**

- `mobile/lib/features/shell/presentation/widgets/garden_hero_card.dart` — `GardenHeroCard`
- `mobile/lib/features/shell/presentation/widgets/garden_continue_card.dart` — `GardenContinueCard`
- `mobile/lib/features/shell/presentation/widgets/garden_patch_card.dart` — `GardenPatchCard`, `GardenFlowerCard`, `GardenMetaChip`

**Files modified:**

- `mobile/lib/features/shell/presentation/screens/garden_screen.dart` — remove 6 classes, add 3 imports, update name references

**Verify:**

```bash
cd mobile && flutter analyze
cd mobile && flutter test test/features/practice/garden_growth_shell_test.dart
```

### T03 — Home widget extraction (~6 files)

**Files created (under `mobile/lib/features/practice/presentation/widgets/`):**

- `home_today_scene_card.dart` — `HomeTodaySceneCard`
- `home_week_stats_card.dart` — `HomeWeekStatsCard`, `HomeStatCell`
- `home_garden_mini_entry.dart` — `HomeGardenMiniEntry`
- `home_growth_summary_card.dart` — `HomeGrowthSummaryCard`
- `home_personalized_hero.dart` — `HomePersonalizedHero`
- `home_recent_result_card.dart` — `HomeRecentResultCard`

**Files modified:**

- `mobile/lib/features/practice/presentation/screens/home_screen.dart` — remove 7 classes, add 6 imports, update all name references in build method

**Verify:**

```bash
cd mobile && flutter analyze
cd mobile && flutter test test/features/practice/garden_growth_home_test.dart
```

### T04 — Final combined verification

**Verify:**

```bash
cd mobile && flutter analyze
cd mobile && flutter test test/smoke/
cd mobile && flutter test test/features/practice/garden_growth_home_test.dart
cd mobile && flutter test test/features/practice/garden_growth_shell_test.dart
cd mobile && flutter test test/features/shell/discover_screen_test.dart
```

---

## Risks and Gotchas

1. **Class rename completeness**: In `home_screen.dart` build method, every `_TodaySceneCard(...)` call must become `HomeTodaySceneCard(...)`, etc. Search-replace carefully — the state class also references some widget keys indirectly via builder closures.

2. **DiscoverBrowseView circular dependency**: Do NOT import `discover_screen.dart` from `discover_view_toggle.dart`. Move the enum TO the toggle file, import toggle FROM discover screen.

3. **`_reactionLabel` scope change**: Once moved to `discover_activity_card.dart`, it becomes file-private to that new file. No change to call sites (only `_DiscoverActivityCard.build` uses it, and that class moves with it).

4. **`flutter analyze` after each task**: Run analyze between T01, T02, T03 — don't batch all three. Dart's import resolver will catch orphaned imports and unused-import warnings early.

5. **Test verification must run from `cd mobile`** (per MEM028, MEM030): `flutter test test/...` from the worktree root fails. All verify commands must use `cd mobile && flutter test ...`.

6. **T01 depends on creating the `widgets/` subdirectory**: The path `mobile/lib/features/shell/presentation/widgets/` does not exist yet. Using `write` with the full path auto-creates the directory — no explicit mkdir needed.

7. **`kDebugMode` import in GardenHeroCard**: `_GardenHeroCard` (lines 145–276 of garden_screen.dart) uses `kDebugMode`. The new `garden_hero_card.dart` must import `package:flutter/foundation.dart`.

8. **No new shared banner widget**: `_HomeBanner`, `_GardenBanner`, `_DiscoverBanner` share identical structure but are used in one file each. Per D124 (structural-only) and Karpathy (no abstractions for single-use code), do not consolidate them.

---

## Verification Suite Reference

```
cd mobile && flutter analyze
cd mobile && flutter test test/smoke/                                      # 58/58 baseline
cd mobile && flutter test test/features/practice/garden_growth_home_test.dart   # 8 tests
cd mobile && flutter test test/features/practice/garden_growth_shell_test.dart  # 5 tests
cd mobile && flutter test test/features/shell/discover_screen_test.dart         # 6 tests
```

**Mentor test** (`mentor_shell_panel_test.dart`) is not required for S05 because no mentor entry point is touched by extraction — the FAB stays inside `_HomeScreenState.build` which is not extracted.
