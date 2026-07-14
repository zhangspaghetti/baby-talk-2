# T4 One-Utterance Loop Implementation Plan

Date: 2026-07-01
Status: Draft for user review
Branch: `gsd/v0.1-milestone`
Base commit: `9fb5ddb966d9aee5a56d96ab38c0d197b852b29e`
Scope: planning only. No code implementation, no commit.

## Prerequisite State

- T0 Reaction Contract ADR is complete.
- T1 Reaction clean cutover is complete.
- Backend verification fix is complete.
- T2 care_path facade is complete and committed: `fa3bbcd4375fb8311e2e29754fd0c00529d8c96c`.
- T3 Today / Scene IA adapter is complete and committed: `9fb5ddb966d9aee5a56d96ab38c0d197b852b29e`.
- Worktree was clean at plan start.
- `mobile_v2` is no longer the product implementation mainline.
- `PracticeSessionScreen` is still the legacy execution path. T4 is the first approved slice that may adjust it.

## T4 Scope Challenge

T4 is the narrow execution-loop cutover. It should not become a screen redesign, Garden redesign, backend slice, or internal rename campaign.

Target user loop:

```text
current utterance
  -> 听一下
  -> 我说了
  -> 宝宝反应
  -> 下一句照护支持
  -> 花园痕迹
```

The existing code already solves most of the mechanics:

```text
PracticeSessionScreen
  - route validation and safe fallback
  - audio injection seam for tests
  - current phrase rendering shell
  - haptics

PracticeSessionNotifier
  - audio controller abstraction
  - old phrase index and completion state machine
  - old local-event write path

carePathNotifierProvider
  - current care moment
  - current utterance
  - reaction save through PracticeRepository.recordReaction()
  - duplicate-write suppression through operation coalescing and phase checks
  - next support utterance
  - latest Garden impact

SceneReactionChipRow
  - canonical five reaction options and user copy

GardenGrowthRepository
  - local event -> latest impact projection
```

Minimum complete T4:

1. Change `PracticeSessionScreen` to render one care turn from `carePathNotifierProvider`.
2. Remove user-visible step/progress/session/completion framing from this screen.
3. Preserve route args, audio playback, `我说了`, reaction capture, local event write, and Garden trace mechanics.
4. Add a real `utteranceReady -> reactionPrompt -> savingTrace -> nextSupportReady/heldWithFallback` care-path flow.
5. Keep fallback gentle when there is no next utterance.
6. Add focused widget/state/copy-firewall tests.

Complexity check:

- Expected production files: 5 to 7 if l10n generated files are counted.
- Expected test files: 3 to 5.
- New public classes/services: 0 preferred. A private screen widget or private audio-state enum is acceptable.
- If implementation needs more than 8 production files, stop and re-scope before coding.

Search check:

- No new SDK, external library, routing framework, concurrency primitive, storage engine, or backend API is introduced.
- This is [Layer 1]: reuse Flutter/Riverpod/provider patterns already in the repo.

TODOS cross-reference:

- `TODOS.md` has broad historical backlog and old product items, but no item blocks T4.
- Do not bundle older Garden, analytics, dark mode, ASR, or backend safety TODOs into this slice.

Completeness check:

- The complete version for T4 is not "just hide the progress bar." It must also prevent duplicate writes, verify canonical reaction values, prove exit has no completion summary, and add a targeted copy firewall.
- The shortcut of bridging both notifiers saves little implementation time and preserves the two-state-machine problem. Do not take it.

Distribution check:

- No new artifact type is introduced. No build or publish pipeline change is needed.

## Existing PracticeSession Assets Reuse Map

| T4 need | Existing asset | Current state | T4 reuse decision |
| --- | --- | --- | --- |
| Route entry | `PracticeRouteArgs`, `PracticeRouteEntry`, `PracticeRouteArgs.push()` | Home/Scene already pass `spaceId/activityId` into the practice route | Reuse unchanged. T4 changes destination behavior only. |
| Safe fallback | `PracticeFallbackScaffold` in `practice_session_screen.dart` | Handles invalid route and repository error | Reuse, but migrate visible copy away from `练习` where it appears on this screen. |
| Current care state | `carePathNotifierProvider` | Exposes `CarePathViewModel`, `moment`, `currentUtterance`, `nextSupportUtterance`, `latestGardenImpact` | Use directly as the screen source of truth. |
| Current utterance selection | `CarePathRepository.startMoment()` | Loads requested activity from catalog and resume info | Reuse. Screen should call `startMoment(routeArgs.spaceId, routeArgs.activityId)` on entry. |
| Local event write | `CarePathRepository.recordReaction()` | Calls `PracticeRepository.recordReaction()` and attaches `traceEventKey` | Reuse. Do not call `PracticeRepository.recordReaction()` directly from the screen. |
| Duplicate-save guard | `CarePathNotifier._operationFuture`, `canSelectReaction`, phase checks | Already blocks second write after one reaction | Reuse and strengthen with widget test double tap. |
| Reaction options | `SceneReactionChipRow.sceneReactionOptions()` | Already has `配合 / 犹豫 / 不想 / 没反应 / 其他` backed by `BabyReactionType` | Reuse. Do not add `CareReactionType`. |
| Audio playback | `PracticeAudioController`, `AudioplayersPracticeAudioController` | Lives at top of `practice_session_notifier.dart` and is test-injectable through `PracticeSessionScreen.audioControllerFactory` | Reuse the abstraction. Prefer extracting only the audio abstraction to a small shared file if implementation wants to remove the notifier import. Do not reuse the old notifier state machine. |
| Phrase display | `PhraseCard` | Renders `第 N 句`, status pills, `PracticePhrase`, `PracticeSaveStatus`, and reaction chips | Do not reuse as-is. It leaks step/status framing and known stacking tests should not block T4. Reuse lower-level visual pieces instead. |
| Bottom actions | `PracticeBottomActionBar` | Shows `说完了`, `换一句`, `结束`, `跳过，下一句`, completion-oriented states | Do not reuse as-is. T4 needs only `听一下`, `我说了`, reaction prompt, optional exit. |
| Completion summary | `PracticeCompletionView` | Shows `今天完成了` and spoken-count summary | Remove from `PracticeSessionScreen` path. Keep file untouched unless dead-code cleanup is requested later. |
| Garden trace | `GardenGrowthRepository.buildSnapshot()` via T2 facade | Produces `LatestPracticeImpact` | Show a small textual trace from `latestGardenImpact`. Do not change Garden/Growth visuals. |

## Proposed One-Utterance Loop Architecture

Use `PracticeSessionScreen` as a thin care-turn screen over `carePathNotifierProvider`.

```text
Practice route
  -> PracticeRouteEntry.fromObject(extra)
  -> PracticeSessionScreen
      -> carePathNotifierProvider.startMoment(routeArgs.spaceId, routeArgs.activityId)
      -> CarePathViewModel
      -> one-turn UI
```

State flow:

```text
CarePathRepository.startMoment()
  -> CareTurnSnapshot(
       currentUtterance: phrase from nextPhraseId or fallback phrase,
       phase: utteranceReady
     )

User taps 听一下
  -> local playback state only
  -> no event write
  -> no care-path state mutation

User taps 我说了
  -> CarePathNotifier.markSaid()
  -> phase: reactionPrompt
  -> reaction chips become visible

User selects reaction
  -> CarePathNotifier.selectReaction(BabyReactionType)
  -> phase: savingTrace
  -> CarePathRepository.recordReaction()
      -> PracticeRepository.recordReaction()
      -> CarePathRepository.startMoment(same moment) for next support
      -> GardenGrowthRepository.buildSnapshot() for latest impact
  -> phase: nextSupportReady if next support exists
  -> phase: heldWithFallback if no next support exists
```

Screen composition:

```text
Scaffold
  AppBar: quiet current scene title, no session title
  Body:
    current care moment label
    current utterance card
      English phrase
      Chinese / pronunciation
      when-to-say copy
      听一下
      我说了
    reaction prompt
      SceneReactionChipRow
    next support panel
      下一句可以这样说
      next support English/Chinese/pronunciation
      gentle fallback if absent
    Garden trace strip
      latestImpact.headline/detail or trace saved note
```

Key rule:

```text
T4 may show next support, but it must not show lesson progress, 1 of N, XP, streak,
task completion, activity completion, or a session summary.
```

## Decision: Use carePathNotifier Directly

Recommendation: use `carePathNotifierProvider` directly in `PracticeSessionScreen`. Do not wrap or bridge the existing `PracticeSessionNotifier`.

Why:

1. `PracticeSessionNotifier` is a session/index state machine. It advances by phrase index, sets `sessionCompleted`, drives `PracticeCompletionView`, and owns skip/end mechanics.
2. T4 must remove user-visible step/progress/session framing, so bridging the old notifier keeps the wrong source of truth alive.
3. `CarePathNotifier` already owns the T4 contract: current utterance, reaction save, duplicate-write guard, next support, fallback state, and Garden impact.
4. A bridge creates two valid-looking states for the same user action:

```text
old notifier: phrasePhase saved/advancing/complete + currentPhraseIndex
care notifier: reactionPrompt/savingTrace/nextSupportReady + currentUtterance
```

That is exactly the conflict T4 is supposed to eliminate.

Allowed reuse from `PracticeSessionNotifier`:

- audio abstraction and playback controller
- status copy only if extracted into a neutral audio helper
- existing tests as characterization of what gets removed

Disallowed reuse from `PracticeSessionNotifier`:

- `currentPhraseIndex`
- `sessionCompleted`
- `saveCurrentPhrase()`
- `skipCurrentPhrase()`
- `skipToNextPhrase()`
- `endSession()`
- dynamic practice event-skip behavior
- completion summary behavior

Small care-path facade adjustment required:

- `CarePathRepository._buildTurnSnapshot()` should return `CareTurnPhase.utteranceReady` when it has a current utterance.
- `CarePathNotifier` should add `markSaid()`:

```text
if current utterance exists and phase == utteranceReady:
  phase = reactionPrompt
else:
  keep current snapshot and expose a gentle message
```

This uses an existing enum value and prevents the screen from faking core state locally.

## File-Level Implementation Plan

### 1. Care-path state transition

Files:

- `mobile/lib/features/care_path/data/repositories/care_path_repository.dart`
- `mobile/lib/features/care_path/presentation/care_path_notifier.dart`
- `mobile/lib/features/care_path/presentation/care_path_view_model.dart`
- `mobile/test/features/care_path/data/care_path_repository_test.dart`
- `mobile/test/features/care_path/presentation/care_path_notifier_test.dart`

Plan:

1. Change loaded/start snapshots with a current utterance from `reactionPrompt` to `utteranceReady`.
2. Keep `CarePathViewModel.canSelectReaction` false until phase is `reactionPrompt`.
3. Add `CarePathNotifier.markSaid()` and tests.
4. Keep `selectReaction()` unchanged in shape, but verify it only writes in `reactionPrompt`.
5. Adjust `CarePathRepository.recordReaction()` fallback:
   - if the write succeeds but no next support exists, keep the current utterance, keep `traceEventKey`, attach `latestGardenImpact`, set `phase: heldWithFallback`, and show gentle copy.
   - do not mark activity/session complete.
6. Keep duplicate write protection through existing `_operationFuture` and phase guard.

### 2. PracticeSessionScreen care-turn rewrite

Files:

- `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart`
- maybe `mobile/lib/features/practice/presentation/practice_audio_controller.dart` if extracting audio types
- `mobile/test/features/practice/critical_ui_coverage_test.dart`

Plan:

1. Keep `PracticeSessionScreen` constructor and `audioControllerFactory`.
2. Keep `PracticeRouteEntry` validation.
3. Replace `practiceSessionNotifierProvider(widget.providerArgs)` watch/read with `carePathNotifierProvider`.
4. In `initState` or a post-frame callback, call:

```text
carePathNotifier.startMoment(
  spaceId: routeArgs.spaceId,
  activityId: routeArgs.activityId,
)
```

Lifecycle guardrails:

- `carePathNotifier.startMoment(...)` may only be triggered from `initState`, a post-frame init scheduled from `initState`, or `didUpdateWidget` when normalized route args change.
- It must never be triggered from `build`.
- The route must either call `resetToSafeEmpty()` on dispose or prove that provider lifetime/keying prevents state from leaking into the next route entry.
- Tests must cover repeated pumps and route-args changes:
  - repeated pump does not call `startMoment` again.
  - route args changing from one activity to another starts the new moment exactly once.
  - route dispose/reset does not let a prior turn overwrite the next entry.

5. Reset local audio state when the current utterance phrase ID changes.
6. Remove:
   - `session-progress`
   - `practice-progress-text`
   - `practiceProgress(...)` semantics
   - `PracticeCompletionView`
   - `PracticeBottomActionBar`
   - skip/end/session controls
7. Render current utterance from `CareUtterance`, not `PracticePhrase`.
8. Add visible controls:
   - `听一下`: audio playback or TTS fallback if no asset
   - `我说了`: calls `carePathNotifier.markSaid()`
9. Render reaction prompt only when phase is `reactionPrompt` or `savingTrace`.
10. Render selected reaction after save using the canonical label.
11. Render next support when `viewModel.nextSupportUtterance != null`.
12. Render fallback copy when phase is `heldWithFallback` and next support is null.
13. Render Garden trace from `viewModel.latestGardenImpact`.
14. Exit behavior: app bar back or a quiet text button may pop the route, but it must not set a completion phase or show completion summary.

Audio abstraction and fallback guardrails:

- If `CareUtterance.audioAsset` is present, use the existing `PracticeAudioController` abstraction.
- Do not re-depend on the `PracticeSessionNotifier` state machine just to reuse audio.
- If `PracticeAudioController` can only be imported from `practice_session_notifier.dart` at implementation time, either extract it to a neutral helper file or keep the smallest import possible. In both cases, do not read or call old notifier session/progress state.
- T4 must not restore or depend on `currentPhraseIndex`, `sessionCompleted`, `skipCurrentPhrase`, `skipToNextPhrase`, `endSession`, `PhraseInteractionPhase.complete`, or `PracticeCompletionView`.
- If `CareUtterance.audioAsset` is absent, default behavior is: keep the text visible and make `听一下` show a quiet unavailable/retryable message.
- Use the existing `FlutterTtsMentorAudioController` only if it requires no mentor flow, no dynamic practice generation, and no new dependency.
- Do not expand audio fallback into a major T4 workstream.
- Keep playback failures local to the screen with a retryable message. Do not block reaction recording.

### 3. Widget extraction only if it keeps the diff smaller

Preferred:

- private `_CareTurnCard`, `_NextSupportPanel`, `_GardenTraceStrip`, and `_CareTurnActionRow` inside `practice_session_screen.dart`.

Optional if the file becomes hard to test:

- `mobile/lib/features/practice/presentation/widgets/care_turn_card.dart`
- `mobile/test/features/practice/widgets/care_turn_card_test.dart`

Do not extract a new product screen or create `TodayScreen` / `SceneScreen`.

### 4. Copy and localization

Files:

- `mobile/lib/l10n/app_zh.arb`
- `mobile/lib/l10n/app_localizations.dart`
- `mobile/lib/l10n/app_localizations_zh.dart`
- `mobile/test/tool/verify_t4_one_utterance_copy_firewall_test.dart`

Plan:

1. Add T4-specific keys for the one-turn surface.
2. Update `practiceInvalidParams`, `practiceUnavailable`, and `practiceBackHome` only if visible on this route and still using `练习`.
3. Do not rewrite Home/Scene/Garden/Growth l10n unless a T4 test covers that visible surface.
4. Generated localization Dart must stay in sync with ARB.
5. Add a targeted copy firewall for this screen and relevant l10n keys.

### 5. Tests and verification

Files:

- `mobile/test/features/practice/critical_ui_coverage_test.dart`
- `mobile/test/features/care_path/data/care_path_repository_test.dart`
- `mobile/test/features/care_path/presentation/care_path_notifier_test.dart`
- `mobile/test/tool/verify_t4_one_utterance_copy_firewall_test.dart`
- optional `mobile/test/features/practice/widgets/care_turn_card_test.dart`

Plan:

1. Replace old screen test expectations that require `session-progress` and `第 1 / 3 句`.
2. Add assertions that those keys/copy are absent.
3. Keep old `PhraseCard` stacking baseline tests out of T4 unless they break focused T4 tests.
4. Add care-path state tests for `utteranceReady`, `markSaid`, no-next fallback, and duplicate write.
5. Add widget tests for the full T4 user loop.

## Test Plan

### Coverage diagram

```text
CODE PATHS                                            USER FLOWS
[+] CarePathRepository.startMoment                    [+] Open current care moment
  |-- [GAP] returns utteranceReady with current phrase    |-- [GAP] current utterance renders
  |-- [GAP] missing activity keeps safe fallback          |-- [GAP] no step/progress/session copy

[+] CarePathNotifier.markSaid                         [+] Parent says the sentence
  |-- [GAP] utteranceReady -> reactionPrompt             |-- [GAP] 我说了 opens reaction prompt
  |-- [GAP] no utterance -> heldWithFallback             |-- [GAP] no event write before reaction

[+] CarePathNotifier.selectReaction                   [+] Record baby reaction
  |-- [★★] existing canonical write coverage             |-- [GAP] each chip writes canonical value
  |-- [★★] existing duplicate attempt coverage            |-- [GAP] double tap does not duplicate write
  |-- [GAP] no-next-support fallback keeps current        |-- [GAP] next support appears or current holds

[+] PracticeSessionScreen care-turn UI                [+] Listen / say / react / trace
  |-- [GAP] loads carePathNotifier from route args        |-- [GAP] 听一下 remains available
  |-- [GAP] audio success/failure stays local             |-- [GAP] reaction prompt is gated by 我说了
  |-- [GAP] next support panel renders                    |-- [GAP] Garden trace strip appears after save
  |-- [GAP] exit does not show completion summary         |-- [GAP] pop route has no completion screen

[+] Copy firewall                                    [+] Product semantics
  |-- [GAP] screen source has no lesson/progress framing  |-- [GAP] visible strings avoid practice/session copy
  |-- [GAP] T4 l10n keys avoid blocked terms              |-- [GAP] no CareReactionType / mobile_v2 / backend API

COVERAGE TARGET: every T4 branch above covered by unit or widget tests.
E2E: not required for T4 unless widget tests cannot prove route -> save -> trace.
```

### Required tests

Care-path repository tests:

- `startMoment` returns `CareTurnPhase.utteranceReady` with `bath_time_warm_water`.
- `recordReaction` writes `BabyReactionType.cooperating`, `hesitant`, `resisting`, `noResponse`, and `other` without fallback remapping.
- `recordReaction` with next support returns `nextSupportReady` and `nextSupportUtterance`.
- `recordReaction` with no next support returns `heldWithFallback`, keeps `currentUtterance`, preserves `traceEventKey`, and attaches Garden impact when available.

Care-path notifier tests:

- `markSaid` opens reaction prompt.
- `selectReaction` before `markSaid` does not write.
- `selectReaction` after `markSaid` writes exactly once.
- rapid duplicate reaction tap writes one event.
- `resetToSafeEmpty` clears snapshot/message after route teardown.

PracticeSessionScreen widget tests:

- current utterance renders from `carePathNotifierProvider`.
- initial route start happens outside `build`; repeated pump does not restart or overwrite the current turn.
- changing route args starts the new care moment exactly once.
- disposing/reopening the route clears or isolates the prior turn.
- no `session-progress`, `practice-progress-text`, `practice-completion-view`, `第 1 / 3 句`, `说完了`, `换一句`, `结束`, `跳过，下一句`.
- `听一下` is visible/enabled when audio is available.
- tapping `听一下` plays the asset and keeps the utterance visible.
- missing audio keeps the text speakable and shows a quiet unavailable/retryable message, unless the existing TTS fallback is used without extra scope.
- tapping `我说了` opens reaction prompt.
- reaction prompt shows `配合 / 犹豫 / 不想 / 没反应 / 其他`.
- selecting `其他` writes canonical `BabyReactionType.other`; it is not an invalid fallback.
- next support appears after save.
- no-next-support fallback holds the current utterance.
- rapid double tap on a reaction chip writes one event.
- exit/back does not show `PracticeCompletionView` or completion summary copy.
- Garden trace copy appears from `LatestPracticeImpact`.

Copy firewall test:

Target files:

```text
mobile/lib/features/practice/presentation/screens/practice_session_screen.dart
mobile/lib/l10n/app_zh.arb targeted T4 keys only
```

Blocked visible terms for T4 surface:

```text
课程
学习进度
完成任务
第 1 /
1 of N
XP
金币
排行榜
streak
lesson
task
completion summary
CareReactionType
mobile_v2
```

Conditional blocked terms:

- `练习` and `session` are blocked in visible strings for this route.
- Internal identifiers such as `PracticeSessionScreen`, `PracticeRouteArgs`, and file names are allowed.

Verification commands:

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub `
    test/features/care_path/data/care_path_repository_test.dart `
    test/features/care_path/presentation/care_path_notifier_test.dart `
    test/features/practice/critical_ui_coverage_test.dart `
    test/tool/verify_t4_one_utterance_copy_firewall_test.dart
} finally {
  Pop-Location
}
```

Focused analyze:

T4 required analyze gate covers touched files. Full `flutter analyze --no-pub`
may be recorded for awareness, but existing warning/info outside the T4 touched
files is not a T4 blocker. A full-analyze issue becomes a T4 blocker only when it
is newly introduced in files touched by this slice.

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' analyze --no-pub `
    lib/features/care_path/data/repositories/care_path_repository.dart `
    lib/features/care_path/presentation/care_path_notifier.dart `
    lib/features/care_path/presentation/care_path_view_model.dart `
    lib/features/practice/presentation/screens/practice_session_screen.dart `
    lib/l10n `
    test/features/care_path `
    test/features/practice/critical_ui_coverage_test.dart `
    test/tool/verify_t4_one_utterance_copy_firewall_test.dart
} finally {
  Pop-Location
}
```

Optional full analyze record:

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' analyze --no-pub
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
git status --short -- backend mobile_v2
rg -n "CareReactionType|class TodayScreen|class SceneScreen|@Collection" mobile/lib mobile/test
```

## Copy / l10n Migration Plan

Add or update T4 keys with these target meanings:

| Key direction | Chinese copy |
| --- | --- |
| screen title | `现在这一句` or scene title only |
| listen action | `听一下` |
| said action | `我说了` |
| reaction prompt title | `宝宝反应` |
| reaction prompt hint | `按宝宝刚才的状态记一下。` |
| next support title | `下一句可以这样说` |
| no next fallback | `这句先留在这里。刚才已经记下来了，等一等再继续也可以。` |
| garden trace title | `花园已经记下` |
| garden trace fallback | `这次已经留下痕迹，回到花园后会一起整理。` |
| exit label | `先回去` |
| invalid route fallback | `这个场景暂时打不开，请从今天或场景重新进入。` |

Do not use:

```text
说完了
练习
第 N 句
本轮
完成
进度
任务
打卡
XP
streak
```

Reaction labels are already correct in `SceneReactionChipRow`:

```text
cooperating -> 配合
hesitant -> 犹豫
resisting -> 不想
noResponse -> 没反应
other -> 其他
```

Generated localization files must be updated with ARB:

- `mobile/lib/l10n/app_zh.arb`
- `mobile/lib/l10n/app_localizations.dart`
- `mobile/lib/l10n/app_localizations_zh.dart`

If the repo's localization generation command is available, use it. If not, keep generated edits mechanical and covered by widget tests.

## Failure Modes

| Codepath | Failure mode | User impact | Test coverage | Handling |
| --- | --- | --- | --- | --- |
| route load | route args are invalid | user sees dead screen | existing fallback test, update copy | `PracticeFallbackScaffold` with care-scene copy |
| startMoment | activity missing from catalog | blank current utterance | repository + widget fallback tests | `CareTurnPhase.error/heldWithFallback` with gentle message |
| startMoment | activity has no phrases | no sentence to say | repository fallback test | disable `我说了`, keep safe message |
| listen | audio asset missing | parent cannot hear pronunciation | widget audio fallback test | use TTS fallback or visible retry message; phrase remains visible |
| listen | audio playback throws or times out | button looks broken | widget/unit audio failure test | local retryable banner, no event write |
| markSaid | user taps before utterance is loaded | reaction prompt opens on null state | notifier test | hold fallback, no write |
| reaction | user double taps same chip | duplicate local events and duplicate Garden trace | notifier + widget double-tap tests | coalesce while saving, disallow after selected |
| reaction | `other` treated as invalid fallback | canonical reaction data lost | repository canonical value tests | parse/write `other` exactly |
| next support | last phrase has no next utterance | old completion summary appears or blank next card | repository + widget no-next tests | keep current utterance and gentle fallback |
| Garden trace | projection fails after event write | user thinks save failed although trace exists locally | repository projection-failure test | preserve `traceEventKey`, show generic trace fallback |
| exit | user leaves after reaction | completion summary appears | widget exit test | pop only; no `PracticeCompletionView` |
| copy firewall | old progress/session copy leaks | product feels like lesson/course again | T4 copy firewall | fail focused test |

Critical gap to avoid:

```text
No test + no error handling + silent duplicate write on double tap.
```

The plan covers this with notifier and widget double-tap tests.

## Explicitly Not In Scope

- No backend changes.
- No `mobile_v2` changes.
- No reaction contract semantic changes.
- No `CareReactionType`.
- No Garden/Growth visual refactor.
- No Today/Scene visual refactor.
- No new Isar collection.
- No parallel local event storage.
- No backend API for next support.
- No lesson/progress/XP/streak/task/completion framing.
- No broad visual redesign.
- No route architecture migration.
- No `TodayScreen` or `SceneScreen` classes.
- No full internal rename from `practice` to `care_path`.
- No dynamic practice generation changes.
- No ASR/STT or hands-free voice work.
- No PhraseCard stacking baseline repair unless focused T4 tests fail because of it.
- No commit from this planning step.

## Worktree Sequencing

Recommended implementation is sequential. The screen, care-path notifier, l10n, and critical UI tests overlap too much for useful parallel work.

Dependency table:

| Step | Modules touched | Depends on |
| --- | --- | --- |
| T4.1 Care-path phase hardening | `mobile/lib/features/care_path`, `mobile/test/features/care_path` | T2 |
| T4.2 Practice screen one-turn UI | `mobile/lib/features/practice/presentation/screens`, optional practice audio helper | T4.1 |
| T4.3 l10n/copy keys | `mobile/lib/l10n` | T4.2 copy decisions |
| T4.4 Widget and copy tests | `mobile/test/features/practice`, `mobile/test/tool` | T4.1-T4.3 |
| T4.5 Verification | `mobile` test/analyze/format | all |

Parallel lanes:

```text
Lane A: T4.1 care-path phase hardening
  -> T4.2 PracticeSessionScreen one-turn UI
  -> T4.3 l10n/copy keys
  -> T4.4 tests
  -> T4.5 verification
```

Optional split after T4.1:

```text
Lane A: screen UI
Lane B: copy firewall draft
```

Conflict flags:

- Both lanes touch T4 copy and tests, so keep one owner for `app_zh.arb` and `critical_ui_coverage_test.dart`.
- Do not parallelize l10n generated-file edits.
- Do not parallelize any work that touches `PracticeSessionScreen`.

Implementation tasks:

- [ ] **T4.1 (P1, human: ~90min / CC: ~25min)** - care_path state - Use `utteranceReady`, add `markSaid`, and harden no-next fallback.
  - Surfaced by: Architecture decision to use care-path as the only state machine.
  - Files: `mobile/lib/features/care_path/data/repositories/care_path_repository.dart`, `mobile/lib/features/care_path/presentation/care_path_notifier.dart`, `mobile/lib/features/care_path/presentation/care_path_view_model.dart`, `mobile/test/features/care_path/data/care_path_repository_test.dart`, `mobile/test/features/care_path/presentation/care_path_notifier_test.dart`.
  - Verify: focused care_path tests.

- [ ] **T4.2 (P1, human: ~3h / CC: ~60min)** - PracticeSessionScreen - Replace legacy session UI with one current utterance, listen, said, reaction, next support, and trace.
  - Surfaced by: T4 target and T3 boundary.
  - Files: `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart`, optional `mobile/lib/features/practice/presentation/practice_audio_controller.dart`.
  - Verify: `critical_ui_coverage_test.dart` T4 loop coverage.

- [ ] **T4.3 (P1, human: ~45min / CC: ~15min)** - l10n/copy - Add one-turn copy and update generated localization files.
  - Surfaced by: Copy firewall and no session/progress framing.
  - Files: `mobile/lib/l10n/app_zh.arb`, `mobile/lib/l10n/app_localizations.dart`, `mobile/lib/l10n/app_localizations_zh.dart`.
  - Verify: widget tests and copy firewall.

- [ ] **T4.4 (P1, human: ~2h / CC: ~40min)** - tests - Replace legacy progress assertions and add duplicate-write, no-next fallback, exit, and copy firewall coverage.
  - Surfaced by: Test review diagram.
  - Files: `mobile/test/features/practice/critical_ui_coverage_test.dart`, `mobile/test/tool/verify_t4_one_utterance_copy_firewall_test.dart`.
  - Verify: focused test command.

- [ ] **T4.5 (P1, human: ~45min / CC: ~15min)** - verification - Run focused Flutter tests, analyze, format check, diff check, and scope guard.
  - Surfaced by: completion gate.
  - Files: no product files unless verification finds gaps.
  - Verify: commands in Test Plan.

TODOS.md updates:

- No `TODOS.md` update is recommended for T4.
- Reason: T4 is an approved implementation slice with concrete tasks in this document. Existing broader TODOs are not blockers and should not be bundled.

Retrospective learning applied:

- Prior learning `riverpod-dependency-override` applies. If implementation changes provider dependencies or overrides, update provider `dependencies:` declarations and prove nested `ProviderScope` still works in tests.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
| --- | --- | --- | --- | --- | --- |
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | not run | Not requested for T4. Product direction already constrained by T0-T3. |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run | Skipped; user asked for a planning document only. |
| Eng Review | `/plan-eng-review` | Architecture & tests | 1 | draft_clear | Primary decision: use `carePathNotifierProvider` directly, add `markSaid`, do not bridge `PracticeSessionNotifier`. |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not run | Optional later because T4 changes UI, but scope forbids broad visual redesign. |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | Not applicable. |

**UNRESOLVED:** 0

**VERDICT:** ENG PLAN DRAFT CLEAR FOR REVIEW - T4 may proceed after user approval, limited to the care-path one-utterance loop inside `PracticeSessionScreen`, focused care-path state hardening, l10n/copy updates, and tests. No backend, `mobile_v2`, reaction-contract, Garden/Growth visual, Today/Scene redesign, storage, API, lesson/progress/XP/streak/task/completion, or broad visual work is approved by this plan.
