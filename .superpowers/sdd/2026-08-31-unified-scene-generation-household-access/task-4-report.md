# Task 4 — unified scene generation engine

Status: `DONE_WITH_CONCERNS` (implementation and Task 4 verification complete; repository-wide verification still reports pre-existing/parallel WIP failures listed below).

## Implementation, interface, and seams

`PracticeGeneratedContentService.generateScene(SceneGenerationInput)` is the single source-neutral public generation interface. `custom` and `preset` inputs now use one reserve → cache/fingerprint → rate-limit → orchestration → repair/validator/judge → persistence path. The service owns profile-scoped owner identity (`profile` scope, subject owner account/profile/version), while `PreparedScene` carries transient resolved execution text and persistence-safe text. `SceneGenerationOrchestrator.GenerationExecution` carries the transient resolved text and one exact `GenerationRequestContext` through initial generation, repair, and judge.

The request has 11 fields; `installationId` is between `locale` and `clientRequestId`. It is only converted through the existing HMAC installation-reference seam; raw installation IDs are not persisted or logged. `GenerationRequestContext` has exactly: `babyName`, `ageRange`, `parentGoal`, `locale`, `actorRole`, `recentPracticeCount`, `dominantReaction`, and `recentActivitySummary`. Request/execution/context string representations are redacted.

The new fingerprint material contains exactly source, custom canonical-text hash or preset-version identity, profile/version, weekly context version, generation profile/prompt/strategy/rubric/evidence versions, and refresh epoch. It excludes actor role, baby name, raw resolved text, installation ID, actor account, and locale. Thus primary/caregiver requests for the same profile/preset/week share a bundle; the first actual request's actor role is still sent to the provider prompt.

Preset persistence stores only a version marker and stable input `spaceSlug`/`activitySlug`; resolved preset text is transient and never enters the generated row, audit, logs, or exceptions. Custom persistence retains only normalized custom input text. Final active preset routes are forced from stable input IDs, never model-proposed routes.

## Mechanical renames (`git mv`)

Production:

- `DisabledCustomSceneGenerationService.java` → `DisabledSceneContentGenerator.java`
- `FakeCustomSceneGenerationService.java` → `FakeSceneContentGenerator.java`
- `CustomSceneGeneratedContentValidator.java` → `SceneGeneratedContentValidator.java`
- `AgenticCustomSceneGenerator.java` → `AgenticSceneContentGenerator.java`
- `CustomSceneGenerator.java` → `SceneContentGenerator.java`
- `CustomSceneGenerationOrchestrator.java` → `SceneGenerationOrchestrator.java`

Tests:

- `CustomSceneGenerationProviderWiringTest.java` → `SceneContentGeneratorProviderWiringTest.java`
- `CustomSceneGeneratedContentValidatorTest.java` → `SceneGeneratedContentValidatorTest.java`
- `AgenticCustomSceneGeneratorTest.java` → `AgenticSceneContentGeneratorTest.java`
- `CustomSceneAgenticGenerationIntegrationTest.java` → `SceneAgenticGenerationIntegrationTest.java`
- `CustomSceneGenerationOrchestratorTest.java` → `SceneGenerationOrchestratorTest.java`

Operator-facing Spring AI capability IDs, YAML keys, metric/audit capability strings, and the internal `CustomScene*` repair/judge/evidence seams were preserved. Old shared Java type names are absent from source/tests/tool references after the rename audit.

## TDD RED/GREEN evidence

Initial RED (before adding the 11th input field):

```text
bash ./mvnw -pl app-api '-Dtest=PracticeGeneratedContentServiceTest,PracticeGeneratedContentServiceOrchestrationTest,PracticeGeneratedContentKeyFactoryTest,CustomSceneGenerationOrchestratorTest,SceneGenerationInputTest' test
SceneGenerationInputTest.java:[13,21] constructor SceneGenerationInput ... needs 10 args, found 11
```

After mechanical renames, the focused compatibility suite was GREEN: `108` tests. The unified provider/context/key suite was GREEN: `151` tests. Provider wiring, validator, mapper, and concurrency suite was GREEN: `108` tests. The new real PostgreSQL/Testcontainers test `concurrentPrimaryAndCaregiverPresetRequestsShareOneProfileOwnedRow` was GREEN: `1` test; it proves one provider call, one profile-owned live row, shared fingerprint/reuse, and no duplicate reservation. The complete generated-bundle verifier ran `311` tests and passed.

Commands used (from `backend`):

```text
bash ./mvnw -pl app-api '-Dtest=PracticeGeneratedContentServiceTest,PracticeGeneratedContentServiceOrchestrationTest,PracticeGeneratedContentKeyFactoryTest,SceneGenerationOrchestratorTest,SceneGenerationInputTest' test
bash ./mvnw -pl app-api '-Dtest=PracticeGeneratedContentUnifiedEngineTest,PracticeGeneratedContentKeyFactoryTest,AgenticSceneContentGeneratorTest,AgenticCustomSceneRepairerTest,AgenticCustomSceneQualityJudgeTest,PracticeGeneratedContentServiceTest,PracticeGeneratedContentServiceOrchestrationTest,SceneGenerationOrchestratorTest,SceneGenerationInputTest' test
bash ./mvnw -pl app-api '-Dtest=SceneContentGeneratorProviderWiringTest,SceneGeneratedContentValidatorTest,PracticeGeneratedContentMapperTest,PracticeGeneratedContentConcurrencyTest' test
bash ./mvnw -pl app-api '-Dtest=PracticeGeneratedContentConcurrencyTest#concurrentPrimaryAndCaregiverPresetRequestsShareOneProfileOwnedRow' test
```

Required platform gate:

```text
python3 tool/verify_spring_ai_2_backend_platform.py
Spring AI 2 backend platform contract verified
```

The final focused post-change run (`PracticeGeneratedContentUnifiedEngineTest,PracticeGeneratedContentKeyFactoryTest,SceneGenerationInputTest`) was `15/15` GREEN. A full `cd backend && bash ./mvnw clean test` compiled app-api and ran `1093` tests; only two failures were in the dirty parallel Task 7 `CaregiverInviteApiWebTest` WIP (expected 200/403, received 404). Other modules were not reached because Maven stopped at app-api failure.

## Persistence, cache, concurrency, and privacy evidence

- New rows use mode `scene_generation`, owner scope `profile`, subject owner account, profile ID/version, source, household context version, and preset IDs. Actor account/role is not persisted in generated rows.
- Cache/rate-limit/lock identity is profile-owned and actor-role neutral. Same profile/preset/week reuses; changes to week/profile/template/prompt/strategy/rubric/evidence/refresh invalidate. Concurrent primary/caregiver same-preset requests produce one live reservation.
- Provider request assertions cover all eight context fields in initial, repair, and judge phases and assert custom/preset parity.
- Input/source shape validation rejects null, mixed, or inconsistent preset IDs before reservation. The installation HMAC output is format-checked without retaining raw installation data.
- Privacy-safe `toString()`/error paths omit baby name, resolved preset text, and full request/context values. Custom normalized text is the only permitted user-input persistence exception.

## Staged scope and transition contract

Task 4 staged scope is 42 files (`1941` insertions, `467` deletions), including the source-neutral renames, unified service/orchestrator/generator/validator, context/key tests, real PG concurrency coverage, and verifier path updates. Existing unstaged WIP remains untouched: `PracticeDiscoveryService.java`, `PracticeDiscoveryServiceTest.java`, `PracticeGeneratedContentQueryMapper.xml`, `CaregiverInviteApiWebTest.java`, and mobile files. No forbidden Task 5–7 files are staged.

The minimal `@Deprecated(forRemoval = true)` `generateCustomScene` and `generateCustomSceneForInstallationOwner` adapters remain only to keep this intermediate commit compiling. Both construct/forward into the unified engine and contain no independent cache, persistence, validation, or orchestration. Current legacy callers are `PracticeDiscoveryService` (discovery path) and `PracticeOnboardingConversationGenerator` (onboarding path), plus their existing tests. Task 5 must migrate those callers to `generateScene(SceneGenerationInput)` and delete both adapters; this intermediate commit must not be deployed.

## Self-audit and concerns

`git diff --cached --check` is clean; staged-path audit excludes all declared forbidden WIP. Spring production imports contain no `com.fasterxml.jackson.core.*` or `com.fasterxml.jackson.databind.*`; databind/core usage is `tools.jackson.*`. Bean wiring has one active source-neutral generator/orchestrator implementation; disabled/fake adapters remain test/profile seams.

Concern 1: `verify_practice_generation_privacy.py` still fails its baseline rule that `PresetSceneCatalogMapper.xml` must not persist `coach_tip_zh`; that mapper is outside Task 4 and was not changed. Concern 2: the full backend run is red only on the two parallel dirty `CaregiverInviteApiWebTest` 404 assertions above. Neither concern was fixed or staged to avoid overwriting Task 5–7 WIP.
