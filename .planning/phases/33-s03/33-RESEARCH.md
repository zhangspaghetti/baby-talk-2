# S03 Research: Discover browse clarity

## Summary

`discover_screen.dart` (870 lines) has two density problems:

1. **`_DiscoverHero`** (~lines 165–197): full card with label + titleLarge + bodyMedium `discoverNote`. The 3-line note adds ~100px chrome before browse cards.

2. **`_DiscoverActivityCard`** (~lines 457–610): renders 7 information layers per card: chips row (sceneTag, spaceTitle, "needs attention"), title, summary, LinearProgressIndicator, progress text, nested "latest progress" container (footerText + footerHint + optional warning), CTA button.

## Recommendation

**Hero** (~lines 165–197): Remove `discoverNote` `Text` + its `SizedBox(height:12)`. Keep label + subtitle only.

**Activity card** (~lines 457–610):

- Remove `Wrap([Chip(sceneTag), Chip(spaceTitle), ...])` chips row + `SizedBox(height:12)`. Keep `hasRecoverableIssue` chip — R008 failure visibility — move inline above title.
- Collapse "latest progress" container (~lines 562–590): render only `footerText` as `bodyMedium`. Remove `footerHint` (duplicates progress bar). Keep `warningMessage` (R008).

Result: one title / one progress bar / one context line / one CTA per card.

## Implementation Landscape

**File:** `mobile/lib/features/shell/presentation/screens/discover_screen.dart`

| Location | What changes |
|---|---|
| `_DiscoverHero.build()` ~lines 192–196 | Remove `discoverNote` Text + `SizedBox(height:12)` |
| `_DiscoverActivityCard` ~lines 519–530 | Remove `Wrap([Chip(sceneTag), Chip(spaceTitle)])` + spacing. Keep `hasRecoverableIssue` chip |
| `_DiscoverActivityCard` ~lines 562–590 | Reduce to `footerText` (bodyMedium) + optional `warningMessage`. Remove `footerHint` and container label |

No changes to `_DiscoverSpaceList`, `_DiscoverViewToggle`, loading/error/empty states, view models, data layer.

## Test Stability

- `discover-activity-card-${activityId}` — on Container, unaffected
- `discover-progress-${activityId}` — LinearProgressIndicator stays
- `discover-route-target-${spaceId}-${activityId}` — ElevatedButton stays
- `discover-activity-warning-${activityId}` — warning text stays
- `discover-hero-card`, `discover-view-toggle` — unaffected

## Constraints

- Do NOT remove `hasRecoverableIssue` chip or `warningMessage` — R008
- Do NOT touch `_openActivity`, `_loadCatalog`, or data logic
- `app_theme.dart` tokens only
- Git Bash: `cd /c/code/AI/baby-talk-2`

## Verification

```bash
cd /c/code/AI/baby-talk-2/mobile && flutter analyze
cd /c/code/AI/baby-talk-2/mobile && flutter test test/smoke/
```
