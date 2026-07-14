# T2 Care Path Facade Implementation Plan

Date: 2026-06-30
Status: Draft for user review
Branch: `gsd/v0.1-milestone`
Base commit: `a98a5a48`
Scope: planning only. No code implementation, no commit.

## Prerequisite State

- T0 Reaction Contract ADR is complete: `docs/adr/ADR-0001-reaction-contract-clean-cutover.md`.
- T1 Reaction clean cutover is complete and committed.
- Backend verification fix is complete and committed at `a98a5a482c72c33f1ef47d0fdc196b18202721fa`.
- App API focused tests passed: 27 tests, 0 failures, 0 errors.
- Admin API `AdminUsersWebTest` passed: 3 tests, 0 failures, 0 errors.
- Worktree was clean at plan start.
- `mobile_v2` is no longer the product implementation mainline. It remains architecture/reference context only.

## T2 Scope Challenge

T2 should build a semantic facade, not a new product stack.

The approved care-path docs say the product model is:

```text
Onboarding first usable phrase
  -> Today care path
  -> Scene one utterance
  -> Baby reaction
  -> Next parent support
  -> Garden trace
```

The existing `mobile/` code already owns the mechanics underneath that loop:

```text
PracticeRepository          -> seed catalog, activity snapshots, local event append
PracticeContinuityNotifier  -> current/recommended activity
PracticeSessionNotifier     -> utterance/audio/reaction save mechanics
GardenGrowthRepository      -> local event -> garden projection
OnboardingRepository        -> starter IDs and first-value setup
```

The minimum complete T2 is therefore:

1. Add `features/care_path` domain vocabulary.
2. Add one repository facade that composes existing Practice/Garden/Onboarding assets.
3. Add one notifier/view-model surface that exposes a single care turn.
4. Wire providers for composition tests only.
5. Add focused tests and copy-firewall impact checks.

This intentionally avoids Today, Scene, and One-utterance UI implementation. It also avoids modifying shell tabs, existing screen layout, backend, `mobile_v2`, or the reaction contract.

### Complexity Check

The named domain boundary has five model concepts:

```text
CareMoment
CareUtterance
CareTurnSnapshot
CarePathNodeState
CareTurnPhase
```

That exceeds the usual "more than 2 new classes/services" smell. Here it is acceptable only because these are pure vocabulary types in one domain file, not new storage engines, services, screens, or parallel projections.

Risk control:

- Put the five concepts in one small domain model file.
- Add exactly one repository facade.
- Add exactly one notifier.
- Do not add a new reaction enum. Reuse the T1 `BabyReactionType` contract from `interaction_event_payload.dart`.
- Do not add new persistence. Read existing local event storage through `PracticeRepository`.

## Existing Assets Reuse Map

| T2 need | Existing asset | Reuse decision |
| --- | --- | --- |
| Current care node | `PracticeRepository.getContinuitySnapshot()` and `PracticeContinuitySnapshot.recommendedActivity` | Reuse as the source for current node selection. |
| Catalog and scene metadata | `PracticeRepository.getActivityCatalog()` and `PracticeActivityCatalog` | Reuse for available moments and nearby nodes. |
| Current utterance | `PracticeRepository.getActivitySnapshot()` + `PracticeResumeInfo.nextPhraseId` | Reuse to locate the current phrase. |
| Reaction contract | `BabyReactionType` in `interaction_event_payload.dart` | Reuse. Do not create `CareReactionType`. |
| Local trace write | `PracticeRepository.recordReaction()` | Reuse for `completeTurn` or `recordReaction`. |
| Local event history | `PracticeRepository.listEventHistory()` / `inspectEventLog()` | Reuse for characterization and trace-aware state. |
| Garden projection | `GardenGrowthRepository.buildSnapshot()` and `GardenGrowthSnapshot.latestImpact` | Reuse as optional trace context. Do not create Garden storage. |
| Onboarding starter | `OnboardingRepository` and boot `defaultPracticeRouteArgs` | Reuse starter IDs indirectly through existing app composition. |
| App provider graph | `mobile/lib/app/providers/repository_providers.dart` | Add care-path providers here using existing provider patterns. |
| App composition tests | `mobile/test/app/app_composition_characterization_test.dart` | Extend to prove provider wiring does not break overrides. |
| Copy guard precedent | `tool/verify_mobile_v2_semantic_firewall.dart` and mobile tests around semantic/firewall tools | Add a mobile care-path scan instead of touching `mobile_v2`. |

### Current Verified Code Anchors

- `PracticeRepository.getActivityCatalog()` builds activity summaries from seed content and local event entities.
- `PracticeRepository.getContinuitySnapshot()` selects recent, starter, next incomplete, or safe catalog fallback activity.
- `PracticeRepository.recordReaction()` validates phrase existence and appends an `InteractionEventPayload`.
- `BabyReactionType` now has the approved five values: `cooperating`, `hesitant`, `resisting`, `noResponse`, `other`.
- `GardenGrowthRepository.buildSnapshot()` already projects valid local events into patch, flower, diary, milestone, latest-impact, and warning data.
- `GardenGrowthNotifier` already shows the preferred ChangeNotifier pattern: load status, timeout, refresh coalescing, safe dispose.
- `BabyTalkApp._buildRiverpodOverrides()` already overrides continuity and garden notifiers during app boot.

## Proposed `features/care_path` Architecture

```text
mobile/lib/features/care_path/
  domain/
    models/care_path_models.dart
  data/
    repositories/care_path_repository.dart
  presentation/
    care_path_notifier.dart
    care_path_view_model.dart
```

Provider wiring lives with the existing app providers:

```text
mobile/lib/app/providers/repository_providers.dart
  carePathRepositoryProvider
  carePathNotifierProvider
```

No screen file is added in T2.

### Dependency Direction

```text
care_path/presentation
  depends on care_path/data + care_path/domain

care_path/data
  depends on existing practice repository
  optionally depends on existing garden repository

practice/garden/onboarding
  do not depend on care_path
```

```text
                       +-----------------------------+
                       | care_path presentation      |
                       | CarePathNotifier/ViewModel  |
                       +--------------+--------------+
                                      |
                                      v
                       +-----------------------------+
                       | care_path data facade       |
                       | CarePathRepository          |
                       +------+----------------------+
                              |
          +-------------------+--------------------+
          |                   |                    |
          v                   v                    v
+------------------+ +--------------------+ +----------------------+
| Practice catalog | | Practice local log | | Garden projection    |
| continuity       | | recordReaction     | | latestImpact/context |
+------------------+ +--------------------+ +----------------------+
```

### Domain Boundary

`CareMoment`

- Product-facing wrapper around a `PracticeCatalogActivitySummary`.
- Carries `spaceId`, `activityId`, `spaceTitle`, `title`, `sceneTag`, `careActionLabel`, `coachTip`, and node state.
- Does not expose `completedPhraseIds` as user-facing progress.

`CareUtterance`

- Product-facing wrapper around `PracticePhrase`.
- Carries `phraseId`, `english`, `chinese`, `pronunciation`, `audioAsset`, `whenToSay`, and `isFallback`.
- `whenToSay` can start as `PracticeActivitySnapshot.coachTip` or a simple derived label. Do not invent a new content service in T2.

`CareTurnSnapshot`

- One-turn state for current moment and utterance.
- Carries `moment`, `currentUtterance`, optional selected `BabyReactionType`, optional `nextSupportUtterance`, `phase`, optional `traceEventKey`, optional `latestGardenImpact`, and optional user-safe message.
- Keeps storage details out of UI consumers.

`CarePathNodeState`

Suggested values:

```text
current
nearby
doneToday
unavailable
```

T2 should only derive `current`, `nearby`, and `unavailable`. `doneToday` can exist for future UI semantics but should be tested as a pure value, not wired into shell visuals.

`CareTurnPhase`

Suggested values:

```text
idle
loading
utteranceReady
reactionPrompt
savingTrace
nextSupportReady
heldWithFallback
error
```

This mirrors current notifier status discipline without copying `PracticeSessionNotifier`'s session/progress semantics.

### Facade API Shape

Proposed repository methods:

```text
Future<CareTurnSnapshot> loadCurrentTurn({
  String? starterSpaceId,
  String? starterActivityId,
})

Future<CareTurnSnapshot> startMoment({
  required String spaceId,
  required String activityId,
})

Future<CareTurnSnapshot> recordReaction({
  required CareTurnSnapshot snapshot,
  required BabyReactionType reactionType,
})
```

Important constraints:

- `recordReaction` persists through `PracticeRepository.recordReaction()`.
- The next support utterance is derived locally in T2 from the same activity snapshot and reaction context.
- If no better phrase can be derived, keep the current utterance and phase `heldWithFallback`.
- No backend call is introduced in T2.
- No `mobile_v2` engine import is introduced.

### Notifier API Shape

Proposed notifier methods:

```text
Future<void> initialize()
Future<void> refreshCurrent()
Future<void> startMoment({required String spaceId, required String activityId})
void markSaid()
Future<void> selectReaction(BabyReactionType reactionType)
void resetToSafeEmpty()
```

State exposed:

```text
CarePathViewModel viewModel
CareTurnPhase phase
CareTurnSnapshot? snapshot
bool isBusy
String? message
```

`markSaid()` moves from `utteranceReady` to `reactionPrompt` only. It does not persist an event by itself.

`selectReaction()` persists the local event, refreshes derived snapshot state, and exposes a next support utterance or fallback.

## Data Flow

### Load Current Turn

```text
CarePathNotifier.initialize()
  -> CarePathRepository.loadCurrentTurn()
      -> PracticeRepository.getContinuitySnapshot()
      -> PracticeRepository.getActivitySnapshot(recommended space/activity)
      -> choose current phrase from nextPhraseId or first phrase
      -> optional GardenGrowthRepository.buildSnapshot()
      -> CareTurnSnapshot(phase: utteranceReady)
```

### Start Specific Moment

```text
startMoment(spaceId, activityId)
  -> PracticeRepository.getActivitySnapshot(spaceId, activityId)
  -> PracticeRepository.getResumeInfo(spaceId, activityId)
  -> choose next phrase
  -> CareTurnSnapshot(phase: utteranceReady)
```

### Complete One Turn

```text
markSaid()
  -> phase = reactionPrompt

selectReaction(reactionType)
  -> phase = savingTrace
  -> PracticeRepository.recordReaction(space/activity/phrase/reaction)
  -> reload activity snapshot + resume info
  -> derive next support from reaction + available phrases
  -> optional GardenGrowthRepository.buildSnapshot()
  -> phase = nextSupportReady or heldWithFallback
```

## File-Level Implementation Plan

### 1. Domain Models

Create:

- `mobile/lib/features/care_path/domain/models/care_path_models.dart`
- generated file if Freezed is used:
  - `mobile/lib/generated/features/care_path/domain/models/care_path_models.freezed.dart`

Recommendation: use Freezed only if the existing mobile generated-code workflow is already expected in this slice. If generation friction is high, start with immutable plain Dart classes and add equality manually where tests need it. The implementation should not spend T2 on generator churn unless local conventions require it.

Required content:

- `CareMoment`
- `CareUtterance`
- `CareTurnSnapshot`
- `CarePathNodeState`
- `CareTurnPhase`

Do not add:

- `CareReactionType`
- persistence entities
- JSON DTOs
- API request/response models

### 2. Repository Facade

Create:

- `mobile/lib/features/care_path/data/repositories/care_path_repository.dart`

Dependencies:

- required `PracticeRepository`
- optional `GardenGrowthRepository`

Responsibilities:

- Compose continuity and catalog into the current `CareMoment`.
- Load `CareUtterance` from existing `PracticeActivitySnapshot`.
- Call `PracticeRepository.recordReaction()` for local trace persistence.
- Read optional `GardenGrowthSnapshot.latestImpact` after a write.
- Convert recoverable failures into explicit `CareTurnSnapshot` messages, not thrown UI surprises where possible.

Do not:

- Call backend APIs.
- Create new Isar collections.
- Reinterpret old reaction values.
- Query `mobile_v2`.

### 3. Presentation Notifier and View Model

Create:

- `mobile/lib/features/care_path/presentation/care_path_notifier.dart`
- `mobile/lib/features/care_path/presentation/care_path_view_model.dart`

Pattern to follow:

- `GardenGrowthNotifier` for load status, timeout, queued refresh, safe dispose.
- `PracticeContinuityNotifier` for continuity-aware refresh and starter args.

Responsibilities:

- `startMoment`
- load current utterance
- expose one-turn state
- handle `markSaid`
- handle `selectReaction`
- expose stable view-model fields for future UI

Do not:

- import Flutter widgets.
- implement Today/Scene/One-utterance screen UI.
- modify existing `HomeScreen`, `DiscoverScreen`, or `PracticeSessionScreen`.

### 4. Provider Composition

Modify:

- `mobile/lib/app/providers/repository_providers.dart`

Add:

- `carePathRepositoryProvider`
- `carePathNotifierProvider`

Provider notes:

- `carePathRepositoryProvider` should depend on `practiceRepositoryProvider` and `gardenGrowthRepositoryProvider`.
- Use explicit Riverpod dependencies if nested overrides require them. Prior project learning: providers that watch overridden dependencies can trip debug assertions without declared dependencies.
- Avoid touching `BabyTalkApp._buildRiverpodOverrides()` unless composition tests prove it is needed.

### 5. Test Files

Create:

- `mobile/test/features/care_path/domain/care_path_models_test.dart`
- `mobile/test/features/care_path/data/care_path_repository_test.dart`
- `mobile/test/features/care_path/presentation/care_path_notifier_test.dart`

Modify:

- `mobile/test/app/app_composition_characterization_test.dart`

Optional tool/test addition:

- `mobile/test/tool/verify_care_path_copy_firewall_test.dart`
- or extend an existing source-scan test if one already owns mobile copy audits.

Do not modify:

- `mobile_v2/**`
- backend tests
- shell visual tests unless provider composition requires a nonvisual expectation update

## Test Plan

### Test Diagram

```text
CODE PATHS                                           USER-FACING FUTURE FLOW
[+] care_path domain models                          [+] Today current node, future UI
  |-- [GAP] CareMoment maps activity summary            |-- [GAP] current node has one primary moment
  |-- [GAP] CareUtterance maps practice phrase          |-- [GAP] no Practice/progress wording leaks
  |-- [GAP] CareTurnPhase legal transitions
  |-- [GAP] CarePathNodeState current/nearby/unavailable

[+] CarePathRepository facade                       [+] Scene one-turn entry, future UI
  |-- [GAP] continuity -> recommended current turn      |-- [GAP] selected scene loads one utterance
  |-- [GAP] starter fallback -> current turn            |-- [GAP] missing scene returns gentle fallback
  |-- [GAP] empty catalog error is explicit
  |-- [GAP] missing phrase produces held fallback
  |-- [GAP] recordReaction writes local event
  |-- [GAP] recordReaction refreshes next support
  |-- [GAP] garden latestImpact attaches when available

[+] CarePathNotifier                                [+] One utterance loop, future UI
  |-- [GAP] initialize idempotent loading                |-- [GAP] markSaid opens reaction prompt
  |-- [GAP] startMoment replaces current snapshot        |-- [GAP] selectReaction exposes next support
  |-- [GAP] concurrent start/select is ignored/queued    |-- [GAP] save failure keeps current utterance
  |-- [GAP] resetToSafeEmpty clears state

[+] App provider composition                         [+] App boot, current runtime
  |-- [GAP] carePath providers resolve with existing overrides
  |-- [GAP] nested ProviderScope override stays valid
  |-- [GAP] no mobile_v2 provider import

[+] Copy firewall                                   [+] Product semantics
  |-- [GAP] care_path source has no Ritual Room terms
  |-- [GAP] care_path user-facing constants avoid course/progress pressure
  |-- [GAP] existing mobile_v2 firewall remains untouched

COVERAGE TARGET: all T2 code paths covered by unit/state/composition tests.
E2E: not required in T2 because no real UI screen is implemented.
```

### Domain Model Tests

File:

- `mobile/test/features/care_path/domain/care_path_models_test.dart`

Cases:

- `CareMoment` exposes care-path fields without requiring completion/progress terminology.
- `CareUtterance` keeps English, Chinese, pronunciation, audio, and fallback flag stable.
- `CareTurnSnapshot` supports `copyWith` or equivalent immutable updates across phases.
- `CareTurnPhase` includes the expected one-turn states.
- `CarePathNodeState` includes current/nearby/doneToday/unavailable without deriving UI behavior.

### Repository Facade Tests

File:

- `mobile/test/features/care_path/data/care_path_repository_test.dart`

Use fake or existing characterization harness patterns from `practice_repository_characterization_harness.dart`.

Cases:

- Loads current turn from `getContinuitySnapshot()` recommended activity.
- Falls back to starter or first available activity when no recent event exists.
- Uses `PracticeResumeInfo.nextPhraseId` when present.
- Uses first phrase when resume has no next phrase.
- Returns explicit error/fallback when catalog is empty.
- Returns explicit error/fallback when selected activity has no phrases.
- `recordReaction` writes through `PracticeRepository.recordReaction()` with T1 canonical values.
- `recordReaction` does not map invalid values to `other`.
- `recordReaction` attaches refreshed Garden latest impact when `GardenGrowthRepository` is available.
- `recordReaction` still returns a usable snapshot if Garden projection fails.

### Notifier State Tests

File:

- `mobile/test/features/care_path/presentation/care_path_notifier_test.dart`

Cases:

- `initialize()` transitions `idle -> loading -> utteranceReady`.
- repeated `initialize()` is idempotent while loading.
- `startMoment()` swaps snapshot and clears stale messages.
- `markSaid()` moves only to `reactionPrompt` and does not persist.
- `selectReaction(BabyReactionType.cooperating)` moves through `savingTrace` to `nextSupportReady`.
- concurrent `selectReaction()` while saving does not double-write.
- repository failure moves to `error` or `heldWithFallback` while preserving current utterance.
- `resetToSafeEmpty()` clears snapshot, timers/futures, message, and busy state.
- `dispose()` suppresses late notifications.

### App Composition Characterization Tests

Modify:

- `mobile/test/app/app_composition_characterization_test.dart`

Cases:

- `carePathRepositoryProvider` resolves when `practiceRepositoryProvider` is overridden.
- `carePathNotifierProvider` resolves without forcing a UI screen.
- provider dependency declarations are compatible with nested `ProviderScope` overrides.
- adding care-path providers does not break existing practice, continuity, or garden provider overrides.

### Copy Firewall Impact Assessment

T2 adds new product-facing vocabulary under `features/care_path`. Even without UI screens, the plan should prevent the facade from importing deprecated product semantics.

Add a focused scan that fails if new `features/care_path` files include:

```text
Ritual Room
ritual_room
mobile_v2
XP
金币
排行榜
课程
第 1 课
答对
答错
正确率
```

Allowed internal words in T2:

```text
PracticeRepository
PracticeActivityCatalog
PracticeContinuitySnapshot
GardenGrowthRepository
InteractionEventPayload
BabyReactionType
```

Reason: internal reuse is intentional; user-facing course, reward, Ritual Room, and `mobile_v2` product truth are not.

### Verification Commands

Use Windows PowerShell form already approved in this repo style:

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub `
    test/features/care_path/domain/care_path_models_test.dart `
    test/features/care_path/data/care_path_repository_test.dart `
    test/features/care_path/presentation/care_path_notifier_test.dart `
    test/app/app_composition_characterization_test.dart
} finally {
  Pop-Location
}
```

If a copy firewall tool test is added:

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub `
    test/tool/verify_care_path_copy_firewall_test.dart
} finally {
  Pop-Location
}
```

No backend test is required for T2 unless implementation accidentally touches backend, which is out of scope.

## Failure Modes

| Codepath | Failure mode | User/product impact | Test coverage required | Handling |
| --- | --- | --- | --- | --- |
| current turn load | continuity snapshot throws because catalog is empty | future Today surface has no current node | repository empty-catalog test | return explicit unavailable snapshot/message |
| current turn load | recommended activity no longer exists in seed content | future Today CTA points to dead scene | repository missing-activity test | fall back to first catalog activity with gentle message |
| utterance selection | `nextPhraseId` is null or unknown | future one-utterance UI shows blank phrase | repository phrase fallback test | use first uncompleted or first phrase |
| utterance selection | activity has zero phrases | future scene entry dead-ends | repository empty-phrases test | `CareTurnPhase.heldWithFallback` or `error`, no write |
| reaction save | double tap writes duplicate local events | Garden trace and sync queue duplicate the moment | notifier concurrent-save test | ignore or coalesce while `savingTrace` |
| reaction save | `PracticeRepository.recordReaction()` throws unknown phrase | user loses current context after saying it | repository/notifier save-failure tests | preserve current utterance and show recoverable message |
| garden attach | Garden projection fails after successful local write | trace context missing though event is saved | repository garden-failure test | return saved event with message, no rollback |
| provider composition | nested overrides fail due missing dependencies | debug red screen in tests/app boot | app composition test | declare provider dependencies explicitly |
| copy firewall | care-path facade imports `mobile_v2` or Ritual Room terms | product mainline drifts back to superseded direction | copy firewall scan | fail test, remove import/copy |
| semantic boundary | T2 creates `CareReactionType` parallel to `BabyReactionType` | reaction contract splits after T1 | domain/API review + tests | reuse `BabyReactionType` only |

Critical gap to avoid: a second reaction enum. T1 already made `BabyReactionType` the mobile five-value contract. T2 must not create another reaction authority.

## What Is Explicitly Not In Scope

- Today UI implementation.
- Scene UI implementation.
- One-utterance screen implementation.
- Shell tab label or route changes.
- `HomeScreen`, `DiscoverScreen`, or `PracticeSessionScreen` visual/layout changes.
- `mobile_v2` edits.
- backend edits.
- reaction contract semantic changes.
- Ritual Room implementation or visual polish.
- Garden/Growth visual refactor.
- new local storage, new Isar collections, or parallel event tables.
- backend API calls for next support utterance.
- E2E/golden screenshots for screens that T2 does not build.
- committing the plan or implementation.

## Worktree Parallelization / Sequencing

T2 is small enough to implement sequentially in one worktree. Parallelization is possible but not necessary.

### Dependency Table

| Step | Modules touched | Depends on |
| --- | --- | --- |
| Domain models | `mobile/lib/features/care_path/domain`, `mobile/test/features/care_path/domain` | none |
| Repository facade | `mobile/lib/features/care_path/data`, `mobile/test/features/care_path/data` | domain models |
| Notifier/view-model | `mobile/lib/features/care_path/presentation`, `mobile/test/features/care_path/presentation` | domain + repository facade |
| Provider composition | `mobile/lib/app/providers`, `mobile/test/app` | repository + notifier |
| Copy firewall | `mobile/test/tool` or equivalent tool tests | domain/repository paths known |
| Verification | all touched mobile test modules | all implementation steps |

### Parallel Lanes

Recommended: sequential implementation.

If split across worktrees:

```text
Lane A: domain models -> repository facade
Lane B: copy firewall scan test

After A:
Lane C: notifier/view-model -> provider composition

Final:
Lane D: focused verification
```

Conflict flags:

- Lane A and C both touch `features/care_path`; keep C after A.
- Provider composition touches `repository_providers.dart`, which is a shared app file. Avoid parallel edits there.
- Copy firewall can run in parallel because it only touches tool tests.

## Implementation Tasks

- [ ] **T2.1 (P1, human: ~45min / CC: ~15min)** - care_path domain - Add the five facade vocabulary types in one domain model file.
  - Surfaced by: scope challenge; product semantics need a boundary without new storage.
  - Files: `mobile/lib/features/care_path/domain/models/care_path_models.dart`, `mobile/test/features/care_path/domain/care_path_models_test.dart`.
  - Verify: domain model tests.

- [ ] **T2.2 (P1, human: ~90min / CC: ~25min)** - care_path data - Add repository facade over Practice/Garden assets.
  - Surfaced by: architecture reuse map; avoid parallel Practice/Garden storage.
  - Files: `mobile/lib/features/care_path/data/repositories/care_path_repository.dart`, `mobile/test/features/care_path/data/care_path_repository_test.dart`.
  - Verify: repository facade tests.

- [ ] **T2.3 (P1, human: ~90min / CC: ~25min)** - care_path presentation - Add notifier and view-model for one-turn state.
  - Surfaced by: T2 target; expose `startMoment`, current utterance load, and one-turn state without UI.
  - Files: `mobile/lib/features/care_path/presentation/care_path_notifier.dart`, `mobile/lib/features/care_path/presentation/care_path_view_model.dart`, `mobile/test/features/care_path/presentation/care_path_notifier_test.dart`.
  - Verify: notifier state tests.

- [ ] **T2.4 (P1, human: ~45min / CC: ~15min)** - app composition - Wire care-path providers into existing Riverpod provider graph.
  - Surfaced by: provider dependency prior learning and app composition risk.
  - Files: `mobile/lib/app/providers/repository_providers.dart`, `mobile/test/app/app_composition_characterization_test.dart`.
  - Verify: app composition characterization tests.

- [ ] **T2.5 (P2, human: ~30min / CC: ~10min)** - copy firewall - Add a focused care-path semantic scan.
  - Surfaced by: design contract copy firewall and mobile_v2 supersession.
  - Files: `mobile/test/tool/verify_care_path_copy_firewall_test.dart` or existing source-scan test.
  - Verify: copy firewall test.

- [ ] **T2.6 (P1, human: ~30min / CC: ~10min)** - verification - Run focused mobile tests and record outputs in the task summary.
  - Surfaced by: plan verification gate.
  - Files: no product files unless verification finds gaps.
  - Verify: all focused commands pass.

## TODOS.md Updates

No `TODOS.md` update is recommended for T2.

Reason: T2 is an already-approved implementation slice with concrete tasks above. The only possible follow-up, "rename internal Practice modules to Care Path", is deliberately not a T2 TODO because it would create broad churn before the facade proves useful.

## Retrospective Learning Applied

Prior learning applied: `riverpod-dependency-override` (confidence 8/10, observed 2026-05-27).

Impact on T2: provider additions must declare dependencies where Riverpod requires them, and `app_composition_characterization_test.dart` must cover nested override behavior. This avoids a debug red screen that looks like an app failure even though the underlying repository works.

## Completion Summary

- Step 0 Scope Challenge: scope accepted only as facade; no UI and no new storage.
- Architecture Review: 1 issue found, controlled by reusing `BabyReactionType` and existing Practice/Garden repositories.
- Code Quality Review: 2 guardrails: one domain file for vocabulary, one repository facade only.
- Test Review: diagram produced, 20 T2-specific gaps identified and converted into tasks.
- Performance Review: 0 issues found; no new heavy runtime path.
- NOT in scope: written.
- What already exists: written.
- TODOS.md updates: 0 proposed.
- Failure modes: 10 listed, 1 critical gap flagged.
- Outside voice: skipped.
- Parallelization: sequential recommended; optional 2-lane split for domain/data and copy firewall.
- Lake Score: 4/4 recommendations choose complete tests and explicit boundaries over shortcuts.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
| --- | --- | --- | --- | --- | --- |
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | clear | Care-path supersession approved; implementation held until eng plan |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run | Skipped; user asked for planning doc only |
| Eng Review | `/plan-eng-review` | Architecture & tests | 1 | draft_clear | 1 scope smell accepted with controls; 1 critical anti-duplication rule: no second reaction enum |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not run | Not applicable to T2 because no UI screen implementation |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | Not applicable |

**UNRESOLVED:** 0

**VERDICT:** ENG PLAN DRAFT CLEAR FOR REVIEW - T2 may proceed after user approval, limited to `mobile/features/care_path` facade, provider composition, focused tests, and copy firewall. No UI, shell, backend, `mobile_v2`, reaction-contract, Ritual Room, or Garden visual work is approved by this plan.
