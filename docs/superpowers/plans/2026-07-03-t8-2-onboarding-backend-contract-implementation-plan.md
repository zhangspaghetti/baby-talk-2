# T8.2 Onboarding Backend Contract / Implementation Plan

Date: 2026-07-03
Status: plan for review
Scope: backend contract and implementation plan only. No backend/mobile code implementation, no Flutter UI, no commit.
Source: T8.1 Slice 0 Backend/Mobile API Audit and current repository inspection.

## 1. Backend API Scope Challenge

T8.2 should add only the minimum backend capability required for T8 onboarding to become a backend-supported flow:

```text
welcome
-> baby name
-> age
-> scene discovery
-> moment discovery
-> first utterance
-> listen
-> said
-> reaction
-> backend next support
-> backend garden trace
-> phone verify/save
-> Today
```

The minimum backend scope is:

- account-owned baby/onboarding profile read and save.
- backend-owned scene/moment/starter utterance discovery.
- single-turn care-turn persistence that returns next support and garden impact.
- enough draft handling to preserve post-value phone capture without lying about saved account state.

T8.2 is not:

- a full engagement system.
- T9/T10.
- a leaderboard, score, coin, streak, or shop implementation.
- a Garden visual redesign.
- a broad Today redesign.
- a replacement of the existing reaction contract.

Important sequencing challenge:

- Existing canonical garden projection is account-owned because `interaction_events` requires `account_id` and `session_id`.
- The T8 product path wants backend next support/garden trace before phone verification.
- Therefore T8.2 must distinguish two states:
  - `draft_pending_auth`: backend can return discovery/next support and a preview garden trace tied to `installationId`.
  - `canonical_synced`: after phone verify + consent, the same care turn is persisted into `interaction_events` and becomes part of `GET /api/v1/garden/snapshot`.

Recommendation:

- Keep account-owned canonical persistence strict.
- Add a minimal onboarding draft table for pre-auth care turns, then canonicalize through the same `POST /api/v1/care-turns` endpoint after phone verification.
- Do not make anonymous draft rows visible to Garden/Today as saved progress.

## 2. Existing Backend Reuse

| Existing capability | Current evidence | T8.2 reuse decision |
| --- | --- | --- |
| Phone challenge | `POST /api/v1/auth/challenges` in `AuthConsentSyncController`; `AuthConsentSyncService.createChallenge()` returns `challengeId`, `maskedPhoneNumber`, `codeLength`, `expiresAt`. | Reuse directly. Mobile needs a two-step repository adapter. |
| Phone verify / registration | `POST /api/v1/auth/verify`; `verifyChallenge()` creates or reuses an active account and creates JWT-backed session/refresh tokens. | Reuse directly. Registration remains implicit. |
| JWT/session | `account_sessions`, `account_refresh_tokens`, `JwtTokenService`, `AuthenticatedApiClient`. | Reuse. New authenticated endpoints resolve `sid` from JWT and never trust account id from the request body. |
| Consent | `POST /api/v1/consent/accept`; sync/bootstrap require accepted consent through `requireSessionForSync()`. | Reuse. Canonical profile/care-turn writes should require accepted consent if current account flow requires it. |
| Event sync | `POST /api/v1/sync/events` and `AuthConsentSyncService.ingestEvents()`. | Reuse validation/idempotency internally; keep batch endpoint for background sync. |
| Bootstrap | `GET /api/v1/bootstrap?installationId=...`. | Reuse for account runtime restore after login and future replay reconciliation. |
| Garden snapshot | `GET /api/v1/garden/snapshot`; `GardenSnapshotService` aggregates `interaction_events`. | Reuse projection logic after canonical care-turn insert. Add an internal account-level helper for care-turn response. |
| Growth summary | `GET /api/v1/growth/summary?period=week|month|year`; `GrowthSummaryService` aggregates `interaction_events`. | Reuse for Today/Garden after saved state. No need for T8.2 write path. |
| Mentor controller | `POST /api/v1/mentor/chat`; `POST /api/v1/mentor/practice/generate`. | Reuse as runtime primitives only; do not expose mentor DTOs directly as onboarding contract. |
| Mentor service | `MentorService.generatePractice()` has catalog cache, provider fallback, and catalog write-through. | Reuse behind discovery/next-support strategies where enabled. |
| Practice catalog | `practice_spaces`, `practice_activities`, `practice_phrases`; `PracticeCatalogRepository`. | Reuse as source for stable scene/moment/utterance ids. Add query/ranking helpers rather than a separate content store. |
| Canonical reaction validation | Backend `ALLOWED_REACTION_TYPES`: `cooperating`, `hesitant`, `resisting`, `no_response`, `other`; V23 migration enforces same DB check. | Reuse exactly. Do not add or rename reaction values. |

## 3. New API 1: Baby Profile / Onboarding Completion

Endpoints:

```text
GET /api/v1/onboarding/profile
PUT /api/v1/onboarding/profile
```

Authentication:

- Requires JWT.
- Resolve `accountId` and `sessionId` from `sid`.
- Require active session.
- Require accepted consent if the existing consumer flow requires consent before account data writes.

Cardinality:

- T8.2 supports one active baby profile per account.
- Future multiple-baby support is out of scope.

### DTOs

`GET /api/v1/onboarding/profile`

- If a profile exists: `200 OK` with `OnboardingProfileResponse`.
- If no profile exists: `404 onboarding_profile_not_found`; mobile treats this as "no saved backend profile".

`PUT /api/v1/onboarding/profile` request:

```json
{
  "expectedVersion": 1,
  "babyName": "小满",
  "ageRange": "m7_11",
  "parentGoal": "calmer_care",
  "starter": {
    "sceneId": "daily_care",
    "momentId": "bath_time",
    "activityId": "bath_time",
    "utteranceId": "bath_time_warm_water",
    "phraseId": "bath_time_warm_water",
    "source": "catalog"
  },
  "onboardingState": "completed",
  "completedAt": "2026-07-03T02:00:00Z",
  "claimedCareTurnEventKey": "inst_abc:evt_onb_001",
  "clientTraceId": "onb_profile_001"
}
```

`OnboardingProfileResponse`:

```json
{
  "accountId": "acct_123",
  "babyProfileId": "babyprof_123",
  "babyName": "小满",
  "ageRange": "m7_11",
  "parentGoal": "calmer_care",
  "starter": {
    "sceneId": "daily_care",
    "momentId": "bath_time",
    "activityId": "bath_time",
    "utteranceId": "bath_time_warm_water",
    "phraseId": "bath_time_warm_water",
    "source": "catalog"
  },
  "onboardingState": "completed",
  "onboardingCompletedAt": "2026-07-03T02:00:00Z",
  "claimedCareTurnEventKey": "inst_abc:evt_onb_001",
  "version": 2,
  "createdAt": "2026-07-03T01:58:00Z",
  "updatedAt": "2026-07-03T02:00:01Z"
}
```

### Validation

- `babyName`: trim; allow blank/null only for skipped name, store display fallback separately in mobile; max 40 chars.
- `ageRange`: enum only:
  - `m0_3`
  - `m4_6`
  - `m7_11`
  - `m12_17`
  - `m18_23`
  - `m24_30`
  - `m31_36`
- `parentGoal`: small backend enum for T8:
  - `natural_opening`
  - `confident_pronunciation`
  - `calmer_care`
  - `keep_talking`
- `starter.sceneId`, `activityId`, `phraseId`: required for `completed`.
- `starter.momentId` and `starter.utteranceId`: required for T8 completed profile.
- `onboardingState`: `draft` or `completed`.
- `completedAt`: required when state is `completed`; must not be far future.
- `claimedCareTurnEventKey`: optional for draft, required before treating Today/Garden as backend-saved.
- `expectedVersion`: optional on create; required on update after mobile has seen a version. Version mismatch returns `409 version_conflict`.

### DB Table / Migration

Add `baby_profiles`:

```sql
create table baby_profiles (
    profile_id varchar(64) primary key,
    account_id varchar(64) not null unique references accounts(account_id),
    baby_name varchar(80) null,
    age_range varchar(16) not null,
    parent_goal varchar(48) null,
    starter_scene_id varchar(96) null,
    starter_moment_id varchar(96) null,
    starter_activity_id varchar(96) null,
    starter_utterance_id varchar(120) null,
    starter_phrase_id varchar(120) null,
    starter_source varchar(32) null,
    onboarding_state varchar(24) not null,
    onboarding_completed_at timestamp with time zone null,
    claimed_care_turn_event_key varchar(128) null,
    version integer not null default 1,
    created_at timestamp with time zone not null,
    updated_at timestamp with time zone not null,
    constraint chk_baby_profiles_age_range check (age_range in ('m0_3','m4_6','m7_11','m12_17','m18_23','m24_30','m31_36')),
    constraint chk_baby_profiles_parent_goal check (parent_goal is null or parent_goal in ('natural_opening','confident_pronunciation','calmer_care','keep_talking')),
    constraint chk_baby_profiles_state check (onboarding_state in ('draft','completed'))
);

create index idx_baby_profiles_account_updated_at on baby_profiles(account_id, updated_at desc);
create index idx_baby_profiles_claimed_event_key on baby_profiles(claimed_care_turn_event_key);
```

Migration notes:

- Use next valid Flyway version after reconciling the current migration stream. The repo has V22/V23 files, while `DbMigrationApplication.EXPECTED_CURRENT_VERSION` is currently pinned to `21`; update migration smoke constants in the implementation slice.
- Do not reuse `baby_profile_summary` from caregiver invite tables as canonical profile storage. It is invite/shared-context oriented.

### Backend Classes

- `OnboardingProfileController`
- `OnboardingProfileService`
- `OnboardingProfileRepository`
- `OnboardingProfileMapper.xml` if following existing MyBatis mapper style, or `JdbcTemplate` repository if the team prefers the newer small-service style.

Service responsibilities:

- Resolve account/session from JWT.
- Validate consent and ownership.
- Upsert profile idempotently per account.
- Enforce optimistic version.
- Verify starter ids exist in catalog or generated-content registry before `completed`.
- Verify `claimedCareTurnEventKey` belongs to this account/profile before linking.

### Tests

- Controller: auth required; no profile returns expected 404; PUT creates; PUT updates; version mismatch returns 409.
- Service: account ownership, consent-required behavior, completed-state validation.
- Repository: insert/update/read, unique one-profile-per-account, version increment.
- Migration: table, constraints, indexes, current version/count.

## 4. New API 2: Scene / Moment Discovery

Endpoint:

```text
POST /api/v1/onboarding/discovery
```

Authentication:

- JWT optional.
- If JWT and `babyProfileId` are present, verify ownership.
- If unauthenticated, allow only non-PII draft discovery by `installationId`, `ageRange`, `parentGoal`, and `locale`.

Rationale:

- T8 discovery happens before phone capture in the product path.
- Mobile must render backend DTOs and must not hardcode the scene/moment universe.

### DTOs

Request:

```json
{
  "installationId": "inst_abc",
  "babyProfileId": "babyprof_123",
  "ageRange": "m7_11",
  "parentGoal": "calmer_care",
  "locale": "zh-CN",
  "limit": 6,
  "clientTraceId": "onb_disc_001"
}
```

Response:

```json
{
  "discoveryTraceId": "disc_20260703_abc",
  "profileMode": "draft",
  "profileVersion": null,
  "source": "catalog_fallback",
  "scenes": [
    {
      "sceneId": "daily_care",
      "title": "日常照护",
      "rank": 1,
      "reasonCode": "age_goal_match"
    }
  ],
  "moments": [
    {
      "momentId": "bath_time",
      "sceneId": "daily_care",
      "activityId": "bath_time",
      "title": "洗澡前后",
      "sceneTag": "bath_time",
      "coachTip": "先用一句短句建立预期。",
      "rank": 1,
      "starterUtterances": [
        {
          "utteranceId": "bath_time_warm_water",
          "phraseId": "bath_time_warm_water",
          "english": "Warm water.",
          "chinese": "温温的水。",
          "pronunciation": "Warm wa-ter.",
          "difficulty": "starter",
          "source": "catalog"
        }
      ]
    }
  ],
  "starter": {
    "sceneId": "daily_care",
    "momentId": "bath_time",
    "activityId": "bath_time",
    "utteranceId": "bath_time_warm_water",
    "phraseId": "bath_time_warm_water",
    "source": "catalog"
  },
  "trace": {
    "strategy": "catalog_ranked",
    "fallbackReason": null,
    "candidateCount": 12,
    "retrievalTraceId": null,
    "mentorCorrelationId": null
  }
}
```

### Service Strategy

Create `OnboardingDiscoveryService` with ordered strategies:

1. `PracticeCatalogDiscoveryStrategy`
   - Read `practice_spaces`, `practice_activities`, and first starter phrases from `practice_phrases`.
   - Rank by `ageRange`, `parentGoal`, `scene_tag_en`, seed sort order, and content completeness.
2. `MentorGeneratedDiscoveryStrategy`
   - Optional, behind config.
   - Calls `MentorService.generatePractice()` or a smaller internal runtime method only when catalog is insufficient.
   - Generated rows must be persisted before they are returned.
3. `SafeCatalogFallbackStrategy`
   - Backend-side deterministic fallback from existing catalog rows.
   - No mobile product wording generation.

### Stable ID Rules

- For seeded content, return existing slugs:
  - `practice_spaces.slug` -> `sceneId`
  - `practice_activities.slug` -> `momentId` / `activityId`
  - `practice_phrases.slug` -> `utteranceId` / `phraseId`
- For generated content, do not return random `llm_<scene>_<uuid>` ids for onboarding discovery.
- Add a deterministic generated slug helper:
  - `gen_onb_activity_<hash(locale|ageRange|parentGoal|sceneTag|title)>`
  - `gen_onb_phrase_<hash(activitySlug|english|chinese)>`
- Do not include baby name, phone number, or other PII in generated slug inputs.
- Persist generated content into catalog before returning it, so later care-turn events and garden projections can resolve ids.

### Tests

- Controller: auth optional; authenticated profile ownership; invalid enum/locale/limit.
- Service: catalog ranking, fallback when catalog sparse, mentor unavailable fallback.
- Repository: catalog query returns stable slug ids and starter utterances.
- Stable ids: repeated same input returns same ids for generated content.
- DTO validation: mobile-facing response always has `scenes`, `moments`, and `starter`; no null starter in success response.

## 5. New API 3: Care-Turns Immediate Response

Endpoint:

```text
POST /api/v1/care-turns
```

Purpose:

- Single-turn API for onboarding and later immediate care support.
- Reuses sync internals but is not a batch sync endpoint.
- Returns next support and garden impact immediately.

### DTOs

Request:

```json
{
  "clientEventId": "evt_onb_001",
  "installationId": "inst_abc",
  "babyProfileId": "babyprof_123",
  "draftCareTurnId": "draft_turn_123",
  "sceneId": "daily_care",
  "momentId": "bath_time",
  "activityId": "bath_time",
  "utteranceId": "bath_time_warm_water",
  "phraseId": "bath_time_warm_water",
  "utteranceText": "Warm water.",
  "reactionType": "cooperating",
  "clientTimestamp": "2026-07-03T02:00:10Z",
  "trace": {
    "source": "onboarding_first_trace",
    "discoveryTraceId": "disc_20260703_abc",
    "clientTraceId": "onb_turn_001",
    "mentorCorrelationId": null,
    "deviceLocale": "zh-CN"
  }
}
```

Response:

```json
{
  "persistenceState": "canonical_synced",
  "draftCareTurnId": null,
  "eventKey": "inst_abc:evt_onb_001",
  "persistedEventId": "inst_abc:evt_onb_001",
  "duplicate": false,
  "nextSupport": {
    "kind": "utterance",
    "sceneId": "daily_care",
    "momentId": "bath_time",
    "activityId": "bath_time",
    "utteranceId": "bath_time_all_done",
    "phraseId": "bath_time_all_done",
    "english": "All done.",
    "chinese": "洗好啦。",
    "pronunciation": "All done.",
    "coachTip": "如果宝宝配合，可以马上收尾并表扬。",
    "reasonCode": "reaction_cooperating_catalog_next",
    "source": "catalog"
  },
  "gardenImpact": {
    "mode": "canonical",
    "eventKey": "inst_abc:evt_onb_001",
    "knownEventsDelta": 1,
    "knownEvents": 1,
    "coveredSpaceCount": 1,
    "currentStreakDays": 1,
    "milestonesUnlocked": ["first_opening"],
    "snapshotGeneratedAt": "2026-07-03T02:00:11Z"
  },
  "trace": {
    "strategy": "catalog_next_support",
    "fallbackReason": null,
    "mentorCorrelationId": null,
    "retrievalTraceId": null
  },
  "syncedAt": "2026-07-03T02:00:11Z"
}
```

Unauthenticated draft-mode response:

```json
{
  "persistenceState": "draft_pending_auth",
  "draftCareTurnId": "draft_turn_123",
  "eventKey": "inst_abc:evt_onb_001",
  "persistedEventId": null,
  "duplicate": false,
  "nextSupport": { "kind": "utterance" },
  "gardenImpact": {
    "mode": "preview",
    "eventKey": "inst_abc:evt_onb_001",
    "knownEventsDelta": 1,
    "knownEvents": 1,
    "coveredSpaceCount": 1,
    "currentStreakDays": 1,
    "milestonesUnlocked": ["first_opening"]
  },
  "syncedAt": "2026-07-03T02:00:11Z"
}
```

### Persistence and Idempotency

Canonical authenticated mode:

- Resolve `accountId`/`sessionId` from JWT.
- Require accepted consent.
- Verify `installationId` equals session installation id.
- Verify `babyProfileId` belongs to account.
- Build `eventKey = installationId + ":" + clientEventId`.
- Validate canonical reaction values by the same allowed set as `/sync/events`.
- Insert into `interaction_events` with `on conflict (event_key) do nothing`.
- If conflict:
  - fetch existing event by `event_key`.
  - if same account/profile/payload hash, return `duplicate=true`.
  - if owned by another account or materially different payload, return `409 event_key_conflict`.
- `persistedEventId` is `eventKey` in T8.2; no surrogate event id is required.

Draft mode:

- Used only when no JWT is present.
- Persist sanitized payload into `onboarding_care_turn_drafts`.
- Unique by `(installation_id, client_event_id)`.
- Do not write to `interaction_events`.
- Do not expose draft rows through Garden/Growth/Bootstrap.
- After phone verify + consent, mobile calls the same `POST /api/v1/care-turns` with JWT and `draftCareTurnId`; service canonicalizes and marks the draft `claimed`.

### Service Design

Add `CareTurnController`, `CareTurnService`, and a small reusable `InteractionEventIngestionService`.

Refactor target:

- Move shared validation/insert logic from `AuthConsentSyncService.validateSyncEvent()` / `insertInteractionEvent()` into `InteractionEventIngestionService`.
- `/sync/events` continues to use batch wrapper.
- `/care-turns` uses single-event wrapper and adds profile/trace/next/garden response.

Next support strategy:

1. If activity has a next phrase in catalog, use it.
2. If reaction suggests support copy but no next phrase exists, use backend safe fallback phrases by reaction type.
3. If Mentor runtime is enabled and latency budget allows, ask Mentor/Spring AI for next support and persist returned content to catalog before returning it.
4. If Mentor/Spring AI fails, return backend-side fallback and store trace reason.

### Tests

- Auth required for canonical mode.
- Draft mode succeeds without JWT but does not write `interaction_events`.
- Canonical mode writes `interaction_events`.
- Duplicate canonical request returns `duplicate=true`.
- Duplicate draft request returns same `draftCareTurnId`.
- Cross-account event key conflict returns 409.
- Invalid reaction returns `invalid_reaction_type`.
- Garden impact appears after canonical insert.
- Draft garden impact is marked `preview`.
- Mentor unavailable returns backend fallback, not mobile-generated copy.

## 6. Garden Progress Integration

Current backend Garden state:

- `GardenSnapshotService.loadSnapshot(sessionId)` resolves account id and aggregates `interaction_events`.
- It returns `knownEvents`, `coveredSpaceCount`, `currentStreakDays`, `milestones`, and `pendingEventKeys`.

T8.2 integration:

- Canonical onboarding first trace enters backend Garden by inserting exactly one `interaction_events` row through `POST /api/v1/care-turns` after auth/consent.
- Draft onboarding trace can show backend-calculated preview impact, but it is not part of Garden until canonicalized.
- `gardenImpact` in `POST /api/v1/care-turns` should be computed server-side.

Recommended helper:

- Add `GardenImpactService` or `GardenSnapshotService.loadSnapshotForAccount(accountId)` internal method.
- For canonical insert:
  - compute `before` snapshot before insert if delta is needed.
  - insert event.
  - compute `after` snapshot.
  - return delta fields plus current aggregate fields.
- For duplicate:
  - do not increment.
  - return current aggregate and `knownEventsDelta: 0`.

Today/Garden follow-up:

- Today should read backend/synced state after saved onboarding.
- Garden should continue reading `GET /api/v1/garden/snapshot`.
- Growth should continue reading `GET /api/v1/growth/summary`.
- Mobile local projection remains offline/cache only and must not be the saved source of truth.

## 7. Mentor / Agentic Runtime Integration

Discovery initial version:

- Use catalog ranking first.
- Do not require Spring AI for T8.2 launch readiness.
- Mentor/Spring AI can be added behind a feature flag once stable ids and persistence are guaranteed.

Next support initial version:

- Use catalog-next phrase first.
- Use reaction-specific backend fallback when catalog cannot provide a next utterance.
- Optionally call Mentor runtime for richer next support after the deterministic path works.

Fallback rules:

- Fallback must live in backend service code or backend catalog data.
- Mobile must not generate product wording for scenes, moments, starter utterances, next support, or garden impact.
- Every fallback response includes trace metadata:
  - `strategy`
  - `fallbackReason`
  - `candidateIds`
  - `mentorCorrelationId` when used
  - `retrievalTraceId` when RAG/agentic retrieval is used
  - `providerStatus`

Runtime risk:

- Current `MentorService.persistToCatalog()` uses random `llm_<scene>_<uuid>` activity slugs.
- T8.2 discovery/next-support must not return random generated ids as stable onboarding ids.
- Add deterministic slugging or a generated-content registry before using Mentor-generated content in care-turn events.

## 8. Mobile Impact Plan

Design only; no mobile implementation in T8.2 plan review.

Required mobile adapters:

- `AccountRepository` two-step adapter:
  - `requestPhoneChallenge(phoneNumber)`
  - `verifyPhoneChallenge(challengeId, verificationCode, installationId)`
  - keep existing `signIn()` for old surfaces until migration.
- `OnboardingBackendRepository`:
  - `loadProfile()`
  - `saveProfile()`
  - maps local draft to backend profile DTO.
- `OnboardingDiscoveryRepository`:
  - calls `POST /api/v1/onboarding/discovery`.
  - renders only backend DTOs.
  - no hardcoded scene/moment universe in mobile.
- Backend-backed `CarePathRepository.recordReaction` adapter:
  - calls `POST /api/v1/care-turns`.
  - stores `draftCareTurnId` before auth.
  - canonicalizes after phone verify.
  - consumes backend `nextSupport` and `gardenImpact`.
- Authenticated garden/growth wiring:
  - move `GardenSnapshotApiService` and `GrowthSummaryApiService` behind `AuthenticatedApiClient` or pass access token through the same refresh wrapper.
  - wire remote-first state into `GardenGrowthRepository` or a new remote-backed repository facade.

No local-only product source of truth:

- local onboarding snapshot is draft/cache only.
- local practice catalog is fixture/offline cache only.
- local garden projection is offline/cache only.
- saved account state comes from backend profile + canonical care-turn + backend garden/growth.

## 9. DB Migration Plan

Recommended migration split:

1. `V24__create_onboarding_profile_tables.sql`
2. `V25__extend_interaction_events_for_care_turns.sql`

Use actual next Flyway versions after reconciling the repo's migration constants.

### New Profile Table

Add `baby_profiles` as defined in section 3.

### Draft Care Turn Table

Add `onboarding_care_turn_drafts`:

```sql
create table onboarding_care_turn_drafts (
    draft_care_turn_id varchar(80) primary key,
    installation_id varchar(128) not null,
    client_event_id varchar(96) not null,
    event_key varchar(128) not null,
    baby_name varchar(80) null,
    age_range varchar(16) not null,
    parent_goal varchar(48) null,
    scene_id varchar(96) not null,
    moment_id varchar(96) null,
    activity_id varchar(96) not null,
    utterance_id varchar(120) null,
    phrase_id varchar(120) not null,
    utterance_text varchar(240) null,
    reaction_type varchar(32) not null,
    client_timestamp timestamp with time zone not null,
    next_support_json jsonb not null,
    garden_impact_preview_json jsonb not null,
    trace_metadata jsonb not null default '{}'::jsonb,
    status varchar(24) not null,
    claimed_account_id varchar(64) null references accounts(account_id),
    claimed_event_key varchar(128) null,
    created_at timestamp with time zone not null,
    claimed_at timestamp with time zone null,
    constraint uq_onboarding_drafts_install_event unique (installation_id, client_event_id),
    constraint chk_onboarding_drafts_reaction check (reaction_type in ('cooperating','hesitant','resisting','no_response','other')),
    constraint chk_onboarding_drafts_status check (status in ('pending','claimed','expired')),
    constraint chk_onboarding_drafts_trace_object check (jsonb_typeof(trace_metadata) = 'object')
);

create index idx_onboarding_drafts_install_created_at on onboarding_care_turn_drafts(installation_id, created_at desc);
create index idx_onboarding_drafts_status_created_at on onboarding_care_turn_drafts(status, created_at);
create index idx_onboarding_drafts_claimed_account on onboarding_care_turn_drafts(claimed_account_id, claimed_at desc);
```

Retention:

- Draft rows should expire after a short window, e.g. 7 days.
- Add cleanup job later if needed; no hard dependency for T8.2.

### Extend Interaction Events

Current `interaction_events` is not enough for care-turn metadata. Add nullable columns for backward compatibility:

```sql
alter table interaction_events
    add column if not exists baby_profile_id varchar(64) null references baby_profiles(profile_id),
    add column if not exists scene_id varchar(96) null,
    add column if not exists moment_id varchar(96) null,
    add column if not exists utterance_id varchar(120) null,
    add column if not exists utterance_text varchar(240) null,
    add column if not exists trace_metadata jsonb not null default '{}'::jsonb;

alter table interaction_events
    add constraint chk_interaction_events_trace_metadata_object
    check (jsonb_typeof(trace_metadata) = 'object');

create index if not exists idx_interaction_events_profile_time
    on interaction_events(baby_profile_id, client_timestamp desc)
    where baby_profile_id is not null;

create index if not exists idx_interaction_events_account_profile_time
    on interaction_events(account_id, baby_profile_id, client_timestamp desc)
    where baby_profile_id is not null;
```

Uniqueness / idempotency:

- Keep `event_key` as primary key.
- Keep service rule `event_key = installationId + ":" + clientEventId`.
- Optionally add `unique (installation_id, local_event_id)` after confirming historical data has no mismatch.

## 10. Security / Privacy

Phone auth:

- Use existing challenge/verify endpoints.
- Do not add password/social-login scope for T8.2.
- Verification code errors should remain retryable but not reveal account existence.

Account ownership:

- New profile and canonical care-turn writes resolve account from JWT `sid`.
- Ignore any account id sent by client.
- Verify `babyProfileId` belongs to resolved account.
- Verify `claimedCareTurnEventKey` belongs to resolved account before profile completion.

Baby profile privacy:

- Baby name is private account data.
- Do not put baby name in generated ids, logs, trace ids, slugs, or public URLs.
- Limit trace metadata to ids/status/reason codes; no raw phone numbers.

Draft privacy:

- Draft mode stores only what is necessary to support post-value phone capture.
- Draft rows are installation-bound, not public.
- Draft rows are not visible in Garden/Growth/Bootstrap until claimed.

No public leaderboard:

- T8.2 creates no leaderboard, public score, public ranking, social comparison, coin, or streak system.

Error messages:

- Use existing `ContractException` shape:
  - `timestamp`
  - `status`
  - `code`
  - `message`
  - `details`
- Messages should be actionable but not leak whether a baby profile or event exists for another account.

Consent:

- If existing consumer flow requires consent before sync/bootstrap, require accepted consent before:
  - `PUT /api/v1/onboarding/profile`
  - canonical `POST /api/v1/care-turns`
  - `GET /api/v1/onboarding/profile`
- Mobile save sequence should call `/api/v1/consent/accept` after phone verify and before canonical profile/care-turn writes when needed.

## 11. Tests

Controller tests:

- `OnboardingProfileControllerTest`
- `OnboardingDiscoveryControllerTest`
- `CareTurnControllerTest`
- auth required for profile/canonical care-turn.
- discovery draft mode allowed without JWT.
- existing error body shape preserved.

Service tests:

- `OnboardingProfileServiceTest`
- `OnboardingDiscoveryServiceTest`
- `CareTurnServiceTest`
- `GardenImpactServiceTest`
- consent-required paths.
- account ownership and profile ownership.
- draft-to-canonical care-turn claim.

Repository tests:

- `OnboardingProfileRepositoryTest`
- `OnboardingCareTurnDraftRepositoryTest`
- `CareTurnInteractionEventRepositoryTest`
- `PracticeCatalogDiscoveryRepositoryTest`

Flyway migration tests:

- Extend `DbMigrationSmokeTest` to assert:
  - `baby_profiles` exists.
  - `onboarding_care_turn_drafts` exists.
  - new `interaction_events` columns exist.
  - indexes exist.
  - canonical reaction constraints still exist.
  - `DbMigrationApplication.EXPECTED_CURRENT_VERSION` and count are current.

Auth-required tests:

- Profile GET/PUT without JWT returns 401/403 according to Spring Security setup.
- Canonical care-turn without JWT falls into draft mode only when request is allowed and explicitly marked `draft_pending_auth`.
- Canonical claim without accepted consent returns `consent_required`.

Duplicate care-turn event tests:

- Same `installationId + clientEventId` authenticated twice returns duplicate.
- Same draft request twice returns duplicate/same draft id.
- Different account using same event key returns conflict, not duplicate success.

Canonical reaction validation tests:

- All five existing values accepted.
- Unknown values rejected.
- No new reaction values added.

Garden impact projection tests:

- First canonical care-turn returns `knownEventsDelta: 1`.
- Duplicate canonical care-turn returns `knownEventsDelta: 0`.
- Milestone unlock diff is stable.
- Draft preview does not change `GET /api/v1/garden/snapshot`.

Discovery DTO validation tests:

- Response always includes at least one scene, moment, and starter when successful.
- Generated content has stable ids.
- Mentor unavailable falls back backend-side.
- Mobile does not need local scene/moment universe.

## 12. Sequencing

B1 profile/onboarding API:

- Add profile table/migration.
- Add repository/service/controller.
- Add profile tests.
- Require JWT and consent.

B2 discovery API using catalog fallback:

- Add discovery service/controller.
- Add catalog ranking repository helpers.
- Add backend fallback and stable generated id rules.
- Add discovery tests.

B3 care-turns immediate API:

- Add care-turn draft table.
- Add interaction event metadata columns.
- Extract shared single-event ingestion helper.
- Add draft and canonical `POST /api/v1/care-turns`.
- Add idempotency tests.

B4 gardenImpact integration:

- Add internal Garden impact helper.
- Return preview impact for draft and canonical impact for saved event.
- Verify duplicate/delta behavior.

B5 mentor/runtime next-support integration:

- Start with catalog-next and backend fallback.
- Add Mentor/Spring AI strategy behind config.
- Persist generated content before returning ids.
- Store trace/reason metadata.

B6 mobile repository adapter plan handoff:

- Hand off API contracts to mobile implementation.
- Implement two-step auth adapter.
- Implement onboarding profile/discovery repositories.
- Implement backend-backed care-turn adapter.
- Wire authenticated garden/growth remote services.

## 13. Explicitly Not In Scope

- No Flutter UI.
- No mobile UI changes.
- No T9/T10 engagement system.
- No leaderboard implementation.
- No score implementation.
- No coin/shell economy implementation.
- No streak implementation beyond existing Garden projection fields.
- No Garden visual redesign.
- No `mobile_v2`.
- No reaction contract value changes.
- No new reaction enum.
- No copied Duolingo assets.
- No admin-web changes.
- No commit during this plan review.

## 14. Verification Commands

Plan/doc-only verification:

```bash
git status --short
git diff -- docs/superpowers/plans/2026-07-03-t8-2-onboarding-backend-contract-implementation-plan.md
git diff --name-only -- backend mobile mobile_v2 admin-web
```

Backend focused tests for future implementation:

```bash
cd backend && mvn test -pl app-api -Dtest=OnboardingProfileControllerTest,OnboardingDiscoveryControllerTest,CareTurnControllerTest
cd backend && mvn test -pl app-api -Dtest=OnboardingProfileServiceTest,OnboardingDiscoveryServiceTest,CareTurnServiceTest,GardenImpactServiceTest
cd backend && mvn test -pl app-api -Dtest=OnboardingProfileRepositoryTest,OnboardingCareTurnDraftRepositoryTest,CareTurnInteractionEventRepositoryTest,PracticeCatalogDiscoveryRepositoryTest
```

Migration tests:

```bash
cd backend && mvn test -pl db-migration -Dtest=DbMigrationSmokeTest
```

Regression tests around reused contracts:

```bash
cd backend && mvn test -pl app-api -Dtest=AuthConsentSyncWebTest,AuthConsentSyncServiceTest,GrowthSummaryControllerTest,MentorWebTest,MentorServiceTest
```

Mobile no-change scope guard for this plan review:

```bash
git diff --name-only -- mobile mobile_v2
```

Future mobile contract verification after implementation handoff:

```bash
cd mobile && flutter test test/features/account
cd mobile && flutter test test/features/onboarding
cd mobile && flutter test test/features/care_path
cd mobile && flutter test test/features/growth
cd mobile && flutter test test/features/garden
```

## GSTACK REVIEW REPORT

Plan path:

- `docs/superpowers/plans/2026-07-03-t8-2-onboarding-backend-contract-implementation-plan.md`

API endpoints proposed:

- `GET /api/v1/onboarding/profile`
- `PUT /api/v1/onboarding/profile`
- `POST /api/v1/onboarding/discovery`
- `POST /api/v1/care-turns`

DB changes proposed:

- Add `baby_profiles`.
- Add `onboarding_care_turn_drafts` for post-value phone capture draft support.
- Extend `interaction_events` with baby profile, scene/moment/utterance, utterance text, and trace metadata columns.
- Add indexes for profile lookup, draft idempotency, and profile/event projection.
- Keep current canonical reaction check values unchanged.

Blockers / risks:

1. Strict T8 product order wants backend next support/garden trace before phone verification, but canonical Garden projection requires account/session; draft-to-canonical handoff is required unless product moves phone verification earlier.
2. Current Mentor-generated practice persistence uses random ids; onboarding discovery must add deterministic generated ids before using runtime-generated content.
3. `DbMigrationApplication` migration constants appear pinned behind existing V22/V23 files; implementation must reconcile Flyway expected version/count before adding T8.2 migrations.
4. Mobile garden/growth remote services currently lack authenticated wiring and must be adapted before Today/Garden can read saved backend state.

Git status at plan authoring:

```text
clean before writing this plan; after writing, expected doc-only change:
?? docs/superpowers/plans/2026-07-03-t8-2-onboarding-backend-contract-implementation-plan.md
```

No code implementation:

- Confirmed. This plan proposes backend/mobile work but does not implement backend code, mobile code, migrations, tests, or commits.

Waiting for review:

- Ready for user review before any T8.2 implementation starts.
