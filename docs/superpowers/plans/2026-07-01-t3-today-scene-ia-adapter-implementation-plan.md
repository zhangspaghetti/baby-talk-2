# T3 Today / Scene IA Adapter Implementation Plan

Date: 2026-07-01
Status: Draft for user review
Branch: `gsd/v0.1-milestone`
Base commit: `fa3bbcd4375fb8311e2e29754fd0c00529d8c96c`
Scope: planning only. No code implementation, no commit.

## Prerequisite State

- T0 Reaction Contract ADR is complete.
- T1 Reaction clean cutover is complete.
- Backend verification fix is complete.
- T2 care_path facade is complete and committed: `fa3bbcd4375fb8311e2e29754fd0c00529d8c96c`.
- Worktree was clean at plan start.
- `mobile_v2` is no longer the product implementation mainline.

## T3 Scope Challenge

T3 is an information-architecture adapter, not a new interaction loop.

The product direction is:

```text
Home -> Today / current care node surface
Discover -> Scene / browse-search surface
PracticeSessionScreen -> temporary legacy execution path
T4 -> one-turn / one-utterance loop replacement or adjustment
```

T3 should make `mobile/` read as care-path oriented at the shell, Home, and Discover levels while preserving the existing execution path. The minimum complete change is:

1. Rename shell-visible Home / Discover surfaces to `今天` / `场景`.
2. Adapt Home into a current care node surface backed by `carePathNotifierProvider`.
3. Adapt Discover into a scene browse/search surface backed by existing catalog mechanics and, where useful, `carePathRepositoryProvider.startMoment`.
4. Keep Home and Discover CTAs routing through existing `PracticeSessionScreen` route args.
5. Add copy/l10n firewalls so user-visible Home/Discover/shell copy stops saying practice/course/progress/task framing.

Critical boundary:

```text
PracticeSessionScreen remains the legacy execution path until T4 replaces/adjusts the one-turn loop.
```

T3 can change CTA copy such as:

- `开始这个照护时刻`
- `继续这个场景`
- `现在说一句`

T3 cannot make the current `PracticeSessionScreen` look like the final care-path screen. It can only navigate there as a temporary execution path.

## Approach Comparison

### Option A - Minimal IA Adapter, Recommended

Keep the shell routes and screen classes. Update visible labels/copy, wire Home to `carePathNotifierProvider`, and let Discover keep its current search/filter structure while changing card framing from phrase library/practice to care scenes. CTAs still build `PracticeRouteArgs` and push the existing practice route.

Pros:

- Smallest blast radius.
- Matches T3 target exactly.
- Keeps existing tests/harnesses useful.
- Avoids introducing a second Today or Scene screen tree.

Cons:

- Some internal class names still say `HomeScreen`, `DiscoverScreen`, `PracticeRouteArgs`, and `PracticeRepository`.
- PracticeSession still shows legacy execution copy internally until T4.

### Option B - New Today/Scene Wrapper Widgets Around Existing Screens

Add `TodayScreen` and `SceneScreen` wrappers that embed existing Home/Discover content with care-path adapters.

Pros:

- Cleaner public widget names for future work.
- Easier to delete old names later.

Cons:

- Violates the request not to start broad UI architecture.
- Adds parallel screen identity before T4 clarifies the execution loop.
- Increases route/shell risk.

### Option C - Route-Level Rename and Practice Session Copy Sweep

Rename route concepts and update PracticeSession copy now.

Pros:

- Stronger end-to-end product semantics.

Cons:

- Too broad for T3.
- Risks changing PracticeSession core flow.
- Blurs T3/T4 boundary and can break existing practice tests.

Recommendation: Option A.

## Existing Home / Discover / Shell Reuse Map

| T3 need | Existing asset | Current state | T3 reuse decision |
| --- | --- | --- | --- |
| Bottom tab index 0 | `AppShellScreen` `IndexedStack` child 0: `HomeScreen` | Label uses `l.shellHome`; title uses `l.shellPractice` / `l.shellPracticeName(name)` | Keep index 0 and `HomeScreen`; change visible label/title to `今天` semantics. |
| Bottom tab index 1 | `AppShellScreen` child 1: `DiscoverScreen` | Label/title use `l.shellDiscover` | Keep index 1 and `DiscoverScreen`; change visible label/title to `场景`. |
| Garden index | `AppShellScreen._openGardenTab` sets `_selectedIndex = 2`; Garden is child 2 | Stable current behavior | Keep index 2. Add test to ensure Home/Scene label changes do not shift Garden. |
| Current node mechanics | T2 `carePathNotifierProvider` / `CarePathViewModel` | Exposes `moment`, `currentUtterance`, phase/message, next support | Home should read this instead of deriving visible product state from dashboard/progress-first Garden stats. |
| Legacy launch path | `PracticeRouteArgs.push(context)` and `PracticeSessionScreen` route | Existing route and practice execution path | Continue using it for T3 CTAs. Do not modify PracticeSession core flow. |
| Home current UI pieces | `HomeBCareMomentTitle`, `HomeBMentorBubble`, `HomeBSceneCard`; current `HomeScreen` uses `HomeBotanicalHeader`, `HomeProgressBar`, `HomeGardenCard`, `HomeDailyActivities` | Some Home B widgets already model care moment semantics; current screen still shows progress/garden/activity dashboard | Prefer reusing Home B widgets where they fit. Remove or demote progress-first widgets from the first screen. |
| Discover browse/search | `DiscoverScreen` search field, scene pills, sort dropdown, `_applyFilters` | Works over `PracticeActivityCatalog.activities`; cards say phrase/practice | Reuse search/filter/sort mechanics; reframe activities as care scenes. |
| Discover route hook | `DiscoverPracticeOpener` test seam and `_openActivity` | Allows tests to verify route args without real navigation | Keep and update expected CTA copy/semantics. |
| Copy storage source | `PracticeRepository.getActivityCatalog()` and T2 care_path facade | Internal names still say Practice | Allowed internally. Copy firewall should target user-visible Home/Discover/shell strings, not every internal identifier. |
| l10n | `mobile/lib/l10n/app_zh.arb`, `app_localizations.dart`, `app_localizations_zh.dart` | Checked in generated localization Dart exists | T3 must update ARB and generated Dart together, or run the existing generation path if available. |

## Proposed Adapter Architecture

```text
AppShellScreen
  - keeps route/tab structure
  - label/title copy: Home -> 今天, Discover -> 场景
  - keeps Garden index = 2

HomeScreen
  - watches carePathNotifierProvider for CarePathViewModel
  - initializes/refreshes current turn using onboarding/default starter args
  - renders current CareMoment + CareUtterance as today's primary surface
  - one primary CTA routes to PracticeSessionScreen via PracticeRouteArgs
  - secondary Garden/Growth/account cards remain lower priority only if already present and not visually refactored

DiscoverScreen
  - keeps existing search/filter/sort mechanics
  - catalog remains PracticeActivityCatalog internally
  - each card is framed as a care scene, not a phrase/practice lesson
  - CTA routes to PracticeSessionScreen via PracticeRouteArgs
  - optionally probes carePathRepository.startMoment for scene-specific current utterance preview if this can be done without per-card async churn

PracticeSessionScreen
  - unchanged core execution flow
  - legacy path only
```

### Data Flow

Home:

```text
onboardingSnapshot/defaultPracticeRouteArgs
  -> carePathNotifierProvider.initialize(starterSpaceId, starterActivityId)
  -> CarePathViewModel
  -> Today current node UI
  -> PracticeRouteArgs(spaceId: moment.spaceId, activityId: moment.activityId)
  -> PracticeSessionScreen legacy execution path
```

Discover:

```text
practiceRepositoryProvider.future.getActivityCatalog()
  -> existing search/filter/sort
  -> scene card
  -> PracticeRouteArgs(spaceId, activityId)
  -> PracticeSessionScreen legacy execution path
```

Optional Discover preview:

```text
CarePathRepository.startMoment(spaceId, activityId)
  -> CareUtterance preview
```

Only add the optional preview if it stays simple and testable. Do not create a new Scene repository, cache, storage table, or backend API.

## File-Level Implementation Plan

### Shell Label / Title Adapter

Files:

- `mobile/lib/features/shell/presentation/app_shell_screen.dart`
- `mobile/lib/l10n/app_zh.arb`
- `mobile/lib/l10n/app_localizations.dart`
- `mobile/lib/l10n/app_localizations_zh.dart`
- tests under `mobile/test/features/shell` and/or `mobile/test/smoke`

Plan:

1. Change `shellHome` visible Chinese copy from `首页` to `今天`.
2. Change `shellDiscover` visible Chinese copy from `发现` to `场景`.
3. Change `_titleForIndex` index 0 from `shellPractice` / `shellPracticeName(name)` to Today semantics. Avoid `练习`.
4. Change index 1 title to Scene semantics.
5. Keep `_selectedIndex` defaults and child order unchanged.
6. Keep `_openGardenTab` selecting index 2. Add or update tests that would fail if Garden shifts.

Notes:

- Do not rename routes or change navigation framework.
- Keep internal `_surfaceForIndex` strings (`home`, `discover`, `garden`, `me`) unless tests prove user-visible analytics copy leaks. These are internal identifiers.

### Home / Today Adapter

Files:

- `mobile/lib/features/practice/presentation/screens/home_screen.dart`
- existing reusable widgets under `mobile/lib/features/practice/presentation/widgets/`
- `mobile/test/features/practice/critical_ui_coverage_test.dart`
- `mobile/test/features/practice/home_b_widgets_test.dart`
- optional focused new test: `mobile/test/features/practice/home_today_adapter_test.dart`

Plan:

1. Add `carePathNotifierProvider` watch/read in `HomeScreen`.
2. During bootstrap, initialize care path with the same starter args currently used by continuity:
   - `starterSpaceId: _resolveStarterArgs()?.spaceId`
   - `starterActivityId: _resolveStarterArgs()?.activityId`
3. On pull-to-refresh and `didPopNext`, refresh care path current utterance alongside existing continuity/garden refreshes.
4. Replace first-screen dashboard/progress-first content with one current node area:
   - care moment title
   - scene/care action label
   - current utterance English + Chinese/pronunciation if available
   - one primary CTA
   - fallback/loading/error state
5. Reuse Home B widgets where practical:
   - `HomeBCareMomentTitle` for moment title
   - `HomeBSceneCard` if it can be fed care_path values without carrying old practice copy
   - otherwise keep a small local adapter widget inside Home scope
6. Demote or remove from first screen:
   - `HomeProgressBar(label: '本周学习进度')`
   - `HomeGardenCard` as the primary module
   - `HomeDailyActivities` if it creates multiple competing CTAs
7. CTA:
   - visible copy must be care-path copy, e.g. `现在说一句`, `开始这个照护时刻`, or `继续这个场景`
   - route must be existing `PracticeRouteArgs.push(context)`
   - expected args derive from `carePathViewModel.moment.spaceId/activityId`
8. Fallback:
   - if care path is loading, show skeleton/quiet loading.
   - if error/unavailable, show safe copy that does not say practice/course/progress.
   - if no current utterance, CTA disabled or hidden with explanation.

Explicit locked boundary:

- Do not modify `PracticeSessionScreen` core flow.
- Do not assert that `PracticeSessionScreen` becomes one-utterance loop.
- Do not assert that all PracticeSession copy is care-path migrated.

### Discover / Scene Adapter

Files:

- `mobile/lib/features/shell/presentation/screens/discover_screen.dart`
- maybe `mobile/lib/features/shell/presentation/widgets/discover_activity_card.dart` only if the current internal `_PhraseCard` is intentionally replaced by an existing widget without broad refactor
- `mobile/test/features/shell/discover_screen_test.dart`

Plan:

1. Keep `DiscoverScreen` class and route position.
2. Rename visible surface copy from Discover/phrase library to Scene/care scene:
   - hero subtitle
   - search hint
   - semantic label
   - result count
   - empty states
   - CTA label
3. Keep existing mechanics:
   - `_searchController`
   - `_selectedScene`
   - `_sortMode`
   - `_applyFilters`
   - `DiscoverPracticeOpener` seam
4. Rename private UI concepts only where it reduces confusion and does not broaden churn:
   - `_DiscoverPhraseList` can become `_DiscoverSceneList`
   - `_PhraseCard` can become `_SceneCard`
   - keys can either remain stable for tests or add new Scene keys while keeping backward compatibility only if needed.
5. Cards should frame each `PracticeCatalogActivitySummary` as a care scene:
   - title = care scene name
   - summary = care action or context
   - next phrase preview can become "现在可以说"
   - total/completed phrase progress should not be first-class visible copy
6. CTA routes to existing `PracticeSessionScreen` via `PracticeRouteArgs`.
7. Optional: use `carePathRepositoryProvider.startMoment` to preview current utterance for a selected card. Only do this if a simple single selected-card preview is enough. Do not introduce per-card async builders for every card unless tests show it remains stable.

### Provider Integration

Files:

- `mobile/lib/app/providers/repository_providers.dart` only if provider dependencies need adjustment
- `mobile/test/app/app_composition_characterization_test.dart`

Plan:

1. Prefer no provider graph changes; T2 already added `carePathRepositoryProvider` and `carePathNotifierProvider`.
2. If Home needs a starter-aware initialization, keep it as a notifier method call in `HomeScreen`; do not create a family provider unless repeated test setup becomes hard to reason about.
3. App composition test should confirm the shell can resolve care path providers after boot and Home/Discover changes do not break nested overrides.

## Test Plan

### Shell Label Tests

Cover:

- bottom nav label index 0 is `今天`.
- bottom nav label index 1 is `场景`.
- app bar title index 0 uses Today semantics, not `练习`.
- app bar title index 1 uses Scene semantics.
- Garden tab remains index 2 and `_openGardenTab(GrowthTab.garden/growth)` still selects Garden/Growth without label shift.

Likely files:

- `mobile/test/features/shell/...`
- `mobile/test/smoke/app_boot_test.dart`

### Home / Today Widget Tests

Cover:

- Home initializes/reads `carePathNotifierProvider`.
- current node title/action/utterance render from `CarePathViewModel`.
- primary CTA exists.
- CTA uses care-path copy, e.g. `现在说一句` or `继续这个场景`.
- CTA navigates to existing PracticeSession route with expected `PracticeRouteArgs`.
- loading/error/held fallback states do not expose `练习`, `课程`, `学习进度`, `完成任务`, or `1 of N`.
- Garden/Growth/account lower content, if retained, does not become primary above current care node.

Do not test:

- one-utterance loop behavior.
- PracticeSession internal copy conversion.
- Garden visual redesign.

### Discover / Scene Widget Tests

Cover:

- Scene screen renders search field, scene pills, sort/dropdown.
- hero and empty states use Scene/care copy, not phrase library/practice copy.
- cards are care scene cards, not phrase/practice lesson cards.
- search/filter mechanics still work.
- CTA copy is care-path copy.
- CTA calls `DiscoverPracticeOpener` with expected `PracticeRouteArgs`.
- malformed card remains safe and does not navigate.

Existing tests to update:

- `mobile/test/features/shell/discover_screen_test.dart`

### Provider Integration Tests

Cover:

- app composition can resolve `carePathRepositoryProvider` and `carePathNotifierProvider`.
- Home boot with nested provider overrides initializes current turn without provider errors.
- no Garden index regression.

Existing test:

- `mobile/test/app/app_composition_characterization_test.dart`

### Copy Firewall Tests

Add or extend a focused source/copy scan. Suggested new file:

- `mobile/test/tool/verify_t3_today_scene_copy_firewall_test.dart`

Scan target should be intentionally narrow:

```text
mobile/lib/features/shell/presentation/app_shell_screen.dart
mobile/lib/features/shell/presentation/screens/discover_screen.dart
mobile/lib/features/practice/presentation/screens/home_screen.dart
mobile/lib/l10n/app_zh.arb keys used by shell/Home/Discover
```

Blocked user-visible terms for these surfaces:

```text
练习
课程
学习进度
完成任务
第 1 / 
1 of N
Lesson
XP
金币
排行榜
Duolingo
```

Allowed internal terms:

```text
PracticeRepository
PracticeRouteArgs
PracticeSessionScreen
practiceRepositoryProvider
practice route
```

Reason: T3 changes user-visible IA copy for Home/Discover/shell. It does not rename every internal class or alter legacy execution internals.

### Accessibility / Semantics Smoke Tests

If existing harness supports it:

- Update `mobile/test/smoke/a11y_semantics_test.dart` or add a focused widget semantics test.
- Ensure Today CTA has a meaningful label.
- Ensure Scene card CTA label is not duplicated/incoherent.
- Ensure search field semantics say scene/care scene, not phrase/practice.

## Copy / l10n Migration Plan

### Shell Copy

Update:

- `shellHome`: `今天`
- `shellDiscover`: `场景`
- `shellPractice`: replace with Today title copy or stop using it for index 0
- `shellPracticeName`: replace with `{name} 的今天` or stop using it for index 0
- `shellDiscoverTooltip`: scene-oriented copy if visible

### Home Copy

Replace first-screen visible copy:

| Old framing | New framing direction |
| --- | --- |
| `本周学习进度` | remove or replace with current care state note |
| `开始练习` / `继续练习` | `现在说一句` / `继续这个场景` |
| `练习建议` | `今天的照护时刻` |
| `下一条可继续的练习` | `下一个可接上的照护时刻` |

Keep lower Garden/Growth copy changes out of T3 unless it appears on the first Home surface and breaks the copy firewall.

### Discover Copy

Replace:

| Old framing | New framing direction |
| --- | --- |
| `发现` | `场景` |
| `短语` as primary library framing | `照护场景` / `可说的一句` |
| `练这一句` | `现在说一句` |
| `活动卡` | `场景卡` |
| `目录` if user-visible | `场景列表` |
| progress counts like `{completed}/{total} 句已练` | demote/remove or reword as non-progress context |

### Localization Files

Because this repo checks in generated localization Dart, implementation must update:

- `mobile/lib/l10n/app_zh.arb`
- `mobile/lib/l10n/app_localizations.dart`
- `mobile/lib/l10n/app_localizations_zh.dart`

If a generation command exists, use it. If not, keep edits mechanical and covered by widget tests.

## Failure Modes

| Area | Failure mode | Impact | Detection | Mitigation |
| --- | --- | --- | --- | --- |
| shell labels | label changes shift tab indices | Garden/FAB/Me behavior breaks | shell label/index tests | keep `IndexedStack` order unchanged; assert Garden index 2 |
| Home boot | care path initializes before providers are ready | runtime provider exception | app composition + Home widget tests | use existing provider graph and starter args after boot |
| Home CTA | CTA routes with stale continuity args instead of care moment args | opens wrong scene | Home CTA route test | derive args from `CarePathViewModel.moment` |
| Home copy | dashboard/progress remains primary | product IA still feels course/progress-first | copy firewall + widget tests | remove/demote `HomeProgressBar` from first screen |
| Discover mechanics | copy migration breaks filtering/search | scene browse regression | Discover tests | keep `_applyFilters` mechanics unchanged |
| Discover performance | per-card `startMoment` causes async churn | flaky tests/jank | widget tests + review | avoid per-card async; use catalog summaries unless necessary |
| PracticeSession boundary | T3 modifies execution loop | scope creep into T4 | diff review + tests | no PracticeSession core edits |
| copy firewall | broad scan flags PracticeSession/Garden/Account legacy copy | noisy failing test | firewall scope review | scan only T3 target surfaces |
| l10n | ARB and generated Dart drift | compile/test failures | focused analyze/tests | update ARB + generated Dart together |
| reaction contract | new reaction enum introduced | splits T1 contract | source scan | continue using `BabyReactionType`; no `CareReactionType` |

## What Is Explicitly Not In Scope

- No One-utterance screen loop implementation.
- No `PracticeSessionScreen` core flow changes.
- No claim that `PracticeSessionScreen` is the final care-path screen.
- No Garden/Growth visual refactor.
- No backend changes.
- No `mobile_v2` changes.
- No reaction contract semantic changes.
- No `CareReactionType`.
- No new Isar collection.
- No parallel local event table.
- No backend API.
- No Duolingo identity, gamification, lesson framing, XP, coins, leaderboard, streak pressure, or course framing.
- No broad visual redesign of Home or Discover.
- No routing framework migration.

## Worktree Sequencing

Recommended sequence is mostly serial because Home/Discover/shell tests overlap on app boot and l10n.

```text
T3.1 Shell labels and l10n base
  -> shell label/index tests

T3.2 Home/Today adapter
  -> Home widget tests
  -> provider/app composition tests

T3.3 Discover/Scene adapter
  -> Discover widget tests

T3.4 Copy firewall and accessibility smoke
  -> focused copy scan
  -> semantics smoke if harness fits

T3.5 Verification
  -> focused flutter tests
  -> focused analyze
  -> dart format check
  -> git diff --check
  -> scope guard for backend/mobile_v2/PracticeSession/reaction contract
```

Parallelization:

- Shell l10n and copy firewall can be drafted in parallel only if one owner controls `app_zh.arb`.
- Home and Discover can be implemented in parallel if they do not both edit l10n at the same time. Otherwise sequence them.
- Provider/app composition should wait until Home wiring is stable.
- Avoid parallel edits to `app_shell_screen.dart`, `app_zh.arb`, and generated localization files.

## Verification Commands

Focused tests should include at least:

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub `
    test/features/shell/discover_screen_test.dart `
    test/features/practice/critical_ui_coverage_test.dart `
    test/features/practice/home_b_widgets_test.dart `
    test/app/app_composition_characterization_test.dart `
    test/tool/verify_t3_today_scene_copy_firewall_test.dart
} finally {
  Pop-Location
}
```

Add shell/smoke/a11y tests to the command if implementation touches those harnesses.

Focused analyze:

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' analyze --no-pub `
    lib/features/shell/presentation/app_shell_screen.dart `
    lib/features/shell/presentation/screens/discover_screen.dart `
    lib/features/practice/presentation/screens/home_screen.dart `
    lib/l10n `
    test/features/shell `
    test/features/practice `
    test/tool
} finally {
  Pop-Location
}
```

Format and diff checks:

```powershell
& 'C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe' format --output=none --set-exit-if-changed mobile/lib mobile/test
git diff --check
```

Scope guard:

```powershell
git status --short -- backend mobile_v2 mobile/lib/features/practice/presentation/screens/practice_session_screen.dart mobile/lib/features/practice/domain/models/interaction_event_payload.dart
```

## GSTACK Review Report

**Scope verdict:** T3 is appropriately scoped if it stays at IA adapter level: shell labels, Home current care node, Discover scene browse, tests, l10n/copy firewall.

**Primary execution risk:** accidentally converting T3 into T4 by changing `PracticeSessionScreen` or asserting one-turn loop behavior. The plan blocks this explicitly.

**Architecture risk:** Home currently has progress/garden/dashboard-first code and unused Home B assets. The adapter should reuse existing care-moment widgets where possible, but avoid broad visual redesign or a new Today screen.

**Copy risk:** legacy `练习` copy is widespread. The copy firewall must be targeted to Home/Discover/shell user-visible surfaces, not entire `mobile/lib`, otherwise it will fail on intentionally out-of-scope PracticeSession/Garden/Growth/account copy.

**Testing risk:** shell label changes can hide index regressions. Tests must assert label text and Garden index behavior together.

**Recommendation:** approve implementation only as Option A: minimal IA adapter, legacy execution path preserved, T4 reserved for one-turn loop.

**Open questions:** none. User explicitly approved continuing CTA navigation to existing `PracticeSessionScreen` as a temporary legacy execution path.

**Verdict:** Draft ready for user review. No implementation is approved by this document until reviewed.
