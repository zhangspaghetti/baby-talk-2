# T8 Duolingo-like Onboarding Redesign Plan

Date: 2026-07-02
Status: Draft for user review
Branch: `gsd/v0.1-milestone`
Planning base commit: `bb522f92`
Scope: plan only. No implementation, no backend changes, no `mobile_v2`, no commit.

## Product Correction

T8 is not an incremental layout fix. It is a product-direction correction for first-run onboarding.

The current onboarding must stop behaving like a setup form followed by an isolated phrase loop. The target is a Baby Talk onboarding that learns the interaction model and pacing of Duolingo-style onboarding without copying its brand, owl, visual assets, exercise types, or wording:

```text
immersive welcome
  -> guide asks one simple question
  -> one-screen single choice
  -> top progress advances
  -> one strong bottom CTA
  -> light feedback
  -> early real product value
  -> one mini care-turn
  -> ritual trace
  -> Today tab
```

Baby Talk translation:

```text
Baby Talk welcome
  -> 选择宝宝年龄
  -> 选择今天常见照护场景
  -> 选择家长英语目标
  -> 选择当前照护时刻
  -> 立刻给出第一句家庭英语
  -> 听一下
  -> 我说了
  -> 选择宝宝反应: 配合 / 犹豫 / 不想 / 没反应 / 其他
  -> 下一句照护支持
  -> 花园留下第一条痕迹
  -> 进入 今天 tab
```

The product rule for T8:

```text
No ordinary setup wizard. No dashboard. No stats-led garden tour. No course path.
The user must experience a real care-turn before the main shell.
```

## Current Onboarding Audit

### Why It Does Not Feel Duolingo-like

Code evidence:

| Current path | Evidence | Product issue |
| --- | --- | --- |
| First route starts on scene grid | `mobile/lib/app/app.dart` maps `/onboarding` directly to `OnboardingSceneScreen`. | No full-screen brand/welcome moment and no guide-led first question. |
| Nickname and age are on one form page | `OnboardingNameScreen` combines `TextField`, age grid, save, and skip. | It is a settings form, not one-screen-one-question pacing. |
| Scene selection auto-advances on card tap | `OnboardingSceneScreen._selectScene()` immediately calls `_startPractice()`. | No bottom CTA, no deliberate confirmation, no feedback beat. |
| Progress exists only inside the phrase loop | `OnboardingPracticeScreen` shows `current / total` from `OnboardingSessionNotifier`. | Progress tracks phrases in one old screen, not the full onboarding journey. |
| Mini-turn is not a real care-turn | `OnboardingPracticeScreen` uses `ScenePhraseService`, `OnboardingSession`, and `BabyReaction`. | It does not write through `PracticeRepository.recordReaction()`, does not use `care_path`, and does not produce a reliable Today/Garden trace. |
| Reaction model is old and narrower | `BabyReaction` has `responded`, `calmed`, `noResponse`. | It does not use the canonical five `BabyReactionType` values. |
| Completion screen uses old completion framing | `OnboardingCompleteScreen` says the first group was shared and pushes garden welcome. | This is still detached from the real T2/T3/T4 one-turn contract. |
| Account is already separate | `AuthState` checks only completed `OnboardingSnapshot`; `/account` is independent. | This is good: phone/account capture can stay after first value. |

### Keep

Keep these assets and patterns:

| Keep | Why |
| --- | --- |
| `OnboardingWarmScaffold` | Good full-screen warm shell, already constrained to mobile content width. |
| `OnboardingAssetImage` and `OnboardingAssets` | Existing mascot/guide assets can carry the companion feeling without copying Duolingo. |
| `OnboardingMentorBubble` | Good guide speech primitive, but should be placed in a consistent guide area. |
| `OnboardingPrimaryButton` | Good strong CTA primitive; may need height/padding hardening for text scale. |
| `OnboardingProgressBar` | Keep concept, but add a top-journey variant with optional hidden count. |
| `AppScaleButton` and haptics | Useful for light feedback on choices and CTA. |
| `PracticeScene` labels/assets | Useful vocabulary for care context choices. |
| `OnboardingRepository`, `OnboardingSnapshot`, `OnboardingSnapshotStore` | Local-first onboarding completion already exists and does not require login. |
| `CarePathRepository`, `CarePathNotifier`, `CareTurnSnapshot` | Correct mini-turn mechanics: utterance, said, reaction, next support, trace. |
| `SceneReactionChipRow` or its canonical option list | Correct five reaction labels backed by `BabyReactionType`. |
| `GardenGrowthRepository.buildSnapshot()` | Already projects a local event into latest garden impact. |

### Redo

Hard replace these as public onboarding surfaces:

| Redo | Decision |
| --- | --- |
| `OnboardingSceneScreen` | Replace with a guided scene question page inside the new flow. No card-tap auto navigation. |
| `OnboardingNameScreen` | Remove from first-run path. Nickname can become a later profile/account prompt. |
| `OnboardingPracticeScreen` | Replace with a new onboarding mini-turn surface backed by `care_path`. Do not reuse the old phrase loop. |
| `OnboardingCompleteScreen` | Replace with micro-ritual trace screen. Avoid old completion framing. |
| `OnboardingGardenWelcomeScreen` | Replace with a one-trace transition to Today. Do not make Garden/stats the onboarding body. |
| `OnboardingSessionNotifier` and `OnboardingSession` | Supersede with a flow state machine that can represent age, scene, goal, moment, mini-turn, and trace. |
| `ScenePhraseService` for first value | Do not use for the mini-turn. Use seed content through `PracticeRepository` and `care_path` so the first action is real product data. |
| `BabyReaction` onboarding enum | Stop using on the new flow. Keep only if old tests need temporary compatibility; the new flow uses `BabyReactionType`. |

## New Architecture

Use one orchestrated onboarding route:

```text
/onboarding
  -> OnboardingFlowScreen
      -> OnboardingFlowNotifier
      -> OnboardingFlowShell
      -> question pages
      -> onboarding mini-turn page
      -> ritual trace page
      -> complete local snapshot
      -> context.go('/', extra: snapshot)
```

Provider/source-of-truth plan:

| Layer | New/changed piece | Responsibility |
| --- | --- | --- |
| Domain | `OnboardingFlowStep` | Enumerates welcome, age, scene, goal, moment, first phrase, listen, said, reaction, support, trace. |
| Domain | `OnboardingFlowState` | Holds selected age, scene, goal, moment activity ids, CTA enabled state, feedback state, and mini-turn status. |
| Presentation | `OnboardingFlowNotifier` | Advances steps, stores answers, computes progress, maps scene/moment to a care activity, and coordinates mini-turn lifecycle. |
| Presentation | `OnboardingMiniTurnController` or scoped `CarePathNotifier` | Starts the selected care moment, gates `听一下`, `我说了`, reaction save, next support, and trace. |
| Repository | `OnboardingRepository.completeOnboarding` optional starter override | Store the actual starter ids from the mini-turn instead of always using boot default. |
| Route | `/onboarding` only | Old child routes redirect to `/onboarding` or are removed after tests prove no callers remain. |

Do not use the global `carePathNotifierProvider` directly for onboarding because it currently auto-initializes through `..initialize()`. T8 should create a scoped onboarding mini-turn notifier, or add a non-auto-init factory/family, so the selected onboarding moment is started exactly once.

## Complete Step Flow

Progress denominator: 10 user-visible onboarding steps after splash. The splash can animate without counting, or count as step 0 with no numeric label.

| Step | User job | Data captured | Advances when |
| --- | --- | --- | --- |
| 0. Welcome | Feel this is Baby Talk, not a form. | none | Tap `先拿第一句`. |
| 1. Baby age | Pick rough age bucket. | `OnboardingAgeBucket` | One option selected and CTA tapped. |
| 2. Common care scene | Pick a common daily care context. | scene category | One option selected and CTA tapped. |
| 3. Parent English goal | Pick why they want help today. | goal: easy opening, pronunciation confidence, natural care words, calm transition. | One option selected and CTA tapped. |
| 4. Current care moment | Pick what is happening now. | concrete `spaceId/activityId` candidate. | One option selected and CTA tapped. |
| 5. First phrase | See the first family English sentence. | current `CareUtterance`. | CTA `听一下` tapped or explicit skip-to-say affordance. |
| 6. Listen | Hear or attempt audio/TTS. | local audio state only. | Playback completed, failed with fallback, or user taps `我说了`. |
| 7. Said | Confirm parent said it. | `markSaid()` transition, no event write yet. | CTA `我说了` tapped. |
| 8. Baby reaction | Pick canonical baby reaction. | `BabyReactionType`. | Reaction selected and save succeeds. |
| 9. Next support | See next care-support sentence. | `nextSupportUtterance`. | CTA `留下痕迹` or automatic trace acknowledgement. |
| 10. Garden trace | See first trace and enter Today. | local event key, latest garden impact, completed onboarding snapshot. | CTA `进入今天`. |

## Step UI Structure

Every step uses the same skeleton:

```text
SafeArea
  top progress row
  guide area
  question/title area
  options/content area
  feedback area
  pinned bottom CTA
```

| Step | Top progress | Guide area | Question/title | Options/content | Bottom CTA | Feedback state |
| --- | --- | --- | --- | --- | --- | --- |
| Welcome | Hidden or 0% slim bar | Large mascot/guide with brand mark. | `Baby Talk` plus a value line about one real care sentence. | No form fields. One immersive visual. | `先拿第一句` | Tiny entrance animation, haptic on CTA. |
| Age | `1/10` or bar only | Guide asks one question. | `宝宝现在大概多大？` | 5 age cards from `OnboardingAgeBucket`. | Disabled until selected, then `继续`. | Selected card lifts, guide says `我会按这个阶段准备句子`. |
| Scene | `2/10` | Guide stays visible. | `今天最常遇到哪个照护场景？` | 4 to 6 scene cards using existing assets. | `继续` | Selected card plus one-line reassurance. |
| Goal | `3/10` | Guide asks why they want help. | `你今天最想要哪种帮助？` | Goal cards, text-only or icon+text. | `继续` | Feedback copy changes by goal. |
| Moment | `4/10` | Guide asks what is happening now. | `现在最像哪一刻？` | Activity cards mapped to seed content ids. | `给我第一句` | Shows `马上就能说`. |
| First phrase | `5/10` | Guide points at sentence. | `这一句可以现在说` | Care utterance card with English, Chinese, pronunciation, when-to-say. | `听一下` | If audio missing, show gentle inline fallback, keep CTA path open. |
| Listen | `6/10` | Guide listens with parent. | Same phrase remains stable. | Audio state pill: playing, heard, or retryable. | `我说了` | Playback success/failure feedback, no event write. |
| Said | `7/10` | Guide celebrates softly. | `宝宝刚才是什么反应？` | Canonical five reaction chips/cards. | No separate CTA if reaction card commits; or `记录反应` if selection first. | Selection haptic, save spinner only after explicit action. |
| Reaction save | `8/10` | Guide confirms. | `记下来了` | Selected reaction summary. | Disabled while saving. | `savingTrace` state from care path. |
| Next support | `9/10` | Guide gives next line. | `下一句可以这样接住` | `nextSupportUtterance` card or gentle fallback if none. | `留下第一条痕迹` | Shows saved trace event key only as internal debug in tests, not visible. |
| Trace | `10/10` | Guide and tiny garden trace. | `今天已经留下第一条照护痕迹` | Small trace card from `LatestPracticeImpact` or generic local trace fallback. | `进入今天` | No stats dashboard, no growth refactor, no old completion page. |

Progress rules:

- The top progress bar is always in the same location after welcome.
- Progress advances only after CTA or committed reaction save, not on mere card focus.
- The bar must be stable at `390x844`, `427x952`, and text scale `1.3`.
- Numeric count can be visually hidden if it feels too mechanical, but semantics should expose step progress for accessibility.

## Mini Care-turn Integration

Use the T2/T3/T4 stack, not the old onboarding phrase loop.

```text
selected onboarding moment
  -> resolve to seed content spaceId/activityId
  -> scoped CarePathNotifier.startMoment(spaceId, activityId)
  -> current CareUtterance
  -> 听一下 uses existing PracticeAudioController abstraction or TTS fallback
  -> 我说了 calls CarePathNotifier.markSaid()
  -> reaction uses BabyReactionType
  -> CarePathNotifier.selectReaction()
  -> CarePathRepository.recordReaction()
  -> PracticeRepository.recordReaction()
  -> GardenGrowthRepository.buildSnapshot()
  -> nextSupportUtterance + latestGardenImpact
  -> completeOnboarding(localOnly)
  -> Today tab receives a real local event through existing continuity
```

Connection to prior slices:

| Slice | How T8 uses it |
| --- | --- |
| T2 `care_path` facade | Main mini-turn state machine and local event trace. |
| T3 Today/Scene IA | After entering shell, Today can read the just-written local event through continuity. |
| T4 one-utterance route | The interaction contract is reused, but the normal route screen is not mounted as onboarding. |

Do not push the user into `PracticeSessionScreen` during onboarding. It is an app route with normal shell/route semantics and existing file/class names. T8 should reuse lower-level care-turn logic and selected UI primitives, while keeping the onboarding pacing controlled by `OnboardingFlowScreen`.

## OnboardingPracticeScreen Decision

Do not reuse `OnboardingPracticeScreen` as the T8 mini-turn.

Reasons:

1. It uses `ScenePhraseService`, not seed content through `PracticeRepository`.
2. It writes only to `OnboardingSession`, not the local interaction event log.
3. It uses old `BabyReaction`, not canonical `BabyReactionType`.
4. It has phrase-count loop mechanics and an old complete page.
5. It already needed T7 overflow hardening because it was not designed as a stable onboarding shell.

Allowed salvage:

- Copy useful layout ideas into new private widgets.
- Reuse `OnboardingWarmScaffold`, `OnboardingMentorBubble`, `OnboardingPrimaryButton`, and asset images.
- Keep the old file temporarily only if deleting it in one PR creates routing churn, but it must no longer be reachable from `/onboarding`.

Preferred new surface:

```text
mobile/lib/features/onboarding/presentation/screens/onboarding_flow_screen.dart
mobile/lib/features/onboarding/presentation/widgets/onboarding_flow_shell.dart
mobile/lib/features/onboarding/presentation/widgets/onboarding_question_page.dart
mobile/lib/features/onboarding/presentation/widgets/onboarding_mini_turn_page.dart
mobile/lib/features/onboarding/presentation/widgets/onboarding_trace_page.dart
```

## Account Capture

Account, phone, and sync capture should be after the first value moment.

Current repo evidence:

- `AuthState.load()` only checks `OnboardingRepository.readCompletedSnapshot()`.
- `OnboardingRepository.completeOnboarding()` writes a local `OnboardingSnapshot`.
- `/account` is a separate route.
- Existing account copy supports local-only mode.

T8 decision:

```text
No phone/account field during first-run onboarding.
Complete local onboarding after mini care-turn.
Offer account/sync later from Today, drawer, profile, or a post-value non-blocking prompt.
```

Because `completeOnboarding()` currently requires `childDisplayName`, use `宝宝` as the local default if T8 removes the early nickname form. Add optional starter overrides so the snapshot can store the selected mini-turn activity/phrase.

No backend change is needed.

## File-Level Implementation Plan

### T8.1 Flow state model

Files:

- `mobile/lib/features/onboarding/domain/models/onboarding_flow_state.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_flow_option.dart`
- `mobile/lib/features/onboarding/presentation/onboarding_flow_notifier.dart`
- `mobile/test/features/onboarding/presentation/onboarding_flow_notifier_test.dart`

Plan:

1. Define `OnboardingFlowStep` for welcome, age, scene, goal, moment, first phrase, listen, said, reaction, support, trace.
2. Define selected answer fields: `ageBucket`, `scene`, `goal`, `momentSpaceId`, `momentActivityId`, `reactionType`.
3. Compute `currentStepIndex`, `totalSteps`, `progressFraction`, and `canContinue`.
4. Enforce one-step progression through notifier methods, not route pushes.
5. Add feedback state for selected cards and saved trace.

### T8.2 Care moment mapping

Files:

- `mobile/lib/features/onboarding/domain/models/onboarding_care_moment_catalog.dart`
- `mobile/test/features/onboarding/domain/onboarding_care_moment_catalog_test.dart`

Plan:

1. Map onboarding choices to existing seed content ids, such as `daily_care/bath_time`.
2. Validate ids against `PracticeRepository.getActivityCatalog()` before starting the mini-turn.
3. If the chosen moment is unavailable, fall back to the boot starter activity and show gentle guide copy.
4. Do not add backend APIs or new storage.

### T8.3 Onboarding route replacement

Files:

- `mobile/lib/app/app.dart`
- `mobile/lib/app/router/app_route_contract.dart`
- `mobile/test/app/app_route_contract_test.dart`
- `mobile/test/widget_test.dart`

Plan:

1. Change `/onboarding` to build `OnboardingFlowScreen`.
2. Redirect or remove `/onboarding/name`, `/onboarding/scene`, `/onboarding/practice`, `/onboarding/complete`, and `/onboarding/garden-welcome`.
3. Keep `AppRouteNames` canonical paths stable only if tests or deep links still require them; otherwise prune in a focused route-contract update.
4. Update boot tests so fresh install lands on welcome, not scene grid.

### T8.4 New onboarding UI shell

Files:

- `mobile/lib/features/onboarding/presentation/screens/onboarding_flow_screen.dart`
- `mobile/lib/features/onboarding/presentation/widgets/onboarding_flow_shell.dart`
- `mobile/lib/features/onboarding/presentation/widgets/onboarding_question_page.dart`
- `mobile/lib/features/onboarding/presentation/widgets/onboarding_option_card.dart`
- `mobile/lib/features/onboarding/presentation/widgets/onboarding_feedback_strip.dart`
- `mobile/lib/features/onboarding/presentation/widgets/onboarding_design_widgets.dart`

Plan:

1. Build one shared shell with top progress, guide area, content area, feedback, and bottom CTA.
2. Make option cards select-only. CTA advances.
3. Use existing mascot/guide assets, not Duolingo assets.
4. Add stable layout constraints for the top progress and bottom CTA at 1.3x text scale.
5. Avoid nested cards and avoid making Garden/stats the main onboarding content.

### T8.5 Mini-turn page

Files:

- `mobile/lib/features/onboarding/presentation/widgets/onboarding_mini_turn_page.dart`
- `mobile/lib/features/onboarding/presentation/onboarding_mini_turn_notifier.dart` or scoped `CarePathNotifier` factory
- `mobile/lib/features/practice/presentation/practice_audio_controller.dart` if audio abstraction needs extraction
- `mobile/test/features/onboarding/presentation/onboarding_mini_turn_notifier_test.dart`
- `mobile/test/features/onboarding/presentation/widgets/onboarding_mini_turn_page_test.dart`

Plan:

1. Start selected care moment exactly once outside `build`.
2. Render current `CareUtterance`.
3. `听一下` uses existing audio controller abstraction, with a retryable local fallback if missing.
4. `我说了` calls `markSaid()`.
5. Reaction choices use `BabyReactionType.cooperating`, `hesitant`, `resisting`, `noResponse`, `other`.
6. Save through `CarePathNotifier.selectReaction()`.
7. Render `nextSupportUtterance`.
8. Render first trace from `latestGardenImpact` or generic local trace fallback.
9. Prevent duplicate reaction writes.

### T8.6 Completion snapshot and shell entry

Files:

- `mobile/lib/features/onboarding/data/repositories/onboarding_repository.dart`
- `mobile/test/features/onboarding/onboarding_repository_test.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_snapshot.dart` only if optional starter override requires generated model changes

Plan:

1. Add optional `starterSpaceId`, `starterActivityId`, and `starterPhraseId` parameters to `completeOnboarding()`, or accept an `OnboardingStarterSeed`.
2. Default `childDisplayName` to `宝宝` when no nickname was captured.
3. Keep `OnboardingConsentState.localOnly`.
4. Complete after reaction save and trace display, not before first value.
5. Navigate to `/` with the completed snapshot.

### T8.7 Copy and l10n

Files:

- `mobile/lib/l10n/app_zh.arb`
- `mobile/lib/l10n/app_localizations.dart`
- `mobile/lib/l10n/app_localizations_zh.dart`
- `mobile/test/tool/verify_t8_onboarding_copy_firewall_test.dart`

Plan:

1. Add targeted onboarding keys for the new flow.
2. Remove visible old setup-copy from the first-run path.
3. Add a T8 copy firewall that scans only the new onboarding files and targeted l10n keys.
4. Allow blocked terms only in file/class identifiers and tests that explicitly assert they are absent.

Forbidden visible onboarding framing:

```text
lesson
course
XP
streak
task
completion summary
课程
学习进度
完成任务
打卡
排行榜
金币
```

Conditional visible terms:

- `练习` should not appear in the new onboarding UI copy.
- `完成` should not be used as the primary success frame. Use trace/ritual wording instead.

### T8.8 Test migration

Files:

- Replace or rewrite `mobile/test/features/onboarding/presentation/screens/onboarding_practice_screen_test.dart`
- Replace or rewrite `mobile/test/features/onboarding/presentation/screens/onboarding_name_screen_test.dart`
- Extend `mobile/test/features/onboarding/presentation/onboarding_session_notifier_test.dart` into new flow notifier tests, or retire it if the old notifier is removed.
- Add `mobile/test/features/onboarding/presentation/screens/onboarding_flow_screen_test.dart`
- Add `mobile/test/tool/verify_t8_onboarding_copy_firewall_test.dart`

Plan:

1. Old screen tests should not keep old public behavior alive.
2. New tests prove flow progression, progress fraction, option selection, mini-turn persistence, and viewport resilience.
3. Keep care-path unit tests as shared foundation.

## Required Tests

### Step progression tests

- Welcome CTA moves to age.
- Age cannot advance until selected.
- Scene cannot auto-advance on card tap.
- Goal and moment follow the same select-then-CTA rule.
- Back navigation, if included, moves one step and preserves selected answers.
- Entering trace completes local onboarding and lands on shell.

### Progress bar tests

- Initial question progress is stable.
- Progress advances once per committed step.
- Reaction save advances only after save success.
- Error/retry does not falsely advance.
- Semantics exposes current step and total.

### Option selection tests

- Selecting an option updates state but does not navigate.
- Changing selection before CTA updates selected card and feedback.
- CTA disabled/enabled state is correct.
- Cards fit at `390x844`, `427x952`, and `1.3x`.

### Mini care-turn tests

- Selected moment starts exactly once.
- Current utterance renders from `CarePathNotifier`, not `ScenePhraseService`.
- `听一下` does not write an event.
- `我说了` opens reaction prompt and still does not write an event.
- Each canonical reaction can be selected.
- Selecting `other` writes `BabyReactionType.other`, not fallback.
- Double tap writes one event.
- Save returns `nextSupportUtterance`.
- Trace card appears from `latestGardenImpact` or generic fallback.
- Onboarding snapshot is written after the trace, local-only.

### Copy firewall

Create:

```text
mobile/test/tool/verify_t8_onboarding_copy_firewall_test.dart
```

Targets:

```text
lib/features/onboarding/presentation/screens/onboarding_flow_screen.dart
lib/features/onboarding/presentation/widgets/onboarding_flow_shell.dart
lib/features/onboarding/presentation/widgets/onboarding_question_page.dart
lib/features/onboarding/presentation/widgets/onboarding_mini_turn_page.dart
lib/features/onboarding/presentation/widgets/onboarding_trace_page.dart
targeted T8 app_zh.arb keys
```

Assertions:

- No course/progress/task/XP/streak/completion framing in visible strings.
- No `CareReactionType`.
- No `mobile_v2`.
- No visible `练习` in the new onboarding flow.
- No old screen route keys like `onboarding-name-input` in the new flow tests except compatibility redirect tests.

### Viewport and text scale tests

Required matrix:

```text
390x844 @ 1.0
390x844 @ 1.3
427x952 @ 1.0
427x952 @ 1.3
```

States to cover:

- welcome
- longest age/goal option labels
- scene/moment cards
- first phrase
- audio fallback
- reaction prompt
- next support
- trace screen

Commands after implementation:

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location C:\code\AI\baby-talk-2\mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\onboarding `
    test\tool\verify_t8_onboarding_copy_firewall_test.dart `
    test\features\care_path\presentation\care_path_notifier_test.dart
} finally {
  Pop-Location
}
```

Focused analyze after implementation:

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location C:\code\AI\baby-talk-2\mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' analyze --no-pub `
    lib\features\onboarding `
    lib\features\care_path `
    test\features\onboarding `
    test\tool\verify_t8_onboarding_copy_firewall_test.dart
} finally {
  Pop-Location
}
```

Scope guard:

```powershell
git status --short -- backend mobile_v2
git diff --name-only -- backend mobile_v2
rg -n "CareReactionType|mobile_v2|lesson|XP|streak|排行榜|金币" mobile/lib/features/onboarding mobile/test/features/onboarding mobile/test/tool
```

## Migration and Risk

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Old child routes remain reachable | Users/tests can still enter form/grid/old loop. | Redirect old onboarding children to `/onboarding`, or remove them and update route contract tests. |
| Global care path notifier auto-starts wrong moment | `carePathNotifierProvider` calls `..initialize()`. | Use scoped non-auto-init notifier for onboarding mini-turn. |
| First event does not appear in Today | If mini-turn writes outside `PracticeRepository`, Today cannot see it. | Save only through `CarePathRepository.recordReaction()`. |
| Snapshot starter ids mismatch selected moment | Current `completeOnboarding()` uses boot starter ids. | Add mobile-only optional starter override. |
| Account capture sneaks back in | Early phone field blocks first value. | Copy firewall and route tests assert no account field before trace. |
| Old copy returns through l10n | Existing ARB contains many old onboarding strings. | Target only new T8 keys and assert old route widgets are unreachable. |
| Text scale overflow | T7 showed onboarding can break at 1.3x. | Add matrix tests for each step. |
| Deleting old screens causes broad churn | Existing tests may import old screens. | Replace tests in the same T8 implementation, or leave files unregistered for one PR with explicit removal task. |
| Product slips into Garden stats | Trace screen may become dashboard-like. | Trace must be one lightweight mark, not Garden/Growth visual refactor. |

Migration sequence:

1. Add new flow in parallel behind `/onboarding` route.
2. Keep old files compiling but remove public route reachability.
3. Replace tests to assert new behavior.
4. Add copy firewall.
5. After focused tests pass, delete or quarantine old onboarding screen files if no references remain.
6. Run fresh-install manual path at `390x844 @ 1.3`.

## Explicitly Not In Scope

- No backend changes.
- No `mobile_v2` changes.
- No reaction contract changes.
- No new `CareReactionType`.
- No new `BabyReactionType` value.
- No Garden/Growth visual refactor.
- No dashboard, stats, or growth analytics as onboarding body.
- No course path, lesson path, XP, streak, task, or old completion framing.
- No redirect to the normal app one-turn route during onboarding.
- No account, phone, CAPTCHA, consent, or sync gate before first value.
- No dynamic AI generation requirement.
- No ASR/STT or hands-free voice input.
- No broad theme redesign.
- No new backend API.
- No commit from this planning step.

## Implementation Tasks

- [ ] **T8.1 (P0, human: ~2h / CC: ~35min)** - Add onboarding flow state and notifier.
  - Files: `onboarding_flow_state.dart`, `onboarding_flow_option.dart`, `onboarding_flow_notifier.dart`, notifier tests.
  - Verify: step progression and option selection unit tests.

- [ ] **T8.2 (P0, human: ~2h / CC: ~30min)** - Add care moment mapping to existing seed content.
  - Files: `onboarding_care_moment_catalog.dart`, catalog tests.
  - Verify: every visible moment maps to a valid activity or safe fallback.

- [ ] **T8.3 (P0, human: ~3h / CC: ~60min)** - Replace `/onboarding` with `OnboardingFlowScreen`.
  - Files: `app.dart`, route contract, new screen/widgets.
  - Verify: fresh boot lands on welcome, old child routes no longer expose old screens.

- [ ] **T8.4 (P0, human: ~3h / CC: ~70min)** - Build onboarding mini-turn over `care_path`.
  - Files: mini-turn notifier/page, optional audio extraction, mini-turn tests.
  - Verify: listen, said, reaction, next support, trace, duplicate-write guard.

- [ ] **T8.5 (P1, human: ~1h / CC: ~20min)** - Complete local snapshot after trace.
  - Files: `OnboardingRepository`, repository tests.
  - Verify: no login dependency, local-only snapshot, selected starter ids preserved.

- [ ] **T8.6 (P1, human: ~2h / CC: ~45min)** - Add l10n keys and T8 copy firewall.
  - Files: ARB/generated l10n, `verify_t8_onboarding_copy_firewall_test.dart`.
  - Verify: firewall passes and no forbidden onboarding framing leaks.

- [ ] **T8.7 (P1, human: ~2h / CC: ~45min)** - Add viewport matrix tests.
  - Files: onboarding flow screen tests.
  - Verify: `390x844` and `427x952` at `1.3x` cover all major states.

- [ ] **T8.8 (P1, human: ~45min / CC: ~15min)** - Manual fresh-install validation.
  - Files: evidence report only after implementation, not during this plan.
  - Verify: welcome to Today, mini care-turn trace visible, no account gate.

## Completion Summary Template

Use this shape after implementation:

```markdown
# T8 Completion Summary

- Scope guard: pass/fail
- Fresh install starts at new welcome: pass/fail
- Old onboarding routes unreachable or redirected: pass/fail
- One-screen-one-question flow: pass/fail
- Top progress stable: pass/fail
- Bottom CTA stable: pass/fail
- Mini care-turn writes local event: pass/fail
- Canonical reaction contract preserved: pass/fail
- Next support appears: pass/fail
- Garden trace appears without visual refactor: pass/fail
- Local onboarding snapshot written after trace: pass/fail
- Account capture deferred: pass/fail
- Copy firewall: pass/fail
- 390x844 / 427x952 / 1.3x matrix: pass/fail
- Backend untouched: pass/fail
- mobile_v2 untouched: pass/fail
```

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | clear | Product correction accepted: T8 must create a new guided onboarding architecture, not patch the current form/grid/old phrase loop. |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run | Skipped because the user asked for a plan document only and no implementation. |
| Eng Review | `/plan-eng-review` | Architecture & tests | 1 | draft_clear | Use `care_path` for the onboarding mini-turn, avoid global auto-init notifier, defer account capture, add route migration and viewport/copy-firewall tests. |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not run | Recommended before implementation screenshots, but not required for this plan request. |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | Not required; file-level implementation and verification commands are explicit. |

**UNRESOLVED:** 0

**VERDICT:** CEO + ENG PLAN DRAFT CLEAR FOR USER REVIEW. T8 should proceed only as a mobile onboarding architecture replacement with a real mini care-turn before Today, local-only completion, no backend, no `mobile_v2`, no reaction-contract change, no Garden/Growth visual refactor, and no early account gate.
