# Unified Scene Generation and Household Access Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the custom-only generation contract with one strict preset/custom generation pipeline that resolves family baby context on the server and shares generated bundles through active household permissions.

**Architecture:** A new `SceneGenerationService` resolves a tagged source, a server-owned `GenerationSubject`, and a weekly structured personalization context before calling one generation/persistence engine. Generated content remains profile-owned; every bundle/audio read checks owner-or-active-household access.

**Tech Stack:** PostgreSQL 17, Flyway, Spring Boot 4.0.7, Java 17 bytecode, Spring AI 2.0.0, MyBatis-Plus, Jackson 3, JUnit 5, Mockito, Testcontainers.

**Spec:** `docs/superpowers/specs/2026-08-31-unified-scene-generation-household-profile-design.md`

## Global Constraints

- Complete `2026-08-31-preset-scene-publishing.md` first; this plan consumes `PresetSceneCatalogService.requirePublished(String)` and Flyway V37.
- Run `python3 tool/verify_spring_ai_2_backend_platform.py` and `cd backend && bash mvnw clean test` before Task 1; both must exit 0.
- Use Flyway version `V38`; update `DbMigrationApplication.EXPECTED_CURRENT_VERSION` from `37` to `38`.
- Raise `app.contract.min-supported-version` from `1.2.0` to `1.3.0` when the new endpoint is complete.
- Production Jackson databind/core imports must use `tools.jackson.*`; `com.fasterxml.jackson.annotation.*` remains allowed.
- Client requests must not contain `babyProfileId`, `ageRange`, or `parentGoal`.
- A `caregiver` always uses the active household primary caregiver's profile, even when the caregiver has a historical personal profile.
- Personalization may include baby name, age range, parent goal, locale, actor role, and aggregate recent practice/reaction summaries; never include phone, account ID, installation ID, or raw interaction text in prompts/logs.
- New generated content uses `owner_scope='profile'`, `account_id=profile owner`, `profile_id=resolved profile`.
- Do not keep `/api/v1/household/shared-profile-context`; server generation resolves the profile directly.
- Preserve unrelated worktree changes and exclude `mobile/windows/flutter/generated_*` from commits.

---

## File Structure

### Migration and persistence

- Create `backend/db-migration/src/main/resources/db/migration/V38__unify_scene_generation_ownership.sql`.
- Modify `backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java`.
- Modify `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`.
- Modify `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeGeneratedContentEntity.java`.
- Modify generated-content mapper interfaces/XML and mapper tests.

### Subject and personalization

- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/profile/HouseholdBabyProfileAccessService.java`.
- Modify `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/profile/BabyProfileMapper.java`.
- Modify `backend/app-api/src/main/resources/mapper/profile/BabyProfileMapper.xml`.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/GenerationSubject.java`.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/ScenePersonalizationContext.java`.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/ScenePersonalizationContextMapper.java`.
- Create `backend/app-api/src/main/resources/mapper/practice/ScenePersonalizationContextMapper.xml`.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/ScenePersonalizationContextService.java`.
- Delete `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/HouseholdSharedProfileService.java`.
- Delete `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/HouseholdSharedProfileController.java`.

### Unified generation API and engine

- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/SceneGenerationRequest.java`.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/SceneGenerationResponse.java`.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/SceneGenerationService.java`.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/SceneGenerationController.java`.
- Rename `CustomSceneGenerationOrchestrator.java` to `SceneGenerationOrchestrator.java` and its test accordingly.
- Rename `CustomSceneGenerator.java` to `SceneContentGenerator.java`; rename agentic/fake generator implementations and tests consistently.
- Rename `CustomSceneGeneratedContentValidator.java` to `SceneGeneratedContentValidator.java` and its test.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/SceneGenerationInput.java`.
- Modify `PracticeGeneratedContentService.java`, key factory, entity mappers, command mappers, and orchestration tests.
- Modify `PracticeDiscoveryService.java`, `PracticeDiscoveryMode.java`, controller tests, and service tests to retain catalog preview only.

### Household-protected reads

- Modify `PracticeGeneratedContentQueryMapper.java` and XML.
- Modify `GeneratedUtteranceAudioService.java`.
- Modify mapper/audio integration tests.

---

### Task 1: Extend generated-content schema for unified sources

**Files:**
- Create: `backend/db-migration/src/main/resources/db/migration/V38__unify_scene_generation_ownership.sql`
- Modify: `backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java`
- Modify: `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeGeneratedContentEntity.java`
- Modify: `backend/app-api/src/main/resources/mapper/practice/generated/PracticeGeneratedContentQueryMapper.xml`
- Modify: `backend/app-api/src/main/resources/mapper/practice/generated/PracticeGeneratedContentCommandMapper.xml`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapperTest.java`

**Interfaces:**
- Consumes: V37 preset version IDs.
- Produces: persistence fields used by unified generation.

- [ ] **Step 1: Write failing migration and mapper tests**

Assert the new columns and source-shape constraints:

```java
assertThat(columnExists(jdbc, "practice_generated_content", "input_source")).isTrue();
assertThat(columnExists(jdbc, "practice_generated_content", "preset_scene_version_id")).isTrue();
assertThat(columnExists(jdbc, "practice_generated_content", "household_context_version")).isTrue();
```

Insert a `scene_generation/preset` row with missing preset IDs and expect check violation. Insert a `scene_generation/custom` row with preset IDs and expect check violation. Insert two active preset rows with the same stable activity slug but different weekly context versions and expect success.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd backend
bash mvnw -pl db-migration,app-api -am -Dtest=DbMigrationSmokeTest,PracticeGeneratedContentMapperTest test
```

Expected: missing V38 columns/constraints.

- [ ] **Step 3: Implement V38**

Add:

```sql
alter table practice_generated_content
    add column input_source varchar(16) null,
    add column preset_activity_id bigint null,
    add column preset_scene_version_id bigint null,
    add column profile_version integer null,
    add column household_context_version varchar(16) null;

alter table practice_generated_content
    add constraint fk_practice_generated_content_preset_activity
        foreign key (preset_activity_id) references practice_activities(id),
    add constraint fk_practice_generated_content_preset_version
        foreign key (preset_scene_version_id) references practice_preset_scene_versions(version_id),
    add constraint chk_practice_generated_content_input_source
        check (input_source is null or input_source in ('custom', 'preset')),
    add constraint chk_practice_generated_content_scene_generation_shape
        check (
            mode <> 'scene_generation'
            or (
                owner_scope='profile'
                and input_source is not null
                and profile_version >= 0
                and household_context_version is not null
                and ((input_source='custom' and preset_activity_id is null and preset_scene_version_id is null)
                  or (input_source='preset' and preset_activity_id is not null and preset_scene_version_id is not null))
            )
        );
```

Allow `mode in ('custom_scene','scene_generation')` so existing stored rows remain readable, but all new API writes use `scene_generation`. Backfill existing rows to `input_source='custom'` where safe. Recreate active space/activity unique indexes so they apply only to non-preset content; preset rows must share stable `space_slug/activity_slug` across weeks.

- [ ] **Step 4: Map new entity fields**

Add Java fields/getters/setters for `inputSource`, `presetActivityId`, `presetSceneVersionId`, `profileVersion`, and `householdContextVersion`; add them to query and command result maps/inserts.

- [ ] **Step 5: Raise Flyway expected version and run GREEN**

Set expected version to `38`, rerun Step 2, and expect exit 0.

- [ ] **Step 6: Commit Task 1**

```bash
git add backend/db-migration backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model backend/app-api/src/main/resources/mapper/practice/generated backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapperTest.java
git commit -m "feat(db): persist unified scene sources"
```

---

### Task 2: Resolve the server-owned household baby profile

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/GenerationSubject.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/profile/HouseholdBabyProfileAccessService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/profile/BabyProfileMapper.java`
- Modify: `backend/app-api/src/main/resources/mapper/profile/BabyProfileMapper.xml`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/CaregiverInviteRepository.java`
- Delete: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/HouseholdSharedProfileService.java`
- Delete: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/HouseholdSharedProfileController.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/profile/HouseholdBabyProfileAccessServiceTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/profile/BabyProfileMapperTest.java`

**Interfaces:**
- Produces: `GenerationSubject resolve(String sessionId)`.

- [ ] **Step 1: Write failing role-precedence tests**

Cover caregiver with no own profile, caregiver with a historical own profile, primary member, standalone profile owner, unknown active role, missing shared profile, inactive membership, and invalid session.

Use this decisive assertion:

```java
var subject = service.resolve("sess_caregiver_with_own_profile");
assertThat(subject.actorAccountId()).isEqualTo("acct_caregiver");
assertThat(subject.ownerAccountId()).isEqualTo("acct_primary");
assertThat(subject.profileId()).isEqualTo("babyprof_primary");
assertThat(subject.actorRole()).isEqualTo("caregiver");
```

- [ ] **Step 2: Run tests and verify RED**

```bash
cd backend
bash mvnw -pl app-api -Dtest=HouseholdBabyProfileAccessServiceTest,BabyProfileMapperTest test
```

Expected: missing service/type.

- [ ] **Step 3: Define the subject contract**

```java
public record GenerationSubject(
        String actorAccountId,
        String ownerAccountId,
        String profileId,
        int profileVersion,
        String babyName,
        String ageRange,
        String parentGoal,
        String householdId,
        String actorRole
) {}
```

Normalize values, validate age/goal against `BabyProfileOptions`, and never include this record in logs or error details.

- [ ] **Step 4: Implement active-household SQL and service precedence**

Keep `findSharedByHouseholdMemberAccountId(accountId)` as one joined query over active household, active caregiver member, active primary member, owner account, and baby profile. `caregiver` resolution runs this query before any own-profile query. No membership falls back to `findByAccountId(actorAccountId)`.

Map missing caregiver profile to `404 shared_profile_unavailable`; missing personal profile to `404 profile_unavailable`; unknown active role to `403 household_access_required`.

- [ ] **Step 5: Remove the rejected two-request endpoint**

Delete the two untracked shared-profile endpoint files. No app endpoint may return age range, parent goal, profile ID, or baby name solely to prepare generation.

- [ ] **Step 6: Run tests and verify GREEN**

Run Step 2. Expected: exit 0.

- [ ] **Step 7: Commit Task 2**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/profile backend/app-api/src/main/resources/mapper/profile backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/CaregiverInviteRepository.java backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene backend/app-api/src/test/java/com/zhangspaghetti/babytalk/profile
git commit -m "feat(profile): resolve household generation subject"
```

---

### Task 3: Build privacy-bounded weekly personalization context

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/SceneGenerationInput.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/ScenePersonalizationContext.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/ScenePersonalizationContextMapper.java`
- Create: `backend/app-api/src/main/resources/mapper/practice/ScenePersonalizationContextMapper.xml`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/ScenePersonalizationContextService.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/scene/ScenePersonalizationContextServiceTest.java`

**Interfaces:**
- Consumes: `GenerationSubject`.
- Produces: `ScenePersonalizationContext build(GenerationSubject, String locale, OffsetDateTime now)`.

- [ ] **Step 1: Write failing aggregation/privacy tests**

Assert household context aggregates all active household actors, standalone context only aggregates owner events, raw interaction text is absent, empty history yields zero counts, and ISO week rollover changes the version.

```java
assertThat(context.householdContextVersion()).isEqualTo("2026-W36");
assertThat(context.recentPracticeCount()).isEqualTo(7);
assertThat(context.dominantReaction()).isEqualTo("hesitant");
assertThat(context.toString()).doesNotContain("acct_", "13800138000");
```

- [ ] **Step 2: Run tests and verify RED**

```bash
cd backend
bash mvnw -pl app-api -Dtest=ScenePersonalizationContextServiceTest test
```

- [ ] **Step 3: Define the context**

```java
public record ScenePersonalizationContext(
        String babyName,
        String ageRange,
        String parentGoal,
        String locale,
        String actorRole,
        int recentPracticeCount,
        String dominantReaction,
        String recentActivitySummary,
        String householdContextVersion
) {}
```

`recentActivitySummary` must be built from bounded IDs/counts, not raw event text. Override `toString()` with a redacted summary that excludes baby name.

- [ ] **Step 4: Implement weekly aggregate query and service**

Query only `interaction_events` fields required for counts, stable activity IDs, reaction/result, and timestamps. Derive ISO week with `IsoFields.WEEK_BASED_YEAR` and `IsoFields.WEEK_OF_WEEK_BASED_YEAR` in UTC. If aggregation fails, return zero-count context with the core profile intact; do not fail generation.

- [ ] **Step 5: Run tests and verify GREEN**

Run Step 2. Expected: exit 0.

- [ ] **Step 6: Commit Task 3**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene backend/app-api/src/main/resources/mapper/practice/ScenePersonalizationContextMapper.xml backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/scene
git commit -m "feat(practice): build weekly family context"
```

---

### Task 4: Generalize one generation and persistence engine

**Files:**
- Rename: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneGenerationOrchestrator.java` to `SceneGenerationOrchestrator.java`
- Rename: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneGenerator.java` to `SceneContentGenerator.java`
- Rename: agentic/fake generator implementation files and matching tests consistently.
- Rename: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidator.java` to `SceneGeneratedContentValidator.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactory.java`
- Modify: orchestration, service, concurrency, key-factory, and validator tests.

**Interfaces:**
- Consumes: resolved source text, `GenerationSubject`, `ScenePersonalizationContext`, optional published preset definition.
- Produces: `PracticeGeneratedContentEntity generateScene(SceneGenerationInput)`.

- [ ] **Step 1: Add failing unified-input and cache-key tests**

Define expected input:

```java
public record SceneGenerationInput(
        String inputSource,
        String resolvedSceneText,
        GenerationSubject subject,
        ScenePersonalizationContext personalization,
        Long presetActivityId,
        Long presetSceneVersionId,
        String stableSpaceId,
        String stableActivityId,
        String locale,
        String clientRequestId
) {}
```

Tests must prove custom and preset call the same orchestrator, same family/same preset/same week reuses a row, new week/profile/template/strategy creates a new row, preset route IDs override model-proposed route IDs, custom and preset consume the same profile-owned rate-limit component, and concurrent primary/caregiver requests reserve only one preset generation row.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd backend
bash mvnw -pl app-api -Dtest=PracticeGeneratedContentServiceTest,PracticeGeneratedContentServiceOrchestrationTest,PracticeGeneratedContentKeyFactoryTest,CustomSceneGenerationOrchestratorTest test
```

Expected: missing unified input/orchestrator.

- [ ] **Step 3: Rename source-neutral seams**

Use `git mv` for orchestrator, generator interface/implementations, validator, and tests. Update Spring wiring and test imports in one mechanical commit scope; no behavior change yet.

- [ ] **Step 4: Implement `generateScene`**

Replace custom-only owner resolution with the already resolved subject. Set:

```java
row.setMode("scene_generation");
row.setInputSource(input.inputSource());
row.setAccountId(input.subject().ownerAccountId());
row.setProfileId(input.subject().profileId());
row.setProfileVersion(input.subject().profileVersion());
row.setHouseholdContextVersion(input.personalization().householdContextVersion());
row.setPresetActivityId(input.presetActivityId());
row.setPresetSceneVersionId(input.presetSceneVersionId());
```

For preset input, persist stable `spaceSlug/activitySlug` from the published definition after validating the generated bundle. For custom input, retain generated unique route IDs.

- [ ] **Step 5: Pass personalization through generation, repair, and quality prompts**

Extend the source-neutral generator request with the complete structured context:

```java
public record GenerationRequestContext(
        String babyName,
        String ageRange,
        String parentGoal,
        String locale,
        String actorRole,
        int recentPracticeCount,
        String dominantReaction,
        String recentActivitySummary
) {}
```

Use it in initial generation, repair, and quality evaluation so both sources receive identical personalization. Provider-request tests must see the baby name and aggregate context; audit/log summary tests must remain redacted and contain neither baby name nor resolved scene text.

- [ ] **Step 6: Extend fingerprint material**

Include input source, custom canonical text hash or preset version ID, profile version, weekly context version, generation profile, rubric, evidence policy, and refresh epoch. Do not include baby name in logs or error messages.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run the Step 2 command with `SceneGenerationOrchestratorTest` replacing `CustomSceneGenerationOrchestratorTest`. Expected: exit 0.

- [ ] **Step 8: Commit Task 4**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice
git commit -m "refactor(practice): unify scene generation engine"
```

---

### Task 5: Add the strict unified generation API

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/SceneGenerationRequest.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/SceneGenerationResponse.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene/SceneGenerationService.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/SceneGenerationController.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/scene/SceneGenerationServiceTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/SceneGenerationControllerTest.java`
- Modify: `PracticeDiscoveryService.java`, `PracticeDiscoveryMode.java`, and their tests.

**Interfaces:**
- Consumes: `HouseholdBabyProfileAccessService`, `ScenePersonalizationContextService`, `PresetSceneCatalogService`, `PracticeGeneratedContentService.generateScene`.
- Produces: `POST /api/v1/practice/scene-generations`.

- [ ] **Step 1: Write failing strict-contract tests**

Test valid custom and preset bodies plus these invalid bodies:

```json
{"source":{"type":"preset","presetSceneId":"bath_time","text":"override"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
```

```json
{"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1","babyProfileId":"forbidden"}
```

Both must return `400 invalid_scene_source` or strict unknown-field validation; none may reach the generation engine.

- [ ] **Step 2: Run controller/service tests and verify RED**

```bash
cd backend
bash mvnw -pl app-api -Dtest=SceneGenerationControllerTest,SceneGenerationServiceTest test
```

- [ ] **Step 3: Implement strict request types**

Use one nested source record and manual exact-field validation:

```java
public record SceneGenerationRequest(
        SourceRequest source,
        String locale,
        String installationId,
        String clientRequestId
) {
    public record SourceRequest(String type, String text, String presetSceneId) {}
}
```

Apply `@JsonIgnoreProperties(ignoreUnknown = false)` and `@JsonAnySetter` rejection at both levels. `custom` requires only `text`; `preset` requires only `presetSceneId`.

- [ ] **Step 4: Implement service source resolution**

Order operations: accepted session, subject, source, personalization, generation. Preset source calls `requirePublished`; custom source uses `SceneTextCanonicalizer` and security policy. Map missing/unpublished/disabled preset to `404 preset_scene_unavailable` without exposing internal state.

- [ ] **Step 5: Implement response mapping**

Return complete six-utterance bundle plus:

```java
public record SourceView(String type, String presetSceneId, Integer presetSceneVersion) {}
```

Never return resolved input text or profile fields.

- [ ] **Step 6: Remove custom generation from discovery**

Keep `PracticeDiscoveryService` only for curated onboarding/catalog preview. `custom_scene` on `/api/v1/practice/discovery` must no longer be a supported surface/mode pair.

- [ ] **Step 7: Run tests and verify GREEN**

Run Step 2 plus:

```bash
bash mvnw -pl app-api -Dtest=PracticeDiscoveryServiceTest,PracticeDiscoveryControllerTest test
```

- [ ] **Step 8: Commit Task 5**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/scene backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/SceneGenerationController.java backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/scene backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/SceneGenerationControllerTest.java backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery
git commit -m "feat(api): add unified scene generation"
```

---

### Task 6: Enforce household access on every generated-content read

**Files:**
- Modify: `PracticeGeneratedContentQueryMapper.java`
- Modify: `backend/app-api/src/main/resources/mapper/practice/generated/PracticeGeneratedContentQueryMapper.xml`
- Modify: `GeneratedUtteranceAudioService.java`
- Modify: `PracticeGeneratedContentMapperTest.java`
- Modify: `GeneratedUtteranceAudioServiceTest.java`
- Modify: `GeneratedUtteranceAudioHttpIntegrationTest.java`

**Interfaces:**
- Produces: owner-or-active-household authorization for bundle and audio reads.

- [ ] **Step 1: Write failing access/revocation tests**

Seed one profile-owned generated bundle. Assert owner, active caregiver A, and active caregiver B can read; outsider cannot; caregiver A cannot read after membership status changes to inactive; nobody can read through an inactive household.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd backend
bash mvnw -pl app-api -Dtest=PracticeGeneratedContentMapperTest,GeneratedUtteranceAudioServiceTest,GeneratedUtteranceAudioHttpIntegrationTest test
```

Expected: caregivers cannot read owner content or revoked users remain incorrectly allowed.

- [ ] **Step 3: Rename ownership queries to access queries**

Use exact method names:

```java
PracticeGeneratedContentEntity findActiveAccessibleByAccountId(String generatedContentId, String accountId);
PracticeGeneratedContentUtteranceEntity findPlayableAccessibleActiveBundleUtterance(
        String generatedContentId, String utteranceId, String accountId);
```

- [ ] **Step 4: Centralize the SQL predicate**

Add one mapper fragment and reuse it in every consumer-facing generated-content lookup. Keep internal generation/audit queries unchanged:

```xml
<sql id="accountCanAccessProfileContent">
  and (
    c.account_id = #{accountId}
    or (
      c.owner_scope = 'profile'
      and exists (
        select 1
        from households h
        join household_members requester
          on requester.household_id = h.household_id
         and requester.account_id = #{accountId}
         and requester.status = 'active'
        join household_members owner_member
          on owner_member.household_id = h.household_id
         and owner_member.account_id = c.account_id
         and owner_member.role = 'primary_caregiver'
         and owner_member.status = 'active'
        where h.owner_account_id = c.account_id
          and h.status = 'active'
      )
    )
  )
</sql>
```

- [ ] **Step 5: Run tests and verify GREEN**

Run Step 2. Expected: exit 0, including post-revocation denial.

- [ ] **Step 6: Commit Task 6**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated backend/app-api/src/main/resources/mapper/practice/generated backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GeneratedUtteranceAudioHttpIntegrationTest.java
git commit -m "fix(practice): authorize household bundle reads"
```

---

### Task 7: Close integration, privacy, and version gates

**Files:**
- Modify: `backend/app-api/src/main/resources/application.yml`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/ApiVersionHandshakeWebTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/CaregiverInviteApiWebTest.java`
- Modify: relevant generation integration and privacy tests.

**Interfaces:**
- Produces: deployable app-api contract for the new mobile client.

- [ ] **Step 1: Add end-to-end family generation tests**

Create primary profile, household, caregiver, and published preset. Generate preset as caregiver, then custom as caregiver. Assert both rows use the primary account/profile, preset route IDs remain stable, primary can reuse/read, outsider cannot, and synced practice events record caregiver actor.

- [ ] **Step 2: Add privacy assertions**

Capture response and logs. Assert no response/error contains owner account ID, profile ID, phone, generation brief, or raw personalization record. Generated content may contain baby name because the approved product design permits it.

- [ ] **Step 3: Raise minimum client version**

Change default:

```yaml
app:
  contract:
    min-supported-version: ${BABY_TALK_MIN_SUPPORTED_VERSION:1.3.0}
```

Update handshake tests: `1.2.0` returns `426 app_version_required`; `1.3.0` succeeds.

- [ ] **Step 4: Run all backend tests**

```bash
cd backend
bash mvnw clean test
```

Expected: exit 0.

- [ ] **Step 5: Re-run platform verification**

```bash
cd ..
python3 tool/verify_spring_ai_2_backend_platform.py
```

Expected: exit 0 and no forbidden Jackson 2 databind/core imports.

- [ ] **Step 6: Commit integration fixes**

```bash
git add backend/app-api/src/main/resources/application.yml backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/ApiVersionHandshakeWebTest.java backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/CaregiverInviteApiWebTest.java backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/SceneGenerationControllerTest.java backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneAgenticGenerationIntegrationTest.java
git commit -m "test(practice): close family scene generation"
```

Skip the commit when Steps 4-5 required no changes.
