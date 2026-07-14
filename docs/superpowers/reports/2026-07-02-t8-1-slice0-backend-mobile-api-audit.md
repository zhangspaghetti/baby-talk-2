# T8.1 Slice 0 Backend/Mobile API Audit

Date: 2026-07-03
Requested report path date: 2026-07-02
Scope: backend-supported onboarding API reuse and minimum missing contracts.
Constraint: audit/report only. No Flutter UI, backend, mobile, mobile_v2, or commit changes.

## Recommendation

Proceed to Slice 1 only in limited fixture/dev-only mode, or as an API-contract/adapter preparation slice.

Do not claim "backend-supported onboarding" until backend adds the minimum contracts for baby profile/onboarding save, scene/moment discovery, and care-turn next-support response. Phone auth and existing event/garden foundations are reusable, but they are not enough to support the full T8.1 onboarding loop end to end.

## Evidence Scope

Reviewed app-api routes and services, mobile repository/service contracts, local persistence models, sync/garden projections, and mentor/Spring AI integration.

Primary files:

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncController.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/MentorProviderConfiguration.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GardenSnapshotService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GrowthSummaryService.java`
- `mobile/lib/features/account/data/services/account_api_service.dart`
- `mobile/lib/features/account/data/repositories/account_repository.dart`
- `mobile/lib/features/account/data/local/account_local_store.dart`
- `mobile/lib/features/onboarding/data/repositories/onboarding_repository.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_snapshot.dart`
- `mobile/lib/features/practice/data/repositories/practice_repository.dart`
- `mobile/lib/features/practice/domain/models/interaction_event_payload.dart`
- `mobile/lib/features/care_path/data/repositories/care_path_repository.dart`
- `mobile/lib/features/garden/data/remote/garden_snapshot_api_service.dart`
- `mobile/lib/features/growth/data/remote/growth_summary_api_service.dart`

## Existing Capability Map

| Area | Existing capability | Evidence | Reuse decision |
| --- | --- | --- | --- |
| Phone challenge | `POST /api/v1/auth/challenges` creates SMS challenge and returns `challengeId`, `maskedPhoneNumber`, `codeLength`, `expiresAt`. | `AuthConsentSyncController`, `AuthConsentSyncService.createChallenge()` | Reuse. Backend supports step 1 of two-step phone UI. |
| Phone verify/register | `POST /api/v1/auth/verify` validates challenge/code, creates account if missing, creates session, returns JWT access token and refresh token. | `AuthConsentSyncService.verifyChallenge()` | Reuse. This is both login and registration. |
| Session persistence | Mobile persists `AccountSession` in `AccountLocalStore` backed by `FlutterSecureStorage`; refresh/logout exist. | `account_local_store.dart`, `account_session.dart`, `AccountRepository` | Reuse, but onboarding needs a two-step adapter. |
| Resend semantics | No explicit `/resend`; calling `/auth/challenges` again creates a new challenge. Expired/wrong code errors carry retryable details. | `createChallenge()`, `verifyChallenge()` | Reuse as "request new challenge"; document client semantics. |
| Error model | Backend returns `{timestamp,status,code,message,details}` through `ApiExceptionHandler`. Mobile maps code/message/details into `AccountApiException`. | `ApiExceptionHandler`, `AccountApiService` | Reuse. New APIs should follow same `ContractException` shape. |
| Sync events | `POST /api/v1/sync/events` accepts batch events with `eventKey`, `localEventId`, `installationId`, `spaceId`, `activityId`, `phraseId`, `reactionType`, `clientTimestamp`. | `AuthConsentSyncController.SyncEventPayload`, `AuthConsentSyncService.ingestEvents()` | Reuse as durable event ingest foundation. Not enough for onboarding next-support response. |
| Canonical reactions | Backend allows `cooperating`, `hesitant`, `resisting`, `no_response`, `other`; mobile enum maps the same values. | `AuthConsentSyncService.ALLOWED_REACTION_TYPES`, `BabyReactionTypeWire` | Reuse. |
| Mentor chat | `POST /api/v1/mentor/chat` supports mentor response with Spring AI provider modes and authenticated/anonymous execution. | `MentorController`, `MentorService.chat()`, `SpringAiMentorProvider` | Reuse for general mentor responses, not as typed onboarding turn contract. |
| Practice generation | `POST /api/v1/mentor/practice/generate` accepts `surface`, `babyAgeMonths`, `sceneTag`, `installationId`; returns generated activities/phrases. | `MentorController`, `MentorService.generatePractice()` | Reuse as content-generation primitive. Needs wrapping/stable IDs for onboarding discovery. |
| Practice catalog storage | Backend has practice catalog tables/repository and seeds from mobile seed content. | `PracticeCatalogRepository`, `V22__create_practice_catalog_tables.sql`, `V22_1__seed_practice_catalog.sql` | Reuse internally. No public catalog/list endpoint exists. |
| Garden snapshot | `GET /api/v1/garden/snapshot` aggregates `interaction_events` into `knownEvents`, `coveredSpaceCount`, `currentStreakDays`, milestones, pending event keys. | `GardenSnapshotController`, `GardenSnapshotService` | Reuse after event sync. Mobile remote service needs auth/wiring. |
| Growth summary | `GET /api/v1/growth/summary?period=week|month|year` aggregates `interaction_events`. | `GrowthSummaryController`, `GrowthSummaryService` | Reuse after event sync. Mobile remote-first path exists only as service/test, not wired into app flow. |
| Local onboarding snapshot | Mobile stores `childDisplayName`, `ageBucket`, `approxMonths`, current stage, starter space/activity/phrase, and completion time locally. | `OnboardingRepository`, `OnboardingSnapshotStore`, `OnboardingSnapshot` | Reuse as offline cache/migration source only. |
| Local care path | `CarePathRepository.recordReaction()` calls local `PracticeRepository.recordReaction()`, then returns the next local phrase and local garden impact. | `care_path_repository.dart` | Reuse only for fixture/dev-only mode. Backend-supported mode needs remote adapter. |

## Missing Capability Map

| Area | Missing capability | Impact |
| --- | --- | --- |
| Baby profile persistence | No app-api endpoint/table found for baby profile or onboarding completion. Existing `baby_profile_summary` is invite/shared-context oriented, not a canonical profile store. | Backend cannot remember onboarding profile across installs/devices or drive backend recommendations. |
| Parent goal persistence | No mobile or backend field/contract for `parentGoal`/goal taxonomy. | Scene/moment discovery cannot use parent goal without a new contract. |
| Backend onboarding completion | No endpoint to save `childDisplayName`, `ageRange`, `approxMonths`, selected starter scene/moment/utterance, or completion timestamp. | Onboarding remains local-only. |
| Scene/moment discovery API | No public `catalog`, `recommendation`, `scene`, `moment`, `pack`, `graph`, or agentic search route returning scene/moment lists by profile + goal. | Slice 1 cannot fetch backend-supported onboarding choices. |
| Typed first utterance | Mentor practice generation can create phrases, but no endpoint returns a typed onboarding first utterance tied to baby profile, scene, and moment. | UI would need local fixtures or custom client-side mapping. |
| Reaction-based next support | No API accepts a reaction and returns next support in the same response. Existing sync returns accepted/duplicate keys only. | Onboarding cannot show backend-generated "what to try next" after first reaction. |
| Trace metadata persistence | `/sync/events` does not accept baby profile id, utterance text, source, prompt/retrieval trace ids, conversation/correlation ids, or arbitrary trace metadata. | First onboarding trace cannot be audited end to end beyond ids/reaction/timestamp. |
| Persisted event result shape | Sync response lacks per-event persisted event id, per-event duplicate flag object, next support, and garden impact. | Mobile must make extra calls and still cannot get next support. |
| Mobile two-step auth repository | `AccountApiService` supports challenge/verify separately, but `AccountRepositoryContract.signIn(phoneNumber, verificationCode)` collapses both into one call and does not persist `challengeId`/`expiresAt`. | Backend supports two-step UI, mobile repository surface does not. Needs adapter/split methods. |
| Mobile authenticated garden/growth services | `GardenSnapshotApiService` and `GrowthSummaryApiService` send no Authorization header and are not wired into `GardenGrowthRepository`. | Backend garden/growth progress exists but mobile care path still uses local projection. |
| Dynamic practice auth | `DynamicPracticeApiService.generatePractice()` accepts `accessToken` but does not send Authorization. | Dynamic practice cannot reliably use authenticated profile/context until fixed. |

## Reuse Decision

- Reuse existing auth challenge/verify/session/refresh/logout APIs for phone auth and implicit registration.
- Reuse existing app-api `ContractException` error body for all new onboarding APIs.
- Reuse `/api/v1/sync/events` for background event upload, but do not use it as the immediate onboarding next-support API.
- Reuse mentor practice generation and practice catalog persistence as backend primitives, not as the mobile-facing onboarding discovery contract.
- Reuse garden/growth projection logic after events are persisted, but add authenticated mobile wiring and/or a care-turn `gardenImpact` response for onboarding.
- Keep local onboarding/practice/care-path repositories as offline cache and fixture fallback, not as the source of truth for backend-supported onboarding.

## Minimal New API Proposal

Minimum backend work for production backend-supported onboarding:

- `GET /api/v1/onboarding/profile`
- `PUT /api/v1/onboarding/profile`
- `POST /api/v1/onboarding/discovery`
- `POST /api/v1/care-turns`

The detailed request/response sketches are below in the relevant audit sections.

## Phone Auth / Registration Audit

Backend-supported:

- `POST /api/v1/auth/challenges`
  - Request: `{ "phoneNumber": "..." }`
  - Response: `{ "challengeId", "maskedPhoneNumber", "codeLength", "expiresAt" }`
- `POST /api/v1/auth/verify`
  - Request: `{ "challengeId", "verificationCode", "installationId" }`
  - Response: `SessionResponse` with `accountId`, `sessionId`, `consentStatus`, `accessToken`, `refreshToken`, token expiry fields.
- `POST /api/v1/auth/refresh` and `POST /api/v1/auth/logout` exist.
- Verify creates an active account if the phone has no active account, so registration is implicit.

Mobile-supported:

- `AccountApiService.createChallenge()` and `verifyChallenge()` map to the backend routes.
- `AccountRepository.signIn()` currently calls `createChallenge()` and `verifyChallenge()` inside one repository method.
- `AccountLocalStore` persists session state in secure storage.
- Runtime sync/refresh uses `AuthenticatedApiClient` for account/sync routes.

Two-step onboarding phone UI:

- Backend: yes.
- Low-level mobile API service: yes.
- Current mobile repository contract: no. It needs an adapter such as `requestPhoneChallenge()` and `verifyPhoneChallenge()` or an onboarding-specific auth facade that persists `challengeId`/expiry between screens.
- Resend can be modeled as "request a new challenge" by calling `/auth/challenges` again. There is no dedicated resend idempotency or cooldown response beyond provider/contract errors.

## Baby Profile / Onboarding Completion Audit

Existing:

- Mobile local onboarding stores baby name and age bucket through `OnboardingRepository.completeOnboarding()`.
- `OnboardingSnapshot` stores:
  - `childDisplayName`
  - `ageBucket`
  - `approxMonths`
  - `currentStage`
  - `starterSpaceId`
  - `starterActivityId`
  - `starterPhraseId`
  - `consentState`
  - `birthDate`
  - `completedAt`
- Consent state is currently `localOnly`.

Missing:

- No backend baby profile/onboarding endpoint.
- No backend canonical baby profile table found.
- No parent goal field found.
- No backend completion endpoint to connect onboarding to authenticated account/session.

Minimum API needed:

```http
PUT /api/v1/onboarding/profile
Authorization: Bearer <accessToken>
Content-Type: application/json
```

Request:

```json
{
  "babyDisplayName": "宝宝",
  "ageRange": "6-12",
  "approxMonths": 9,
  "birthDate": null,
  "parentGoal": "calmer_bedtime",
  "starter": {
    "spaceId": "daily_care",
    "activityId": "bath_time",
    "phraseId": "bath_time_warm_water"
  },
  "completedAt": "2026-07-03T02:00:00Z",
  "clientTraceId": "onb_..."
}
```

Response:

```json
{
  "profileId": "babyprof_...",
  "accountId": "acct_...",
  "version": 1,
  "babyDisplayName": "宝宝",
  "ageRange": "6-12",
  "approxMonths": 9,
  "birthDate": null,
  "parentGoal": "calmer_bedtime",
  "starter": {
    "spaceId": "daily_care",
    "activityId": "bath_time",
    "phraseId": "bath_time_warm_water"
  },
  "onboardingCompletedAt": "2026-07-03T02:00:00Z",
  "updatedAt": "2026-07-03T02:00:01Z"
}
```

Companion read endpoint:

```http
GET /api/v1/onboarding/profile
Authorization: Bearer <accessToken>
```

Validation should reuse the app-api error model: `ContractException` -> `{timestamp,status,code,message,details}`.

## Scene / Moment Discovery Audit

Existing:

- Mobile `PracticeRepository.getActivityCatalog()` builds catalog/recommendation locally from seed assets and local Isar events.
- Mobile continuity chooses recent activity/starter fallback/next incomplete activity locally.
- Backend has practice catalog tables/repository and `MentorService.generatePractice()`.
- Spring AI and palace retrieval exist internally; `agentic` is a provider/runtime mode, not a public discovery route.

Missing:

- No app-api scene list endpoint.
- No app-api moment list endpoint.
- No recommendation API that takes baby profile + parent goal and returns stable scene/moment ids.
- No public catalog/list API over backend `practice_catalog` tables.
- No pack/graph/agentic search API available to mobile onboarding.

Minimum API needed:

```http
POST /api/v1/onboarding/discovery
Authorization: Bearer <accessToken>
Content-Type: application/json
```

Request:

```json
{
  "profileId": "babyprof_...",
  "ageRange": "6-12",
  "approxMonths": 9,
  "parentGoal": "calmer_bedtime",
  "limit": 6,
  "clientTraceId": "onb_disc_..."
}
```

Response:

```json
{
  "profileId": "babyprof_...",
  "profileVersion": 1,
  "scenes": [
    {
      "spaceId": "daily_care",
      "title": "日常照护",
      "reason": "适合低摩擦开场",
      "rank": 1
    }
  ],
  "moments": [
    {
      "momentId": "bath_time",
      "spaceId": "daily_care",
      "activityId": "bath_time",
      "title": "洗澡前后",
      "sceneTag": "bath_time",
      "coachTip": "先用一句短句建立预期。",
      "utterances": [
        {
          "utteranceId": "bath_time_warm_water",
          "phraseId": "bath_time_warm_water",
          "english": "Warm water.",
          "chinese": "温温的水。",
          "pronunciation": "Warm wa-ter.",
          "difficulty": "starter"
        }
      ],
      "rank": 1
    }
  ],
  "starter": {
    "spaceId": "daily_care",
    "activityId": "bath_time",
    "phraseId": "bath_time_warm_water"
  },
  "trace": {
    "source": "catalog",
    "retrievalTraceId": "retr_..."
  }
}
```

Implementation note:

- Prefer stable slugs for `spaceId`, `activityId`, and `phraseId`; event persistence depends on these ids.
- If mentor generation creates new content, persist it to the practice catalog before returning it, or return a stable generated id namespace that `/sync/events` and garden projections can resolve later.

## First Utterance / Next Support Audit

Existing:

- `MentorController` exposes:
  - `POST /api/v1/mentor/chat`
  - `POST /api/v1/mentor/practice/generate`
- `MentorService.generatePractice()` validates `surface=practice`, `babyAgeMonths`, and optional `sceneTag`, calls mentor provider, parses structured JSON, and may persist generated content to catalog.
- Spring AI runtime exists via `MentorProviderConfiguration` and `SpringAiMentorProvider`; provider modes include dev/github-models/openai and retrieval modes including rag/agentic.

Can support:

- Generating a candidate first utterance, if wrapped behind onboarding discovery/first-turn contract.
- General mentor coaching.

Cannot support yet:

- A typed onboarding "first utterance" endpoint tied to saved baby profile + parent goal.
- Reaction-based "next support" after a care turn.
- Atomic event persistence + next support + garden impact in one response.

Minimum API needed:

```http
POST /api/v1/care-turns
Authorization: Bearer <accessToken>
Content-Type: application/json
```

Request:

```json
{
  "clientEventId": "evt_...",
  "installationId": "inst_...",
  "profileId": "babyprof_...",
  "spaceId": "daily_care",
  "activityId": "bath_time",
  "phraseId": "bath_time_warm_water",
  "utteranceText": "Warm water.",
  "reactionType": "cooperating",
  "clientTimestamp": "2026-07-03T02:00:10Z",
  "trace": {
    "source": "onboarding_first_trace",
    "discoveryTraceId": "retr_...",
    "mentorCorrelationId": "corr_..."
  }
}
```

Response:

```json
{
  "eventKey": "inst_...:evt_...",
  "persistedEventId": "inst_...:evt_...",
  "duplicate": false,
  "nextSupport": {
    "kind": "utterance",
    "spaceId": "daily_care",
    "activityId": "bath_time",
    "phraseId": "bath_time_all_done",
    "english": "All done.",
    "chinese": "洗好啦。",
    "coachTip": "如果宝宝配合，可以马上收尾并表扬。",
    "reason": "reaction_cooperating"
  },
  "gardenImpact": {
    "knownEvents": 1,
    "coveredSpaceCount": 1,
    "currentStreakDays": 1,
    "milestonesUnlocked": ["first_practice"]
  },
  "syncedAt": "2026-07-03T02:00:11Z"
}
```

Alternative:

- Extend `/api/v1/sync/events` with `results[]`, `includeNextSupport`, and `includeGardenImpact`.
- This is less clean for onboarding because the current endpoint is batch-oriented. A single-turn endpoint is clearer for immediate UI response while keeping `/sync/events` for background sync.

## Care-Turn Event Persistence Audit

Existing:

- Mobile `InteractionEventPayload` and backend `SyncEventPayload` align on:
  - `eventKey`
  - `localEventId`
  - `installationId`
  - `spaceId`
  - `activityId`
  - `phraseId`
  - `reactionType`
  - `clientTimestamp`
- Backend persists into `interaction_events` with account/session/installation context.
- Backend response returns `acceptedEventKeys`, `duplicateEventKeys`, counts, and `syncedAt`.
- Mobile `PracticeRepository.recordReaction()` appends a pending local event.
- Mobile `AccountRepository.refreshRuntimeState()` uploads pending records and marks accepted/duplicate keys as synced.

Missing:

- Explicit `babyProfileId`.
- Utterance text/version.
- Trace metadata.
- Per-event persisted result object.
- Next support.
- Garden impact/delta.
- Immediate backend-backed behavior from `PracticeRepository.recordReaction()`; it is currently local-first and uploaded later.

Decision:

- Reuse `/sync/events` for background/local-first upload.
- Add `POST /api/v1/care-turns` for onboarding and other immediate-response experiences.

## Garden Progress Audit

Existing backend:

- `GET /api/v1/garden/snapshot` requires JWT `sid` and aggregates `interaction_events`.
- `GET /api/v1/growth/summary` requires JWT `sid` and aggregates `interaction_events`.
- Garden snapshot returns `knownEvents`, `coveredSpaceCount`, `currentStreakDays`, milestones, and pending event keys.
- Growth summary returns total events, unique phrases/activities, cooperating count, first/last event, practiced days, and window timestamps.

Existing mobile:

- `GardenGrowthRepository` builds garden progress from local practice events and seed content.
- `GardenSnapshotApiService` exists but sends no Authorization header.
- `GrowthSummaryApiService` exists but sends no Authorization header.
- `GrowthStatsService.remoteFirst()` exists and is covered by tests, but app provider wiring still exposes local garden growth repository.

Can onboarding first trace become real garden progress?

- Yes, if the user has an authenticated accepted session and the event is persisted through `/sync/events` or the proposed `/care-turns`.
- Not immediately with current mobile onboarding because the onboarding trace is local-only and garden progress is local-projected.
- No existing endpoint returns garden impact as part of event ingestion.

Minimum change:

- Use authenticated API client for garden/growth remote services.
- Either call garden snapshot after care-turn persistence or return `gardenImpact` directly from `POST /api/v1/care-turns`.

## Mobile Repository Impact

Reusable:

- `AccountApiService` low-level challenge/verify/refresh/logout/consent/sync/bootstrap methods.
- `AuthenticatedApiClient` token refresh wrapper.
- `AccountLocalStore` and `AccountSession` secure token persistence.
- `PracticeRepository` seed catalog and local pending event store as offline cache.
- `InteractionEventPayload` reaction/event id model.
- `MentorApiService` authenticated chat path.

Needs adapter:

- `AccountRepositoryContract` should expose two-step auth for onboarding:
  - `requestPhoneChallenge(phoneNumber)`
  - `verifyPhoneChallenge(challengeId, code, installationId)`
  - optional `resendPhoneChallenge(phoneNumber)` as a wrapper over request challenge.
- `OnboardingRepository` needs a backend-backed adapter that saves/loads profile and keeps local snapshot as cache.
- `PracticeRepository` needs a remote discovery adapter or separate `OnboardingDiscoveryRepository`.
- `CarePathRepository` needs a backend-backed `recordReaction` path that consumes `POST /api/v1/care-turns` and updates next support/garden impact from response.
- `GardenGrowthRepository` needs a remote snapshot adapter or remote-first mode.

Cannot stay local-only for backend-supported onboarding:

- `OnboardingRepository.completeOnboarding()`
- `PracticeRepository.getActivityCatalog()` as the sole discovery source
- `PracticeRepository.recordReaction()` as the sole event write path
- `CarePathRepository.recordReaction()` as local next-phrase selection
- `GardenGrowthRepository.buildSnapshot()` as the sole garden projection

Current `PracticeRepository.recordReaction()` status:

- Not backend-backed at call time.
- It validates against local activity snapshot and appends a pending local event.
- Backend upload happens later through account runtime sync.

`CarePathRepository` required change:

- Accept backend `nextSupport` and `gardenImpact` response.
- Preserve local pending-event fallback for offline/fixture mode.
- Stop deriving production next support only from local next phrase.
- Ensure returned event ids are stable and can be reconciled with local event log.

## Backend Impact

Required additions:

- New onboarding profile storage:
  - table such as `baby_profiles` or `onboarding_profiles`
  - account/session ownership
  - display name, age range, approx months, optional birth date
  - parent goal taxonomy
  - starter ids
  - version/updated timestamps
- New controller/service:
  - `GET /api/v1/onboarding/profile`
  - `PUT /api/v1/onboarding/profile`
  - `POST /api/v1/onboarding/discovery`
- New care-turn endpoint:
  - `POST /api/v1/care-turns`
  - persist event idempotently using `installationId:clientEventId`
  - optionally extend `interaction_events` with `profile_id`, `utterance_text`, and `trace_metadata`
  - return `duplicate`, `nextSupport`, and `gardenImpact`
- Discovery should reuse:
  - session/consent validation from `AuthConsentSyncService`
  - practice catalog tables/repository
  - mentor/Spring AI provider for generation/ranking when needed
  - existing error model
- Garden projection can reuse existing aggregation over `interaction_events`; add a small delta/projection helper if returning `gardenImpact` from care-turn endpoint.

Recommended constraints:

- Keep onboarding discovery response bounded (`limit <= 20`).
- Keep ids stable and slug-like where possible.
- Treat generated content as persisted catalog content before it appears in event contracts.
- Reuse canonical reaction values exactly.

## Risk List

| Priority | Risk | Mitigation |
| --- | --- | --- |
| P1 | No backend baby profile/onboarding save blocks backend-supported onboarding. | Add profile endpoint/table before production Slice 1. |
| P1 | No scene/moment discovery API means UI would rely on fixtures/local catalog. | Add discovery endpoint or explicitly scope Slice 1 to dev-only fixture mode. |
| P1 | No reaction-based next-support API means first reaction cannot get backend support. | Add `POST /api/v1/care-turns` or equivalent sync extension. |
| P1 | Generated practice content may not have stable ids compatible with event sync/garden. | Persist generated catalog rows and return stable ids before allowing reactions. |
| P2 | Mobile auth repository collapses challenge+verify and does not persist challenge id/expiry. | Add an onboarding auth adapter around `AccountApiService`. |
| P2 | Garden/growth remote services are unauthenticated and not wired into app projection. | Move them behind `AuthenticatedApiClient` and remote-first repository path. |
| P2 | `DynamicPracticeApiService` accepts `accessToken` but does not send Authorization. | Use `AuthenticatedApiClient` or add auth headers before relying on dynamic generation. |
| P2 | `/sync/events` is batch/background-oriented and cannot return immediate UI support. | Keep it for background sync; add single-turn endpoint. |
| P3 | Parent goal taxonomy is undefined. | Define a small enum before API implementation. |
| P3 | Multiple babies per account are not modeled. | Decide v1 cardinality: one active baby profile per account, with versioning. |

## GSTACK Review Report

Review mode: read-only API/design review. No code fix pass because the user explicitly requested audit only and prohibited code changes/commits.

Findings:

- P1: Backend lacks canonical baby profile/onboarding persistence. Any "backend-supported onboarding" claim would be false until a profile contract exists.
- P1: Backend lacks mobile-facing discovery contract for scene/moment lists by baby profile + parent goal. Existing mentor practice generation is a primitive, not the onboarding API.
- P1: Existing event sync cannot provide reaction-based next support or garden impact. It only acknowledges accepted/duplicate batch keys.
- P2: Mobile can call challenge/verify separately at service level, but the repository/presentation contract currently models a one-shot sign-in. Two-step onboarding auth needs a repository adapter.
- P2: Mobile garden/growth remote services are present but unauthenticated and not wired into `GardenGrowthRepository`.
- P2: Dynamic practice service has an `accessToken` parameter that is not sent in request headers, so authenticated dynamic generation is not currently reliable.

Verification performed:

- Enumerated app-api controller routes.
- Reviewed auth/session/sync DTOs and service behavior.
- Reviewed mobile account API/repository/session persistence.
- Reviewed local onboarding snapshot and repository.
- Reviewed practice/care-path event flow.
- Reviewed mentor controller/service and Spring AI provider configuration.
- Reviewed garden/growth controllers/services and mobile remote services.
- No tests were run; this was a source audit and documentation-only deliverable.

## Final Decision

Status: proceed with limited fixture/dev-only mode, or pause Slice 1 production implementation until backend API is added.

Backend-supported Slice 1 is blocked by:

- Missing onboarding profile save/read API.
- Missing scene/moment discovery API.
- Missing care-turn event + next support + garden impact API.

Slice 1 can still proceed safely if explicitly scoped to:

- mobile auth adapter work against existing phone challenge/verify APIs,
- local/fixture discovery,
- local care-path/garden behavior,
- and implementation behind a backend-contract feature flag.
