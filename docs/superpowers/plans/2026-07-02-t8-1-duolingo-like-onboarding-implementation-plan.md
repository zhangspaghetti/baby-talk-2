# T8.1 Duolingo-like Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL after approval: use `subagent-driven-development` or `executing-plans` task-by-task. This document is a plan only. Do not write Flutter code, do not touch backend/mobile/mobile_v2 during plan review, and do not commit until the implementation phase is explicitly approved.

**Goal:** Replace the old Flutter onboarding with a TaTa-guided, Duolingo-like, backend-supported first-run flow that captures baby profile, completes one real care-turn, persists the trace through backend auth/sync contracts, and hands off to Today.

**Architecture:** T8.1 is not a mobile-only rewrite. The implementation starts with a backend/mobile API audit, then adds backend-backed DTO/repository contracts, reusable care-turn presentation components, and finally the onboarding shell. Local state is only a temporary draft/cache for incomplete or offline work; after phone verification, backend account/profile/event/garden state becomes the source of truth.

**Tech Stack:** Flutter, Riverpod, GoRouter, feature-first Flutter layers, generated Chinese l10n, existing `AccountApiService` / `AccountRepository` / `AuthenticatedApiClient`, existing `care_path`, existing `PracticeRepository`, Spring Boot app-api, JWT-backed consumer auth, `/api/v1/sync/events`, `/api/v1/garden/snapshot`, Mentor/Spring AI runtime where appropriate.

---

## Source Of Truth

- T8.0 contract commit: `b9cfc43b6cd2d3115d88892a0d7894bdce5677da`
- T8.0 contract: `docs/superpowers/specs/2026-07-02-t8-visual-interaction-contract.md`
- Locked mascot: TaTa 小水獭, active mascot
- This revised T8.1 plan replaces the earlier local-first assumptions in this same document.

Revised T8 path:

```text
welcome
-> baby name
-> age
-> scene
-> goal
-> moment
-> first utterance
-> listen
-> said
-> baby reaction
-> next support
-> garden trace
-> save trace / phone capture
-> Today
```

Product direction lock:

- Backend-supported, not product-local-only.
- Agentic/runtime-supported scene, moment, and next-support path where backend capability exists or is introduced.
- Reusable care-turn components, not onboarding-only practice widgets.
- Responsive layout by constraints, not fixed-device branching.
- TaTa production assets must be newly generated production PNGs based on the T8.0 mascot contract, not crops from concept sheets or mascot reference images.

## Current Onboarding Code Audit

| Surface | Current behavior | T8.1 decision | Reusable / extractable pieces |
| --- | --- | --- | --- |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart` | Current `/onboarding` public entry. Uses old mentor framing, local `PracticeScene`, scene grid, and starts old onboarding practice from a selected scene. | Replace as route entry. New scene step lives inside `OnboardingFlowShell` and renders backend-provided scene options. | Basic warm visual density and option-card lessons can inform new `ResponsiveOptionList`, but scene data must not be the product source of truth. |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_name_screen.dart` | Combines optional child name, age grid, skip, and route push to garden welcome. | Do not reuse as-is. Add a new `baby name` step with T8 copy and typed flow state. | Reuse the product idea that a child nickname personalizes the experience; do not copy the old combined name+age flow. |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart` | Uses `OnboardingSessionNotifier`, `ScenePhraseService`, old onboarding `BabyReaction`, in-memory `PracticeRecord`, and old phrase-loop progress. | Retire from T8 route. Do not reuse the old state machine. Extract the useful UI behaviors into generic care-turn widgets in `care_path/presentation/widgets`. | Phrase panel hierarchy, bottom CTA density, haptics, listen/said/reaction/next-support rhythm. These become reusable care-turn components, not onboarding-only widgets. |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart` | Old sprout completion screen with old completion language and garden CTA. | Replace with K Garden Trace plus L Phone Capture. | Only the success-beat idea is relevant; implementation should use backend garden progress response. |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_garden_welcome_screen.dart` | Calls `OnboardingRepository.completeOnboarding()` and routes home. | Replace as public completion path. Local completion may remain a cache/gate after backend completion succeeds or user explicitly skips save, but it must not be the source of truth for saved users. | Today handoff can reuse route conventions; not the old completion model. |

Old onboarding state/domain retirement:

| Piece | Problem | T8.1 action |
| --- | --- | --- |
| `OnboardingSessionNotifier` | Bound to old `ScenePhraseService`, old records, and old reaction enum. | Supersede for T8. Keep temporarily only if other routes/tests still import it, then delete in route retirement slice. |
| `OnboardingSession` / `PracticeRecord` | Onboarding-only records do not represent backend-persisted care-turn events. | Do not use in T8.1. |
| `BabyReaction` under onboarding | Not canonical; conflicts with `BabyReactionType`. | Do not use. |
| `ScenePhraseService` | Local hardcoded onboarding phrase service. | Do not use for product path. |
| `OnboardingRepository.completeOnboarding()` | Local gate/snapshot only. | Use only as cache/local gate after backend-backed onboarding completion or explicit skip; never as the saved account source of truth. |

Reusable bottom-layer pieces:

- Keep or adapt `OnboardingWarmScaffold` into a responsive shell, if it can honor the new layout contract.
- Keep `OnboardingPrimaryButton` / `OnboardingOutlinedButton` styling ideas but move pinned CTA behavior into `PinnedBottomCta`.
- Keep `OnboardingAssetImage` only as a neutral asset wrapper.
- Keep `AppScaleButton` and `AppHaptics` for feedback.
- Reuse `SceneReactionChipRow` and existing `BabyReactionType` label mapping after extracting an onboarding-safe, care-turn-generic selector.
- Reuse account and sync infrastructure: `AccountApiService`, `AccountRepository`, `AuthenticatedApiClient`, `AccountLocalStore`, `/api/v1/auth/*`, `/api/v1/sync/events`, `/api/v1/bootstrap`.
- Reuse care path orchestration names and snapshots, but update the repository adapter so the product path persists through backend-backed sync/event APIs.

## Backend And Mobile API Audit Slice

Slice 0 must be completed before UI implementation. Do not assume missing backend capability until this audit is done.

Backend phone verification / login / registration audit task:

```text
Explore existing backend phone verification / login / registration flow:
- backend controller routes
- request / response DTOs
- mobile existing auth API client
- token/session persistence
- error model
- resend code behavior
- whether phone capture can be completed inside onboarding
```

Known evidence from current repo:

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncController.java`
  - `POST /api/v1/auth/challenges`
  - `POST /api/v1/auth/verify`
  - `POST /api/v1/auth/refresh`
  - `POST /api/v1/auth/logout`
  - `POST /api/v1/consent/accept`
  - `POST /api/v1/sync/events`
  - `GET /api/v1/bootstrap`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java`
  - creates SMS challenges
  - verifies challenge codes
  - creates or reuses active account by phone
  - creates session and JWT tokens
  - accepts/revokes consent
  - ingests interaction events
  - bootstraps synced events
  - allows only canonical reaction values: `cooperating`, `hesitant`, `resisting`, `no_response`, `other`
- `mobile/lib/features/account/data/services/account_api_service.dart`
  - already wraps `/api/v1/auth/challenges`, `/api/v1/auth/verify`, `/api/v1/auth/refresh`, `/api/v1/auth/logout`, `/api/v1/consent/accept`, `/api/v1/sync/events`, `/api/v1/bootstrap`
- `mobile/lib/features/account/data/repositories/account_repository.dart`
  - already persists session locally after verification
  - accepts consent
  - refreshes runtime state and bootstraps events
  - currently has a fallback placeholder path when no API service is injected; T8 product path must not use that fallback after the user chooses save.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java`
  - `POST /api/v1/mentor/practice/generate` exists and may be relevant for first utterance / next support audit.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GardenSnapshotController.java`
  - `GET /api/v1/garden/snapshot` exists for authenticated garden state.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GrowthSummaryController.java`
  - `GET /api/v1/growth/summary` exists and reads backend-derived progress.

Audit outputs required before Slice 2:

- Confirm whether `AccountRepository.signIn()` can support the onboarding two-screen phone flow or needs split methods:
  - `requestPhoneCode(phoneNumber)`
  - `verifyPhoneCode(challengeId, verificationCode)`
  - `persistVerifiedSession(AccountSession)`
- Confirm resend semantics:
  - whether resend is another `POST /api/v1/auth/challenges`
  - cooldown / retryable error handling
  - challenge replacement behavior in mobile state
- Confirm where baby profile and onboarding completion should be persisted:
  - existing endpoint/schema if present
  - otherwise proposed minimal endpoint in this plan
- Confirm whether backend scene/moment discovery already exists:
  - practice catalog controller
  - activity/catalog endpoints
  - recommendation endpoints
  - Mentor/agentic generation endpoint
  - graph/search/pack endpoints
- Confirm whether next support can come from existing Mentor practice generate or needs a new runtime endpoint.
- Confirm how `/api/v1/sync/events` should carry first care-turn event metadata and how garden progress is projected.

## New Onboarding Architecture

```text
/onboarding
  -> OnboardingFlowScreen
      -> OnboardingFlowNotifier
          -> OnboardingDraftStore
          -> AccountRepository / AccountApiService
          -> OnboardingBackendRepository
          -> OnboardingDiscoveryRepository
          -> CareTurnRepositoryAdapter
          -> CarePathNotifier or CarePathRepository-backed controller
      -> OnboardingFlowViewModel
      -> OnboardingFlowShell
          -> A-M step widgets
```

Core boundary:

- `OnboardingFlowNotifier` owns flow orchestration.
- Repositories own persistence and API calls.
- Widgets receive typed view models and callbacks.
- Widgets do not call repositories or parse backend DTOs.
- Domain option codes are not localized strings.
- Presentation mappers convert backend/domain DTOs to l10n-backed view models.

Local state rule:

- Local draft/cache is allowed for:
  - resume before completion
  - offline pending sync marker
  - user who taps `稍后再说`
  - route gate cache after backend completion
- Local state is not the saved-account source of truth.
- After phone verification succeeds, backend account/session/profile/event/garden state becomes authoritative and mobile caches the returned state.

### `OnboardingFlowShell`

Create:

- `mobile/lib/features/onboarding/presentation/widgets/onboarding_flow_shell.dart`

Slots:

```text
progress
tataGuide
title
content
feedback
bottomCta
secondaryAction
```

Rules:

- One primary CTA per step.
- CTA stays safe-area reachable through `PinnedBottomCta`.
- No nested cards around full sections.
- Stable progress height.
- Screen-reader order: progress -> TaTa guide -> title -> content/options -> feedback -> primary CTA -> secondary action.
- No viewport-specific branches such as `if width == 390` or device model checks.

### Step Model

Create:

- `mobile/lib/features/onboarding/domain/models/onboarding_flow_step.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_flow_state.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_flow_options.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_age_range.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_baby_profile_draft.dart`

`OnboardingStepId`:

```text
welcome
babyName
age
scene
goal
moment
firstUtterance
listen
said
babyReaction
nextSupport
gardenTrace
phoneCapture
todayHandoff
```

Progress semantics:

- `welcome` is not counted.
- `babyName` through `gardenTrace` are value/proof steps.
- `phoneCapture` is a post-value save step, not a pre-value login gate.
- `todayHandoff` is a handoff state and should not show course-style progress.

Recommended progress denominator:

```text
babyName: 1/11
age: 2/11
scene: 3/11
goal: 4/11
moment: 5/11
firstUtterance: 6/11
listen: 7/11
said: 8/11
babyReaction: 9/11
nextSupport: 10/11
gardenTrace: 11/11
```

State fields:

- `stepId`
- `babyName`
- `ageRangeCode`
- `selectedSceneId`
- `selectedMomentId`
- `selectedGoalCode`
- `firstUtteranceId`
- `firstUtteranceText`
- `firstUtteranceTranslation`
- `listenStarted`
- `listenCompleted`
- `saidConfirmed`
- `selectedReactionType`
- `reactionSaveStatus`
- `persistedCareTurnEventId`
- `nextSupport`
- `gardenTrace`
- `phoneNumber`
- `phoneChallengeId`
- `phoneMaskedNumber`
- `phoneCodeLength`
- `phoneCaptureStatus`
- `accountSession`
- `backendOnboardingCompletionId`
- `pendingSyncStatus`
- `lastError`

### Baby Name Step

Add `babyName` immediately after welcome.

Visible copy:

- Title: `宝宝叫什么？`
- Description: `TaTa 会用这个名字帮你记住照护时刻。`
- Input placeholder: `宝宝小名`
- Primary CTA: `继续`
- Secondary action: `先跳过`

Rules:

- Do not reuse `OnboardingNameScreen` as-is.
- Empty or skipped name is allowed; backend payload should either allow null/empty or default display name to `宝宝`.
- Name must be included in backend onboarding/profile save when the user completes phone verification and chooses save.
- Name remains in local draft only until backend save.

### Age Range Model

Replace the previous broad buckets with product-specific codes:

| Code | Visible label | Development intent |
| --- | --- | --- |
| `m0_3` | `0-3个月` | parent soothing / voice comfort |
| `m4_6` | `4-6个月` | cooing / vocal turn-taking |
| `m7_11` | `7-11个月` | name response / babbling / gesture |
| `m12_17` | `12-17个月` | first words / simple imitation |
| `m18_23` | `18-23个月` | action words / yes-no / 2-word phrase beginning |
| `m24_30` | `24-30个月` | short routine phrase / two-step care support |
| `m31_36` | `31-36个月` | simple conversation / richer routine language |

Rationale:

- CHOP speech/language milestones organize early language by Birth-3 months, 4-6 months, 7-11 months, 12-17 months, 18-23 months, and 2-3 years.
- CDC milestone checkpoints at 24 months, 30 months, and 3 years justify splitting 2-3 years into 24-30 and 31-36 for Baby Talk guidance.

Implementation note:

- Do not map these to old `zeroToSix` as the long-term product model.
- Slice 0 must determine whether backend already accepts age range strings or needs a new enum/code.
- If existing `OnboardingSnapshot` cannot represent these ranges, add a T8-specific code field or plan an enum migration; do not collapse product data into older broad buckets.

### Controller / Notifier

Create:

- `mobile/lib/features/onboarding/presentation/onboarding_flow_notifier.dart`
- `mobile/lib/features/onboarding/presentation/onboarding_flow_view_model.dart`

Responsibilities:

- Own flow state.
- Load/resume draft.
- Fetch scene/moment/utterance options from backend-backed repositories.
- Derive CTA enabled/disabled state.
- Commit selections on CTA only.
- Start the mini care-turn once.
- Mark listen state without writing a care event.
- `我说了` moves the flow to reaction prompt and must not write a reaction event.
- Reaction writes one canonical `BabyReactionType` through backend-backed care-turn persistence.
- Guard duplicate reaction saves using in-flight state and persisted event id.
- Store next support and garden trace from backend response.
- Run phone verification when the user chooses save.
- Save profile/onboarding completion after account session is available.
- Cache backend completion for route gating.

View model rule:

- `OnboardingFlowNotifier` is the single mutable source for UI flow.
- `OnboardingFlowViewModel` is read-only projection for widgets.
- No mutable ViewModel duplicate state.

### Route Entry

Modify during implementation, not now:

- `mobile/lib/app/app.dart` or the current GoRouter route file
- replace public `/onboarding` builder with `OnboardingFlowScreen`
- gate Today using backend completion cache where present
- keep old route available only behind a temporary dev flag if rollback requires it

Route behavior:

- Fresh install with no backend/local completion -> `/onboarding`
- Draft exists and no completion -> resume at latest safe step
- Saved account completion exists -> Today
- `稍后再说` chosen -> Today with local-only/pending-save banner state, not an account-saved state

## Backend Persistence Contract

T8.1 completion cannot rely only on `OnboardingRepository.completeOnboarding()`.

Backend must ultimately save:

- phone-auth user identity
- baby/profile id
- baby name
- age range code
- selected scene id
- selected moment id
- parent goal
- first utterance id/content id
- first care-turn trace
- selected `BabyReactionType`
- next support returned by backend runtime
- garden progress / trace
- onboarding completion state

Existing pieces to reuse first:

- Auth/session:
  - `POST /api/v1/auth/challenges`
  - `POST /api/v1/auth/verify`
  - `POST /api/v1/auth/refresh`
  - `POST /api/v1/consent/accept`
- Event persistence:
  - `POST /api/v1/sync/events`
  - `GET /api/v1/bootstrap`
- Garden:
  - `GET /api/v1/garden/snapshot`
- Agentic practice generation:
  - `POST /api/v1/mentor/practice/generate`

If backend already has profile/onboarding/garden write endpoints:

- Reuse them.
- Add mobile DTOs and repository methods only.
- Do not introduce duplicate storage paths.

If missing, proposed minimal backend API contract for later implementation:

```text
POST /api/v1/onboarding/complete

Request:
- babyName
- ageRangeCode
- parentGoalCode
- sceneId
- momentId
- firstUtteranceId
- firstUtteranceText
- reactionType
- persistedEventId
- nextSupportId or nextSupport payload reference
- gardenTraceId or gardenProgressVersion

Response:
- onboardingCompletionId
- accountId
- babyProfileId
- currentStage
- savedSceneId
- savedMomentId
- latestGardenSnapshot
- todayEntry
```

Mobile persistence rules:

- The local draft store is a recovery cache only.
- After verification, mobile submits or syncs the first care-turn and profile completion to backend.
- Mobile caches backend response for route gate and Today continuity.
- If network fails after auth, mark backend save as pending and show a retryable pending-sync state; do not pretend backend completion succeeded.

## Backend Scene / Moment Discovery Contract

Scene and moment options must not be hardcoded in mobile as the product source.

Slice 0 audit:

- Search backend for scene/activity/catalog/recommendation/pack/graph/agentic search APIs.
- Check practice catalog migrations and services.
- Check whether `MentorController.practiceGenerate` can be used for utterance generation only or also discovery.
- Check mobile existing API clients/DTOs for catalog/discovery.

Preferred product path:

- Backend returns scene list after baby name/age/goal context.
- Backend returns moment list after scene selection.
- Backend can use catalog, recommendation, graph, or agentic search internally.
- Mobile renders generic option cards from backend DTO/presentation model.
- Mobile does not know that 洗澡/喂奶/换尿布/穿鞋/睡前 are the product universe.

If no endpoint exists, propose minimal contract:

```text
POST /api/v1/onboarding/discovery/scenes

Request:
- babyName optional
- ageRangeCode
- parentGoalCode optional
- locale
- installationId

Response:
- scenes[]:
  - id
  - displayTitle
  - displaySubtitle
  - iconHint
  - enabled
  - reason

POST /api/v1/onboarding/discovery/moments

Request:
- babyProfileDraft
- selectedSceneId
- parentGoalCode
- locale

Response:
- moments[]:
  - id
  - sceneId
  - displayTitle
  - displaySubtitle
  - iconHint
  - enabled
  - recommendationReason
```

Fallback fixtures:

- Allowed only for tests/dev/offline degradation.
- Must be named and wired as fixtures, not product catalog.
- UI must show retry/pending when product discovery is unavailable in production.

## Backend Next Support Contract

Next Support is core intelligent product value and must come from backend agentic/runtime response on the main path.

Inputs:

- account/session when available
- baby profile or profile draft
- selected scene id
- selected moment id
- parent goal
- first utterance id/content id
- selected `BabyReactionType`
- prior trace/context when available
- locale

Response:

- `supportId`
- English utterance
- Chinese support copy
- when-to-say guidance
- audio asset URL or TTS instruction
- strategy/reason metadata if needed
- trace/garden metadata if bundled

Existing capability to audit:

- `POST /api/v1/mentor/practice/generate`
- `MentorService.generatePractice`
- Spring AI provider / agentic search mode
- any recommendation/continuity backend service

Main-path rule:

- Mobile only renders returned support.
- Mobile must not generate product next-support wording locally.
- Local fallback is allowed only for network error, dev fixture, or offline degradation.
- Fallback UI must be marked as temporary/retryable and must not be treated as the canonical product result.

## Backend Garden Progress Contract

Garden trace is not just a local success decoration.

Rules:

- The onboarding first trace is the first real garden/progress event for the user.
- Mobile may show optimistic UI after backend event acceptance or while a sync request is in flight.
- The trace must either be submitted to backend or queued with explicit pending-sync state.
- Today/Garden should read backend or synchronized progress state.
- If offline, Trace screen and Today continuity must expose pending sync.

Existing capability to audit:

- `/api/v1/sync/events`
- `/api/v1/bootstrap`
- `/api/v1/garden/snapshot`
- `/api/v1/growth/summary`
- backend projection from interaction events to garden/growth

If missing a direct progress write response, the minimal implementation path is:

1. Persist care-turn interaction via sync/events.
2. Refresh/bootstrap account runtime state.
3. Read garden snapshot or consume returned projection if backend adds it.
4. Render K Garden Trace from backend-confirmed or pending-sync projection.

## Mini Care-Turn Integration Contract

Required existing concepts:

- `care_path`
- `CarePathNotifier`
- `CarePathRepository.recordReaction()`
- `PracticeRepository.recordReaction()`
- existing `BabyReactionType`

Forbidden in T8.1:

- new reaction enum
- old onboarding `BabyReaction`
- `ScenePhraseService`
- local-only `InteractionEventPayload` as the product source of truth

Repository adaptation requirement:

- If current `PracticeRepository.recordReaction()` only writes local `InteractionEventPayload`, plan a backend-backed adapter.
- Local event payload/queue may remain as upload cache, retry buffer, and offline pending record.
- Source of truth after sync is backend persisted event.

Backend-persisted event input must include:

- user/account id from session
- baby/profile id or profile draft id
- scene id
- moment/activity id
- utterance id/content id
- reaction
- timestamp
- trace metadata
- garden metadata if available

Backend/runtime response should include:

- persisted event id or accepted event key
- duplicate status if already accepted
- next support
- garden impact/progress
- updated onboarding/session state when relevant

Flow semantics:

- F First Utterance displays backend-selected utterance.
- G Listen starts/plays audio/TTS and does not write an event.
- H `我说了` marks the care-turn as said and does not write reaction.
- I Baby Reaction writes exactly one canonical `BabyReactionType`.
- J Next Support renders backend returned support.
- K Garden Trace renders backend-confirmed or explicitly pending progress.

## Reusable Care-Turn Component Strategy

Do not keep old `OnboardingPracticeScreen` as the T8 state machine. Extract the reusable presentation loop.

Generic care-turn widgets:

- `mobile/lib/features/care_path/presentation/widgets/care_turn_utterance_panel.dart`
- `mobile/lib/features/care_path/presentation/widgets/care_turn_audio_control.dart`
- `mobile/lib/features/care_path/presentation/widgets/care_turn_said_cta.dart`
- `mobile/lib/features/care_path/presentation/widgets/care_turn_reaction_selector.dart`
- `mobile/lib/features/care_path/presentation/widgets/care_turn_next_support_panel.dart`
- `mobile/lib/features/care_path/presentation/widgets/care_turn_trace_preview.dart`

Rules:

- Onboarding uses these widgets.
- Today/Scene can later use these same widgets to start a scene/moment after onboarding.
- Widgets are not bound to onboarding.
- Widgets are not bound to a specific scene/moment.
- Widgets receive typed view models/DTOs and callbacks.
- Widgets do not query local catalog or repositories.
- UI copy comes from l10n or a presentation model.
- Audio/TTS controls are injected via view model/callback.

Onboarding-specific orchestration widgets:

- `onboarding_first_utterance_step.dart`
- `onboarding_listen_step.dart`
- `onboarding_said_step.dart`
- `onboarding_reaction_step.dart`
- `onboarding_next_support_step.dart`
- `onboarding_garden_trace_step.dart`

These are thin wrappers that bind onboarding state to generic care-turn components.

Old screen retirement strategy:

1. Add generic care-turn widgets.
2. Make new onboarding route use them.
3. Add route/tests proving old onboarding practice route is not used.
4. Delete or quarantine old `OnboardingPracticeScreen` and old session classes in a final cleanup slice.

## Responsive Layout Architecture

Use the `flutter-build-responsive-layout` approach.

Design rules:

- Layout is constraints-driven.
- Use `LayoutBuilder`, `MediaQuery.sizeOf`, safe area, `Expanded`, `Flexible`, `ConstrainedBox`, `SingleChildScrollView`, `Wrap`, and slivers where appropriate.
- Do not implement device-model branches.
- Do not hardcode behavior for `390x844` or `427x952`.
- Regression viewports are test matrix entries, not implementation conditions.
- CTA remains safe-area reachable through layout contract.
- Options and reaction chips handle text scale `1.3` with scroll/wrap, not smaller fonts.
- No text scales with viewport width.
- Text must not overlap TaTa, progress, CTA, or following content.

Reusable responsive components:

- `OnboardingResponsiveScaffold`
- `OnboardingContentColumn`
- `PinnedBottomCta`
- `AdaptiveTaTaGuideSlot`
- `ResponsiveOptionList`
- `ResponsiveUtterancePanel`
- `ResponsivePhoneCaptureForm`

Acceptance matrix:

```text
390x844 @ text scale 1.0
390x844 @ text scale 1.3
427x952 @ text scale 1.0
427x952 @ text scale 1.3
```

Required assertions:

- No overflow exceptions.
- CTA visible and tappable.
- Long Chinese copy wraps.
- Reaction chips wrap/scroll.
- Phone input and code input remain reachable with keyboard.
- TaTa guide slot does not occlude content.

## Flutter Architecture And Coding Standard

Use the `flutter-architecting-apps` approach:

- UI layer renders immutable view models.
- Notifier/ViewModel orchestrates state and user actions.
- Repository/data layer owns API/local cache.
- Backend DTOs are mapped before they reach widgets.
- Domain models do not depend on l10n.
- Repositories do not import presentation.
- Notifiers do not import concrete Flutter widgets.
- Widgets receive view models and callbacks.
- Riverpod provider overrides remain testable.

Plan a first implementation step to update:

- `mobile/AGENTS.md`

Add coding standard:

```text
- Follow feature-first structure.
- Keep domain/data/presentation separated.
- Do not put multi-step flows into a single giant widget file.
- Widgets receive view models and callbacks.
- No repository calls from widgets.
- No backend DTO leakage into widgets.
- No hardcoded viewport-specific layout branches.
- All visible copy through l10n.
- Tests required for new flow state and viewport behavior.
```

File-size guard:

- Do not put all steps into one giant `onboarding_flow_screen.dart`.
- Each complex step gets its own widget file.
- Shared care-turn widgets live under `care_path/presentation/widgets`.
- Onboarding orchestration widgets live under `onboarding/presentation/widgets/steps`.

## Motion And Transition Implementation Plan

Use Flutter implicit animations first.

Motion surfaces:

- Page transition: `AnimatedSwitcher` or route-level fade/slide with stable semantics.
- Progress advance: `TweenAnimationBuilder` or animated progress value.
- Selected card feedback: `AnimatedContainer`, check marker, small lift via transform.
- TaTa blink/nod/shell glow: static PNG plus `AnimatedOpacity`, `AnimatedScale`, or glow container.
- CTA press/haptic: existing `AppScaleButton` / `AppHaptics`.
- Feedback strip enter: `AnimatedSlide` + `AnimatedOpacity`.
- Listening pulse: subtle pulse while audio/TTS is active.
- Trace success shell glow: one-time success glow after backend accepted/pending trace.
- Phone capture warm reveal: fade/slide reveal after garden trace.

Reduced motion:

- Add a motion settings path using platform accessibility where available.
- Disable repeating pulse/scale under reduced motion.
- Keep static state changes and semantic announcements.
- Tests must verify reduced motion does not block state progression or CTA enablement.

Do not use:

- Complex Lottie pipeline in T8 unless separately approved.
- Duolingo assets.
- Text baked into TaTa image assets.

## Screen Implementation Plan

### A Welcome

Purpose:

- Set TaTa, value promise, and flow expectation.

Implementation:

- `OnboardingWelcomeStep`
- TaTa guide image: `tata_guide.png`
- CTA: start the guided flow.
- No account gate.

Backend:

- No write.
- Preload or warm up discovery repository if safe.

Tests:

- TaTa appears as guide.
- CTA enters Baby Name.
- No auth call on welcome.

### B Baby Name

Copy:

- `宝宝叫什么？`
- `TaTa 会用这个名字帮你记住照护时刻。`
- Placeholder: `宝宝小名`
- CTA: `继续`
- Secondary: `先跳过`

Implementation:

- `OnboardingBabyNameStep`
- Store name in draft.
- Allow empty/skipped name.
- Include name in backend onboarding/profile payload after save.

Tests:

- CTA enabled for non-empty input.
- `先跳过` advances and defaults later display to `宝宝`.
- Name persists through resume.

### C Baby Age

Options:

- `0-3个月`
- `4-6个月`
- `7-11个月`
- `12-17个月`
- `18-23个月`
- `24-30个月`
- `31-36个月`

Implementation:

- `OnboardingAgeStep`
- `ResponsiveOptionList`
- Persist `ageRangeCode`.
- Use backend-compatible code or plan enum migration.

Tests:

- CTA disabled until selection.
- All age ranges visible/wrappable at text scale `1.3`.
- Backend payload uses refined age code.

### D Scene

Implementation:

- `OnboardingSceneStep`
- Fetch backend scene options after age/goal context where possible.
- Render generic scene cards.
- Do not hardcode product catalog in mobile.

Fallback:

- Test/dev/offline fixture only.
- Production network failure shows retry/temporary state.

Tests:

- Renders backend scene DTO.
- CTA disabled until selection.
- Mobile does not depend on fixed scene labels.

### E Goal

Implementation:

- `OnboardingGoalStep`
- Parent goal can be local domain option if product-defined and sent to backend as code, or backend-provided if audit finds goal catalog.
- Goal influences scene/moment/next support requests.

Tests:

- Selected state feedback.
- Goal code included in discovery and final profile payload.

### F Moment

Implementation:

- `OnboardingMomentStep`
- Fetch moments from backend based on age, goal, and selected scene.
- Render generic moment cards.
- Do not hardcode fixed moments as source of truth.

Tests:

- Moment list follows selected scene.
- CTA disabled until selection.
- Moment id included in care-turn start payload.

### G First Utterance

Implementation:

- `OnboardingFirstUtteranceStep`
- Use `CareTurnUtterancePanel`.
- Utterance comes from backend discovery/runtime response.
- Show English and Chinese support through l10n/presentation model.

Tests:

- First utterance visible.
- No local catalog lookup required by widget.

### H Listen

Implementation:

- `OnboardingListenStep`
- Use `CareTurnAudioControl`.
- Plays backend audio asset or TTS instruction.
- Listening marks UI state only.

Tests:

- Listen does not write event.
- Listening pulse disabled under reduced motion but CTA still works.

### I Said

Implementation:

- `OnboardingSaidStep`
- Use `CareTurnSaidCta`.
- `我说了` advances to reaction prompt.

Tests:

- `我说了` does not write reaction.
- Step progression works.

### J Baby Reaction

Implementation:

- `OnboardingReactionStep`
- Use `CareTurnReactionSelector`.
- Write through backend-backed care-turn repository using existing `BabyReactionType`.
- Disable while save in flight.
- Guard duplicate save by persisted event id / event key.

Tests:

- Reaction writes canonical `BabyReactionType`.
- Duplicate reaction guard.
- Error state retry does not create two accepted events.

### K Next Support

Implementation:

- `OnboardingNextSupportStep`
- Use `CareTurnNextSupportPanel`.
- Render backend returned next support.
- Include when-to-say and audio/TTS if returned.

Tests:

- Next support appears after reaction save.
- No local product wording generation in main path.
- Network fallback is marked retryable/temporary.

### L Garden Trace

Implementation:

- `OnboardingGardenTraceStep`
- Use `CareTurnTracePreview`.
- Render backend-confirmed or pending-sync garden progress.
- Show trace before phone capture.

Tests:

- Trace appears before phone capture.
- Pending sync state is visible if event accepted locally but backend sync is pending.
- Today/Garden continuity reads backend/synced state.

### M Save Trace / Phone Capture

Implementation:

- `OnboardingPhoneCaptureStep`
- Use `ResponsivePhoneCaptureForm`.
- This is post-value only.
- User enters phone number.
- Mobile sends verification code through existing backend capability.
- User enters code.
- On verification success:
  - persist session/tokens through existing account repository/store
  - accept consent if current account flow requires it
  - save onboarding profile
  - sync/persist first care-turn trace
  - ensure garden progress is saved or queued
  - cache backend onboarding completion
  - enter Today

Allowed skip:

- `稍后再说` enters Today.
- It means skip account save now.
- It must not mark backend-saved profile/event/garden completion.
- It should leave a clear local pending-save state for account surface.

Tests:

- Phone challenge call happens after trace, not before value.
- Verification success enters Today after backend save/cache.
- `稍后再说` enters Today without calling verify.
- Auth errors show retryable messages.
- Resend behavior follows backend cooldown/challenge semantics.

### N Today Handoff

Implementation:

- `OnboardingTodayHandoffState` is a handoff state, not a separate marketing screen.
- Route to Today after saved or skipped state is settled.
- Today reads backend/synced progress when saved.
- Today shows local pending-save continuity if skipped.

Tests:

- Today continuity shows first trace state.
- Saved account path reads backend/synced state.
- Skipped path does not pretend account data was saved.

## TaTa Asset Strategy

T8.0 concept images are contract/reference assets only.

Do not crop:

- `docs/superpowers/specs/assets/...`
- `assets/mascot/吉祥物形象约定图*.png`
- any concept sheet

Do not use:

- Duolingo assets
- Owl/bird-like mascot shapes
- UI text baked into images

Production asset rule:

- Missing TaTa assets must be generated as production-ready transparent PNGs using Image Gen based on the T8.0 TaTa contract.
- Store final production PNGs under:
  - `mobile/assets/images/mascot/tata/`
- Add to `mobile/pubspec.yaml`:
  - `assets/images/mascot/tata/`

Required assets:

- `mobile/assets/images/mascot/tata/tata_guide.png`
- `mobile/assets/images/mascot/tata/tata_listening.png`
- `mobile/assets/images/mascot/tata/tata_success_shell.png`
- `mobile/assets/images/mascot/tata/tata_corner.png`
- optional `mobile/assets/images/mascot/tata/tata_phone_capture.png`

Prompt/source record:

- Create `docs/superpowers/specs/assets/tata-production-prompts.md` or equivalent implementation note.
- Record:
  - T8.0 reference source
  - final prompt
  - generated asset filenames
  - acceptance notes

Visual acceptance:

- Must read as a baby-friendly otter.
- Must include shell motif and teal/green scarf.
- Must not resemble owl/bird/Duolingo.
- Must work on warm paper UI.
- Transparent or Flutter-friendly clean background.
- No visible copy inside PNG.

## Copy And L10n Plan

Rules:

- All visible copy is native text.
- All visible copy goes through Chinese l10n keys.
- Production images contain no text.
- No English product copy unless it is the actual care utterance.
- Update copy firewall tests.

Forbidden visible copy:

```text
课程
第几课
学习进度
完成任务
答对
答错
发音分
lesson
quiz
```

New key family:

- `onboardingT8WelcomeTitle`
- `onboardingT8WelcomeBody`
- `onboardingT8BabyNameTitle`
- `onboardingT8BabyNameBody`
- `onboardingT8BabyNamePlaceholder`
- `onboardingT8BabyNameSkip`
- `onboardingT8AgeTitle`
- `onboardingT8AgeM0_3`
- `onboardingT8AgeM4_6`
- `onboardingT8AgeM7_11`
- `onboardingT8AgeM12_17`
- `onboardingT8AgeM18_23`
- `onboardingT8AgeM24_30`
- `onboardingT8AgeM31_36`
- `onboardingT8SceneTitle`
- `onboardingT8GoalTitle`
- `onboardingT8MomentTitle`
- `onboardingT8FirstUtteranceTitle`
- `onboardingT8ListenTitle`
- `onboardingT8SaidCta`
- `onboardingT8ReactionTitle`
- `onboardingT8NextSupportTitle`
- `onboardingT8GardenTraceTitle`
- `onboardingT8PhoneTitle`
- `onboardingT8PhoneSendCode`
- `onboardingT8PhoneVerifyCode`
- `onboardingT8PhoneLater`
- `onboardingT8TodayHandoff`

Copy firewall updates:

- Extend `mobile/test/tool/verify_care_path_copy_firewall_test.dart` or create `mobile/test/tool/verify_onboarding_t8_copy_firewall_test.dart`.
- Scan new onboarding widgets and l10n ARB entries.
- Fail on forbidden course/quiz/progress-score wording.

## Engagement Layer Boundary

T8 may lightly hint:

- `亲子英语能量`
- `小贝壳`
- `连续照护痕迹`

T8 must not implement:

- XP system
- coin economy
- streak mechanics
- leaderboard
- scoring
- pronunciation score
- full engagement dashboard

T9/T10 can expose a richer engagement layer later.

## File-Level Implementation Plan

New mobile domain/data files:

- `mobile/lib/features/onboarding/domain/models/onboarding_flow_step.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_flow_state.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_flow_options.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_age_range.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_baby_profile_draft.dart`
- `mobile/lib/features/onboarding/data/local/onboarding_draft_store.dart`
- `mobile/lib/features/onboarding/data/repositories/onboarding_backend_repository.dart`
- `mobile/lib/features/onboarding/data/repositories/onboarding_discovery_repository.dart`
- `mobile/lib/features/onboarding/data/services/onboarding_api_service.dart` if backend endpoints exist or are added.

New onboarding presentation files:

- `mobile/lib/features/onboarding/presentation/onboarding_flow_notifier.dart`
- `mobile/lib/features/onboarding/presentation/onboarding_flow_view_model.dart`
- `mobile/lib/features/onboarding/presentation/screens/onboarding_flow_screen.dart`
- `mobile/lib/features/onboarding/presentation/widgets/onboarding_flow_shell.dart`
- `mobile/lib/features/onboarding/presentation/widgets/onboarding_responsive_scaffold.dart`
- `mobile/lib/features/onboarding/presentation/widgets/onboarding_content_column.dart`
- `mobile/lib/features/onboarding/presentation/widgets/pinned_bottom_cta.dart`
- `mobile/lib/features/onboarding/presentation/widgets/adaptive_tata_guide_slot.dart`
- `mobile/lib/features/onboarding/presentation/widgets/responsive_option_list.dart`
- `mobile/lib/features/onboarding/presentation/widgets/responsive_phone_capture_form.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_welcome_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_baby_name_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_age_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_scene_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_goal_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_moment_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_first_utterance_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_listen_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_said_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_reaction_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_next_support_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_garden_trace_step.dart`
- `mobile/lib/features/onboarding/presentation/widgets/steps/onboarding_phone_capture_step.dart`

New generic care-turn widgets:

- `mobile/lib/features/care_path/presentation/widgets/care_turn_utterance_panel.dart`
- `mobile/lib/features/care_path/presentation/widgets/care_turn_audio_control.dart`
- `mobile/lib/features/care_path/presentation/widgets/care_turn_said_cta.dart`
- `mobile/lib/features/care_path/presentation/widgets/care_turn_reaction_selector.dart`
- `mobile/lib/features/care_path/presentation/widgets/care_turn_next_support_panel.dart`
- `mobile/lib/features/care_path/presentation/widgets/care_turn_trace_preview.dart`

Modified mobile files during later implementation:

- `mobile/AGENTS.md`
- `mobile/pubspec.yaml`
- `mobile/lib/app/app.dart` or current route owner
- `mobile/lib/app/providers/repository_providers.dart`
- `mobile/lib/l10n/app_zh.arb`
- generated l10n files after Flutter gen-l10n
- `mobile/lib/features/account/data/repositories/account_repository.dart` only if split challenge/verify methods are needed for onboarding phone capture.
- `mobile/lib/features/account/data/services/account_api_service.dart` only if existing DTO parsing lacks fields required by onboarding.
- `mobile/lib/features/practice/data/repositories/practice_repository.dart` only to introduce backend-backed recordReaction/sync adapter behavior.
- `mobile/lib/features/care_path/data/repositories/care_path_repository.dart` to return backend next support/garden progress.

Retired/replaced files after route replacement tests pass:

- `mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart`
- `mobile/lib/features/onboarding/presentation/screens/onboarding_name_screen.dart`
- `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart`
- `mobile/lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart`
- `mobile/lib/features/onboarding/presentation/screens/onboarding_garden_welcome_screen.dart`
- `mobile/lib/features/onboarding/presentation/onboarding_session_notifier.dart`
- `mobile/lib/features/onboarding/data/services/scene_phrase_service.dart`
- old onboarding `BabyReaction` model if no remaining imports.

Backend files only if Slice 0 finds missing APIs:

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/OnboardingController.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/OnboardingService.java`
- repository/mapper/migration files for profile/onboarding completion if no existing schema supports them.

No changes in T8.1:

- `mobile_v2`
- broad Today redesign
- broad Garden/Growth visual refactor

Asset changes during later implementation:

- Add `mobile/assets/images/mascot/tata/*.png`.
- Add pubspec asset directory.
- Add prompt/source note under docs.

Test files:

- `mobile/test/features/onboarding/onboarding_flow_notifier_test.dart`
- `mobile/test/features/onboarding/onboarding_flow_view_model_test.dart`
- `mobile/test/features/onboarding/onboarding_backend_repository_test.dart`
- `mobile/test/features/onboarding/onboarding_discovery_repository_test.dart`
- `mobile/test/features/onboarding/onboarding_flow_screen_test.dart`
- `mobile/test/features/onboarding/onboarding_responsive_layout_test.dart`
- `mobile/test/features/onboarding/onboarding_phone_capture_test.dart`
- `mobile/test/features/care_path/care_turn_widgets_test.dart`
- `mobile/test/tool/verify_onboarding_t8_copy_firewall_test.dart`
- backend tests only if missing backend endpoints are added in a later implementation slice.

## Tests

State and progression:

- Step progression follows revised path including baby name.
- Welcome not counted in progress.
- Progress semantics are correct for 11 value/proof steps.
- CTA disabled/enabled state per step.
- Selected-state feedback for age/scene/goal/moment/reaction.
- Resume restores latest safe committed step.
- Skip/resume behavior distinguishes local pending-save from backend saved.

Backend/auth:

- Phone capture appears only after trace.
- Send code calls existing challenge API.
- Verify code calls existing verify API.
- Successful verification persists session/token state.
- Successful save writes profile/onboarding completion to backend or queues explicit pending sync.
- `稍后再说` enters Today without claiming backend save.
- Auth error model renders retryable messages.
- Resend behavior follows backend challenge semantics.

Care-turn:

- TaTa appears as guide.
- First utterance visible.
- Listen does not write event.
- `我说了` does not write reaction.
- Reaction writes canonical `BabyReactionType`.
- Duplicate reaction guard.
- Backend persisted/accepted event id or event key is stored.
- Next support appears from backend response.
- Trace appears before phone capture.
- Garden trace uses backend-confirmed or pending-sync progress.

Responsive/accessibility:

- `390x844 @ 1.0`
- `390x844 @ 1.3`
- `427x952 @ 1.0`
- `427x952 @ 1.3`
- No overflow.
- CTA safe-area reachable.
- Semantic order is progress -> TaTa -> title -> content -> feedback -> CTA.
- Buttons/inputs have labels.
- Reduced motion does not block state/CTA.

Copy:

- All visible copy through l10n.
- No forbidden course/quiz/progress-score terms.
- No text in production images.

## Revised Sequencing

Slice 0: Backend/mobile API audit

- phone auth
- profile/onboarding save
- scene/moment discovery
- next support generation
- care-turn event persistence
- garden progress
- existing mobile API clients/DTOs
- missing API contract proposal

Slice 1: Architecture/coding standard

- update `mobile/AGENTS.md` coding standard
- responsive layout architecture
- feature/module file boundaries
- no giant screen file

Slice 2: Backend DTO/repository contracts

- no UI yet
- account challenge/verify split if needed
- onboarding profile repository
- discovery repository
- backend-backed care-turn event adapter
- garden/progress repository contract

Slice 3: Reusable care-turn UI components

- backend-backed view models
- generic utterance/audio/said/reaction/next/trace widgets
- component tests

Slice 4: Onboarding shell A-F

- welcome
- baby name
- age
- scene
- goal
- moment
- dynamic scene/moment from backend or marked fixture in tests

Slice 5: Mini care-turn G-L

- first utterance
- listen
- said
- reaction
- next support
- garden trace
- backend persisted reaction/next/garden

Slice 6: Phone verification registration and backend profile save

- phone number
- send code
- verify code
- account/session persistence
- onboarding profile completion
- first trace/garden save or pending sync
- Today handoff

Slice 7: Route replacement and old onboarding retirement

- swap `/onboarding`
- route gate from backend/cache completion
- retire old onboarding screens after tests pass
- rollback flag only if necessary

Slice 8: Assets/motion/l10n/copy firewall/viewport/a11y

- Image Gen TaTa production PNGs
- pubspec asset registration
- implicit animations
- reduced motion
- l10n keys
- copy firewall
- viewport/accessibility tests

Rollback plan:

- Keep route swap isolated.
- Keep old onboarding files until the new route and tests pass.
- If backend discovery/next-support is not ready, merge only Slice 0 contract proposal and pause product UI implementation.
- If phone verification works but profile completion endpoint is missing, implement repository contract and backend proposal before releasing save flow.
- If garden projection is delayed, show explicit pending-sync state rather than a fake saved garden.

## Explicitly Not In Scope

- No backend implementation during plan review.
- No Flutter code during plan review.
- No `mobile_v2`.
- No reaction contract changes.
- No new `CareReactionType`.
- No old onboarding `BabyReaction`.
- No full engagement system.
- No Garden/Growth visual refactor.
- No Duolingo assets.
- No T9/T10 features.
- No broad Today redesign.
- No broad Scene redesign.
- No mobile hardcoded product catalog as the source of truth.
- No local-only product completion for users who choose save.

## Verification Commands

Plan-review verification:

```bash
git status --short
git diff -- docs/superpowers/plans/2026-07-02-t8-1-duolingo-like-onboarding-implementation-plan.md
git diff --name-only -- mobile backend mobile_v2
```

Backend audit commands for Slice 0:

```bash
rg -n "auth/challenges|auth/verify|sync/events|bootstrap|garden/snapshot|mentor/practice/generate" backend/app-api/src/main/java mobile/lib
rg -n "onboarding|profile|baby|ageRange|scene|moment|recommendation|catalog" backend/app-api/src/main/java backend/db-migration/src/main/resources mobile/lib
```

Future implementation verification:

```bash
cd mobile && flutter test test/features/onboarding
cd mobile && flutter test test/features/care_path
cd mobile && flutter test test/tool/verify_onboarding_t8_copy_firewall_test.dart
cd mobile && flutter test --update-goldens test/features/onboarding/onboarding_responsive_layout_test.dart
cd backend && mvn test -pl app-api
```

Expected before completion:

- No Flutter analyzer errors.
- Onboarding tests pass.
- Care-turn tests pass.
- Copy firewall passes.
- Backend tests pass if API changes are implemented.
- `git status --short` shows only intended implementation files.

## GSTACK REVIEW REPORT

Review mode:

- Plan engineering review after user整改 request.
- Scope changed from mobile-local draft plan to backend-supported, agentic, responsive, reusable component plan.

Key corrections made:

- Phone capture now uses existing backend SMS verification and account/session flow when the user chooses save.
- Baby name step added to the canonical path.
- Age buckets refined to seven product ranges.
- Local draft is downgraded to temporary resume/cache/pending-sync support.
- Backend persistence, scene/moment discovery, next support, garden progress, and care-turn event contracts are explicit.
- Old `OnboardingPracticeScreen` is not reused as a state machine; useful UI is extracted into generic care-turn widgets.
- Responsive layout architecture added using constraints-driven Flutter layout.
- Flutter architecture/coding standard added, including planned `mobile/AGENTS.md` update.
- Motion plan added with implicit animations and reduced-motion handling.
- TaTa production asset strategy changed to Image Gen production PNGs, no crops from concept/reference sheets.

Open implementation risks:

- Backend may not yet expose a single onboarding profile/completion endpoint.
- Scene/moment discovery and next support may require a new backend contract or extension of Mentor practice generation.
- Current mobile `AccountRepository.signIn()` may need split challenge/verify methods for the two-step onboarding phone UI.
- Current `PracticeRepository.recordReaction()` may need a backend-backed adapter so the main product path is not local-only.

Recommendation:

- Do not start UI implementation before Slice 0 produces an API audit note and confirms which contracts already exist.
- Implement in the revised slices, with backend/repository contracts before presentation.
