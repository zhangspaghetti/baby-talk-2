# Task 5 report — strict unified scene generation API

## Status

Implemented the profile-owned, source-neutral generation endpoint and removed the old discovery/onboarding generation adapters. The intermediate client-version gate remains `1.2.0`; Task 7 owns the later `1.3.0` bump.

## API contract

`POST /api/v1/practice/scene-generations` reads `sid` only from `JwtAuthenticationToken` and accepts exactly these top-level JSON fields: `source`, `locale`, `installationId`, and `clientRequestId`.

Valid source shapes are:

```json
{"type":"custom","text":"洗澡时宝宝不想碰水"}
```

```json
{"type":"preset","presetSceneId":"bath_time"}
```

`SceneGenerationRequest.StrictDeserializer` rejects unknown or duplicate keys, mixed/missing/null fields, arrays/objects where strings are required, numeric/string coercion, trailing tokens, and malformed JSON. All binding/shape failures map to privacy-safe `400 invalid_scene_source` with empty details. No subject, personalization, catalog, or engine collaborator is reached on a binding failure.

The service order is: `HouseholdBabyProfileAccessService.resolve(sessionId)` → source semantics (custom canonicalization/security or current published preset lookup/brief validation) → `ScenePersonalizationContextService.build(...)` → `PracticeGeneratedContentService.generateScene(SceneGenerationInput)`.

Custom invalid/unsafe text maps to `400 invalid_custom_scene_text` with empty details. Missing, disabled, unpublished, malformed, or unsafe preset definitions map to `404 preset_scene_unavailable` with empty details. `SceneGenerationInput` is constructed with all 11 fields; custom preset IDs/stable IDs are null, while preset IDs and stable IDs come only from the current catalog definition.

The response is privacy-safe and complete: `generatedContentId`, schema version, stable/generated route metadata, scene metadata, one starter, five canonical `reaction_support` utterances, per-utterance provider provenance, and `SourceView(type,presetSceneId,presetSceneVersion)`. Bundle shape, approval status/version, role/reaction mapping, display order, IDs, and provenance are validated before serialization. No resolved/normalized input, generation brief, owner/account/profile/household fields, baby name, or internal numeric activity/version IDs are returned; custom `SourceView` never returns text.

## TDD and verification

- RED: the requested controller/service test command initially failed compilation because the new API production seams did not yet exist; onboarding RED likewise failed while the generator still required the removed generation service.
- `SceneGenerationControllerTest` + `SceneGenerationServiceTest`: **42/42**.
- `PracticeDiscoveryServiceTest` + `PracticeDiscoveryControllerTest`: **49/49**; old `custom_scene` mode is rejected before catalog/profile work.
- Restored/migrated generated core suites: `PracticeGeneratedContentServiceTest` **50/50**, orchestration **8/8**, concurrency **11/11**, `SceneAgenticGenerationIntegrationTest` **11/11**; combined **80/80**.
- Task 4 unified focused suite (engine, keys, orchestrator, input, provider wiring, validator, mapper): **173/173**.
- Onboarding generator + conversation controller/service/turn suites: **22/22**; generator now uses deterministic server-curated scene/reaction copy with stable IDs and no AI/generated-service dependency.
- Primary/caregiver preset PG concurrency target: **1/1** with real Testcontainers PostgreSQL/pgvector and Ryuk; full concurrency suite also passed.
- Clean app-api run: **1126 tests**, only the two pre-existing dirty Task 7 `CaregiverInviteApiWebTest` shared-profile cases fail (`200→404`, `403→404`); no Task 5 failure.
- `python3 tool/verify_spring_ai_2_backend_platform.py`: PASS.
- `python3 tool/verify_practice_generation_privacy.py`: PASS.
- `python3 test/tool/verify_practice_generation_privacy_test.py`: **13/13**.
- Backend Java audit: `generateCustomScene`, `generateCustomSceneForInstallationOwner`, and `CustomSceneDiscoveryRequest`: **no matches**. Mobile continuation enum references remain untouched by scope.

## Test migration and scope audit

The four generated core test files were restored from the base commit and migrated to `SceneGenerationInput`/`generateScene`; they were not deleted to hide adapter compile errors. Only obsolete discovery custom-mode cases were removed. Installation-owned cleanup coverage remains exercised with direct terminal fixtures; unified generation coverage uses profile ownership. Task 6 query XML, Task 7 `CaregiverInviteApiWebTest`, and all mobile/windows WIP remain unstaged and unchanged.

## Concerns

The clean app-api result remains red only because of the explicitly out-of-scope Task 7 dirty test changes. Preset and custom response DTOs intentionally use a nested route/scene/utterance shape; `SourceView` follows the approved exact field contract. No deployment or minimum-version change was made.

## Fix round 1/5

RED first added `SceneGenerationRequestTest` (2 failures): default record `toString()` exposed custom text and preset/installation/client values. A preset catalog runtime-failure test also failed because `SceneGenerationService` converted an arbitrary `RuntimeException` into `404 preset_scene_unavailable`.

GREEN now overrides both request records with type/presence-only diagnostics; no text or identifier value is rendered. Preset lookup maps only the catalog's expected not-found `ContractException` to the coarse 404; arbitrary runtime failures propagate to the existing generic 500 handler. Preset brief security `ContractException` remains coarse 404, while unrelated runtime failures propagate. Controller coverage asserts generic 500 response omits the catalog exception message.

Fix round focused result: request 2/2, service 10/10, controller 34/34. Platform and privacy gates remained PASS. Changes are limited to `SceneGenerationRequest.java`, `SceneGenerationService.java`, their request/service/controller tests, and this report; Task 6 XML, Task 7 test, and mobile/windows WIP remain untouched and unstaged.

Self-audit: no sensitive values appear in request `toString()` output or generic HTTP response; no broad preset lookup runtime catch remains. Existing base commit is `af756fef`; this fix is committed separately as `fix(api): protect scene request errors`.
