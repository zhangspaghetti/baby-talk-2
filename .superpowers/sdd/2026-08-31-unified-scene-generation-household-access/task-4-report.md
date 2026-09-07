# Task 4 — unified scene generation engine

Status: `DONE_WITH_CONCERNS` (this review round is implemented and verified; PostgreSQL/Testcontainers rerun is blocked by the unavailable local Docker daemon, and parallel WIP failures remain external).

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

After mechanical renames, the focused compatibility suite was GREEN: `108` tests. The unified provider/context/key suite was GREEN: `151` tests. Provider wiring, validator, mapper, and concurrency suite was GREEN: `108` tests. The new real PostgreSQL/Testcontainers test `concurrentPrimaryAndCaregiverPresetRequestsShareOneProfileOwnedRow` was GREEN: `1` test in the prior Task 4 run; the review-round rerun was attempted but Docker was unavailable. The complete generated-bundle verifier previously ran `311` tests and passed; its review-round rerun reached `311` tests but had `15` Docker initialization errors.

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

## Self-audit and privacy-verifier scope closure

`git diff --cached --check` is clean; staged-path audit excludes all declared forbidden WIP. Spring production imports contain no `com.fasterxml.jackson.core.*` or `com.fasterxml.jackson.databind.*`; databind/core usage is `tools.jackson.*`. Bean wiring has one active source-neutral generator/orchestrator implementation; disabled/fake adapters remain test/profile seams.

The verifier concern is closed in follow-up commit `test(practice): scope generation privacy verifier`: the `coach_tip_zh` rule now scans every app-api mapper XML and migration SQL whose content operates on `practice_generated_content` (including non-standard paths), rather than relying on one directory. Preset catalog/version mappers remain allowed; immutable V25 history and the approved V27 backfill/drop transition are explicit exceptions, while future generated persistence remains fail-closed. No blanket substring allowlist was added.

Verifier TDD evidence:

```text
RED: python3 test/tool/verify_practice_generation_privacy_test.py
Ran 9 tests ... FAILED (failures=2: current repository and preset catalog fixture)
GREEN: python3 test/tool/verify_practice_generation_privacy_test.py
Ran 9 tests ... OK
GREEN: python3 tool/verify_practice_generation_privacy.py
practice generation privacy verification passed
```

Follow-up staged scope is exactly `tool/verify_practice_generation_privacy.py`, `test/tool/verify_practice_generation_privacy_test.py`, and this report; no discovery/query/Caregiver/mobile WIP was staged. Remaining external concern: the full backend run has the two parallel dirty `CaregiverInviteApiWebTest` 404 assertions documented above; no Task 4 verifier concern remains.

## Review round 1 — three findings

### A. Palace logging privacy

Root cause: `PalaceSearchService`, `PalaceKeywordRepository`, and `PalaceHybridRetrievalService` interpolated raw vector queries/keywords into success and fallback logs; the keyword metadata warning logged exception messages, and Hybrid fallback copied an exception message into its temporal trace. The real Logback capture test was intentionally added before the fix:

```text
bash ./mvnw -pl app-api '-Dtest=PalaceRetrievalLoggingPrivacyTest' test
Tests run: 5, Failures: 5, Errors: 0
```

The minimum fix keeps real retrieval input unchanged and emits only safe diagnostics. Vector logs use `queryLength`, `topK`, `filterPresent`, `resultCount`, and `exceptionType`; keyword logs use `keywordsLength`, filter-presence booleans, `limit`, `resultCount`, and `exceptionType`; Hybrid logs use `queryLength`, vector/keyword/result counts, phase-presence booleans, and `exceptionType`. No raw query, derived keywords, filter expression, exception message, throwable, or stack is passed to these loggers. Hybrid persisted error-fallback trace now carries only the exception class name.

GREEN:

```text
bash ./mvnw -pl app-api '-Dtest=PalaceRetrievalLoggingPrivacyTest,PalaceHybridRetrievalServiceTest,PalaceKeywordRepositoryTest' test
Tests run: 21, Failures: 0, Errors: 0
```

The capture fixture includes distinct preset-brief/custom-prompt/keyword and exception-message markers and asserts their absence across success, fallback, and error events.

### B. Coach-tip verifier completeness

Root cause: the prior checker only inspected the fixed V27 migration and `mapper/practice/generated`. RED fixtures proved both blind spots:

```text
python3 test/tool/verify_practice_generation_privacy_test.py
Ran 12 tests ... FAILED (failures=2: future generated migration and non-standard mapper)
```

The verifier now discovers all migration SQL that operates on a generated-content table and all app-api mapper XML, then applies a table-content check. It permits the preset catalog/version surface, immutable V25 baseline, and only the safe V27 `coalesce` backfill plus `drop column` transition; a future V38/V99 generated migration or mapper query/command/audit field is rejected.

GREEN:

```text
python3 test/tool/verify_practice_generation_privacy_test.py
Ran 12 tests ... OK
python3 tool/verify_practice_generation_privacy.py
practice generation privacy verification passed
python3 test/ci/test_full_ci_contract.py
Ran 15 tests ... OK
```

### C. Deterministic fake preset coverage

Root cause: `FakeSceneContentGenerator` inferred only from display text, so the five V37 stable published IDs were not all representable (notably `bath_time` and `post_cry_soothing`). RED first compiled the desired internal request seam and failed because no stable-ID constructor existed:

```text
bash ./mvnw -pl app-api '-Dtest=SceneContentGeneratorProviderWiringTest#fakeProviderSupportsEveryPublishedPresetByStableActivityId' test
Compilation error: no suitable GeneratorRequest constructor (11 arguments)
```

`SceneContentGenerator.GeneratorRequest` now carries validated safe `stableActivityId`; the orchestrator and direct path pass it through, and the Agentic prompt payload deliberately omits it. Fake deterministic mappings cover exactly V37 `bath_time`, `diaper_change`, `post_cry_soothing`, `feeding_time`, and `bedtime`; null ID retains the existing custom keyword fallback. Each parameterized fake result is a six-utterance bundle and passes the deterministic validator.

GREEN:

```text
bash ./mvnw -pl app-api '-Dtest=SceneContentGeneratorProviderWiringTest,AgenticSceneContentGeneratorTest' test
Tests run: 29, Failures: 0, Errors: 0
```

The Agentic prompt test asserts the stable-ID marker is absent from serialized provider payload while existing personalization remains present.

### Review-round verification and scope

Final non-PostgreSQL Task 4 focused run passed `164/164`: Palace logging `5`, Hybrid `6`, keyword `10`, unified engine `4`, key factory `10`, orchestrator `41`, service `50`, service orchestration `8`, input `1`, Agentic generator `15`, and provider wiring `14`. The Spring AI platform gate passed:

```text
python3 tool/verify_spring_ai_2_backend_platform.py
Spring AI 2 backend platform contract verified
```

Required PG rerun was attempted:

```text
bash ./mvnw -q -pl app-api '-Dtest=PracticeGeneratedContentConcurrencyTest#concurrentPrimaryAndCaregiverPresetRequestsShareOneProfileOwnedRow' test
Tests run: 1, Failures: 0, Errors: 1
Could not find a valid Docker environment ... dockerDesktopLinuxEngine ... daemon is not running
```

The same environment caused the review-round complete-bundle verifier to report `311` tests with `15` initialization errors. No Testcontainers skip/disable was used. Current round staged files are limited to the three Palace production classes plus their capture test, the stable fake/request forwarding production/test files, the privacy verifier and its unit test, and this report. `PracticeDiscoveryService.java`, `PracticeDiscoveryServiceTest.java`, `PracticeGeneratedContentQueryMapper.xml`, `CaregiverInviteApiWebTest.java`, and all mobile/windows WIP remain unstaged.
