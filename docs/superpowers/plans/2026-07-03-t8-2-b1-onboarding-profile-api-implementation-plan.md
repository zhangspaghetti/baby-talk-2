# T8.2 B1 Onboarding Profile API Implementation Plan

Date: 2026-07-03
Status: waiting for review
Scope: first backend slice only.

This plan narrows the approved T8.2 Backend Contract / Implementation Plan to B1:

```text
GET /api/v1/onboarding/profile
PUT /api/v1/onboarding/profile
baby_profiles table
```

No code should be implemented from this document until it is reviewed.

## Scope Decision

B1 creates the authenticated account-owned baby profile contract. It does not create discovery, care-turn persistence, Garden changes, mobile UI, or mobile repository wiring.

B1 implementation remains only:

```text
GET /api/v1/onboarding/profile
PUT /api/v1/onboarding/profile
baby_profiles table
accepted session resolver
profile controller/service/repository/mapper/tests
```

B1 explicitly does not implement:

```text
discovery API
care-turns API
mentor/chat security hardening
PracticeCatalogRepository migration
Flutter UI
mobile repository wiring
Garden/Growth changes
```

This document still records the cross-slice gates because B2/B3 can drift if those boundaries are left implicit.

The slice is intentionally small:

```text
Bearer JWT
  -> sid claim
  -> accepted account session
  -> one account-owned baby profile row
  -> read/update response with optimistic version
```

Data flow:

```text
Mobile authenticated request
        |
        v
OnboardingProfileController
        |
        | extracts sid from JwtAuthenticationToken
        v
OnboardingProfileService
        |
        | reuses account/session/consent rules
        v
AuthConsentSyncService accepted-session resolver
        |
        | returns accountId/sessionId from server state
        v
OnboardingProfileRepository
        |
        v
baby_profiles
```

## Current Backend Audit

### Controller / Service / Repository / Mapper Style

Current app-api code is mostly flat packages:

- Controllers: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/*Controller.java`.
- Services/repositories/mappers: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/*`.
- MyBatis XML mappers: `backend/app-api/src/main/resources/mapper/service/*Mapper.xml`.

The consumer auth/sync path uses:

- `AuthConsentSyncController` as a `@RestController` under `/api/v1`.
- `AuthConsentSyncService` for transactional validation and business rules.
- `AuthConsentSyncRepository` as a thin `@Repository` wrapper.
- `AuthConsentSyncMapper` plus `AuthConsentSyncMapper.xml` for SQL.

There is also a smaller `JdbcTemplate` repository style in `PracticeCatalogRepository`, but B1 touches account-owned mutable profile state with optimistic update semantics. Recommendation: follow the auth/sync MyBatis style for B1, not the catalog `JdbcTemplate` style.

### Cross-Slice Note: Practice Catalog MyBatis Migration

B1 does not migrate `PracticeCatalogRepository` because B1 only implements baby profile read/write and does not read the practice catalog.

B2 discovery will depend on practice catalog queries, ranking, and starter utterance lookup. Before B2 starts, catalog repository style must be made deliberate instead of allowing a second wave of ad hoc SQL.

Recommended B2 setup options:

- Add `PracticeCatalogDiscoveryMapper.java`.
- Add `PracticeCatalogDiscoveryMapper.xml`.
- Add `PracticeCatalogDiscoveryRepository`.

Alternative:

- Migrate the existing `PracticeCatalogRepository` from `JdbcTemplate` to MyBatis.

Do not continue expanding new `JdbcTemplate` SQL inside the discovery API. The B2 plan must include this prerequisite:

```text
B2.0 Practice catalog MyBatis migration / discovery repository setup
```

### Auth / Session Parsing

Current controller pattern:

- Authenticated controllers receive `JwtAuthenticationToken`.
- Controllers extract `sid` with `authentication.getToken().getClaimAsString("sid")`.
- They do not accept `accountId` from request bodies.

Current JWT shape:

- Consumer access token subject is `accountId`.
- Consumer access token carries `sid` and `rtid`.
- Access tokens are validated as `type=access` and must include `sid` and `rtid`.

Current security behavior:

- `/api/v1/auth/**`, share/invite/download/health/info/error, and `/api/v1/share-links` are permit-all.
- `/api/v1/mentor/chat` is also currently permit-all. This is repo state and a security risk, not target state.
- Everything else is authenticated by default.
- A guard filter validates `(subject accountId, sid, rtid)` against server session/refresh-token state on every authenticated request.

B1 rule:

- Do not add `/api/v1/onboarding/profile` to permit-all.
- Controller passes only `sid` to the service.
- Service resolves `accountId` from the server-side session row, not from JWT subject alone and never from the request body.

### Cross-Slice Security Note: Mentor Chat Must Not Remain Permit-All

`/api/v1/mentor/chat` is currently permit-all. That is a current repository fact, not the desired security posture.

`mentor/chat` is a high-flexibility AI/mentor surface and is not suitable as a long-term anonymous endpoint. The long-term target is that `/api/v1/mentor/chat` requires an authenticated accepted consumer session.

Future hardening should include:

- Remove `/api/v1/mentor/chat` from the permit-all list.
- Have the controller read `JwtAuthenticationToken`.
- Have the service resolve the session through:

```java
requireAcceptedConsumerSession(sessionId, "mentor_chat")
```

- Add unauthorized, `consent_required`, and accepted-session tests.
- If the product still needs anonymous AI ability, add a separate typed and limited endpoint. Do not keep open-ended chat anonymously exposed.

B1 does not modify `/api/v1/mentor/chat`, but this is a B2/B3 security gate before mentor runtime is treated as production-safe.

### Consent-Required Rule

Current `AuthConsentSyncService.requireSessionForSync()` enforces:

- deleted account/session -> `410 account_deleted`
- revoked session/consent -> `409 consent_revoked`
- missing accepted consent -> `409 consent_required`
- inactive session -> `401 invalid_session`

Growth/Garden-style authenticated account data reads already route through this accepted-session rule. B1 should require accepted consent for both `GET` and `PUT` because baby profile data is private account data.

Implementation note:

- `requireSessionForSync()` is currently private and its messages mention bootstrap/sync.
- Add a small public/package-visible resolver method on `AuthConsentSyncService`, for example `requireAcceptedConsumerSession(String sessionId, String purpose)`, returning a session view with `accountId`, `sessionId`, `installationId`, and `latestConsentStatus`.
- Keep the same status/code semantics as sync/bootstrap, with profile-specific messages.
- Do not duplicate session SQL in `OnboardingProfileService`.

Session view:

```java
public record ConsumerSessionView(
    String accountId,
    String sessionId,
    String installationId,
    String latestConsentStatus
) {}
```

Use this accepted-session resolver for:

```text
GET /api/v1/onboarding/profile
PUT /api/v1/onboarding/profile
POST /api/v1/care-turns canonical_synced mode
GET /api/v1/garden/snapshot
GET /api/v1/growth/summary
POST /api/v1/mentor/chat after security hardening
```

Do not use this resolver for:

```text
pre-auth onboarding draft next-support
anonymous draft discovery
auth/challenges
auth/verify
```

The pre-auth draft path must not fake a session. A future care-turn access boundary can model the split explicitly:

```java
sealed interface CareTurnAccessContext {
  record Canonical(ConsumerSessionView session) implements CareTurnAccessContext {}
  record Draft(String installationId, String clientEventId) implements CareTurnAccessContext {}
}
```

This boundary is documented for B3. B1 does not need to implement `CareTurnAccessContext`.

### ContractException / Error Model

Current app-api error model:

```json
{
  "timestamp": "2026-07-03T00:00:00Z",
  "status": 409,
  "code": "consent_required",
  "message": "当前账号尚未完成同意，不能保存宝宝档案。",
  "details": {
    "retryable": true
  }
}
```

Existing pieces:

- `ContractException` stores `HttpStatus`, stable `code`, message, and immutable `details`.
- `ApiExceptionHandler` maps it to `{timestamp,status,code,message,details}`.
- Bean validation failures return `400 validation_failed` with `details.fields`.
- Security failures use the same envelope from `AppSecurityConfig.writeError()`.

B1 must not add a new error envelope.

### Care-Turns Is Not Mentor Chat

Mentor/Spring AI may be reused internally as an implementation detail, but `/api/v1/care-turns` is not a chat endpoint.

```text
Mentor/Spring AI = engine
/api/v1/mentor/chat = open-ended chat steering wheel
/api/v1/care-turns = bounded product transaction for a care moment
```

`/api/v1/mentor/chat`:

```text
- general mentor chat
- free-form user message
- high-flexibility AI surface
- should require authenticated accepted session
- suitable for logged-in Ask TaTa / Ask Mentor use cases
- not the onboarding pre-auth next-support interface
```

`/api/v1/care-turns`:

```text
- typed care-turn product transaction
- accepts scene/moment/utterance/reaction ids
- persists or drafts a care-turn
- returns typed nextSupport
- returns gardenImpact or preview gardenImpact
- may internally call Mentor/Spring AI
- mobile never sends free-form prompt to this endpoint
- suitable for onboarding first care-turn and later scene care-turn loop
```

Internal AI reuse does not make care-turns equivalent to mentor/chat. `care-turns` exposes a constrained product contract; `mentor/chat` exposes open-ended conversation.

### Pre-Auth Onboarding Next Support Boundary

When onboarding needs next support before phone verification, mobile must not call `/api/v1/mentor/chat`. It must call the future typed `/api/v1/care-turns` endpoint in `draft_pending_auth` mode.

`/api/v1/care-turns` draft mode:

- Can be used before login.
- Is only for the onboarding first care-turn.
- Does not accept a free-text chat prompt.
- Does not accept arbitrary user-provided AI prompts.
- Accepts a typed care-turn payload:
  - `installationId`
  - `clientEventId`
  - `ageRange`
  - `parentGoal`
  - `sceneId`
  - `momentId`
  - `activityId`
  - `utteranceId`
  - `phraseId`
  - `reactionType`
  - `discoveryTraceId`
- May internally call Mentor/Spring AI runtime.
- Returns typed `nextSupport` and preview `gardenImpact`.
- Writes only `onboarding_care_turn_drafts`.
- Does not write canonical `interaction_events`.
- Canonicalizes only after phone verification plus accepted consent.

Mobile must not directly call `/api/v1/mentor/chat` for this pre-auth next-support moment.

```text
mentor/chat = authenticated general mentor surface
care-turns draft mode = bounded pre-auth onboarding support surface
```

### Current Flyway State

Current migration files:

- `backend/db-migration/src/main/resources/db/migration` contains 22 SQL files.
- The latest migration file is `V23__reaction_contract_clean_cutover.sql`.
- There is also `V22_1__seed_practice_catalog.sql`, which Flyway treats as version `22.1`.

Current migration application constants:

```java
static final String EXPECTED_CURRENT_VERSION = "21";
static final int EXPECTED_APPLIED_MIGRATION_COUNT = 19;
```

These constants are stale relative to the migration directory. B1 must not add another migration on top of a stale smoke expectation without reconciling it.

Expected handling if no other migration lands first:

- Current reconciled state before B1: current version `23`, applied versioned migration count `22`.
- Add B1 as `V24__create_baby_profiles.sql`.
- Update `DbMigrationApplication.EXPECTED_CURRENT_VERSION` to `"24"`.
- Update `DbMigrationApplication.EXPECTED_APPLIED_MIGRATION_COUNT` to `23`.

If another migration lands first, use the next Flyway version and recalculate both constants from the actual migration stream.

## DB Migration Plan

Migration file:

```text
backend/db-migration/src/main/resources/db/migration/V24__create_baby_profiles.sql
```

Use this version only if the current stream is still through V23 when B1 starts.

### Table

```sql
create table baby_profiles (
    profile_id varchar(64) primary key,
    account_id varchar(64) not null references accounts(account_id),
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
    version integer not null default 1,
    created_at timestamp with time zone not null,
    updated_at timestamp with time zone not null,

    constraint uq_baby_profiles_account_id unique (account_id),
    constraint chk_baby_profiles_baby_name_len
        check (baby_name is null or char_length(baby_name) <= 40),
    constraint chk_baby_profiles_age_range
        check (age_range in (
            'm0_3',
            'm4_6',
            'm7_11',
            'm12_17',
            'm18_23',
            'm24_30',
            'm31_36'
        )),
    constraint chk_baby_profiles_parent_goal
        check (parent_goal is null or parent_goal in (
            'natural_opening',
            'confident_pronunciation',
            'calmer_care',
            'keep_talking'
        )),
    constraint chk_baby_profiles_state
        check (onboarding_state in ('draft', 'completed')),
    constraint chk_baby_profiles_version_positive
        check (version >= 1),
    constraint chk_baby_profiles_starter_source
        check (starter_source is null or starter_source in ('catalog', 'generated')),
    constraint chk_baby_profiles_completed_shape
        check (
            onboarding_state <> 'completed'
            or (
                parent_goal is not null
                and starter_scene_id is not null
                and starter_moment_id is not null
                and starter_activity_id is not null
                and starter_utterance_id is not null
                and starter_phrase_id is not null
                and starter_source is not null
                and onboarding_completed_at is not null
            )
        )
);

create index idx_baby_profiles_updated_at
    on baby_profiles(updated_at desc);

create index idx_baby_profiles_state_updated_at
    on baby_profiles(onboarding_state, updated_at desc);
```

### Cardinality

B1 supports exactly one profile row per account. That satisfies "one active baby profile per account" without adding unused lifecycle flags.

Do not add multiple-baby lifecycle state in B1. If future multi-baby support needs inactive rows, that future slice can replace `uq_baby_profiles_account_id` with a partial unique index over an explicit active-state column.

### Constraints

Age range enum:

```text
m0_3
m4_6
m7_11
m12_17
m18_23
m24_30
m31_36
```

Parent goal enum:

```text
natural_opening
confident_pronunciation
calmer_care
keep_talking
```

Onboarding state:

```text
draft
completed
```

Optimistic version:

- `version` starts at `1`.
- Every successful update increments by one.
- Repository update must include `where account_id = ? and version = ?`.
- Create races resolve through the unique account constraint and return a stable `409 version_conflict`.

## API Contract

Base route:

```text
/api/v1/onboarding/profile
```

Authentication:

- JWT required for both endpoints.
- Accepted consent required for both endpoints.
- `accountId` is resolved from server-side session state.
- No request field may override ownership.

### GET /api/v1/onboarding/profile

Success:

```json
{
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
  "version": 2,
  "createdAt": "2026-07-03T01:58:00Z",
  "updatedAt": "2026-07-03T02:00:01Z"
}
```

Notes:

- Do not include `accountId` in the response unless a current mobile contract requires it. The caller already owns the account through JWT.
- Return `babyName` only on this authenticated account-owned endpoint.
- Do not include care-turn fields in B1.

No profile:

```http
404 Not Found
```

```json
{
  "timestamp": "...",
  "status": 404,
  "code": "onboarding_profile_not_found",
  "message": "当前账号还没有宝宝档案。",
  "details": {}
}
```

Mobile should treat this as "no saved backend profile".

### PUT /api/v1/onboarding/profile

Request:

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
  "clientTraceId": "onb_profile_001"
}
```

Create request:

- `expectedVersion` must be absent for first create.
- If the profile already exists and `expectedVersion` is absent, return `400 expected_version_required`.

Update request:

- `expectedVersion` is required once the client has seen a profile version.
- If the row version does not match, return `409 version_conflict`.

Success response:

```json
{
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
  "version": 2,
  "createdAt": "2026-07-03T01:58:00Z",
  "updatedAt": "2026-07-03T02:00:01Z"
}
```

### Validation

Service-level validation:

- `babyName`: trim; blank becomes `null`; max 40 Unicode code points; never log it.
- `ageRange`: required and must be one of the seven B1 age ranges.
- `parentGoal`: optional for `draft`; required for `completed`; must be one of the four B1 goals when present.
- `onboardingState`: required, `draft` or `completed`.
- `starter`: optional for `draft`; required for `completed`.
- Completed starter requires `sceneId`, `momentId`, `activityId`, `utteranceId`, `phraseId`, and `source`.
- `starter.source`: `catalog` or `generated`.
- `completedAt`: required for `completed`; must not be more than five minutes in the future.
- `clientTraceId`: optional, max 96, slug-like; must not contain baby name or phone number.

Validation failure:

```http
400 Bad Request
```

Use either:

- `validation_failed` from Bean Validation for structural request errors, or
- a specific `ContractException` code for cross-field service rules, such as `completed_profile_missing_starter`.

Version conflict:

```http
409 Conflict
```

```json
{
  "timestamp": "...",
  "status": 409,
  "code": "version_conflict",
  "message": "宝宝档案已在其他地方更新，请重新加载后再保存。",
  "details": {
    "expectedVersion": 1,
    "currentVersion": 2
  }
}
```

Do not include `babyName` in conflict details.

Consent required:

```http
409 Conflict
```

```json
{
  "timestamp": "...",
  "status": 409,
  "code": "consent_required",
  "message": "当前账号尚未完成同意，不能读取或保存宝宝档案。",
  "details": {
    "retryable": true
  }
}
```

## Backend Implementation Files

Proposed new files:

```text
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/OnboardingProfileController.java
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/OnboardingProfileService.java
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/OnboardingProfileRepository.java
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/OnboardingProfileMapper.java
backend/app-api/src/main/resources/mapper/service/OnboardingProfileMapper.xml
backend/db-migration/src/main/resources/db/migration/V24__create_baby_profiles.sql
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/OnboardingProfileControllerTest.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/OnboardingProfileServiceTest.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/OnboardingProfileRepositoryTest.java
```

Proposed existing-file edits:

```text
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/AbstractIntegrationTest.java
backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java
backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java
```

### Controller

`OnboardingProfileController`:

- `@RestController`
- `@Validated`
- `@RequestMapping("/api/v1/onboarding/profile")`
- `GET` method reads `sid` from `JwtAuthenticationToken`.
- `PUT` method reads `sid` and `@Valid @RequestBody PutOnboardingProfileRequest`.

DTO placement:

- For B1, keep request/response records nested in `OnboardingProfileController` or `OnboardingProfileService`, matching current app-api style.
- Do not introduce a new DTO package for only two endpoints.
- If B2/B3 add discovery/care-turn DTO volume, revisit a `web.onboarding` package in that later slice.

### Service

`OnboardingProfileService` responsibilities:

- Resolve accepted session through `AuthConsentSyncService`.
- Normalize and validate request fields.
- Generate `profile_id` as `babyprof_` + UUID for first create.
- Convert blank baby name to `null`.
- Never accept account id from the request.
- Enforce optimistic version behavior.
- Map repository row to API response.
- Throw `ContractException` for 404, validation, consent/session, and version conflicts.

Recommended method shape:

```java
@Transactional(readOnly = true)
public OnboardingProfileResponse getProfile(String sessionId)

@Transactional
public OnboardingProfileResponse putProfile(String sessionId, PutOnboardingProfileRequest request)
```

### Repository / Mapper

`OnboardingProfileRepository`:

- `findByAccountId(accountId)`
- `insert(ProfileRow row)`
- `updateIfVersionMatches(accountId, expectedVersion, ProfilePatch patch, updatedAt)`
- `findVersionByAccountId(accountId)`

`OnboardingProfileMapper.xml`:

- `select` by `account_id`.
- `insert` row.
- `update` with `where account_id = #{accountId} and version = #{expectedVersion}` and `version = version + 1`.
- Avoid `on conflict do update` for versioned updates because explicit conflict handling produces clearer 409 behavior.

Create race handling:

- Attempt insert when no row exists and `expectedVersion` is absent.
- If unique account constraint is hit, fetch current version and return `409 version_conflict`.

## Auth And Privacy

JWT:

- Required for both endpoints by default security config.
- Do not add onboarding profile route to `permitAll`.
- Reuse bearer error codes: missing token -> `consumer_authentication_required`; invalid/expired/revoked token -> existing token/session codes.

Account ownership:

- Resolve `accountId` from the accepted session row.
- No `accountId` field in PUT request.
- Do not trust JWT subject alone; the guard validates it, but service should still use session state as the ownership source.

Consent:

- `GET` and `PUT` require accepted consent.
- A just-verified account with `latest_consent_status = signed_out` or non-accepted should get `409 consent_required`.
- Existing `/api/v1/consent/accept` remains the path to unlock account data writes.

Baby name privacy:

- Baby name is private account data.
- It may be returned only from authenticated profile read/write responses.
- Never include baby name in logs, trace ids, slugs, errors, metrics tags, or conflict details.
- Do not echo request bodies in exception logs.

Trace and logging:

- Accept `clientTraceId` only for correlation and validate max length/shape.
- Do not require or store trace id in the DB for B1 unless implementation needs it for diagnostics.
- If logged, log only route, profile id, account id, result code, and non-PII trace id.
- Do not log phone numbers, verification codes, baby names, request body JSON, or starter display copy.

## Test Plan

### Controller Tests

File:

```text
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/OnboardingProfileControllerTest.java
```

Use existing MockMvc integration style.

Cases:

- `GET /api/v1/onboarding/profile` without JWT returns `401` and code `consumer_authentication_required`.
- `PUT /api/v1/onboarding/profile` without JWT returns `401`.
- Accepted session with no profile returns `404 onboarding_profile_not_found`.
- Non-accepted session returns `409 consent_required` for GET and PUT.
- PUT draft creates profile and returns version `1`.
- PUT completed creates profile with all starter fields.
- PUT update with correct expected version increments version.
- PUT update missing expected version on existing row returns `400 expected_version_required`.
- PUT stale expected version returns `409 version_conflict`.
- Response and errors do not echo phone number or baby name outside the response body success field.

### Service Tests

File:

```text
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/OnboardingProfileServiceTest.java
```

Cases:

- Resolves account id from session, not request.
- Create generates `babyprof_` id and version `1`.
- Blank `babyName` is stored as null.
- `completed` requires parent goal, starter, and completedAt.
- Future completedAt is rejected.
- Invalid age range / parent goal / onboarding state rejected.
- Stale update reports current version.
- Create race path returns version conflict, not duplicate-key stack trace.

### Repository Tests

File:

```text
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/OnboardingProfileRepositoryTest.java
```

Cases:

- Insert and read by account id.
- Unique account id enforces one profile per account.
- Update with matching version changes fields and increments version.
- Update with non-matching version affects zero rows.
- Null optional draft fields persist correctly.
- Completed rows with required fields persist correctly.

### Flyway Migration Tests

File:

```text
backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java
```

Add assertions:

- `baby_profiles` table exists.
- Expected columns exist.
- `uq_baby_profiles_account_id` exists.
- `idx_baby_profiles_updated_at` exists.
- `idx_baby_profiles_state_updated_at` exists.
- Age range check rejects unknown values.
- Parent goal check rejects unknown values.
- State check rejects unknown values.
- Completed-shape check rejects completed rows missing starter/completedAt.
- `version >= 1` check rejects zero/negative values.
- `DbMigrationApplication.EXPECTED_CURRENT_VERSION` and `EXPECTED_APPLIED_MIGRATION_COUNT` are current.

### Auth-Required Tests

Covered in controller tests, plus regression:

- Existing `JwtTokenLifecycleWebTest` should still pass.
- Existing auth challenge/verify/refresh/logout tests should still pass.
- Profile route must not appear in permit-all route list.

### Validation Tests

Cover:

- Missing age range.
- Unknown age range.
- Unknown parent goal.
- Unknown onboarding state.
- Baby name over 40 code points.
- Completed without starter.
- Completed with partial starter.
- Completed without completedAt.
- completedAt too far in the future.
- clientTraceId too long or unsafe.

### Version Conflict Tests

Cover:

- Two updates using the same expected version: first succeeds, second returns `409 version_conflict`.
- Conflict details include `expectedVersion` and `currentVersion`.
- Conflict details do not include baby name.
- Create after another request already created the account profile returns `409 version_conflict`.

## Verification Commands

Doc-only verification for this planning slice:

```bash
git status --short
git diff -- docs/superpowers/plans/2026-07-03-t8-2-b1-onboarding-profile-api-implementation-plan.md
git diff --name-only -- backend mobile mobile_v2 admin-web
```

Future implementation verification:

```bash
cd backend && mvn test -pl db-migration -Dtest=DbMigrationSmokeTest
cd backend && mvn test -pl app-api -Dtest=OnboardingProfileControllerTest
cd backend && mvn test -pl app-api -Dtest=OnboardingProfileServiceTest
cd backend && mvn test -pl app-api -Dtest=OnboardingProfileRepositoryTest
cd backend && mvn test -pl app-api -Dtest=AuthConsentSyncWebTest,JwtTokenLifecycleWebTest,GrowthSummaryControllerTest,GardenSnapshotControllerTest
```

Scope guard verification after implementation:

```bash
git diff --name-only -- mobile mobile_v2 admin-web
git diff --name-only -- backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service backend/db-migration
```

## What Already Exists

- Phone challenge/verify/session/refresh/logout already exist and remain unchanged.
- JWT access token has `sid`; server-side session validation already exists.
- Consent accept/revoke/delete/audit already exists.
- `ContractException` and `ApiExceptionHandler` already provide the error body shape.
- App security already requires JWT for non-permit-all routes.
- MyBatis repository/mapper/XML style already exists for account/session/sync data.
- Practice catalog exists but is not used by B1 except for storing starter ids as strings.
- Garden/Growth projection exists but is not touched by B1.
- `/api/v1/mentor/chat` currently exists and is permit-all, but that is a risk to harden later, not a B1 target state.

## NOT In Scope

- No mobile UI.
- No Flutter onboarding implementation.
- No discovery API.
- No care-turns API.
- No `/api/v1/care-turns` draft mode.
- No Garden visual changes.
- No Garden/Growth projection changes.
- No Today redesign.
- No reaction enum changes.
- No new reaction values.
- No mobile_v2.
- No Duolingo assets.
- No admin-web changes.
- No `/api/v1/mentor/chat` changes.
- No mentor/chat security hardening.
- No mentor/Spring AI runtime changes.
- No PracticeCatalogRepository migration.
- No generated content registry.
- No multiple-baby account model.
- No commit.

Documented downstream gates that remain out of B1:

- `mentor/chat` permit-all is a security risk and should become authenticated-only.
- Pre-auth onboarding next support must not use `mentor/chat`.
- `care-turns` draft mode is the target interface for onboarding pre-auth next support.
- Practice catalog MyBatis migration is a B2 discovery prerequisite.

## Implementation Tasks

Synthesized from this B1 plan. Checkbox only after implementation starts.

- [ ] **B1.1 (P1, human: ~30min / CC: ~10min)** — Migration state — Reconcile Flyway constants before adding B1 migration.
  - Surfaced by: Current backend audit.
  - Files: `DbMigrationApplication.java`, `DbMigrationSmokeTest.java`.
  - Verify: `cd backend && mvn test -pl db-migration -Dtest=DbMigrationSmokeTest`.
- [ ] **B1.2 (P1, human: ~1h / CC: ~15min)** — Database — Add `baby_profiles` migration with enum checks, one-profile-per-account uniqueness, optimistic version, and indexes.
  - Surfaced by: DB migration plan.
  - Files: `V24__create_baby_profiles.sql`, `DbMigrationSmokeTest.java`.
  - Verify: migration smoke test plus constraint assertions.
- [ ] **B1.3 (P1, human: ~1h / CC: ~20min)** — Session reuse — Expose accepted consumer session resolver without duplicating consent/session logic.
  - Surfaced by: Consent-required audit.
  - Files: `AuthConsentSyncService.java`.
  - Verify: auth/consent regression tests.
- [ ] **B1.4 (P1, human: ~2h / CC: ~35min)** — Profile API — Add controller, service, repository, mapper, and XML for GET/PUT.
  - Surfaced by: API contract and backend implementation plan.
  - Files: new onboarding profile Java/XML files.
  - Verify: controller/service/repository tests.
- [ ] **B1.5 (P1, human: ~1h / CC: ~25min)** — Tests — Cover auth, consent, 404, validation, create/update, and version conflicts.
  - Surfaced by: Test review.
  - Files: onboarding profile test classes.
  - Verify: all B1 app-api test commands.

Sequential implementation, no parallelization opportunity. The migration, session resolver, API implementation, and tests all touch the same app-api/db-migration boundary and should land as one small backend slice.

## Future Cross-Slice Dependencies

These are not B1 implementation tasks. They must be handled before the related future slices implement discovery, care-turns, or mentor runtime behavior.

```text
Future B2.0: Practice catalog MyBatis migration / discovery repository setup.
Future B3.0: Mentor chat security hardening.
Future B3.1: /api/v1/care-turns draft_pending_auth boundary for pre-auth onboarding next support.
```

B1 profile API must not expand to include these dependencies. B1 should only leave the boundaries visible so later discovery/care-turns/mentor work does not reuse the wrong interface.

## Failure Modes

| Codepath | Failure mode | Planned handling | Test |
| --- | --- | --- | --- |
| GET profile | Valid JWT but consent not accepted | `409 consent_required` | Controller auth/consent test |
| GET profile | No row for accepted account | `404 onboarding_profile_not_found` | Controller no-profile test |
| PUT create | Two devices create at once | Unique account constraint, loser gets `409 version_conflict` | Service/repository race-style test |
| PUT update | Stale client version | update affects zero rows, return `409 version_conflict` with currentVersion | Version conflict test |
| PUT completed | Missing starter/completedAt | `400 completed_profile_missing_starter` or validation code | Validation tests |
| PUT request | Baby name over limit | `400 validation_failed` or specific validation code | Validation tests |
| Logging | Baby name leaks into logs/errors | No request-body logging, no babyName in error details | Controller content assertions / code review |
| Migration | Constants remain stale | Smoke test fails before implementation can be considered complete | DbMigrationSmokeTest |

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | not run | Backend-only B1 slice; no product-scope decision needed. |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run | No implementation diff exists yet. |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | clear | B1 scope narrowed to profile API/table; migration constants stale and covered as required implementation task. |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not needed | No UI or visual changes in scope. |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | Verification commands and file ownership are specified. |

- **VERDICT:** ENG PLAN WRITTEN — ready for user review before implementation.

NO UNRESOLVED DECISIONS
