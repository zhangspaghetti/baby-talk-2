---
title: BabyTalk Mobile Care Path Engineering Architecture
status: ACTIVE_DRAFT
source_contract: docs/design-spec/BabyTalk_Mobile_Duolingo-like_Care_Path_Design_Contract.md
date: 2026-06-29
branch: gsd/v0.1-milestone
owner: mobile-engineering
scope: mobile architecture plan, not UI implementation
---

# BabyTalk Mobile Care Path Engineering Architecture

本文把 `BabyTalk_Mobile_Duolingo-like_Care_Path_Design_Contract.md` 转成移动端工程架构。结论很直接：

```text
保留现有 Practice / Garden / Onboarding 的状态机器和本地事件资产。
新增 care_path 语义层承接产品模型。
先改信息架构、数据流、测试契约，再做视觉实现。
```

不要新建一套平行移动端，也不要继续把 `Practice` 当用户可见主模型。`Practice` 可以短期作为内部实现词存在，但所有新产品入口必须说“照护时刻 / 说一句 / 宝宝反应 / 下一句 / 花园痕迹”。

## Inputs Read

- `docs/design-spec/BabyTalk_Mobile_Duolingo-like_Care_Path_Design_Contract.md`
- `docs/design-spec/README.md`
- `TODOS.md`
- `mobile/lib/app/app.dart`
- `mobile/lib/features/shell/presentation/app_shell_screen.dart`
- `mobile/lib/features/practice/presentation/screens/home_screen.dart`
- `mobile/lib/features/shell/presentation/screens/discover_screen.dart`
- `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart`
- `mobile/lib/features/practice/presentation/practice_session_notifier.dart`
- `mobile/lib/features/practice/data/repositories/practice_repository.dart`
- `mobile/lib/features/practice/data/services/asset_phrase_service.dart`
- `mobile/lib/features/practice/domain/models/interaction_event_payload.dart`
- `mobile/lib/features/practice/domain/models/practice_continuity_snapshot.dart`
- `mobile/lib/features/practice/domain/models/garden_growth_snapshot.dart`
- `mobile/assets/content/seed_content.json`

Framework check used official docs only:

- Flutter app architecture: layered UI / data separation and repository pattern.
- Riverpod: provider graph, overrides, and explicit async loading/error states.
- go_router: ShellRoute / StatefulShellRoute support, but no need to spend it in slice 1.
- Flutter integration_test: full-flow tests are appropriate for this loop.

`/browse` was attempted first per repo rule, but local gstack browse fails with `Cannot find server.ts`. Official docs were checked via web fallback.

## Step 0 Scope Challenge

### What Already Exists

| Need from contract | Existing asset | Reuse decision |
| --- | --- | --- |
| Four-tab shell | `AppShellScreen` already has 4 tabs | Reuse, relabel and rewire semantics |
| Today current node | `PracticeContinuityNotifier` + `PracticeRepository.getContinuitySnapshot()` | Reuse as input to care path current node |
| Scene browse/search | `DiscoverScreen` already loads catalog, filters, searches, and opens route args | Reuse as `场景` tab, remove phrase-library/course language |
| One utterance screen | `PracticeSessionScreen` already handles phrase/audio/我说了/reaction/local save | Reuse mechanics, change state model to one-turn loop |
| Local trace | `InteractionEventPayload` + `PracticeLocalDataSource` + Isar | Reuse, but reaction enum must be expanded |
| Garden trace | `GardenGrowthRepository.buildSnapshot()` projects events into garden/diary/milestone data | Reuse, remove achievement/completion semantics |
| Onboarding first phrase | Onboarding screens and `OnboardingRepository` already store starter IDs | Reuse, shorten to first usable utterance |
| Deep links/reentry | `AppReentryOrchestrator` serializes share/invite navigation | Keep; update route targets after care path surface exists |
| Tests | Unit/widget/integration tests already cover practice, shell, garden, onboarding | Extend rather than rebuild |

### Minimum Change Set

The smallest complete version is not a visual rewrite. It is a semantic architecture slice:

```text
1. Resolve reaction contract ADR and sync decision.
2. Expand reaction model to contract reaction set.
3. Introduce care_path domain/view-model layer.
4. Relabel shell: 今天 / 场景 / 花园 / 我的.
5. Convert Home into Today path current-node surface.
6. Convert Discover into Scene browse surface.
7. Convert PracticeSession into one-utterance turn loop.
8. Project saved turns into Garden trace without reward language.
9. Add tests and copy firewall.
```

This is bigger than a two-file patch, so implementation should be split into workstreams. The architecture avoids new infrastructure and keeps new abstractions limited to the care path boundary.

### Complexity Call

Full implementation will touch more than eight files. That is acceptable only if split by behavior:

```text
PR 0: Reaction Contract ADR / sync decision
PR 1: semantic contracts + reaction model + copy firewall
PR 2: care_path domain/view-model + Today/Scene adapters after gate
PR 3: one-utterance loop + Garden trace tests after gate
```

Do not combine broad visual polish, Ritual Room cleanup, voice/STT, backend reward logic, or Growth redesign into this slice.

## Architecture Decision

Use a facade, not a rewrite.

```text
features/care_path/
  domain/
    care_path_models.dart
    care_reaction_type.dart
  data/
    care_path_repository.dart
  presentation/
    care_path_notifier.dart
    today_care_path_screen.dart
    scene_care_screen.dart
```

`care_path` is a product-semantic layer over existing `practice` and `garden` assets. It owns the words and workflow that users see. `practice` remains the storage/session engine until a later rename is worth the churn.

```text
┌──────────────────────────────────────────────────────────┐
│ UI: 今天 / 场景 / 花园 / 我的                              │
│                                                          │
│ TodayCarePathScreen  SceneCareScreen  GardenTraceScreen  │
└───────────────┬───────────────────────┬──────────────────┘
                │                       │
┌───────────────▼───────────────────────▼──────────────────┐
│ care_path presentation                                    │
│ CarePathNotifier / CareTurnNotifier                       │
│ - current node                                            │
│ - one utterance                                           │
│ - reaction prompt                                         │
│ - next support                                            │
│ - trace queued/saved state                                │
└───────────────┬───────────────────────┬──────────────────┘
                │                       │
┌───────────────▼───────────────────────▼──────────────────┐
│ care_path data facade                                     │
│ CarePathRepository                                        │
│ - reads PracticeRepository catalog/continuity              │
│ - writes InteractionEventPayload                           │
│ - asks dynamic API only for next support when available     │
│ - falls back to seed/local rule table                       │
└───────────────┬───────────────────────┬──────────────────┘
                │                       │
┌───────────────▼─────────────┐ ┌───────▼──────────────────┐
│ existing practice engine     │ │ existing garden projection│
│ AssetPhraseService           │ │ GardenGrowthRepository    │
│ PracticeRepository           │ │ GardenGrowthNotifier      │
│ PracticeLocalDataSource      │ │ GardenFertilizer optional │
└──────────────────────────────┘ └──────────────────────────┘
```

## Navigation Architecture

Keep the current `IndexedStack` shell for slice 1. It already preserves tab state and avoids a router migration. go_router `StatefulShellRoute` is useful later if tabs need deep-linkable branch navigation, but adding it now spends complexity on routing rather than on the care loop.

Target shell:

| Tab | Current implementation | Target surface | Action |
| --- | --- | --- | --- |
| 今天 | `HomeScreen` | `TodayCarePathScreen` or adapted `HomeScreen` | Replace dashboard/progress copy with current path node |
| 场景 | `DiscoverScreen` | `SceneCareScreen` or adapted `DiscoverScreen` | Keep search/filter, rename activity cards as care scenes |
| 花园 | `GardenGrowthCombinedScreen` | Garden-only primary surface | Hide Growth segment from main path; keep records under My/archive if needed |
| 我的 | `MeScreen` + settings routes | Profile/settings/archive | Move Growth profile/archive affordances here |

### Slice 1 Screen Strategy

优先 adapter/wrapper existing `HomeScreen` / `DiscoverScreen` mechanics；只有当旧 screen 语义污染过重时，才新建 `TodayCarePathScreen` / `SceneCareScreen`。不得同时维护两个用户可见入口。

Current shell bug to fix during migration:

```dart
// app_shell_screen.dart currently initializes garden when index == 1.
if (index == 1) { gardenGrowthNotifier.initialize(); }
```

In the target nav, garden initialization belongs to index `2`.

## Product State Machine

```text
[*]
  │
  ▼
NeedsFirstPhrase
  │ onboarding creates starter care moment
  ▼
TodayPathReady
  │ parent taps current node or chooses scene
  ▼
CareMomentSelected
  │ load one utterance
  ▼
UtteranceReady
  │ parent taps 我说了
  ▼
ReactionPrompt
  │ reaction selected / skipped / other text
  ▼
NextSupportLoading
  ├─ success ───────────────► NextSupportReady
  ├─ timeout/network error ─► UtteranceHeldWithFallback
  └─ unsupported content ───► SafeSceneFallback
  │
  ▼
TraceQueued
  │ Isar append succeeds
  ▼
TraceSaved
  │ garden projection refreshes
  ▼
TodayPathReady
```

Important rule: the loop never advances by lesson count. It advances by care context:

```text
care action + baby reaction + current utterance + local history
→ next parent support utterance
```

## Domain Model

New product-facing domain types:

```dart
enum CarePathNodeState {
  current,
  nearby,
  doneToday,
  unavailable,
}

enum CareReactionType {
  cooperating, // 配合
  hesitant,    // 犹豫
  resisting,   // 不想
  noResponse,  // 没反应
  other,       // 其他
}

class CareMoment {
  final String spaceId;
  final String activityId;
  final String title;
  final String careActionLabel;
  final String whenToSay;
}

class CareUtterance {
  final String phraseId;
  final String english;
  final String chinese;
  final String whenToSay;
  final String? audioAsset;
  final bool isGenerated;
}

class CareTurnSnapshot {
  final CareMoment moment;
  final CareUtterance current;
  final CareReactionType? reaction;
  final CareUtterance? nextSupport;
  final CareTurnPhase phase;
  final String? gentleMessage;
}
```

Do not expose `PracticePhrase.step`, `completedPhraseIds`, or activity completion in care-path UI. Those fields may continue to exist internally for compatibility.

## Reaction Data Contract

This is the one real schema gap.

Current mobile enum:

```text
calm / engaged / imitated / needs_break
```

Contract enum:

```text
cooperating / hesitant / resisting / no_response / other
```

Recommendation: use ADR-0001 Option D, a clean cutover to the new five-value reaction contract before UI implementation starts. Because the project has no production users, no released legacy client, and no online historical data that must remain compatible, do not carry a long-term dual-accept strategy.

```text
Old development/test value     One-time migration target
calm                           cooperating
engaged                        cooperating
imitated                       cooperating
needs_break                    resisting
```

New persisted values:

```text
cooperating
hesitant
resisting
no_response
other
```

Mobile must be new-read/new-write only. Backend validation and the database constraint must accept only the five new values. If development or test data already contains the old four values, handle it with a one-time migration or development reset only. Do not fake the five reactions by compressing them permanently into the old four-value enum; it would lose the product's central signal.

## Implementation Gate: Reaction Contract

在 reaction enum / backend sync compatibility 做出 ADR 之前，不允许开始 Today/Scene/One-utterance UI implementation。

The ADR must choose exactly one strategy:

- Option D: clean cutover to the new 5-value reaction wire contract before UI implementation.

ADR-0001 documents the recommended strategy. 在 ADR 明确批准之前，不允许开始 Today/Scene/One-utterance UI implementation。

不得把 cooperating / hesitant / resisting / no_response / other 永久压缩成旧的 calm / engaged / imitated / needs_break。旧四值不再作为正式 contract 保留。

## Data Flow

```text
App boot
  │
  ├─ AppBootState.load()
  │    └─ AssetPhraseService.loadSeedContent()
  │
  ├─ FeatureGates.resolve()
  │    └─ starter PracticeRouteArgs
  │
  ▼
ProviderScope overrides
  │
  ├─ practiceRepositoryProvider
  ├─ gardenGrowthNotifierProvider
  ├─ practiceContinuityNotifierProvider
  └─ carePathRepositoryProvider    (new facade)
        │
        ├─ PracticeRepository.getActivityCatalog()
        ├─ PracticeRepository.getContinuitySnapshot()
        ├─ PracticeRepository.recordReaction()
        └─ GardenGrowthRepository.buildSnapshot()
```

Care turn:

```text
Today current node
  │
  ▼
CarePathNotifier.startMoment(spaceId, activityId)
  │
  ├─ load current CareUtterance from seed/dynamic source
  └─ phase = UtteranceReady
       │
       ▼
parent taps 我说了
       │
       ▼
phase = ReactionPrompt
       │
       ▼
reaction selected / skipped / other
       │
       ├─ append local InteractionEventPayload
       ├─ request next support utterance
       ├─ refresh garden snapshot
       └─ phase = NextSupportReady
```

## Existing Modules To Adapt

| Module | Required change |
| --- | --- |
| `app_shell_screen.dart` | Change labels and title mapping; fix garden init index; hide Growth as main tab |
| `home_screen.dart` | Replace progress/garden dashboard layout with Today care path view model |
| `discover_screen.dart` | Rename to Scene semantics; keep search/filter; remove `短语库/练习/进度` framing |
| `practice_session_screen.dart` | Remove step progress UI; show one utterance, meaning, when-to-say, listen, `我说了` |
| `practice_session_notifier.dart` | Split or wrap into `CareTurnNotifier`; reaction produces next support, not next static index |
| `interaction_event_payload.dart` | Expand reaction enum and parsers |
| `garden_growth_repository.dart` | Keep projection, adjust copy to trace/continuity instead of completion/milestones pressure |
| `app_zh.arb` | Copy firewall: `首页/发现/成长/练习/完成/学习进度/任务/第 N 句` must disappear from user-facing care path |
| integration tests | Rename core journeys from practice to care path and assert banned terms are absent |

## Copy Firewall

Hard ban for care-path runtime surfaces:

```text
课程
练习
第 1 课
1 of 3
2 of 4
完成任务
答对
答错
评分
正确率
XP
金币
排行榜
连续打卡
学习进度
```

Allowed:

```text
今天
场景
花园
我的
现在说一句
我说了
宝宝现在怎么了？
配合
犹豫
不想
没反应
其他
下一句可以这样说
留下这个时刻
```

内部代码路径可以暂时保留 practice 命名，但 l10n keys、semantics labels、screen titles、tab labels、empty/error/loading copy 不得出现用户侧 Practice/练习 framing。

The existing `mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart` should be extended to scan new care-path surfaces and l10n keys.

## Test Diagram

```text
CODE PATHS                                             USER FLOWS
[+] care_path domain models                            [+] First value onboarding
  ├── [GAP] reaction enum parse old/new wire values       ├── [GAP][E2E] creates first usable phrase
  ├── [GAP] node state derivation                         └── [GAP] no setup/system explanation copy
  └── [GAP] unsupported content fallback

[+] CarePathRepository facade                           [+] Today care path
  ├── [GAP] catalog + continuity compose current node     ├── [GAP][WIDGET] one dominant current node
  ├── [GAP] missing activity safe fallback                ├── [GAP][WIDGET] one primary CTA
  ├── [GAP] append trace locally                          └── [GAP] no sync/status-first dashboard
  └── [GAP] next support timeout fallback

[+] Scene care browse                                   [+] Scene selection
  ├── [★★] existing Discover search/filter tests          ├── [★★] existing discover opens route args
  ├── [GAP] scene labels use care action language         └── [GAP] recent scenes are not completion history
  └── [GAP] invalid route shows gentle fallback

[+] One utterance turn                                  [+] Say one sentence
  ├── [GAP] no progress bar / step count                  ├── [GAP][E2E] listen → 我说了 → reaction
  ├── [GAP] reaction prompt appears after 我说了           ├── [GAP][E2E] next support appears
  ├── [GAP] skipped reaction uses no_response             └── [GAP] parent can exit without completion summary
  └── [GAP] next support keeps current phrase on failure

[+] Garden trace projection                             [+] Trace continuity
  ├── [★★] existing garden snapshot tests                 ├── [GAP][E2E] trace appears after said moment
  ├── [GAP] new reaction values projected safely          └── [GAP] no reward/completion language
  └── [GAP] malformed event does not break garden

COVERAGE: existing coverage is strong around old Practice/Garden mechanics,
but the new care-path semantics are mostly untested until these gaps land.
```

## Failure Modes

| Failure mode | User impact | Test | Handling |
| --- | --- | --- | --- |
| Seed content missing current activity | Today has no safe current node | Unit + widget | Fall back to first available care moment with gentle note |
| Audio asset missing | Parent can still read phrase but cannot listen | Unit existing `validateAssets` + widget | Keep phrase visible, audio retry secondary |
| Backend or DB still uses old reaction contract | New reaction saves fail or contract drifts before UI ships | Backend + sync integration | Block UI implementation until mobile/backend/DB clean cutover lands |
| Next support API timeout | Parent loses flow after reaction | Unit + widget | Keep current utterance and show local safe fallback |
| Development/test data still contains old reaction values | Trace disappears or crashes during cutover verification | Unit + migration/reset check | One-time migrate old dev/test values or reset the development data store |
| App restarts after `我说了` before reaction | Spoken moment might be lost | Widget/integration | Only persist trace after reaction or explicit no-response timeout; restore phase safely |
| Scene search empty | Parent thinks content is missing | Widget | Clear filters action and common scene suggestions |
| Copy regression says `练习/完成/学习进度` | Product drifts into course/task framing | Tool test | Fail CI semantic firewall |

Critical gap: reaction enum/backend clean cutover has no current implementation. Do not start UI implementation until ADR-0001 is explicitly approved and the implementation plan uses new-read/new-write mobile, new-only backend validation, and a new-only DB constraint.

## Performance Review

No new performance-sensitive infrastructure is needed.

Rules:

- Keep `AssetPhraseService` caching as the catalog source.
- Avoid loading full catalog repeatedly in Today, Scene, and Garden in the same frame. The care facade should compose existing snapshots once per refresh.
- Keep Garden projection lazy. Do not initialize Garden when entering `场景`.
- Watch narrow Riverpod slices in widgets; avoid rebuilding the whole shell for a reaction change.
- Existing `r4_performance_benchmark_test.dart` should add one measurement for `Today → one utterance → Garden trace`.

Known O(n) scans over local events are acceptable for the current validation user scale. Defer materialized projections until the already-captured Phase 2 TODO requires it.

## Worktree Parallelization

| Step | Modules touched | Depends on |
| --- | --- | --- |
| Copy firewall + l10n labels | `mobile/lib/l10n`, `mobile/test/tool` | none |
| Care path domain/facade | `mobile/lib/features/care_path`, `mobile/lib/app/providers` | none |
| Reaction Contract ADR / sync decision | docs/ADR, mobile/backend owners | none |
| Reaction enum + sync compatibility | `mobile/lib/features/practice/domain`, sync/backend if included | Reaction Contract ADR |
| Today + Scene surfaces | `mobile/lib/features/practice`, `mobile/lib/features/shell` | care path facade + Reaction Contract ADR |
| One utterance turn | `mobile/lib/features/practice`, `mobile/lib/features/care_path` | reaction model + Reaction Contract ADR |
| Garden trace semantics | `mobile/lib/features/practice/data/repositories`, `mobile/lib/features/shell` | reaction model |
| Integration tests | `mobile/integration_test`, `mobile/test/features` | all behavior slices |

Parallel lanes:

```text
Lane A: Copy firewall + shell labels
Lane B: Care path domain/facade
Lane C: Reaction enum compatibility

After A+B+C merge:
Lane D: Today + Scene surfaces
Lane E: One utterance turn + Garden trace

Final:
Lane F: Integration tests + performance benchmark + semantic audit
```

Conflict flags:

- Lane D and E both touch `mobile/lib/features/practice`; keep them sequential or assign exact files.
- Reaction enum may require backend changes. If so, run it as its own branch and merge before mobile UI.

## NOT In Scope

- Ritual Room visual polish.
- Duolingo brand mimicry, mascot, color, XP, streak, quests, leaderboards.
- Full rewrite of every mobile page.
- Voice/STT or hands-free Phase 2 work.
- A new routing framework migration.
- Backend-wide event-sourcing rewrite.
- Growth as a daily main tab.
- New reward economy or completion economy.

## Implementation Tasks

- [ ] **T0 (P0, human: ~30min / CC: ~10min)** — Reaction Contract ADR / sync decision — Approve ADR-0001 Option D before Today/Scene/One-utterance UI starts.
  - Surfaced by: implementation gate — reaction enum/backend sync compatibility is unresolved.
  - Files: `docs/adr/ADR-0001-reaction-contract-clean-cutover.md`, with mobile/backend owner sign-off.
  - Verify: ADR merged or explicitly approved.

- [ ] **T1 (P1, human: ~2h / CC: ~25min)** — Reaction model implementation — Cut over mobile/backend/database to the new five-value reaction contract.
  - Surfaced by: architecture/data contract — current `BabyReactionType` has 4 values, contract requires 5.
  - Files: `mobile/lib/features/practice/domain/models/interaction_event_payload.dart`, generated files, tests, backend validation, and DB constraint migration.
  - Verify: `cd mobile && flutter test test/features/practice/interaction_event_payload_test.dart`.

- [ ] **T2 (P1, human: ~3h / CC: ~45min)** — Care path facade — Add `features/care_path` domain, repository facade, and notifier.
  - Surfaced by: architecture boundary — new product semantics should not fork storage.
  - Files: `mobile/lib/features/care_path/**`, `mobile/lib/app/providers/repository_providers.dart`.
  - Verify: focused care_path unit tests plus `cd mobile && flutter test test/app/app_composition_characterization_test.dart`.

- [ ] **T3 (P1, human: ~4h / CC: ~1h)** — Today/Scene IA — Relabel shell and adapt Home/Discover into `今天/场景`.
  - Surfaced by: navigation contract — current shell still says Home/Discover/Growth/Practice.
  - Files: `app_shell_screen.dart`, `home_screen.dart`, `discover_screen.dart`, `app_zh.arb`, shell/practice widget tests.
  - Verify: shell and discover widget tests; semantic firewall test.

- [ ] **T4 (P1, human: ~5h / CC: ~90min)** — One utterance loop — Replace static multi-phrase progress with current utterance → reaction → next support.
  - Surfaced by: core loop contract — no step count, no session count, no lesson sequence.
  - Files: `practice_session_screen.dart`, `practice_session_notifier.dart` or new `care_turn_notifier.dart`, phrase/reaction widgets.
  - Verify: practice widget tests + new integration path.

- [ ] **T5 (P2, human: ~2h / CC: ~35min)** — Garden trace language — Keep projection but remove completion/reward semantics.
  - Surfaced by: Garden contract — trace and continuity, not achievement economy.
  - Files: `garden_growth_repository.dart`, `garden_growth_combined_screen.dart`, l10n, garden tests.
  - Verify: garden tests + banned-copy scan.

- [ ] **T6 (P1, human: ~3h / CC: ~45min)** — E2E proof — Add onboarding → today → scene → one utterance → reaction → next → garden trace integration test.
  - Surfaced by: test review — new care-path semantics need full-flow proof.
  - Files: `mobile/integration_test/*care_path*`, test harness.
  - Verify: `cd mobile && flutter test integration_test/<new_test>.dart`.

## Review Summary

- Verdict: Engineering direction approved as draft.
- Verdict: Implementation blocked until reaction contract gate is resolved.
- Verdict: No UI implementation approved by this document.
- Step 0: scope accepted as facade migration, not rewrite.
- Architecture Review: 1 critical gap, reaction enum/backend compatibility.
- Code Quality Review: main risk is old `Practice` naming leaking into user-facing code; solve with care_path facade and copy firewall.
- Test Review: diagram produced, 15 gaps identified for new semantics.
- Performance Review: no new infra; add one benchmark and avoid eager Garden init.
- NOT in scope: written.
- What already exists: written.
- TODO updates: not written to `TODOS.md`; implementation tasks above are specific enough for the next planning pass.
- Failure modes: 8 listed, 1 critical gap.
- Outside voice: skipped because subagent spawning is not authorized unless explicitly requested.
- Parallelization: 6 lanes, 3 can start in parallel.
