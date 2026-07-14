# T8.2 B2 Onboarding Discovery API Implementation Plan

Date: 2026-07-03
Status: waiting for review
Scope: doc-only planning slice. No code implementation, no commit.

This plan adds the B2 onboarding discovery API plan only:

```text
POST /api/v1/onboarding/discovery
catalog-backed scene / moment / starter discovery
```

It does not modify the B2.0 `PracticeCatalogRepository` MyBatis rewrite plan. The B2.0 plan remains:

```text
docs/superpowers/plans/2026-07-03-t8-2-b2-0-practice-catalog-repository-mybatis-rewrite-plan.md
```

B2 depends on the B2.0 repository contract being present and green. In the current workspace, `PracticeCatalogRepository` already exposes the discovery-ready helpers from B2.0:

```text
findSpaces(locale, limit)
findActivitiesBySpace(spaceId, locale, limit)
findStarterPhrase(activityId, locale)
findNextPhrase(activityId, currentPhraseId)
existsSpaceActivityPhrase(spaceId, activityId, phraseId)
```

If the target branch for implementation does not have those helpers yet, B2 must stop and finish B2.0 first.

## 1. Scope

B2 may plan:

```text
POST /api/v1/onboarding/discovery
OnboardingDiscoveryController
OnboardingDiscoveryService
PracticeCatalogRepository-backed discovery
catalog ranking / fallback
catalog stable ids
request / response DTO records
controller / service / security tests
```

B2 may include the minimal security config change required for draft discovery:

```text
permit POST /api/v1/onboarding/discovery without requiring JWT
still process a bearer token when one is present
```

B2 must not plan implementation of:

```text
POST /api/v1/care-turns
reaction-based next support
gardenImpact
draft care-turn persistence
phone auth UI
mobile UI
mobile repository wiring
mentor/chat security hardening
Mentor/Spring AI generation
agentic search generation
generated content registry
PracticeCatalogRepository rewrite beyond B2.0
reaction enum changes
Garden/Growth changes
DB migration by default
```

The intended B2 boundary is narrow:

```text
Mobile onboarding scene picker
        |
        v
POST /api/v1/onboarding/discovery
        |
        v
OnboardingDiscoveryController
        |
        v
OnboardingDiscoveryService
        |
        +--> request profile context only when needed
        |       |
        |       v
        |   AuthConsentSyncService.requireAcceptedConsumerSession
        |       |
        |       v
        |   OnboardingProfileRepository.findByAccountId
        |
        v
PracticeCatalogRepository
        |
        v
practice_spaces / practice_activities / practice_phrases
```

B2 production path is catalog deterministic discovery only.

Hard rules:

```text
B2 must not call /api/v1/mentor/chat.
B2 must not call Mentor/Spring AI in production path.
B2 must not persist generated content.
B2 must not write interaction_events.
B2 may reserve future mode=custom_scene, but must not implement it.
```

## 2. Product Contract

The onboarding scene selection page should fetch candidates from the backend catalog instead of hardcoding the scene/moment universe in mobile.

B2 discovery response must return backend-resolvable stable ids:

```text
sceneId / spaceId
momentId / activityId
utteranceId / phraseId
source = catalog
discoveryTraceId
```

For B2, these pairs are intentionally aliases:

```text
sceneId      == practice_spaces.slug
spaceId      == practice_spaces.slug
momentId     == practice_activities.slug
activityId   == practice_activities.slug
utteranceId  == practice_phrases.slug
phraseId     == practice_phrases.slug
```

B2 must return starter utterances from the curated catalog tables:

```text
practice_spaces
practice_activities
practice_phrases
```

Do not return:

```text
one-off AI text
unpersisted generated ids
random generated slugs
objects mobile cannot later submit as stable reaction/care-turn ids
free-form AI chat output
```

Internal table sources currently include `seed` and `llm`. B2 must treat only curated seed catalog rows as `source = catalog` in the response. Future generated rows are not eligible for B2 discovery until B2.1 adds a generated-source resolver.

## 3. API Contract

Endpoint:

```text
POST /api/v1/onboarding/discovery
```

B2 supports:

```text
mode = catalog
```

B2 reserves but does not implement:

```text
mode = custom_scene
```

`mode = custom_scene` must return a clear not-implemented contract error in B2:

```http
501 Not Implemented
```

```json
{
  "timestamp": "...",
  "status": 501,
  "code": "custom_scene_not_implemented",
  "message": "custom_scene discovery is reserved for B2.1.",
  "details": {
    "supportedModes": ["catalog"]
  }
}
```

Unknown modes should return:

```http
400 Bad Request
```

```text
invalid_discovery_mode
```

### Draft / Pre-Auth Catalog Mode

Used before phone registration during onboarding.

Request shape:

```text
JWT absent
mode = catalog
installationId required
ageRange required
parentGoal required
locale required
babyProfileId absent
```

Rules:

- Does not read account private data.
- Does not need accepted session.
- Does not return account identifiers, session identifiers, phone number, baby name, or baby profile identifiers.
- Returns only catalog-based scene/moment/starter DTOs.
- Does not call mentor/chat.
- Does not call AI generation.
- Does not write `interaction_events`.
- Does not create baby profile.
- Does not write Garden/Growth.

### Authenticated Request Catalog Mode

Used when a bearer token is present but the request does not use saved profile data.

Request shape:

```text
JWT present
mode = catalog
installationId required
ageRange required
parentGoal required
locale required
babyProfileId absent
```

Rules:

- Bearer token, if present, is validated by the existing access token guard.
- Accepted consent is not required because the service does not read account-owned profile data.
- Request fields are still validated exactly like draft mode.
- Response must still omit account/session private identifiers.

### Authenticated Profile Catalog Mode

Used after login when discovery should use an existing saved onboarding profile.

Request shape:

```text
JWT present
mode = catalog
installationId required
babyProfileId required
ageRange optional
parentGoal optional
locale required
```

Rules:

- If request includes `babyProfileId`, JWT is required.
- Service must call `AuthConsentSyncService.requireAcceptedConsumerSession(sessionId, "读取宝宝档案场景发现")`.
- Service reads the profile through the existing account-owned profile repository path:
  - `OnboardingProfileRepository.findByAccountId(session.accountId())`
  - compare returned `profileId` to request `babyProfileId`
- If no profile is found or the id does not match the account, return `404 onboarding_profile_not_found` without exposing ownership details.
- Saved `ageRange` and `parentGoal` are source of truth.
- If request also sends `ageRange` or `parentGoal`, values must either match the saved profile or be rejected as `profile_context_mismatch`.
- If saved profile has no `parentGoal`, request must provide one. Otherwise discovery cannot rank against product intent.
- Still returns only discovery DTOs.
- Does not write care-turn event.
- Does not write Garden/Growth.

### Security Config Boundary

Current `AppSecurityConfig` has two distinct concepts:

```text
authorizeHttpRequests(...).permitAll()
AUTH_IGNORED_MATCHERS used by consumerBearerTokenResolver()
```

B2 must add `/api/v1/onboarding/discovery` to `permitAll` so draft mode works without JWT.

B2 must not add `/api/v1/onboarding/discovery` to `AUTH_IGNORED_MATCHERS`, because that would make `consumerBearerTokenResolver()` ignore a present bearer token. Authenticated profile mode depends on optional bearer processing.

Desired behavior:

```text
no Authorization header       -> draft path allowed
valid bearer, no babyProfile  -> authenticated request path allowed
valid bearer, babyProfileId   -> accepted-session profile path
invalid/expired bearer        -> rejected by existing bearer/token guard
```

## 4. Request DTO

Example:

```json
{
  "mode": "catalog",
  "installationId": "inst_abc",
  "babyProfileId": null,
  "ageRange": "m7_11",
  "parentGoal": "calmer_care",
  "locale": "zh-CN",
  "limit": 6,
  "clientTraceId": "onb_disc_001"
}
```

Recommended service request record:

```java
public record OnboardingDiscoveryRequest(
        String mode,
        String installationId,
        String babyProfileId,
        String ageRange,
        String parentGoal,
        String locale,
        Integer limit,
        String clientTraceId
) {}
```

Validation contract:

| field | B2 rule | error code |
| --- | --- | --- |
| `mode` | required; only `catalog` supported | `invalid_discovery_mode` |
| `mode=custom_scene` | reserved for B2.1, not implemented | `custom_scene_not_implemented` |
| `installationId` | required; safe slug-like; max 128; no phone-like values | `invalid_installation_id` |
| `babyProfileId` | optional; authenticated profile mode only | `consumer_authentication_required` / `onboarding_profile_not_found` |
| `ageRange` | required unless saved profile supplies it | `invalid_age_range` |
| `parentGoal` | required unless saved profile supplies it | `invalid_parent_goal` |
| `locale` | required; B2 only supports `zh-CN` | `unsupported_locale` |
| `limit` | optional; default `6`; bounded `1..20` | `invalid_limit` |
| `clientTraceId` | optional; safe slug-like; max 96; no phone-like values | `invalid_client_trace_id` |

Age ranges are the B1 values:

```text
m0_3
m4_6
m7_11
m12_17
m18_23
m24_30
m31_36
```

Parent goals are the B1 values:

```text
natural_opening
confident_pronunciation
calmer_care
keep_talking
```

Safe id pattern:

```text
^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$
```

Use the 96-character B1 trace-id limit for `clientTraceId`:

```text
^[A-Za-z0-9][A-Za-z0-9_-]{0,95}$
```

PII guard:

- Reject phone-like `installationId` or `clientTraceId` values containing 11+ consecutive digits.
- Do not accept baby name, phone number, free-form prompt, or custom scene text in B2.

## 5. Response DTO

Example:

```json
{
  "discoveryTraceId": "disc_abc123",
  "mode": "catalog",
  "profileMode": "draft",
  "source": "catalog",
  "scenes": [
    {
      "sceneId": "daily_care",
      "spaceId": "daily_care",
      "title": "日常照护",
      "rank": 1,
      "reasonCode": "starter_match"
    }
  ],
  "moments": [
    {
      "momentId": "bath_time",
      "sceneId": "daily_care",
      "spaceId": "daily_care",
      "activityId": "bath_time",
      "title": "洗澡时间",
      "sceneTag": "Bath time",
      "coachTip": "用慢速、夸张的语调重复核心短句。",
      "rank": 1,
      "starterUtterances": [
        {
          "utteranceId": "bath_time_warm_water",
          "phraseId": "bath_time_warm_water",
          "english": "Warm water.",
          "chinese": "水暖暖的。",
          "pronunciation": "wɔːrm ˈwɔː.t̬ɚ",
          "difficulty": "starter",
          "source": "catalog"
        }
      ]
    }
  ],
  "starter": {
    "sceneId": "daily_care",
    "spaceId": "daily_care",
    "momentId": "bath_time",
    "activityId": "bath_time",
    "utteranceId": "bath_time_warm_water",
    "phraseId": "bath_time_warm_water",
    "source": "catalog"
  },
  "trace": {
    "strategy": "catalog_ranked",
    "fallbackReason": null,
    "candidateCount": 4
  }
}
```

Response rules:

- Success response must include at least one `scene`, one `moment`, and one `starter`.
- `sceneId`, `spaceId`, `momentId`, `activityId`, `utteranceId`, and `phraseId` must be stable catalog slugs.
- Every returned source must be `catalog`.
- Do not return numeric DB ids.
- Do not return account id, session id, phone number, baby name, or `babyProfileId` in draft mode.
- Do not return random generated ids.
- Do not return free-form AI output.
- Mobile renders DTOs and should not hardcode the scene/moment universe.

Recommended response records can live inside `OnboardingDiscoveryService` for B2. If B3 adds care-turn DTO volume, extract a `web.onboarding` DTO package then.

## 6. Discovery Service Strategy

B2 initial strategy is deterministic catalog discovery.

Service pipeline:

```text
validate request
    |
    v
resolve profile mode
    |
    +--> draft / authenticated_request: use request ageRange + parentGoal
    |
    +--> authenticated_profile: require accepted session, load saved profile,
         verify babyProfileId ownership, use saved ageRange + parentGoal
    |
    v
query catalog candidates from PracticeCatalogRepository
    |
    v
filter curated catalog rows only
    |
    v
rank in service layer
    |
    v
select deterministic starter
    |
    v
backend-side deterministic fallback if ranking is sparse
    |
    v
return discovery DTO
```

Repository responsibilities:

```text
stable low-level catalog queries
stable ordering
bounded limit helpers from B2.0
full slug-path validation helpers
```

Service responsibilities:

```text
input validation
profile-mode decision
catalog source filtering
age/goal ranking
deduping scenes and moments
fallback choice
response shaping
trace generation
```

Do not put business ranking in MyBatis XML. XML should stay boring: table joins, column mapping, ordering, and limit binding.

Do not call:

```text
MentorService
MentorProvider
Spring AI
PalaceSearchService
/api/v1/mentor/chat
PracticeGenerateController
```

`discoveryTraceId` format:

```text
disc_ + UUID without dashes or equivalent safe random suffix
```

It is returned to mobile but not persisted in B2.

## 7. Catalog Candidate Rules

Candidate shape:

```text
space row
activity row
starter phrase row
score
reasonCode
```

Gathering:

1. `findSpaces("zh-CN", 50)`.
2. For each space, `findActivitiesBySpace(spaceId, "zh-CN", 50)`.
3. Keep activities where `source == "seed"`.
4. For each kept activity, `findStarterPhrase(activityId, "zh-CN")`.
5. Keep phrase where `source == "seed"` and phrase fields are display-complete enough for mobile.

Display-complete phrase means:

```text
phraseId present
english present
chinese present
difficulty present or defaultable to starter
```

`pronunciation` may be null, but response should include the field as null or omitted according to the existing JSON serialization style. Do not fabricate pronunciation.

Deduping:

- Scenes dedupe by `spaceId`.
- Moments dedupe by `activityId`.
- Starter utterances dedupe by `phraseId`.
- Keep first candidate after deterministic sort.

Sparse catalog fallback:

```text
preferred default: daily_care -> bath_time -> starter phrase
secondary default: first curated space by sort_order, then first curated activity, then starter phrase
if no curated starter phrase exists: 503 catalog_unavailable
```

Do not synthesize fallback copy.

## 8. Age / Goal Ranking

Keep ranking deliberately small. This is a catalog selector, not a personalization model.

Suggested score:

```text
score = goalScore + ageScore + completenessScore
tie-break = space.sortOrder ASC, activity.sortOrder ASC, spaceId ASC, activityId ASC, phrase.step ASC
```

Goal rules:

| parentGoal | preferred catalog patterns |
| --- | --- |
| `calmer_care` | daily care, bedtime, soothing/routine moments |
| `natural_opening` | high-frequency care moments |
| `confident_pronunciation` | short starter phrases, low difficulty |
| `keep_talking` | activities with multiple available phrases |

Age rules:

| ageRange | preference |
| --- | --- |
| `m0_3`, `m4_6`, `m7_11` | short sensory/care actions and starter difficulty |
| `m12_17`, `m18_23` | routine phrases with clear repetition |
| `m24_30`, `m31_36` | can allow slightly longer routine phrase options |

Current catalog metadata may be sparse. If a preferred category cannot be inferred from existing columns, use deterministic fallback instead of inventing a complex model.

Reason code examples:

```text
starter_match
goal_match
age_match
fallback_default
fallback_first_catalog
```

## 9. Future custom_scene Boundary

B2 reserves this user path:

```text
"没有我想要的场景"
```

Future custom scene example:

```text
出门前宝宝不想穿鞋
```

This is not B2 implementation.

B2.1 owns:

```text
mode = custom_scene
agentic search / RAG generation
practice_generated_content registry
stable generated slugs
request fingerprint / idempotency
rate limit / abuse control
generated-source resolver
```

B2 behavior when `mode = custom_scene` is sent:

```text
return 501 custom_scene_not_implemented
do not call AI
do not persist anything
do not return generated content
```

## 10. Generated Content Registry Naming

Future generated content registry must not be onboarding-specific because it will serve multiple product entry points.

Do not use:

```text
generated_onboarding_discovery_results
onboarding_generated_catalog_entries
onboarding_generated_content
discovery_generated_content
```

Use:

```text
practice_generated_content
```

Semantic layers:

```text
practice_spaces / practice_activities / practice_phrases
    = curated catalog, official stable content

practice_generated_content
    = AI generated content registry with stable slugs and trace

future promotion
    = generated content may later be promoted into curated catalog after review/aggregation
```

`practice_generated_content` is shared infrastructure for:

```text
onboarding custom scene
app scene search
care-turn next support
Ask TaTa / mentor generated reusable content
future generated-to-curated promotion
```

B2 does not implement this table. B2.1 should plan and implement it.

## 11. Backend Files

New B2 files:

```text
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/OnboardingDiscoveryController.java
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/OnboardingDiscoveryService.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/OnboardingDiscoveryControllerTest.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/OnboardingDiscoveryServiceTest.java
```

Expected existing-file edit:

```text
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/AppSecurityConfig.java
```

Only change needed there:

```text
add /api/v1/onboarding/discovery to permitAll
do not add it to AUTH_IGNORED_MATCHERS
```

Reuse:

```text
PracticeCatalogRepository
OnboardingProfileRepository read path if babyProfileId is used
AuthConsentSyncService.requireAcceptedConsumerSession for authenticated profile mode
ContractException / ApiExceptionHandler
existing MockMvc integration test style
```

No DB migration is required by default.

No `PracticeCatalogRepository` rewrite is part of B2. If B2.0 helpers are missing, implement/review B2.0 first instead of expanding B2.

## 12. Security / Privacy

Draft catalog mode:

- No JWT required.
- `installationId` required and validated.
- No free-form prompt accepted.
- No `babyProfileId` accepted without JWT.
- No account data read.
- No baby name or phone accepted.
- No account/session/profile identifiers returned.
- No mentor/chat call.
- No AI generation.
- No database writes.

Authenticated profile mode:

- `babyProfileId` requires JWT.
- Existing access token guard validates `(accountId, sid, rtid)`.
- Service requires accepted consent only when profile-owned data is read.
- Profile ownership verified by loading the account profile and comparing profile id.
- Mismatched profile id returns not found without leaking ownership.
- Response still does not expose account id or session id.

Logging and traces:

- Do not log request bodies.
- Do not log baby name, phone, or prompt-like input.
- Log at most route, profileMode, discoveryTraceId, clientTraceId, mode, candidateCount, and fallbackReason.
- `clientTraceId` and `installationId` must be safe slug-like and must not contain phone-like strings.

Security test that matters most:

```text
Adding discovery to AUTH_IGNORED_MATCHERS would break authenticated profile mode.
```

The test suite should prove:

```text
no JWT draft request succeeds
valid JWT + babyProfileId reaches accepted-session/profile ownership logic
invalid bearer token is still rejected
```

## 13. Tests

### Controller Tests

File:

```text
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/OnboardingDiscoveryControllerTest.java
```

Required cases:

- Draft catalog discovery succeeds without JWT.
- Draft success response has scenes, moments, starter, `source = catalog`, and no account/private identifiers.
- `custom_scene` mode returns `501 custom_scene_not_implemented`.
- Unknown mode returns `400 invalid_discovery_mode`.
- Invalid ageRange rejected.
- Missing ageRange rejected when no saved profile supplies it.
- Invalid parentGoal rejected.
- Missing parentGoal rejected when no saved profile supplies it.
- Invalid locale rejected.
- Limit lower and upper bounds enforced.
- Invalid installationId rejected.
- Invalid clientTraceId rejected.
- Phone-like installationId/clientTraceId rejected.
- Authenticated request without `babyProfileId` can use request fields without accepted consent.
- Authenticated profile mode verifies ownership.
- Authenticated profile mode uses saved ageRange/parentGoal.
- Authenticated profile mode rejects profile/request context mismatch.
- Profile-owned mode returns `409 consent_required` when consent is not accepted.
- Invalid bearer token on discovery route is rejected, proving optional JWT still runs through resource-server validation.

### Service Tests

File:

```text
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/OnboardingDiscoveryServiceTest.java
```

Required cases:

- Returns at least one scene, moment, and starter.
- Ranking is deterministic for same ageRange/parentGoal/catalog.
- Fallback is deterministic when preferred ranking is sparse.
- No duplicate scenes/moments/starters.
- Starter phrase comes from catalog tables.
- Response maps `spaceId/activityId/phraseId` to stable slugs.
- Underlying `seed` rows map to response `source = catalog`.
- Underlying generated/`llm` rows are excluded in B2.
- Profile mode uses saved ageRange/parentGoal when appropriate.
- Request age/goal values cannot silently override saved profile values.
- `custom_scene` is not implemented in B2.
- No AI provider dependency is injected or called.
- No MentorService or mentor/chat dependency is injected or called.

### Repository Regression

B2 does not rewrite the repository, but this test must stay green:

```text
PracticeCatalogRepositoryTest
```

It covers the B2.0 helper contract discovery depends on.

### Security Tests

Required assertions:

- No account data in draft response.
- No babyName/phone in error response details.
- No generated source in B2 response.
- No `accountId`, `sessionId`, or `babyProfileId` in draft response.
- Invalid bearer token is rejected even though the route is permit-all.

### Regression

Run these existing tests because B2 touches shared app-api security and onboarding/profile/catalog boundaries:

```text
MentorServiceTest
MentorWebTest
PracticeGenerateControllerTest
OnboardingProfileControllerTest
PracticeCatalogRepositoryTest
```

## 14. Coverage Diagram

```text
CODE PATHS                                                TEST EXPECTATION
OnboardingDiscoveryController
  POST /api/v1/onboarding/discovery
    no JWT + catalog mode                                 [GAP -> controller test]
    valid JWT + no babyProfileId                          [GAP -> controller test]
    valid JWT + babyProfileId                             [GAP -> controller test]
    invalid bearer                                        [GAP -> security test]
    custom_scene                                          [GAP -> controller test]
    invalid mode / locale / ids / limit                   [GAP -> validation tests]

OnboardingDiscoveryService
  resolve profile mode
    draft request context                                 [GAP -> service test]
    authenticated request context                         [GAP -> service test]
    authenticated profile context                         [GAP -> service test]
    profile id mismatch                                   [GAP -> service test]
    consent required                                      [GAP -> controller/service test]
  catalog candidates
    spaces -> activities -> starter phrase                [GAP -> service test]
    exclude non-curated generated rows                    [GAP -> service test]
    empty/sparse preferred ranking                        [GAP -> fallback test]
  ranking
    ageRange score                                        [GAP -> deterministic test]
    parentGoal score                                      [GAP -> deterministic test]
    stable tie-break                                      [GAP -> deterministic test]
  response
    no duplicates                                         [GAP -> service test]
    source always catalog                                 [GAP -> service test]
    stable slug ids                                       [GAP -> service test]

USER FLOWS
  Pre-auth onboarding scene picker                        [GAP -> controller test]
  Logged-in profile-backed scene picker                   [GAP -> controller test]
  Future custom scene attempt in B2                       [GAP -> controller test]
  Bad token pasted into client storage                    [GAP -> security regression]

COVERAGE TARGET: every branch above covered before B2 implementation is done.
```

## 15. Failure Modes

| Codepath | Production failure mode | Planned handling | Test |
| --- | --- | --- | --- |
| Security config | Route is added to `AUTH_IGNORED_MATCHERS`, so bearer token is ignored. | Add to `permitAll` only, not ignored matchers. | Authenticated profile controller test. |
| Draft validation | `installationId` or `clientTraceId` carries phone number. | Safe slug pattern plus phone-like rejection. | Invalid id tests. |
| Profile mode | User submits another account's `babyProfileId`. | Load current account profile and compare; return 404. | Ownership test. |
| Consent | Profile-owned mode reads saved profile before consent. | Call `requireAcceptedConsumerSession` before profile read. | consent_required test. |
| Catalog source | B2 returns existing `llm` generated rows as catalog. | Filter to curated seed rows for B2. | no generated source test. |
| Sparse ranking | No preferred goal/age candidate exists. | Deterministic backend fallback from catalog. | fallback test. |
| Empty catalog | No catalog starter exists. | Return `503 catalog_unavailable`; do not synthesize copy. | service empty-catalog test if fixture isolation is practical. |
| Duplicate ids | Same scene/moment appears multiple times in DTO. | Deduplicate by stable slugs after ranking. | no duplicate test. |
| Future mode | `custom_scene` accidentally calls AI. | Return 501 before catalog/AI work. | custom_scene no-call test. |
| Logging | Trace/log captures baby name or phone. | Do not accept those fields; do not log request body. | response/error assertions plus code review. |

No critical silent failure should remain without a controller or service test.

## 16. Verification Commands

Focused backend tests for future implementation:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=OnboardingDiscoveryControllerTest
  mvn test -pl app-api -Dtest=OnboardingDiscoveryServiceTest
  mvn test -pl app-api -Dtest=PracticeCatalogRepositoryTest
  mvn test -pl app-api -Dtest=OnboardingProfileControllerTest
  mvn test -pl app-api -Dtest=MentorServiceTest
  mvn test -pl app-api -Dtest=MentorWebTest
  mvn test -pl app-api -Dtest=PracticeGenerateControllerTest
} finally {
  Pop-Location
}
```

Scope guard:

```powershell
git diff --name-only -- mobile mobile_v2 admin-web
git diff --name-only -- backend/db-migration
```

Doc-only verification for this planning slice:

```powershell
git status --short
git diff -- docs/superpowers/plans/2026-07-03-t8-2-b2-onboarding-discovery-api-implementation-plan.md
git diff --name-only -- backend mobile mobile_v2 admin-web
```

Expected doc-only result:

```text
Only docs/superpowers/plans/2026-07-03-t8-2-b2-onboarding-discovery-api-implementation-plan.md changes.
No Java, XML, SQL, Flutter, React, mobile_v2, or admin-web implementation is written.
No commit is created.
```

## 17. Explicitly Not In Scope

```text
no /api/v1/care-turns
no reaction-based next support
no gardenImpact
no draft care-turn persistence
no phone auth/mobile UI
no mobile code
no Flutter UI
no mentor/chat hardening
no Mentor/Spring AI generation
no agentic search generation
no practice_generated_content table
no generated content registry
no PracticeCatalogRepository rewrite beyond B2.0
no DB migration by default
no reaction enum changes
no Garden/Growth changes
no mobile_v2
no admin-web
no commit
```

## 18. What Already Exists

- `GET /api/v1/onboarding/profile` and `PUT /api/v1/onboarding/profile` exist for account-owned profile data.
- `baby_profiles` exists and stores `ageRange`, `parentGoal`, and starter ids.
- `AuthConsentSyncService.requireAcceptedConsumerSession` exists and is used by profile reads/writes.
- `OnboardingProfileRepository.findByAccountId` exists and can verify one-profile-per-account ownership.
- `ContractException` and `ApiExceptionHandler` provide the standard error envelope.
- `PracticeCatalogRepository` exists.
- In the current workspace, B2.0 discovery-ready helpers and `PracticeCatalogRepositoryTest` exist.
- `practice_spaces`, `practice_activities`, and `practice_phrases` contain curated seed content.
- `AppSecurityConfig` already has optional-auth precedent through `permitAll` endpoints that still accept bearer tokens when present.
- `MentorService`, `MentorWebTest`, and `PracticeGenerateControllerTest` are regression anchors for shared catalog and mentor behavior.

## 19. Implementation Tasks

Synthesized from this plan. Do not start until the plan is reviewed.

- [ ] **B2-01 (P1, human: ~30min / CC: ~10min)** - Security route - Permit discovery for draft mode without disabling optional bearer parsing.
  - Surfaced by: Security config boundary.
  - Files: `AppSecurityConfig.java`, `OnboardingDiscoveryControllerTest.java`.
  - Verify: no-JWT draft succeeds; invalid bearer still rejects; bearer + babyProfileId reaches profile path.

- [ ] **B2-02 (P1, human: ~1h / CC: ~20min)** - Discovery API shell - Add controller/service records, request validation, mode handling, and standard error codes.
  - Surfaced by: API contract and request DTO.
  - Files: `OnboardingDiscoveryController.java`, `OnboardingDiscoveryService.java`, controller/service tests.
  - Verify: invalid mode, custom_scene, invalid fields, and bounds tests.

- [ ] **B2-03 (P1, human: ~1h / CC: ~25min)** - Profile context - Implement draft, authenticated request, and authenticated profile modes with ownership and consent rules.
  - Surfaced by: Draft vs authenticated contract.
  - Files: `OnboardingDiscoveryService.java`, `OnboardingDiscoveryControllerTest.java`, `OnboardingDiscoveryServiceTest.java`.
  - Verify: saved profile age/goal, mismatch, not found, consent_required tests.

- [ ] **B2-04 (P1, human: ~1.5h / CC: ~35min)** - Catalog discovery - Query B2.0 repository helpers, filter curated catalog rows, rank by age/goal/completeness, dedupe, and build DTO response.
  - Surfaced by: Discovery service strategy.
  - Files: `OnboardingDiscoveryService.java`, `OnboardingDiscoveryServiceTest.java`.
  - Verify: scenes/moments/starter, deterministic ranking, fallback, no duplicates, stable slug ids.

- [ ] **B2-05 (P1, human: ~45min / CC: ~20min)** - Regression pass - Keep profile/catalog/mentor tests green and prove no generated/AI path is touched.
  - Surfaced by: Shared catalog and optional-auth blast radius.
  - Files: test files only unless a regression exposes a necessary small fix.
  - Verify: command block in section 16.

Sequential implementation, no parallelization opportunity. The controller, service, security config, and tests all touch the same app-api onboarding/catalog boundary and should land as one backend slice.

## 20. B2.1 / B3 Handoff

B2 completion provides:

```text
catalog discovery output
stable scene/moment/utterance ids
discoveryTraceId
source = catalog
```

B2.1 can then plan:

```text
practice_generated_content
custom_scene mode
agentic search / RAG generation
stable generated slugs
request fingerprint / idempotency
rate limit / abuse control
generated-source resolver
```

B2.1 generated content registry is shared infrastructure, not an onboarding-only table.

B3 can then plan:

```text
POST /api/v1/care-turns
draft_pending_auth
canonical_synced
reaction-based nextSupport
gardenImpact
source = catalog
source = generated
```

B2 does not solve next support or care-turn persistence. It only gives B3 stable ids that a future care-turn endpoint can accept.

## 21. Risks

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Optional JWT is broken by adding route to ignored matcher. | Authenticated profile discovery silently becomes impossible. | Add to `permitAll` only; test invalid bearer and profile-owned mode. |
| B2 accidentally treats generated `llm` rows as curated catalog. | Mobile could persist ids whose source semantics are not ready for B3. | Filter activity/phrase source to curated seed rows in B2. |
| Discovery ranking becomes too clever. | Hard-to-debug product behavior and brittle tests. | Keep service-layer deterministic score and explicit fallback. |
| Profile ownership check leaks account existence. | Privacy issue for guessed `babyProfileId`. | Return not found without account/profile details. |
| Draft mode accepts prompt-like text. | Opens pre-auth AI abuse surface. | B2 request DTO has no prompt/custom scene text field. |
| Tests only cover happy path. | Security and fallback regressions will ship. | Required controller/service/security/regression tests in section 13. |
| Empty catalog response fabricates copy. | Mobile receives ids backend cannot resolve later. | Return `catalog_unavailable`; never synthesize ids or text. |
| B2.0 helper contract missing on implementation branch. | B2 reintroduces ad hoc SQL or duplicate repository. | Stop and finish B2.0 first. |

## 22. Eng Review Completion Summary

- Step 0: Scope Challenge - scope accepted as a backend catalog-only discovery API plan; B2.1/B3 boundaries remain deferred.
- Architecture Review: 1 key implementation risk found and folded into plan - optional JWT must be permit-all without ignored matcher.
- Code Quality Review: 1 boundary guard folded into plan - ranking stays in service layer, mapper stays low-level.
- Test Review: coverage diagram produced; controller/service/security/regression gaps identified.
- Performance Review: no new DB write path; catalog query count is bounded by repository limits and small seed catalog size.
- NOT in scope: written.
- What already exists: written.
- TODOS.md updates: 0 items proposed; existing deferred TODOs are not blocking B2 catalog discovery.
- Failure modes: 0 unhandled critical silent gaps after planned tests.
- Outside voice: skipped; no implementation diff exists.
- Parallelization: sequential implementation, no parallel lanes.
- Lake Score: complete catalog-only plan chosen over shortcut/mobile-hardcoded scene universe.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | not run | User already fixed B2 scope as catalog-only discovery; B2.1/B3 product expansion deferred. |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run | No implementation diff exists. |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | clear | Discovery plan covers optional JWT route shape, draft vs authenticated profile modes, catalog-only ranking/fallback, stable ids, generated registry naming, and test coverage. |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not needed | Backend API plan only; no mobile UI, Flutter UI, or admin-web scope. |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | Focused verification commands and scope guards are included. |

- **VERDICT:** ENG PLAN WRITTEN - ready for user review before B2 implementation.

NO UNRESOLVED DECISIONS
