# T8.2 B2.1 Practice Discovery + Generated Content Registry Plan

Date: 2026-07-03
Status: waiting for review
Scope: doc-only planning slice. No code implementation, no commit.

B2.1 revises B2 discovery into a shared practice/care-scene discovery capability and adds generated custom scene content behind a persisted registry.

Core rule:

```text
Discovery is not onboarding-only.
Onboarding is only the first surface.
AI may generate custom scene practice content.
Mobile must never receive one-off AI text directly.
Generated content must first enter practice_generated_content with stable ids.
Discovery response may only return persisted generated content.
```

## Review Hardening: Approved Contracts

Custom scene eligibility:
- Deterministic sceneIntents are alignment hints, not an allow-list.
- Safe unlisted care scenes may reach the typed provider boundary.
- Fake fixtures return generation_unavailable for unsupported scenes and never return unrelated fallback content.

Canonical text:
- customSceneText is normalized with Unicode NFKC and Unicode whitespace collapse before validation, fingerprinting, persistence, and provider invocation.
- Product grapheme limits and database code-point limits are both enforced.

Fingerprint privacy:
- request_fingerprint is an owner-scoped, domain-separated HMAC over canonical request material.
- It must not be a plain hash that permits cross-owner equality comparison or dictionary recovery.

Generated output privacy:
- Output PII markers, phone/email/name patterns, prompt echo, physical column limits, and opaque provider metadata are validated before activation.

Retention:
- Current-key lookup and rate accounting remain version-bound.
- Global stale-draft expiration and installation retention deletion operate across every owner-key version.

Registry writes:
- PracticeGeneratedContentMapper exposes only explicit state-machine/query operations and does not extend BaseMapper.

## 1. Scope

B2.1 may plan:

```text
PracticeDiscovery rename / route contract
POST /api/v1/practice/discovery
surface + mode split
practice_generated_content registry
surface=onboarding + mode=custom_scene
typed custom scene request
agentic search / RAG generation behind typed port
fake generator test path
generated content persistence before response
stable generated slugs
request fingerprint / idempotency
source=generated discovery response
generated-source resolver contract for future B3
rate limit / abuse control plan
tests
```

B2.1 must not implement:

```text
app scene search endpoint behavior
mobile UI
mobile repository wiring
POST /api/v1/care-turns
reaction-based next support
gardenImpact
Garden/Growth writes
phone auth UI
mentor/chat security hardening
curated catalog promotion workflow
generated-to-curated review admin UI
reaction enum changes
mobile_v2
admin-web
commit
```

## 2. Discovery Naming Decision

Recommendation: rename discovery domain to shared PracticeDiscovery naming.

Use:

```text
PracticeDiscoveryController
PracticeDiscoveryService
PracticeDiscoveryRequest
PracticeDiscoveryResponse
PracticeDiscoveryMode
PracticeDiscoverySurface
```

Avoid new onboarding-specific domain names:

```text
OnboardingDiscoveryController
OnboardingDiscoveryService
OnboardingDiscoveryRequest
OnboardingDiscoveryResponse
```

Existing B2 `OnboardingDiscoveryController` / `OnboardingDiscoveryService` should be renamed or replaced in B2.1 before adding `custom_scene`.

If implementation needs to mention onboarding, it should appear as:

```text
surface = onboarding
```

Not as service/controller/domain naming.

Shared future users:

```text
app scene search
custom scene generation
care-turn next support content resolution
Ask TaTa / mentor generated reusable content
future generated-to-curated promotion
```

## 3. Endpoint Naming Decision

Recommendation: Option A.

Use the shared endpoint:

```text
POST /api/v1/practice/discovery
```

Request uses `surface` to express use case:

```json
{
  "surface": "onboarding",
  "mode": "catalog"
}
```

Future app scene search:

```json
{
  "surface": "scene_search",
  "mode": "custom_scene"
}
```

Why Option A:

```text
Mobile has not integrated the B2 route yet.
Fixing the API name now avoids a public onboarding-only contract.
PracticeDiscovery can serve catalog and generated discovery across surfaces.
```

B2.1 first implementation gate:

```text
Rename/replace B2 discovery endpoint/controller/service with shared PracticeDiscovery naming before adding custom_scene.
```

Short-term alias:

```text
Default recommendation: do not keep /api/v1/onboarding/discovery because mobile has not integrated it.
If hidden clients exist, keep it as a deprecated alias for one release only.
Alias must delegate to PracticeDiscoveryService.
Alias tests must prove catalog behavior is identical.
Alias must not become the canonical route in docs or mobile wiring.
```

Option B is rejected for B2.1 unless compatibility forces it:

```text
POST /api/v1/onboarding/discovery
controller delegates to PracticeDiscoveryService
```

## 4. Surface / Mode Contract

Do not encode mode into surface.

Use:

```text
surface = onboarding | scene_search | care_turn_support | mentor_generation
mode = catalog | custom_scene
```

Do not use:

```text
surface = onboarding_custom_scene
surface = scene_search_custom_scene
surface = mentor_custom_scene
surface = care_turn_custom_scene
```

B2 catalog behavior migrates to:

```text
surface = onboarding
mode = catalog
source = catalog
```

B2.1 implements:

```text
surface = onboarding
mode = custom_scene
source = generated
```

Future reserved, not implemented in B2.1:

```text
surface = scene_search
mode = catalog

surface = scene_search
mode = custom_scene

surface = care_turn_support
mode = custom_scene

surface = mentor_generation
mode = custom_scene
```

Unsupported `surface`/`mode` pairs should return:

```text
400 unsupported_discovery_surface_mode
```

With details:

```json
{
  "supported": [
    {"surface": "onboarding", "mode": "catalog"},
    {"surface": "onboarding", "mode": "custom_scene"}
  ]
}
```

## 5. Product Flow

Custom scene flow:

```text
1. Mobile shows catalog scene candidates from PracticeDiscovery catalog mode.
2. Parent taps "没有我想要的场景".
3. Parent enters custom scene text, e.g. "出门前宝宝不想穿鞋".
4. Mobile calls POST /api/v1/practice/discovery with surface=onboarding, mode=custom_scene.
5. Backend validates typed input.
6. Backend normalizes customSceneText.
7. Backend computes requestFingerprint.
8. Backend computes HMAC owner_key from owner scope and identifiers.
9. Backend checks practice_generated_content by surface + mode + owner_key + fingerprint + versions.
10. Existing active content returns without AI call.
11. Existing draft content returns generation_in_progress or waits briefly, without duplicate AI call.
12. New request reserves draft row.
13. Backend calls internal typed generator, not /api/v1/mentor/chat.
14. Backend validates structured output.
15. Backend persists active generated content.
16. Backend returns source=generated with generatedContentId and stable slugs.
```

Response must never depend on ephemeral provider text.

## 6. API Contract

Endpoint:

```text
POST /api/v1/practice/discovery
```

Catalog onboarding request:

```json
{
  "surface": "onboarding",
  "mode": "catalog",
  "installationId": "inst_abc",
  "ageRange": "m18_23",
  "parentGoal": "calmer_care",
  "locale": "zh-CN",
  "limit": 6,
  "clientTraceId": "onb_catalog_001"
}
```

Custom scene onboarding request:

```json
{
  "surface": "onboarding",
  "mode": "custom_scene",
  "installationId": "inst_abc",
  "babyProfileId": null,
  "customSceneText": "出门前宝宝不想穿鞋",
  "ageRange": "m18_23",
  "parentGoal": "calmer_care",
  "locale": "zh-CN",
  "clientTraceId": "onb_custom_scene_001"
}
```

Draft / pre-auth:

```text
JWT absent
surface=onboarding
installationId required
customSceneText required for mode=custom_scene
ageRange required
parentGoal required
locale required
babyProfileId absent
no account private data
owner_scope = installation
owner_key = HMAC("installation:" + installationId)
```

Authenticated/profile-backed:

```text
JWT present if babyProfileId is used
accepted session required if babyProfileId is used
profile ownership required
saved ageRange / parentGoal may be used
installationId optional, but if present must be validated
owner_scope = profile
owner_key = HMAC("profile:" + accountId + ":" + babyProfileId)
```

Authenticated without `babyProfileId`:

```text
If accepted account session is available:
  owner_scope = account
  owner_key = HMAC("account:" + accountId)

If consent is not accepted:
  do not write account-owned generated content
  require installationId
  owner_scope = installation
```

`customSceneText` validation:

```text
trimmed
min length 4 user-perceived chars
max length 80 user-perceived chars
reject phone-like 11+ digit runs
reject obvious baby name pattern when detectable
reject prompt-injection markers such as "ignore previous", "system prompt", "developer message"
allow Chinese/English mixed input
require caregiving-scene orientation
reject arbitrary chat, homework, lesson, quiz, medical/legal questions
```

Recommended error codes:

| case | status | code |
| --- | --- | --- |
| missing / invalid surface | 400 | `invalid_discovery_surface` |
| missing / invalid mode | 400 | `invalid_discovery_mode` |
| unsupported surface/mode pair | 400 | `unsupported_discovery_surface_mode` |
| missing / short / too long customSceneText | 400 | `invalid_custom_scene_text` |
| phone-like / obvious PII | 400 | `unsafe_custom_scene_text` |
| prompt injection / arbitrary chat | 400 | `unsupported_custom_scene_text` |
| duplicate live generation still running | 409 | `generation_in_progress` |
| provider disabled | 503 | `generation_unavailable` |
| provider timeout | 504 | `generation_timeout` |
| provider unavailable | 503 | `generation_unavailable` |
| invalid provider output | 502 | `generation_invalid_output` |
| unsafe generated output | 422 | `generated_content_rejected` |
| rate limit / daily cap | 429 | `custom_scene_rate_limited` |

## 7. Response Contract

Response fields should stay close to B2 so mobile payload shape remains stable, with `surface` and `generatedContentId` added.

Catalog response:

```text
surface = onboarding
mode = catalog
source = catalog
generatedContentId = null
starter.source = catalog
starter ids are catalog slugs
```

Generated custom scene response:

```json
{
  "discoveryTraceId": "disc_abc123",
  "surface": "onboarding",
  "mode": "custom_scene",
  "profileMode": "draft",
  "source": "generated",
  "generatedContentId": "pgc_8v6z2m1n9q0r",
  "scenes": [
    {
      "sceneId": "gen_scene_8v6z2m1n9q0r",
      "spaceId": "gen_scene_8v6z2m1n9q0r",
      "title": "出门穿鞋",
      "rank": 1,
      "reasonCode": "custom_scene_match"
    }
  ],
  "moments": [
    {
      "momentId": "gen_activity_8v6z2m1n9q0r",
      "sceneId": "gen_scene_8v6z2m1n9q0r",
      "spaceId": "gen_scene_8v6z2m1n9q0r",
      "activityId": "gen_activity_8v6z2m1n9q0r",
      "title": "宝宝不想穿鞋",
      "sceneTag": "Getting shoes on",
      "coachTip": "先贴近动作，再给一个很短的英文提示。",
      "rank": 1,
      "starterUtterances": [
        {
          "utteranceId": "gen_phrase_8v6z2m1n9q0r",
          "phraseId": "gen_phrase_8v6z2m1n9q0r",
          "english": "Shoes on.",
          "chinese": "鞋子穿上。",
          "pronunciation": "shooz on",
          "difficulty": "starter",
          "source": "generated"
        }
      ]
    }
  ],
  "starter": {
    "sceneId": "gen_scene_8v6z2m1n9q0r",
    "spaceId": "gen_scene_8v6z2m1n9q0r",
    "momentId": "gen_activity_8v6z2m1n9q0r",
    "activityId": "gen_activity_8v6z2m1n9q0r",
    "utteranceId": "gen_phrase_8v6z2m1n9q0r",
    "phraseId": "gen_phrase_8v6z2m1n9q0r",
    "source": "generated"
  },
  "trace": {
    "strategy": "custom_scene_generated",
    "fallbackReason": null,
    "candidateCount": 1,
    "returnedCount": 1
  }
}
```

Response rules:

```text
response only returns persisted generated content
generatedContentId must be stable
scene/moment/utterance slugs must be stable
source must be generated for custom_scene success
starter.source must be generated
no direct free-form AI chat response
no account id in draft response
no owner_key in any response
no normalized_scene_text in any response
no baby name / phone in response unless future safe copy rules explicitly allow it
```

## 8. Fallback Error Response

Recommendation stays: no silent catalog fallback.

Do not pretend catalog fallback is a successful generated result. Mobile may show nearby catalog scenes as a separate fallback action.

Provider unavailable:

```json
{
  "code": "generation_unavailable",
  "message": "暂时无法生成这个场景，请稍后再试。",
  "details": {
    "retryable": true,
    "suggestCatalogFallback": true
  }
}
```

Provider timeout:

```json
{
  "code": "generation_timeout",
  "message": "生成超时了，请稍后再试。",
  "details": {
    "retryable": true,
    "suggestCatalogFallback": true
  }
}
```

Feature disabled:

```json
{
  "code": "generation_unavailable",
  "message": "暂时无法生成自定义场景。",
  "details": {
    "retryable": false,
    "suggestCatalogFallback": true,
    "reason": "provider_disabled"
  }
}
```

Product tradeoff:

```text
custom_scene success returns generated content only.
generation failure returns a clear error with UI hints.
Mobile may show catalog suggestions as a separate fallback action.
Backend must not return source=generated for catalog content.
```

## 9. Registry Naming

Use:

```text
practice_generated_content
```

Do not use:

```text
generated_onboarding_discovery_results
onboarding_generated_catalog_entries
onboarding_generated_content
discovery_generated_content
```

Meaning:

```text
practice_spaces / practice_activities / practice_phrases
    = curated catalog, official stable content

practice_generated_content
    = AI generated practice content registry with stable slugs and trace

future promotion
    = generated content may later be promoted into curated catalog after review / aggregation
```

`practice_generated_content` serves:

```text
onboarding custom scene
app scene search
care-turn next support
Ask TaTa / mentor generated reusable content
future generated-to-curated promotion
```

## 10. Schema Recommendation

Recommendation: one table first. One row represents one generated practice unit:

```text
custom scene + generated moment + starter utterance
```

Do not split group/item tables in B2.1. B2.1 needs exactly one scene, one moment, and one starter. A split can wait for multiple generated utterances, review workflow, or promotion batches.

Migration:

```text
backend/db-migration/src/main/resources/db/migration/V25__create_practice_generated_content.sql
```

Recommended columns:

```text
generated_content_id varchar(64) primary key
owner_scope varchar(24) not null
owner_key varchar(96) not null
account_id varchar(64) null references accounts(account_id)
installation_id varchar(128) null
profile_id varchar(64) null
surface varchar(32) not null
mode varchar(32) not null
request_fingerprint varchar(96) not null
normalized_scene_text varchar(160) not null
age_range varchar(16) not null
parent_goal varchar(48) not null
locale varchar(16) not null
space_slug varchar(96) null
activity_slug varchar(96) null
phrase_slug varchar(120) null
space_title_zh varchar(120) null
activity_title_zh varchar(120) null
scene_tag_en varchar(120) null
coach_tip_zh varchar(240) null
english_text varchar(120) null
chinese_text varchar(120) null
pronunciation_hint varchar(120) null
difficulty varchar(16) null
generation_source varchar(32) null
status varchar(24) not null
provider_trace_id varchar(128) null
retrieval_trace_id varchar(128) null
model_name varchar(96) null
prompt_version varchar(48) not null
strategy_version varchar(48) not null
content_version integer not null default 1
generation_error_code varchar(64) null
generation_started_at timestamp with time zone null
generation_expires_at timestamp with time zone null
created_at timestamp with time zone not null
updated_at timestamp with time zone not null
```

Enums / checks:

```text
owner_scope:
  installation
  account
  profile
  global_candidate

surface:
  onboarding
  scene_search
  care_turn_support
  mentor_generation

mode:
  custom_scene

generation_source:
  agentic_search
  rag_generation
  manual
  fake

status:
  draft
  active
  rejected
  expired
  promoted
```

`expired` is explicit. Expired draft rows should be updated to `status='expired'`, not overloaded as rejected. This makes retry logic, diagnostics, and partial unique indexes clearer.

Mode schema decision: Option A. API-level `PracticeDiscoveryMode` remains `catalog | custom_scene`, but `practice_generated_content` is a generated content registry, not a catalog discovery trace table.

```text
B2.1 practice_generated_content rows must use mode = custom_scene.
Catalog mode never writes practice_generated_content.
The table-level mode check should allow only custom_scene.
Catalog discovery remains resolved from practice_spaces / practice_activities / practice_phrases.
```

Source naming decision:

```text
API response source:
  catalog
  generated

practice_generated_content.generation_source:
  agentic_search
  rag_generation
  manual
  fake (test/dev provider only)

Discovery response source must remain catalog/generated.
Generated registry generation_source records how generated content was produced.
Do not return generation_source as response source.
Do not map generation_source into PracticeDiscoveryResponse.source.
fake is explicit test/dev provenance and is only valid when provider-mode=fake.
Production agentic/RAG adapters must return agentic_search or rag_generation and must never return fake.
The generated-output validator must reject fake provenance outside the fake provider path.
```

Shape constraints:

```text
owner_scope = installation
  => installation_id is not null
  => account_id is null
  => profile_id is null

owner_scope = account
  => account_id is not null
  => installation_id is null
  => profile_id is null

owner_scope = profile
  => account_id is not null
  => profile_id is not null
  => installation_id is null

owner_scope = global_candidate
  => account_id is null
  => installation_id is null
  => profile_id is null
```

Active/promoted-row shape check:

```text
status not in ('active', 'promoted')
OR all response fields are non-null:
  space_slug
  activity_slug
  phrase_slug
  space_title_zh
  activity_title_zh
  scene_tag_en
  coach_tip_zh
  english_text
  chinese_text
  difficulty
  generation_source
```

PostgreSQL nullable uniqueness decision:

```text
Do not rely on unique(account_id, installation_id, profile_id, request_fingerprint).
PostgreSQL unique indexes allow multiple NULLs.
Use HMAC owner_key as the canonical non-null scope key.
```

Recommended unique index:

```sql
create unique index uq_practice_generated_content_live_fingerprint
    on practice_generated_content (
        owner_key,
        surface,
        mode,
        request_fingerprint,
        prompt_version,
        strategy_version
    )
    where status in ('draft', 'active', 'promoted');
```

Promoted fingerprint uniqueness decision:

```text
promoted participates in the live fingerprint unique index.
A promoted row still represents reusable generated-content lineage for the same owner/surface/mode/fingerprint/version.
The same request must not create a duplicate active generated row while a promoted row exists.
Future resolver/promotion flow can redirect promoted content to curated catalog if needed.
```

Slug indexes:

```sql
create unique index uq_practice_generated_content_active_space_slug
    on practice_generated_content(space_slug)
    where status in ('active', 'promoted');

create unique index uq_practice_generated_content_active_activity_slug
    on practice_generated_content(activity_slug)
    where status in ('active', 'promoted');

create unique index uq_practice_generated_content_active_phrase_slug
    on practice_generated_content(phrase_slug)
    where status in ('active', 'promoted');
```

Lookup / cleanup indexes:

```sql
create index idx_practice_generated_content_owner_created
    on practice_generated_content(owner_key, surface, mode, created_at desc);

create index idx_practice_generated_content_status_updated
    on practice_generated_content(status, updated_at desc);

create index idx_practice_generated_content_generated_id_status
    on practice_generated_content(generated_content_id, status);

create index idx_practice_generated_content_installation_cleanup
    on practice_generated_content(installation_id, status, created_at desc)
    where owner_scope = 'installation';

create index idx_practice_generated_content_account_cleanup
    on practice_generated_content(account_id, created_at desc)
    where owner_scope in ('account', 'profile');
```

## 11. Owner Key Privacy

Recommendation: HMAC/hash owner key.

Do not store raw:

```text
owner_key = installation:<installationId>
owner_key = account:<accountId>:profile:<babyProfileId>
```

Use:

```text
owner_key = HMAC(server_secret, owner_scope + ":" + owner identifiers)
owner_scope = installation | account | profile | global_candidate
```

Rules:

```text
owner_key does not enter API response
owner_key does not enter logs
owner_key is only for idempotency unique index and cleanup lookup
owner_key must be stable across retries
owner_key secret rotation needs future migration plan, not B2.1
owner_key_version and the HMAC secret are typed configuration
current runtime supports exactly one active owner_key_version
fingerprint lookup, active lookup, rate-limit counting, and retention cleanup bind that current version explicitly
account privacy deletion is the deliberate exception and deletes account/profile rows across every historical owner_key_version
owner_key_version is migration metadata only; B2.1 does not claim controlled rotation support
```

Raw identifiers may still exist in columns for cleanup and FK behavior:

```text
installation_id
account_id
profile_id
```

Those columns must not be returned or logged. They support retention cleanup and account deletion.

## 12. normalized_scene_text Privacy

`normalized_scene_text` is private generated-content input data. It can contain names, family habits, locations, or care details.

Rules:

```text
not returned in API response
not logged
not used in slugs
not exposed in trace
not included in client-visible error details
not sent to unrelated services
```

Retention:

```text
account-scoped rows:
  deleted on account deletion

profile-scoped rows:
  deleted on account deletion
  deleted when profile deletion exists in future

installation-scoped rejected/expired rows:
  short TTL, recommended 7 days

installation-scoped active rows:
  retained only until canonicalized, account-linked, or TTL expires
  recommended TTL 30 days if not linked to an account

installation-scoped promoted rows:
  forbidden by database constraint in B2.1

global_candidate rows:
  only from explicit future promotion/review flow, not B2.1
```

B2.1 does not need a full retention framework, but implementation must add enough metadata and tests so pre-auth installation-scoped content is not retained forever silently.

Required retention hooks:

```text
retention_expires_at is explicit metadata
installation rejected/expired defaults to 7 days
installation active defaults to 30 days
active/rejected/expired terminal rows clear normalized_scene_text
batch stale-draft hook: generation_expires_at <= now -> expired, clear input, installation retention now+7d
batch installation cleanup query/delete covers due active/rejected/expired rows
request-path live lookup does not reuse installation active after retention_expires_at
under the owner lock, a due active row is expired before replacement reservation
no scheduler is required in B2.1
```

## 13. Idempotency and Fingerprint

Fingerprint inputs:

```text
surface
mode
normalizedSceneText
ageRange
parentGoal
locale
owner_scope
promptVersion
strategyVersion
```

Do not include:

```text
clientTraceId
discoveryTraceId
JWT/session id
raw customSceneText before normalization
provider trace id
model runtime trace id
```

Fingerprint algorithm:

```text
1. trim and normalize whitespace
2. normalize full-width punctuation where safe
3. lower-case ASCII letters
4. preserve Chinese text
5. build canonical JSON with sorted keys
6. SHA-256 or HMAC-SHA256 canonical JSON
7. store hex/base64url digest as request_fingerprint
```

Idempotency behavior:

```text
same owner_key + surface + mode + fingerprint + prompt/strategy/policy versions returns existing reusable active/promoted content
existing active/promoted content returns without AI call only while its retention contract remains live
existing draft content returns no AI call
expired/rejected rows do not block retry
unique conflict fetches existing row
failed generation never creates active row
unsafe generated output may store rejected row only for abuse diagnostics
```

Concurrency behavior:

```text
active/promoted may use an unlocked fast path, but the locked path always rechecks the live fingerprint
one REQUIRES_NEW transaction acquires the owner advisory lock, rechecks live fingerprint, counts burst/daily attempts, handles stale/due rows, reserves draft, and commits
the owner lock is never released between count and reserve
request A inserts draft reservation and commits
request B observes the committed live row under the same owner lock
if row is active/promoted, B returns generated response or follows future promoted-to-curated redirect
if row is draft and not expired, B waits briefly or returns 409 generation_in_progress
if row is expired/rejected, B may retry by creating a new draft
provider execution starts only after that reservation transaction has committed and released its owner lock
```

Do not hold a DB transaction open across provider calls. Reserve draft, commit, generate outside transaction, then activate/reject/expire.

## 14. Stable Slug Strategy

Recommendation: hash-only slugs.

Use:

```text
space_slug    = gen_scene_<short_hash>
activity_slug = gen_activity_<short_hash>
phrase_slug   = gen_phrase_<short_hash>
```

Do not use:

```text
gen_scene_<semantic_hint>_<short_hash>
gen_activity_<semantic_hint>_<short_hash>
gen_phrase_<semantic_hint>_<short_hash>
```

Reason:

```text
Semantic hints can leak raw customSceneText or accidental PII.
Hash-only slugs are stable, short, safe for events/API references, and enough for debugging when paired with generatedContentId.
Human-readable titles remain in title fields after validation.
```

Collision rule:

```text
unique slug indexes enforce safety
on rare collision, generate a new generated_content_id suffix and retry before provider response is returned
```

## 15. AI / Agentic Generation Boundary

B2.1 may use internal Mentor/Spring AI / agentic search / RAG runtime through a typed boundary. It must not call public `/api/v1/mentor/chat`.

Feature flag:

```text
custom_scene generation can be disabled by config
provider disabled returns generation_unavailable
provider disabled response is stable, not a server crash
provider timeout has strict cap
CI must not depend on real provider/network/key
provider-mode accepts only disabled, fake, or agentic; unknown values fail startup binding
disabled and not-yet-implemented agentic modes return a controlled non-retryable generation_unavailable before DB, rate limit, owner HMAC, or provider work
agentic is an explicit unavailable placeholder in B2.1, not a real adapter
```

Recommended config:

```text
babytalk.practice.discovery.custom-scene.enabled=false|true
babytalk.practice.discovery.custom-scene.provider-mode=disabled|fake|agentic
babytalk.practice.discovery.custom-scene.timeout=5s
babytalk.practice.discovery.custom-scene.prompt-version=custom_scene_v1
babytalk.practice.discovery.custom-scene.strategy-version=rag_v1
```

Recommended service:

```java
public interface CustomSceneGenerationService {
    GeneratedPracticeContentCandidate generateCustomSceneStarter(
            CustomSceneGenerationRequest request
    );
}
```

Typed request:

```java
public record CustomSceneGenerationRequest(
        String customSceneText,
        String normalizedSceneText,
        String ageRange,
        String parentGoal,
        String locale,
        PracticeDiscoverySurface surface,
        PracticeDiscoveryMode mode,
        String promptVersion,
        String strategyVersion,
        String traceId,
        ContentConstraints constraints
) {}
```

Structured output:

```java
public record GeneratedPracticeContentCandidate(
        String spaceTitleZh,
        String activityTitleZh,
        String sceneTagEn,
        String coachTipZh,
        String englishText,
        String chineseText,
        String pronunciationHint,
        String difficulty,
        List<String> safetyNotes,
        List<String> validationFlags,
        String retrievalTraceId,
        String providerTraceId,
        String modelName,
        String generationSource
) {}
```

Mapping rule:

```text
GeneratedPracticeContentCandidate.generationSource maps to practice_generated_content.generation_source.
PracticeDiscoveryResponse.source remains generated for all generated-content success responses.
Do not expose generation_source as response source.
```

Testing decision:

```text
B2.1 success-path tests use fake CustomSceneGenerationService.
Fake generator returns deterministic successful structured candidates with generation_source=fake.
Timeout, unavailable, malformed-output, and unsafe-output branches use a test-only mutable/mock provider; provider-mode is not a behavior simulator.
provider-mode selects only disabled, fake, or a future agentic provider.
In B2.1, agentic wires an explicit not-implemented provider boundary and fails requests with controlled non-retryable semantics; the real adapter remains a future slice.
No test calls real provider, network, key, Spring AI, or public /api/v1/mentor/chat.
```

Boundary rules:

```text
No free-form prompt from mobile.
No direct use of customSceneText as system instructions.
Generator receives typed product fields and fixed constraints.
Prompt version and strategy version are constants/config from backend.
Provider response must parse into structured output.
Validator runs before active persistence.
Only persisted active row hydrates API response.
```

Provider failure handling:

| failure | handling |
| --- | --- |
| feature/provider mode disabled | do not reserve; return `503 generation_unavailable`, `retryable=false` |
| agentic placeholder | do not reserve; return `503 generation_unavailable`, `retryable=false` |
| timeout | mark draft expired; return `504 generation_timeout`, `retryable=true` |
| provider unavailable | mark draft expired; return `503 generation_unavailable`, `retryable=true` |
| unexpected provider/validation/activation runtime failure | best-effort expire and clear draft input; return sanitized `503 generation_unavailable`, `retryable=true`; stale-draft hook is the second safety net |

All provider and validator terminal cleanup is best-effort: cleanup failure is suppressed on the original typed failure and never replaces the stable client contract.
| invalid JSON / malformed structure | mark rejected; return `502 generation_invalid_output` |
| unsafe content | mark rejected; return `422 generated_content_rejected` |
| too-long phrase | mark rejected; return `422 generated_content_rejected` |
| not caregiving related | reject before provider or reject generated output |
| not suitable for 0-3 | reject generated output |
| lesson/quiz/task wording | reject generated output |
| child-performance wording | reject generated output |

## 16. Validation and Safety

Backend must validate generated output before active persistence.

Generated-output rules:

```text
English starter length bounded, recommended 1-6 words and <= 40 chars
Chinese support text bounded, recommended <= 24 Chinese chars
coachTipZh bounded, recommended <= 80 Chinese chars
sceneTagEn bounded, recommended <= 60 chars
No course/lesson/quiz/task framing
No child-performance scoring
No medical/legal unsafe instruction
No adult/violent/sexual content
No unsupported claims
Parent-speakable full sentence or short phrase
Suitable for 0-3 family care moment
Matches custom scene intent enough
No phone number or obvious baby name leakage
No email leakage
No raw prompt-injection text echoed back
dynamically generated DB varchar fields are checked before persistence: titles 120, pronunciation 120, provider/retrieval trace 128, model name 96
difficulty in starter/easy/medium/hard, prefer starter
production generation_source in agentic_search/rag_generation/manual; fake is accepted only by the test/dev fake-provider validator path
```

Intent and policy configuration:

```text
classpath resource: backend/app-api/src/main/resources/config/practice-discovery-policy.yml
request regexes, PII markers, injection markers, care orientation, output validator lists, and scene-intent markers live in that YAML
PracticeDiscoveryPolicyProperties performs typed binding, validation, normalization, and pattern compilation only
scene classification may match multiple intents; generated output must align with at least one classified intent
every accepted care-orientation marker must belong to a scene-intent request marker; configuration fails fast on gaps, and validator context with no classification fails closed
policy-version is part of the typed properties and persisted fingerprint contract
editing the policy resource requires an explicit policy-version bump in the same change; automatic content-hash enforcement is deferred
```

Validation pipeline:

```text
request validation
    |
    v
idempotency lookup
    |
    v
rate limit if generation needed
    |
    v
draft reservation
    |
    v
typed generator
    |
    v
content validator
    |
    +--> pass: activate row, return generated response from persisted row
    |
    +--> fail: reject/expire row, return stable error
```

## 17. Generated Source Resolver Handoff

Future B3 needs to resolve:

```text
source = catalog
source = generated
```

Plan service boundary:

```java
public interface PracticeContentReferenceResolver {
    PracticeContentReference resolvePracticeContent(
            String source,
            String activityId,
            String phraseId,
            String generatedContentId
    );
}
```

B2.1 recommendation:

```text
Plan resolver contract now.
Implement only lookup needed by PracticeDiscovery generated response hydration tests.
Do not implement POST /api/v1/care-turns.
Do not write reaction-based next support.
```

Resolver behavior:

```text
source=catalog:
  use PracticeCatalogRepository.existsSpaceActivityPhrase / starter lookups

source=generated:
  require generatedContentId
  fetch active practice_generated_content row
  verify activityId and phraseId match row slugs
  return stable reference
```

## 18. Existing practice/generate Compatibility

Decision: B2.1 leaves existing `/mentor/practice/generate` source=`llm` catalog write-through unchanged.

Current behavior from `MentorService.generatePractice()`:

```text
rate limit through mentor audit window
cache hit by catalogRepo.findActivityBySceneTag(sceneTag)
provider call when cache miss
persistToCatalog(sceneTag, parsed)
generated activity slug = llm_<sanitized_scene>_<8 hex>
insertActivity / insertPhrase write source='llm'
write-through failure logs and falls back to parsed provider response
```

B2.1 must not silently rewrite this path.

`practice_generated_content` does not replace existing practice/generate write-through in B2.1. A future migration/compatibility slice can decide whether mentor/practice generated content should dual-write or migrate to `practice_generated_content`.

Compatibility tests must prove:

```text
custom_scene does not call /api/v1/mentor/chat
custom_scene does not use PracticeGenerateController
existing PracticeGenerateControllerTest remains green
existing MentorServiceTest remains green
existing MentorWebTest remains green
```

## 19. Security / Abuse Control

Pre-auth custom_scene can trigger AI cost. Minimum protection:

```text
installationId required for draft
customSceneText length limit
clientTraceId safe slug
request fingerprint idempotency before rate limit
duplicate fingerprint returns existing active content, no AI call
draft reservation prevents concurrent duplicate AI calls
provider timeout cap
feature flag can disable provider
no arbitrary prompt
no mentor/chat exposure
log only non-PII trace data
```

Recommended minimal B2.1 rate-limit strategy:

```text
Use practice_generated_content itself as accounting source.
Count new draft/rejected/expired/active rows by owner_key + surface + mode + created_at window.
Count promoted rows as attempts too.
Do not count idempotent active hits.
Do not depend on Redis.
Do not couple PracticeDiscoveryService to MentorService.
```

Suggested caps:

```text
installation scope:
  burst: 3 new generations / 10 minutes
  daily: 10 new generations / day

account/profile scope:
  burst: 5 new generations / 10 minutes
  daily: 20 new generations / day
```

Scope limit:

```text
installation rate limiting is an atomic per-owner soft limit, not strong abuse prevention, because installationId is client supplied and can be rotated
IP/WAF limiting, device attestation, Redis buckets, and provider billing circuit breakers are future hardening and are not B2.1 scope
```

Logging:

```text
log generatedContentId
log owner_scope, not owner_key
log requestFingerprint
log providerTraceId/retrievalTraceId
log status/error code
do not log owner_key
do not log raw customSceneText
do not log normalized_scene_text
do not log provider raw response
```

## 20. Backend Files

Proposed implementation files:

```text
backend/db-migration/src/main/resources/db/migration/V25__create_practice_generated_content.sql
backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java

backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/PracticeDiscoveryController.java
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeDiscoveryService.java
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeDiscoveryMode.java
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeDiscoverySurface.java

backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeGeneratedContentMapper.java
backend/app-api/src/main/resources/mapper/service/PracticeGeneratedContentMapper.xml
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeGeneratedContentRepository.java
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeGeneratedContentService.java

backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/CustomSceneGenerationService.java
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/CustomSceneGeneratedContentValidator.java
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeContentReferenceResolver.java

backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/PracticeDiscoveryControllerTest.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/PracticeDiscoveryServiceTest.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/PracticeGeneratedContentRepositoryTest.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/PracticeGeneratedContentServiceTest.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/CustomSceneGeneratedContentValidatorTest.java
backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java
```

Existing B2 files to rename or replace:

```text
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/OnboardingDiscoveryController.java
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/OnboardingDiscoveryService.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/OnboardingDiscoveryControllerTest.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/OnboardingDiscoveryServiceTest.java
```

Expected no-touch files:

```text
mobile/**
mobile_v2/**
admin-web/**
```

## 21. Tests

Route / rename tests:

```text
POST /api/v1/practice/discovery catalog succeeds
old /api/v1/onboarding/discovery route is absent by default
if alias is kept, alias delegates to PracticeDiscoveryService and is covered by one compatibility test
request includes surface=onboarding and mode=catalog
invalid surface/mode pair returns unsupported_discovery_surface_mode
invalid bearer token still rejected
```

Repository tests:

```text
V25 table exists with expected columns
owner_scope/surface/mode/generation_source/status checks reject invalid values
status includes expired
shape constraints reject dirty owner shapes
active shape check rejects incomplete active rows
owner_key uniqueness handles nullable account_id / installation_id / profile_id safely
same owner_key + surface + mode + fingerprint + versions cannot have duplicate draft/active/promoted rows
promoted row blocks duplicate active row for same owner/surface/mode/fingerprint/version
different owner_key + same fingerprint may coexist
expired/rejected rows do not block retry
slug uniqueness for active/promoted rows
active/promoted lookup by generatedContentId
active/promoted lookup by owner_key + surface + mode + requestFingerprint + versions
draft reservation conflict returns existing row
retention cleanup queries can find installation-scoped expired/rejected rows
stale-draft batch hook expires rows and clears normalized_scene_text
installation cleanup covers due active/rejected/expired rows
installation promoted rows are rejected by constraint
expired installation active rows are not reused and are lazily expired under owner lock
account privacy deletion removes current and historical owner_key_version rows while retaining installation rows
```

Service tests:

```text
surface=onboarding mode=catalog keeps B2 catalog behavior
surface=onboarding mode=custom_scene without JWT succeeds with installationId
custom_scene with same fingerprint returns existing generated content without AI call
custom_scene concurrent duplicate resolves to existing row or generation_in_progress without duplicate AI call
same owner/different fingerprints cannot pass the atomic cap concurrently
same expired-active fingerprint concurrently reserves at most one replacement and calls provider once
provider starts only after the reservation transaction commits and unlocks the owner
custom_scene persists before response
response returns source=generated
response includes generatedContentId and stable slugs
generated slugs do not expose raw customSceneText or normalized_scene_text
invalid customSceneText rejected
unsafe generated output rejected
feature-disabled provider returns generation_unavailable retryable=false
provider timeout returns generation_timeout retryable=true suggestCatalogFallback=true
no /api/v1/mentor/chat call
draft response has no account private data
authenticated profile custom_scene verifies ownership
accepted account custom_scene without babyProfileId does not require installationId
provided JWT consent_required/consent_revoked errors never fall back to installation scope
rate limit / daily cap behavior
catalog mode remains unchanged
```

Validator tests:

```text
English starter too long rejected
Chinese support text too long rejected
lesson/quiz/task wording rejected
child-performance scoring rejected
medical/legal unsafe instruction rejected
adult/violent/sexual content rejected
unsupported claims rejected
non-caregiving scene rejected
0-3 unsuitable content rejected
parent-speakable short phrase accepted
Chinese/English mixed safe content accepted
prompt-injection echo rejected
```

Regression tests:

```text
PracticeCatalogRepositoryTest
MentorServiceTest
MentorWebTest
PracticeGenerateControllerTest
PracticeDiscoveryServiceTest existing catalog cases
PracticeDiscoveryControllerTest existing catalog cases
```

## 22. Coverage Diagram

```text
CODE PATHS                                                       TEST EXPECTATION
PracticeDiscoveryController
  POST /api/v1/practice/discovery
    surface=onboarding + mode=catalog                            [GAP -> migrated B2 tests]
    surface=onboarding + mode=custom_scene no JWT                 [GAP -> controller test]
    invalid surface / mode / pair                                 [GAP -> controller tests]
    invalid bearer                                                [GAP -> security regression]
    babyProfileId without JWT                                     [GAP -> controller test]
    profile owner / mismatch                                      [GAP -> controller test]
    old onboarding route absent or alias-covered                   [GAP -> route contract test]

PracticeDiscoveryService
  validate request
    customSceneText valid / missing / unsafe / arbitrary chat      [GAP -> service tests]
    surface/mode split                                             [GAP -> service tests]
  resolve owner scope
    installation HMAC owner_key                                    [GAP -> service test]
    account HMAC owner_key                                         [GAP -> service test]
    profile HMAC owner_key                                         [GAP -> service test]
  idempotency
    active hit                                                     [GAP -> no AI call test]
    draft conflict                                                 [GAP -> concurrency test]
    expired/rejected retry                                         [GAP -> service test]
  generation
    fake generator success                                         [GAP -> Spring wiring + service test]
    test-only mutable/mock provider unavailable                     [GAP -> service test]
    test-only mutable/mock provider timeout                         [GAP -> service test]
    invalid structured output                                      [GAP -> validator + service test]
  persistence
    active row before response                                     [GAP -> repository/service test]
    generatedContentId and slugs stable                            [GAP -> service test]
  response
    source=generated                                               [GAP -> controller/service test]
    no owner_key / normalized_scene_text / private draft fields    [GAP -> controller test]

PracticeGeneratedContentRepository
  reserveDraft                                                     [GAP -> repository test]
  activateDraft                                                    [GAP -> repository test]
  rejectDraft                                                      [GAP -> repository test]
  expireDraft                                                      [GAP -> repository test]
  findActiveByOwnerFingerprint                                     [GAP -> repository test]
  findActiveByGeneratedContentId                                   [GAP -> repository test]
  countRecentGenerationAttempts                                    [GAP -> repository test]
  cleanup lookup for installation-scope TTL                        [GAP -> repository test]

LLM integration
  typed agentic boundary with explicit unavailable placeholder      [B2.1]
  real agentic/RAG implementation behind typed port                 [DEFERRED] future slice

USER FLOWS
  Parent cannot find catalog scene, enters custom scene             [GAP -> controller/service integration]
  Parent taps same custom scene twice                              [GAP -> idempotency test]
  Two devices submit same custom scene concurrently                 [GAP -> concurrency test]
  Provider disabled or unavailable during onboarding                [GAP -> stable error test]
  Unsafe custom scene text                                         [GAP -> validation test]

COVERAGE TARGET: every branch above covered before implementation is done.
```

## 23. Implementation Gates

Do not start AI integration before schema/idempotency and fake-generator hydration are stable.

- [ ] **B2.1-01 PracticeDiscovery rename / route contract (P1, human: ~1h / CC: ~25min)**
  - Work: rename/replace B2 `OnboardingDiscovery*` with `PracticeDiscovery*`, introduce `POST /api/v1/practice/discovery`, add `surface` + `mode`, migrate catalog tests.
  - Files: `PracticeDiscoveryController.java`, `PracticeDiscoveryService.java`, `PracticeDiscoverySurface.java`, `PracticeDiscoveryMode.java`, `PracticeDiscoveryControllerTest.java`, `PracticeDiscoveryServiceTest.java`, `AppSecurityConfig.java` if route permit changes.
  - Verify: `mvn test -pl app-api -Dtest=PracticeDiscoveryControllerTest`; invalid bearer still rejects; catalog mode still source=catalog.

- [ ] **B2.1-02 practice_generated_content schema + repository + idempotency (P1, human: ~1.5h / CC: ~35min)**
  - Work: add V25 table, HMAC owner_key contract, owner_scope shape constraints, `expired` status, unique live fingerprint index, MyBatis mapper/repository.
  - Files: V25 migration, `DbMigrationApplication.java`, `DbMigrationSmokeTest.java`, `PracticeGeneratedContentMapper.java`, XML mapper, repository, repository tests.
  - Verify: `mvn test -pl db-migration -Dtest=DbMigrationSmokeTest`; `mvn test -pl app-api -Dtest=PracticeGeneratedContentRepositoryTest`.

- [ ] **B2.1-03 validator + fake generator + response hydration (P1, human: ~1.5h / CC: ~40min)**
  - Work: add custom scene validation, generated output validator, fake `CustomSceneGenerationService`, draft reservation, activation, generated response hydration from active row.
  - Files: `CustomSceneGenerationService.java`, `CustomSceneGeneratedContentValidator.java`, `PracticeGeneratedContentService.java`, `PracticeDiscoveryService.java`, service/validator/controller tests.
  - Verify: fake-generator success wiring; test-only mutable/mock unsafe/timeout/disabled tests; no real provider/network/key.

- [ ] **B2.1-04 typed agentic boundary only (P1 after gates 01-03)**
  - Work: keep `agentic` as an explicit not-implemented provider placeholder; do not add a real adapter in B2.1.
  - Files: provider port, disabled/fake/agentic wiring, typed failure semantics, Spring wiring tests.
  - Verify: disabled and agentic fail before reservation with non-retryable controlled errors; transient mock provider unavailable is retryable; no public `/api/v1/mentor/chat` call.

- [ ] **B2.1-05 rate limit / abuse controls / regression pass (P1, human: ~1h / CC: ~25min)**
  - Work: count generation attempts by owner_key/surface/mode, daily/burst cap, installation TTL cleanup plan hooks, run catalog/mentor/practice regressions.
  - Files: `PracticeGeneratedContentRepository.java`, `PracticeGeneratedContentService.java`, `PracticeDiscoveryService.java`, tests.
  - Verify: rate limit tests; scope guard; `PracticeCatalogRepositoryTest`, `MentorServiceTest`, `MentorWebTest`, `PracticeGenerateControllerTest`.

## 24. Parallelization Strategy

| Gate | Modules touched | Depends on |
| --- | --- | --- |
| B2.1-01 PracticeDiscovery rename | `backend/app-api/web`, `backend/app-api/service`, tests | none |
| B2.1-02 registry schema/repository | `backend/db-migration`, `backend/app-api/service`, mapper XML | none, but aligns with B2.1-01 DTO naming |
| B2.1-03 validator/fake generator/hydration | `backend/app-api/service`, tests | B2.1-01 + B2.1-02 |
| B2.1-04 real provider adapter | `backend/app-api/service/config` | B2.1-03 |
| B2.1-05 rate limits/regressions | `backend/app-api/service`, tests | B2.1-03 |

Recommended execution:

```text
Do B2.1-01 and B2.1-02 first.
Then B2.1-03.
Then B2.1-04 and B2.1-05.
```

Conflict flag:

```text
B2.1-01 and B2.1-03 both touch PracticeDiscoveryService tests.
Keep sequential unless using coordinated worktrees.
```

## 25. Verification Commands

Focused backend tests for future implementation:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl db-migration -Dtest=DbMigrationSmokeTest
  mvn test -pl app-api -Dtest=PracticeDiscoveryControllerTest
  mvn test -pl app-api -Dtest=PracticeDiscoveryServiceTest
  mvn test -pl app-api -Dtest=PracticeGeneratedContentRepositoryTest
  mvn test -pl app-api -Dtest=PracticeGeneratedContentServiceTest
  mvn test -pl app-api -Dtest=CustomSceneGeneratedContentValidatorTest
  mvn test -pl app-api -Dtest=PracticeCatalogMapperTest,PracticeCatalogServiceTest
  mvn test -pl app-api -Dtest=PracticeGeneratedContentConcurrencyTest
  mvn test -pl app-api -Dtest=CustomSceneGenerationProviderWiringTest
  mvn test -pl app-api -Dtest=PracticeDiscoveryPolicyPropertiesTest,PracticeDiscoveryCustomScenePropertiesTest,PracticeGeneratedContentOwnerPropertiesTest
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
git diff --name-only -- backend | Select-String -Pattern 'OnboardingDiscovery|PracticeDiscovery|PracticeGeneratedContent|V25|DbMigration|Mentor|PracticeGenerate|PracticeCatalog'
```

Doc-only verification for this planning slice:

```powershell
git status --short
git diff -- docs/superpowers/plans/2026-07-03-t8-2-b2-1-practice-generated-content-custom-scene-plan.md
git diff --name-only -- backend mobile mobile_v2 admin-web
```

Expected doc-only result:

```text
Only docs/superpowers/plans/2026-07-03-t8-2-b2-1-practice-generated-content-custom-scene-plan.md changes.
No Java, XML, SQL, Flutter, React, mobile_v2, admin-web implementation is written.
No commit is created.
```

## 26. Explicitly Not In Scope

```text
no app scene search endpoint behavior
no mobile code
no mobile repository wiring
no Flutter UI
no POST /api/v1/care-turns
no reaction-based next support
no gardenImpact
no Garden/Growth writes
no phone auth UI
no curated catalog promotion
no generated-to-curated admin review UI
no mentor/chat hardening
no direct call to /api/v1/mentor/chat
no practice/generate rewrite
no reaction enum changes
no mobile_v2
no admin-web
no commit
```

## 27. B3 Handoff

B2.1 completion provides:

```text
PracticeDiscovery shared route and naming
surface=onboarding + mode=catalog from B2
surface=onboarding + mode=custom_scene from B2.1
catalog starter ids
generated starter ids
practice_generated_content active rows
generatedContentId
source=generated
resolver contract for source=catalog/source=generated
profile context from B1
discovery trace from B2/B2.1
```

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

B2.1 does not implement care-turns.

## 28. Risks

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Discovery remains onboarding-named. | Future app search/care-turn/mentor discovery would inherit wrong API/domain names. | B2.1-01 renames to PracticeDiscovery and uses surface=onboarding. |
| Surface/mode combination values creep in. | Creates unbounded magic values like onboarding_custom_scene. | Separate `surface` and `mode` enums and tests. |
| Nullable uniqueness bug. | Duplicate generated rows for same owner/fingerprint. | HMAC `owner_key` and partial unique live index including surface/mode/versions. |
| owner_key leaks identifiers. | Installation/account/profile identifiers become visible in logs or diagnostics. | HMAC owner_key; never return/log it. |
| normalized_scene_text retained forever. | Private family input persists as pre-auth data. | TTL policy for installation rows, deletion for account/profile rows. |
| Draft reservation over-engineering. | Too much machinery for one endpoint. | Single table, explicit `expired`, no queue/worker in B2.1. |
| Holding DB transaction during provider call. | Connection starvation and locks under slow provider. | Reserve draft, commit, generate outside transaction, activate/reject/expire. |
| Real AI makes CI flaky. | Tests fail without provider/network/key. | Fake generator in tests; feature flag; provider adapter behind typed port. |
| Silent catalog fallback. | Parent sees unrelated scene after asking for custom scene. | Clear error response with `suggestCatalogFallback=true`. |
| Rewriting `practice/generate` accidentally. | Breaks existing practice tests and cache semantics. | Leave MentorService write-through unchanged; run regressions. |

## 29. Eng Review Completion Summary

- Step 0: Scope Challenge - scope revised per review: discovery is shared PracticeDiscovery, onboarding is only first surface.
- Architecture Review: 6 issues folded into plan - Option A endpoint, surface/mode split, HMAC owner_key, owner_scope shape constraints, explicit expired state, feature flag.
- Code Quality Review: 4 issues folded into plan - PracticeDiscovery naming, implementation gates, fake generator tests, leave practice/generate unchanged.
- Test Review: coverage diagram updated for route rename, fake generator, privacy, TTL, and regressions.
- Performance Review: bounded rate-limit counts and indexed owner/surface/mode/created lookups.
- NOT in scope: written.
- What already exists: written through B2/B2.0 references.
- TODOS.md updates: 0 items proposed; existing TODOs do not block B2.1 planning.
- Failure modes: 0 unhandled critical silent gaps after planned tests.
- Outside voice: review feedback folded.
- Parallelization: gates defined; sequential recommended after route/schema contracts.
- Lake Score: complete shared discovery plan chosen over onboarding-only shortcut.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | not run | Product scope remains fixed: onboarding custom scene first; app search, care-turns, and promotion UI deferred. |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run | No implementation diff exists. |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 2 | clear | Review folded: PracticeDiscovery naming, Option A endpoint, split surface/mode, HMAC owner_key, expired status, privacy TTL, fake-generator gates, feature flag, compatibility. |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not needed | Backend plan only; no mobile UI, Flutter UI, or admin-web scope. |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | Implementation gates, focused verification commands, and scope guards are included. |

- **VERDICT:** ENG PLAN REVISED - ready for user review before B2.1 implementation.

NO UNRESOLVED DECISIONS
