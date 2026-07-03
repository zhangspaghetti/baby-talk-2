# T8.2 B2.0 PracticeCatalogRepository MyBatis Rewrite Plan

Date: 2026-07-03
Status: waiting for review
Strategy: Option B, migrate the existing `PracticeCatalogRepository` to MyBatis/XML instead of adding a parallel discovery repository.
Scope: doc-only planning slice. No code implementation, no commit.

## 1. Scope

B2.0 only plans the `PracticeCatalogRepository` MyBatis rewrite.

B2.0 may plan:

```text
PracticeCatalogMapper.java
PracticeCatalogMapper.xml
PracticeCatalogRepository rewrite
existing method parity
catalog row models
starter utterance lookup
scene/moment/phrase validation query support
tests
```

B2.0 must not plan implementation of:

```text
POST /api/v1/onboarding/discovery
POST /api/v1/care-turns
Mentor/Spring AI behavior changes
generated content registry
mobile UI
mobile repository wiring
Garden/Growth changes
mentor/chat hardening
reaction enum changes
```

The intended boundary is narrow:

```text
existing callers
    |
    v
PracticeCatalogRepository  (same public legacy contract where possible)
    |
    v
PracticeCatalogMapper      (new MyBatis mapper interface)
    |
    v
PracticeCatalogMapper.xml  (all catalog SQL)
    |
    v
practice_spaces / practice_activities / practice_phrases
```

## 2. Current PracticeCatalogRepository Audit

Current file:

```text
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeCatalogRepository.java
```

Current shape:

- `@Repository` class using `JdbcTemplate`.
- Seven public methods.
- Two nested record models:
  - `CachedActivity(long id, String slug, String spaceSlug, String titleZh, String coachTip)`
  - `CachedPhrase(long id, String slug, int step, String english, String chinese, String pronunciation, String difficulty)`
- Direct production caller: `MentorService.generatePractice()` and `MentorService.persistToCatalog()`.
- No dedicated `PracticeCatalogRepositoryTest` currently exists.
- Existing web/service regressions around the practice path live in:
  - `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/PracticeGenerateControllerTest.java`
  - `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/MentorWebTest.java`
  - `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/MentorServiceTest.java`

Seed catalog assumptions:

- Tables created by `backend/db-migration/src/main/resources/db/migration/V22__create_practice_catalog_tables.sql`.
- Seed rows inserted by `backend/db-migration/src/main/resources/db/migration/V22_1__seed_practice_catalog.sql`.
- Seed content is 2 spaces, 4 activities, 9 phrases:
  - spaces: `daily_care`, `family_rhythm`
  - activities: `bath_time`, `diaper_change`, `feeding_time`, `bedtime`
  - phrases: step-ordered phrase rows under each activity
- `practice_spaces.slug`, `practice_activities.slug`, and `practice_phrases.slug` are the public stable ids used by mobile/Garden/Growth-style flows.
- `practice_activities.id` and `practice_phrases.id` are database ids used by current cache response DTOs.

Current ordering rules:

- `findAllSpaceSlugs()` orders by `practice_spaces.sort_order`.
- `findPhrasesByActivityId(long)` orders by `practice_phrases.step`.
- Seed activity ordering is encoded in `practice_activities.sort_order`, but current `PracticeCatalogRepository` has no list-by-space method.
- Current `findActivityBySceneTag(String)` uses `LIMIT 1` without `ORDER BY`; this is nondeterministic if duplicate `scene_tag_en` values exist.
- Generated activities use `sort_order` default `0`; seed activities have explicit `sort_order`.

Current generated practice persistence behavior:

- `MentorService.persistToCatalog()` is responsible for write-through after LLM practice generation.
- It classifies a `sceneTag` to a space slug:
  - bath/diaper/wash/dressing -> `daily_care`
  - feed/meal/bed/sleep -> `family_rhythm`
  - otherwise -> `general_practice`
- It calls `insertSpace(spaceSlug, spaceSlug)`.
- It creates random generated activity slugs like `llm_<sanitized_scene>_<8 hex>`.
- It calls `insertActivity(activitySlug, spaceId, sceneTag, sceneTag, null)`.
- It inserts generated phrases as `<activitySlug>_<step>`.
- Repository insert methods use `ON CONFLICT (slug) DO NOTHING RETURNING id`, then fall back to lookup by slug.
- Write-through failure is swallowed by `MentorService` and should not break the API response.

### Method Parity Table

| method | current SQL responsibility | current caller(s) | must preserve behavior? | new MyBatis mapper method | test coverage |
| --- | --- | --- | --- | --- | --- |
| `findActivityBySceneTag(String sceneTagEn)` | Join `practice_activities` to `practice_spaces`; select activity id, activity slug, space slug, title, coach tip where `scene_tag_en = ?`; current SQL has `LIMIT 1` and no stable order. | `MentorService.generatePractice()` cache-hit branch. | Yes. Cache hit must still skip provider and return DB-backed activity/phrases. Add deterministic tie-break `ORDER BY a.id ASC` to make duplicate scene tags stable without changing unique-scene behavior. | `PracticeCatalogMapper.findActivityBySceneTag(@Param("sceneTagEn") String sceneTagEn)` | Add repository parity test for seeded scene tag and duplicate scene-tag tie-break; add MentorService/PracticeGenerate regression for cache hit. |
| `findPhrasesByActivityId(long activityId)` | Select phrase id, slug, step, English, Chinese, pronunciation, difficulty from `practice_phrases` where numeric `activity_id = ?`; order by `step`. | `MentorService.generatePractice()` cache-hit branch via `buildCachedResponse()`. | Yes. Phrase DTO ordering must stay step-based. Add `id ASC` tie-break after `step` for stable duplicate-step behavior. | `PracticeCatalogMapper.findPhrasesByActivityId(@Param("activityId") long activityId)` | Add parity test for phrase order under `bath_time`; add duplicate-step stability test. |
| `findSpaceIdBySlug(String slug)` | Select numeric id from `practice_spaces` by slug. | `insertSpace()` fallback path; may be useful directly for tests. | Yes. Empty -> `Optional.empty`; existing row -> id. | `PracticeCatalogMapper.findSpaceIdBySlug(@Param("slug") String slug)` | Add existing slug, missing slug, and insert conflict fallback tests. |
| `findAllSpaceSlugs()` | Select all space slugs ordered by `sort_order`. | No current production caller found. | Yes. Existing public method should remain for compatibility and future callers. Add `slug ASC` tie-break for stable equal sort order. | `PracticeCatalogMapper.findAllSpaceSlugs()` | Add seed order test: `daily_care`, `family_rhythm`; add no-duplicate rows assertion. |
| `insertSpace(String slug, String titleZh)` | Insert `practice_spaces(slug, title_zh)` with `ON CONFLICT (slug) DO NOTHING RETURNING id`; fallback to `findSpaceIdBySlug`; throws `IllegalStateException` if insert and lookup fail. | `MentorService.persistToCatalog()` generated content write-through. | Yes. Must preserve id return on insert and conflict. | `PracticeCatalogMapper.insertSpaceReturningId(@Param("slug") String slug, @Param("titleZh") String titleZh)` plus `findSpaceIdBySlug` | Add inserted row returns id; duplicate slug returns existing id; generated `general_practice` behavior parity. |
| `insertActivity(String slug, long spaceId, String titleZh, String sceneTagEn, String coachTip)` | Insert `practice_activities(slug, space_id, title_zh, scene_tag_en, coach_tip, source='llm')` with `ON CONFLICT (slug) DO NOTHING RETURNING id`; fallback lookup by slug. | `MentorService.persistToCatalog()`. | Yes. Must keep `source='llm'` and conflict fallback. | `PracticeCatalogMapper.insertActivityReturningId(...)`, `PracticeCatalogMapper.findActivityIdBySlug(@Param("slug") String slug)` | Add insert, duplicate slug fallback, source value, scene tag, and coach tip tests. |
| `insertPhrase(String slug, long activityId, int step, String english, String chinese, String pronunciation, String difficulty)` | Insert `practice_phrases(slug, activity_id, step, english, chinese, pronunciation, difficulty, source='llm')` with `ON CONFLICT (slug) DO NOTHING RETURNING id`; fallback lookup by slug. | `MentorService.persistToCatalog()`. | Yes. Must keep `source='llm'`, step, copy fields, and conflict fallback. | `PracticeCatalogMapper.insertPhraseReturningId(...)`, `PracticeCatalogMapper.findPhraseIdBySlug(@Param("slug") String slug)` | Add insert, duplicate slug fallback, source value, null optional fields, and generated persistence parity tests. |

### Current Table Consumers Outside PracticeCatalogRepository

These are not `PracticeCatalogRepository` callers, but they read the same catalog tables and should shape parity expectations:

- `GrowthInsightsService` joins `interaction_events` to `practice_activities`, `practice_spaces`, and first phrase by `pp.step = 1`.
- `GardenSnapshotService` joins `interaction_events` to `practice_activities` and `practice_spaces`.

B2.0 should not rewrite those services, but the plan must avoid schema or seed changes that would disturb them.

## 3. Rewrite Strategy

Use a conservative rewrite:

```text
Keep repository class name: PracticeCatalogRepository
Keep current public method names and return contracts where possible
Move SQL into PracticeCatalogMapper.xml
Add PracticeCatalogMapper.java
Keep legacy CachedActivity and CachedPhrase records unless implementation proves a rename is zero-cost
Do not change MentorService behavior
Do not change current API behavior
Do not change schema or seed data
```

Implementation shape for the future code slice:

```text
PracticeCatalogRepository
    - constructor takes PracticeCatalogMapper
    - wraps nullable mapper returns in Optional
    - enforces limit bounds for new list methods
    - preserves fallback lookup after insert conflicts

PracticeCatalogMapper
    - @Mapper interface
    - @Param on every parameter
    - returns nested repository record rows or nullable Long ids

PracticeCatalogMapper.xml
    - explicit resultMaps for records
    - explicit column lists
    - parameter binding only
    - stable ordering
```

For PostgreSQL `INSERT ... ON CONFLICT ... RETURNING id`, prefer mapper `<select>` statements returning nullable `Long` over `useGeneratedKeys`; this preserves the current "insert or fallback lookup" behavior exactly.

Allowed new repository capabilities are low-level catalog queries only:

```text
list spaces/scenes
list activities/moments by space
find starter phrase by activity
find next phrase by activity/order
validate ids exist
```

These methods do not expose a controller endpoint, do not implement discovery ranking, and do not call Mentor/Spring AI.

## 4. Proposed Files

Future implementation will touch:

```text
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeCatalogMapper.java
backend/app-api/src/main/resources/mapper/service/PracticeCatalogMapper.xml
backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/PracticeCatalogRepository.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/PracticeCatalogRepositoryTest.java
```

Existing test status:

- `PracticeCatalogRepositoryTest.java` does not exist today.
- Create it as a characterization/parity test suite.
- Extend existing regression tests instead of duplicating endpoint coverage:
  - `PracticeGenerateControllerTest` should keep practice API behavior tests.
  - `MentorWebTest` should keep auth/rate-limit web regression tests.
  - `MentorServiceTest` should keep service-level mentor regressions and add focused practice cache/write-through cases only if controller tests are too broad.

Use existing MyBatis conventions:

- Mapper interface package: `com.zhangspaghetti.babytalk.service`
- XML location: `backend/app-api/src/main/resources/mapper/service/PracticeCatalogMapper.xml`
- `AppApiApplication` already has `@MapperScan(value = "com.zhangspaghetti.babytalk", annotationClass = Mapper.class, lazyInitialization = "true")`
- `application.yml` already has `mybatis-plus.mapper-locations: classpath*:/mapper/**/*.xml`

## 5. Query Parity Contract

The rewrite is successful only if these contracts hold:

- Migration and seed data are unchanged.
- Seed catalog read results are identical for unique ids and unique scene tags.
- `findAllSpaceSlugs()` still returns seed slugs in `sort_order` order.
- `findPhrasesByActivityId()` still returns phrase rows ordered by `step`.
- Activity lookup by seeded `scene_tag_en` still returns the same seeded activity.
- Cache-hit `MentorService.generatePractice()` still skips provider and returns DB-backed activity/phrase DTOs.
- Generated catalog write-through still writes `source='llm'` activities and phrases.
- Generated write-through still returns DB ids in generated response DTOs when persistence succeeds.
- Conflict fallback still returns existing ids for duplicate space/activity/phrase slugs.
- Empty/missing lookup behavior remains `Optional.empty()` or empty list, not thrown exceptions.
- `MentorServiceTest`, `PracticeGenerateControllerTest`, and `MentorWebTest` still pass.

Tie-break clarification:

- Current `findActivityBySceneTag()` is nondeterministic for duplicate scene tags because it uses `LIMIT 1` without `ORDER BY`.
- Current `findPhrasesByActivityId()` is nondeterministic for duplicate `step` values because it orders only by `step`.
- MyBatis rewrite should keep behavior for valid unique seed data and add deterministic tie-breaks:
  - activity by scene tag: `order by a.id asc`
  - phrase by activity id: `order by p.step asc, p.id asc`
  - space slugs: `order by sort_order asc, slug asc`
- Tests should explicitly document this as stabilization of ambiguous data, not a business rule change.

## 6. New Discovery-Ready Query Capabilities

B2.0 does not implement discovery API, but the rewritten repository should expose enough reusable query surface for B2:

```java
List<PracticeSpaceRow> findSpaces(String locale, int limit)

List<PracticeActivityRow> findActivitiesBySpace(String spaceId, String locale, int limit)

Optional<PracticePhraseRow> findStarterPhrase(String activityId, String locale)

Optional<PracticePhraseRow> findNextPhrase(String activityId, String currentPhraseId)

boolean existsSpaceActivityPhrase(String spaceId, String activityId, String phraseId)
```

Method names may be adjusted to the local style, but equivalent capability is required.

Recommended row models, likely nested in `PracticeCatalogRepository`:

```java
public record PracticeSpaceRow(
        long id,
        String spaceId,
        String titleZh,
        String descriptionZh,
        int sortOrder
) {}

public record PracticeActivityRow(
        long id,
        String activityId,
        String spaceId,
        String titleZh,
        String sceneTagEn,
        String coachTip,
        int sortOrder,
        String source
) {}

public record PracticePhraseRow(
        long id,
        String phraseId,
        String activityId,
        int step,
        String english,
        String chinese,
        String pronunciation,
        String difficulty,
        String audioAsset,
        String source
) {}
```

Discovery-ready query semantics:

- `spaceId`, `activityId`, and `phraseId` refer to public slug ids, not numeric database ids.
- `locale` is accepted for future-proofing but current schema only stores English plus Chinese columns; B2.0 should not add locale columns.
- `limit` is bounded in repository/service code, for example minimum `1`, maximum `50`, default chosen by the caller.
- `findStarterPhrase()` should prefer starter phrases and stable ordering:

```text
activity slug match
ORDER BY
  CASE WHEN difficulty = 'starter' THEN 0 ELSE 1 END,
  step ASC,
  id ASC
LIMIT 1
```

- `findNextPhrase()` should find the current phrase's step inside the same activity, then return the next higher step ordered by `step ASC, id ASC`.
- `existsSpaceActivityPhrase()` should validate the full slug path:

```text
practice_spaces.slug = spaceId
practice_activities.slug = activityId
practice_phrases.slug = phraseId
activity belongs to space
phrase belongs to activity
```

These capabilities stay repository-only in B2.0. No controller, service ranking, or API response is added.

## 7. MyBatis XML Requirements

XML location:

```text
backend/app-api/src/main/resources/mapper/service/PracticeCatalogMapper.xml
```

Mapper namespace:

```text
com.zhangspaghetti.babytalk.service.PracticeCatalogMapper
```

Requirements:

- Namespace must match the Java mapper fully qualified name.
- Use explicit column lists. Do not use `select *`.
- Use result maps with constructor args for Java records, following `OnboardingProfileMapper.xml` and `MentorMapper.xml`.
- Explicitly map snake_case SQL columns to Java record constructor fields.
- Query sorting must be stable:
  - spaces: `sort_order ASC, slug ASC`
  - activities by space: `sort_order ASC, slug ASC`
  - phrases by activity: `step ASC, id ASC`
  - activity by scene tag: `id ASC`
- Limit parameters must be bounded before calling mapper methods.
- Do not concatenate raw user input into SQL.
- Use parameter binding for `sceneTagEn`, `spaceId`, `activityId`, `phraseId`, `slug`, and `limit`.
- Keep insert SQL source semantics:
  - generated activities: `source = 'llm'`
  - generated phrases: `source = 'llm'`
  - seed rows remain `source = 'seed'` through migration defaults.
- Keep optional columns nullable:
  - `description_zh`
  - `scene_tag_en`
  - `coach_tip`
  - `pronunciation`
  - `difficulty`
  - `audio_asset`

## 8. Tests

Create or extend:

```text
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/PracticeCatalogRepositoryTest.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/MentorServiceTest.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/MentorWebTest.java
backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/PracticeGenerateControllerTest.java
```

Important test isolation note:

- `AbstractIntegrationTest.resetDatabase()` does not reset `practice_spaces`, `practice_activities`, or `practice_phrases`.
- That preserves Flyway seed content for most tests, but generated practice write-through can add rows that survive across tests in the same container.
- Repository tests that need empty catalog behavior or duplicate/tie-break fixtures must isolate their mutations with transactional rollback or explicit after-test restoration.
- Do not globally add practice catalog tables to `RESET_APP_TABLES` in B2.0 unless every affected test is updated to reseed catalog content. Default plan: leave global reset unchanged.

Required coverage:

- Existing repository method parity.
- Spaces/scenes query.
- Activities/moments query.
- Starter phrase lookup.
- Next phrase lookup.
- ID validation.
- Ordering stability.
- Empty catalog behavior.
- Duplicate row prevention / no duplicate result rows.
- Generated content persistence parity.
- MentorService regression.
- No API behavior changes.

### Characterization First

Before implementation changes, add characterization tests against the current `JdbcTemplate` repository:

- Seed spaces return `daily_care`, `family_rhythm` in order.
- `findActivityBySceneTag("Bath time")` returns seeded `bath_time`.
- `findPhrasesByActivityId(bath_time.id)` returns `bath_time_warm_water`, `bath_time_splash_splash`, `bath_time_all_clean` in step order.
- Missing scene tag returns `Optional.empty()`.
- Missing activity id returns empty phrase list.
- `insertSpace()` returns inserted id and duplicate returns existing id.
- `insertActivity()` writes `source='llm'` and duplicate returns existing id.
- `insertPhrase()` writes `source='llm'` and duplicate returns existing id.

Then migrate implementation to MyBatis and keep the same tests passing.

### Discovery-Ready Tests

Add tests for new repository-only methods:

- `findSpaces("zh-CN", limit)` returns public space ids ordered by `sort_order`, no duplicates.
- `findActivitiesBySpace("daily_care", "zh-CN", limit)` returns `bath_time`, `diaper_change` ordered by activity `sort_order`.
- `findStarterPhrase("bath_time", "zh-CN")` returns `bath_time_warm_water`.
- `findNextPhrase("bath_time", "bath_time_warm_water")` returns `bath_time_splash_splash`.
- `findNextPhrase("bath_time", "bath_time_all_clean")` returns empty.
- `existsSpaceActivityPhrase("daily_care", "bath_time", "bath_time_warm_water")` returns true.
- Mismatched space/activity/phrase combinations return false.
- Limit `0`, negative, and overly large values are clamped or rejected consistently by repository/service boundary.

### Regression Tests

Mentor regression must cover:

- Practice generate cache hit for a seeded scene tag returns catalog data and does not call provider.
- Generated practice response still persists generated activity and phrases when scene tag is not in catalog.
- Generated persistence failure still falls back to parsed provider response rather than failing the endpoint.
- Existing `MentorServiceTest` chat tests still pass.
- Existing `MentorWebTest` practice auth/rate-limit tests still pass.
- Existing `PracticeGenerateControllerTest` behavior remains unchanged.

### Coverage Diagram

```text
CODE PATHS                                           TEST EXPECTATION
PracticeCatalogRepository legacy methods
  findActivityBySceneTag(sceneTag)
    -> found unique seed row                         [GAP -> add parity test]
    -> missing scene                                 [GAP -> add empty test]
    -> duplicate scene tie                           [GAP -> add stability test]
  findPhrasesByActivityId(activityId)
    -> ordered phrase rows                           [GAP -> add parity test]
    -> missing activity                              [GAP -> add empty test]
    -> duplicate step tie                            [GAP -> add stability test]
  findSpaceIdBySlug(slug)
    -> found / missing                               [GAP -> add parity test]
  findAllSpaceSlugs()
    -> seed order / no duplicates                    [GAP -> add parity test]
  insertSpace / insertActivity / insertPhrase
    -> insert returns id                             [GAP -> add persistence test]
    -> conflict returns existing id                  [GAP -> add persistence test]
    -> source='llm' preserved                        [GAP -> add persistence test]

PracticeCatalogRepository discovery-ready methods
  findSpaces(locale, limit)                           [GAP -> add repository test]
  findActivitiesBySpace(spaceId, locale, limit)       [GAP -> add repository test]
  findStarterPhrase(activityId, locale)               [GAP -> add repository test]
  findNextPhrase(activityId, currentPhraseId)          [GAP -> add repository test]
  existsSpaceActivityPhrase(space, activity, phrase)   [GAP -> add repository test]

MentorService integration
  generatePractice cache hit                          [GAP -> add regression test]
  persistToCatalog generated write-through            [GAP -> add regression test]
  write-through failure fallback                      [GAP -> add regression test if practical]

COVERAGE TODAY: direct repository coverage 0/12 paths.
COVERAGE TARGET: all legacy methods plus all new repository helpers covered.
```

## 9. Verification Commands

Focused backend tests for future implementation:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeCatalogRepositoryTest
  mvn test -pl app-api -Dtest=MentorServiceTest
  mvn test -pl app-api -Dtest=MentorWebTest
} finally {
  Pop-Location
}
```

Recommended additional regression because practice generate has its own web test:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeGenerateControllerTest
} finally {
  Pop-Location
}
```

Scope guard:

```powershell
git diff --name-only -- mobile mobile_v2 admin-web
```

Doc-only verification for this planning slice:

```powershell
git status --short
git diff -- docs/superpowers/plans/2026-07-03-t8-2-b2-0-practice-catalog-repository-mybatis-rewrite-plan.md
git diff --name-only -- backend mobile mobile_v2 admin-web
```

Expected B2.0 planning result:

```text
Only docs/superpowers/plans/2026-07-03-t8-2-b2-0-practice-catalog-repository-mybatis-rewrite-plan.md changes.
No backend Java/XML/test implementation is written in the planning slice.
No commit is created.
```

## 10. B2 Handoff

B2.0 completion gates before B2 starts:

- `PracticeCatalogRepository` is MyBatis-backed.
- Legacy public method parity is covered by tests.
- Discovery-ready repository helpers exist and are tested.
- MentorService and practice generate regressions pass.
- No schema or seed data changes were made.

Only after B2.0 completes should B2 discovery API design/implementation start:

```text
POST /api/v1/onboarding/discovery
```

B2 discovery API can then reuse:

```text
PracticeCatalogRepository MyBatis-backed query layer
OnboardingProfile profile data
ageRange
parentGoal
locale
installationId
catalog starter phrase
catalog fallback
```

B2.0 itself does not implement a controller, service ranking, request/response DTOs, or discovery endpoint.

## 11. Risk Management

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Rewriting existing repository affects `MentorService`. | Practice generate cache hit and generated write-through depend on this repository. | Keep repository class and legacy public methods; run `MentorServiceTest`, `MentorWebTest`, and `PracticeGenerateControllerTest`. |
| MyBatis mapping fields mismatch and silently return null. | Constructor result maps can silently map wrong columns if aliases drift. | Explicit result maps; test every mapped field for seed and generated rows. |
| Ordering changes starter utterance. | Discovery and cache responses rely on stable first/next phrases. | Characterization tests for seed order; add deterministic tie-breaks and document them. |
| Current `findActivityBySceneTag` nondeterminism hides duplicate bugs. | `LIMIT 1` without order can return different rows once generated content accumulates. | Stabilize with `ORDER BY a.id ASC`; add duplicate-scene tie-break test. |
| Generated content persistence breaks. | `MentorService.persistToCatalog()` expects insert methods to return ids and swallow write-through failure upstream. | Preserve `ON CONFLICT DO NOTHING RETURNING id` plus fallback lookup; test duplicate generated slugs. |
| Tests only cover happy path. | Query parity regressions can pass if only seed reads are tested. | Add empty, duplicate, conflict, missing-id, and ordering tests. |
| Empty catalog tests delete shared seed data. | Current shared test container does not reset practice catalog tables. | Use transactional rollback or explicit after-test reseeding for destructive catalog tests. |
| New query helpers become accidental discovery API. | B2.0 is a repository rewrite slice, not product behavior. | No controller/service endpoint; no ranking service; no API DTOs. |

Hard constraints:

- First write/extend characterization tests.
- Every old public method gets a parity test.
- MentorService / MentorWeb / PracticeGenerate regressions must run.
- Do not change schema.
- Do not change seed data.
- Do not change endpoints.
- Do not change business semantics.

## 12. Explicitly Not In Scope

- No discovery endpoint.
- No care-turns endpoint.
- No mentor/chat security hardening.
- No generated content registry.
- No mobile code.
- No Flutter UI.
- No Garden/Growth changes.
- No reaction enum changes.
- No `mobile_v2`.
- No DB migration by default. Current code does not require a migration for this rewrite.
- No admin-web changes.
- No API DTO changes.
- No controller changes.
- No service ranking implementation.
- No commit.

## 13. What Already Exists

- `PracticeCatalogRepository` already owns catalog read/write-through methods used by `MentorService`.
- `practice_spaces`, `practice_activities`, and `practice_phrases` already exist.
- Seed catalog rows already exist and are enough for catalog fallback.
- MyBatis mapper/XML style already exists in app-api, especially `OnboardingProfileMapper` and `MentorMapper`.
- `AppApiApplication` already scans `@Mapper` interfaces.
- MyBatis XML mapper locations are already configured.
- `PracticeGenerateControllerTest`, `MentorServiceTest`, and `MentorWebTest` already provide API/service regression anchors.
- `AbstractIntegrationTest` already provides a shared Postgres test container, but it does not reset practice catalog tables.

## 14. Implementation Tasks

Synthesized from this plan. Do not start until the plan is reviewed.

- [ ] **B2.0.1 (P1, human: ~45min / CC: ~15min)** - Tests - Add `PracticeCatalogRepositoryTest` characterization coverage for all existing public methods.
  - Surfaced by: Current repository audit.
  - Files: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/PracticeCatalogRepositoryTest.java`.
  - Verify: `mvn test -pl app-api -Dtest=PracticeCatalogRepositoryTest`.
- [ ] **B2.0.2 (P1, human: ~1h / CC: ~20min)** - MyBatis mapper - Add `PracticeCatalogMapper.java` and `PracticeCatalogMapper.xml` with explicit result maps and SQL parity.
  - Surfaced by: Rewrite strategy and XML requirements.
  - Files: mapper Java/XML files.
  - Verify: repository tests still pass.
- [ ] **B2.0.3 (P1, human: ~45min / CC: ~15min)** - Repository rewrite - Replace internal `JdbcTemplate` calls with mapper delegation while keeping public method contracts.
  - Surfaced by: Option B strategy.
  - Files: `PracticeCatalogRepository.java`.
  - Verify: repository parity tests.
- [ ] **B2.0.4 (P1, human: ~45min / CC: ~15min)** - Discovery-ready queries - Add repository-only space/activity/starter/next/validation helpers.
  - Surfaced by: B2 handoff requirement.
  - Files: repository/mapper/XML/test files.
  - Verify: discovery-ready repository tests.
- [ ] **B2.0.5 (P1, human: ~45min / CC: ~15min)** - Regressions - Add or extend Mentor/practice tests for cache hit and generated write-through parity.
  - Surfaced by: Risk management.
  - Files: `MentorServiceTest`, `PracticeGenerateControllerTest`, possibly `MentorWebTest`.
  - Verify: focused commands in section 9.

Sequential implementation, no parallelization opportunity. The mapper, repository, XML, and tests all touch the same app-api service/repository boundary and should land as one small backend refactor slice.

## 15. Failure Modes

| Codepath | Production failure mode | Planned handling | Test |
| --- | --- | --- | --- |
| Cache hit by scene tag | Duplicate generated rows make `LIMIT 1` return a different activity. | Stable `ORDER BY a.id ASC`; duplicate tie-break characterization. | Repository duplicate-scene test. |
| Phrase list | Duplicate steps reorder starter/next phrase. | Stable `ORDER BY step ASC, id ASC`. | Duplicate-step test. |
| Generated insert | `ON CONFLICT DO NOTHING RETURNING id` returns no id on conflict. | Repository fallback lookup by slug. | Duplicate insert tests. |
| MyBatis result map | Wrong alias maps record field to null. | Explicit result maps and full-field assertions. | Seed and generated row tests. |
| Empty catalog | Destructive test removes shared seed rows for later tests. | Use rollback or restore fixtures. | Empty-catalog test plus later seed parity test. |
| Discovery-ready validation | Mismatched space/activity/phrase ids validate true accidentally. | Join all three tables by slug and parent relationship. | Negative validation tests. |
| Mentor regression | Provider is called despite cache hit, or write-through no longer returns ids. | Regression tests at service/web level. | `MentorServiceTest` / `PracticeGenerateControllerTest`. |

No critical silent failure should remain without a repository or Mentor regression test.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | not run | User already selected Option B; product/API scope is explicitly deferred. |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run | No implementation diff exists. |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | clear | Option B accepted; current repository has 7 public methods, 2 row records, MentorService caller risk, no dedicated repository tests, and nondeterministic duplicate ordering to stabilize. |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not needed | Backend repository rewrite only; no UI changes. |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | Focused verification commands and scope guard are included. |

1. Plan path: `docs/superpowers/plans/2026-07-03-t8-2-b2-0-practice-catalog-repository-mybatis-rewrite-plan.md`
2. Confirmed strategy: Option B, migrate existing `PracticeCatalogRepository` to MyBatis/XML.
3. Current repository audit summary: 7 public methods, 2 nested records, direct `MentorService` caller, no dedicated repository test, seed catalog from V22/V22.1, generated write-through currently preserved by insert methods.
4. Proposed files: `PracticeCatalogMapper.java`, `PracticeCatalogMapper.xml`, rewritten `PracticeCatalogRepository.java`, new `PracticeCatalogRepositoryTest.java`.
5. Methods to preserve: `findActivityBySceneTag`, `findPhrasesByActivityId`, `findSpaceIdBySlug`, `findAllSpaceSlugs`, `insertSpace`, `insertActivity`, `insertPhrase`.
6. New discovery-ready repository methods: `findSpaces`, `findActivitiesBySpace`, `findStarterPhrase`, `findNextPhrase`, `existsSpaceActivityPhrase` or equivalent names.
7. Test plan: characterization first, then MyBatis parity, discovery-ready helper tests, generated persistence parity, MentorService/MentorWeb/PracticeGenerate regressions, no API behavior changes.
8. Risks: MentorService regression, MyBatis null mapping, ordering drift, generated persistence breakage, happy-path-only tests, destructive catalog test isolation.
9. Git status at plan authoring: branch was clean before this doc; expected result after writing is this plan file only.
10. Confirmed no code implementation: this document adds no Java, XML mapper, test, schema, mobile, admin-web, or API implementation.
11. Waiting for user review before any B2.0 implementation starts.

- **VERDICT:** ENG PLAN WRITTEN - ready for user review before implementation.

NO UNRESOLVED DECISIONS
