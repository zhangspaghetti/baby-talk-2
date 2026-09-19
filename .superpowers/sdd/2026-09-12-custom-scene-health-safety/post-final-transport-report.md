# Post-final transport correction report

## Root cause

Spring AI 2.0.0 builds `SpringAiOpenAiHttpClient` during `OpenAiChatModel.builder().build()`. A request-level `OpenAiChatOptions.timeout` does not rebuild the already-created HTTP client, so the previous safety-only option change did not prove a three-second transport deadline.

## Correction

- `PracticeAiProviderManager` now builds a dedicated safety-classifier provider client with `Duration.ofSeconds(3)` while generator/judge/repair providers keep configured timeouts.
- `PracticeAiChatClientFactory` applies the override both to model construction options and the actual `SpringAiOpenAiHttpClient.Builder.timeout(...)` customizer.
- Safety routing still selects one provider; existing classifier executor/per-call deadline and cause-free unavailable boundary remain.
- Standalone production release verification now parses `practiceAi.providers` and rejects a missing provider map, unknown safety route provider, or invalid referenced provider definition. Credential values are never read or emitted.

## RED/GREEN evidence

- Added delayed HTTP-server test: before correction safety route remained blocked past five seconds; after correction it failed through the actual client in the two-to-four-second window with one request.
- Added standalone verifier tests for missing provider map, unknown route provider, and invalid provider type.

## Verification

- `python3 tool/verify_spring_ai_2_backend_platform.py` — pass.
- `cd backend && bash mvnw clean test` — pass; app-api 1167, db-migration 16, admin-api 70, gateway 18.
- `cd mobile && flutter test` — pass; 967 tests.
- `dart test test/tool/verify_custom_scene_production_release_test.dart` — pass; 11 tests.
- `dart run tool/verify_custom_scene_production_release.dart` — pass, zero violations.
- app-api checkstyle — 0 violations.
- `git diff --check` — pass.
