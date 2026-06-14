---
phase: "06"
plan: "01"
---

# T01: feat: add Practice Generate API endpoint with JSON parsing, fallback handling, and MemPalace prompt builder

**feat: add Practice Generate API endpoint with JSON parsing, fallback handling, and MemPalace prompt builder**

## What Happened

Implemented the full Practice Generate API backend pipeline:\n\n1. **MemPalacePromptBuilder** — Added `PRACTICE_SYSTEM_PROMPT` constant with structured JSON output instructions and `buildPracticeSystemPrompt(babyAgeMonths, sceneTag, palaceSearch)` method reusing L1 pre-fetch logic.\n\n2. **MentorService** — Added `generatePractice(PracticeGenerateCommand)` with independent pipeline (no rate limit, no turn recording), two-pass JSON parsing (direct → regex code-fence extraction → empty fallback), provider exception handling, and SLF4J INFO/WARN logging per slice spec.\n\n3. **Records** — `PracticeGenerateCommand`, `PracticeGenerateResponse`, `ActivityDto`, `PhraseDto` as nested records in MentorService.\n\n4. **MentorController** — `@PostMapping(\"/practice/generate\")` endpoint.\n\n5. **MentorProperties** — Added `practiceResponseMaxLength` (Integer, default 2000).\n\n6. **application.yml** — Added `practice` to allowed-surfaces, added `practice-response-max-length: 2000`.\n\n7. **Tests** — `PracticeGenerateControllerTest` (9 test cases: valid JSON, non-JSON fallback, code-fence JSON, missing/wrong surface, missing installationId, provider timeout/unavailable/malformed, null sceneTag). Added 6 practice prompt tests to `MemPalacePromptBuilderTest`.\n\n8. **Existing test fixes** — Updated 4 test files for new `practiceResponseMaxLength` constructor param.\n\nPracticeGenerateControllerTest requires Docker/Testcontainers and was interrupted during Spring context boot. MemPalacePromptBuilderTest (26 tests including 6 new) passed fully.

## Verification

- `mvn compile test-compile -q` — passes cleanly (exit 0)\n- `MemPalacePromptBuilderTest` — 26 tests pass including 6 new PracticePromptBuilding tests\n- `PracticeGenerateControllerTest` — compiles, 9 test methods written, requires Docker for execution (integration test with Testcontainers). Execution interrupted during Spring context boot at timeout.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd backend && mvn compile test-compile -q` | 0 | ✅ pass | 28000ms |
| 2 | `cd backend && mvn test -Dtest=com.zhangspaghetti.babytalk.palace.MemPalacePromptBuilderTest -Dsurefire.failIfNoSpecifiedTests=false` | 0 | ✅ pass — 26 tests (6 new practice prompt tests) | 6000ms |
| 3 | `cd backend && mvn test -Dtest=com.zhangspaghetti.babytalk.web.PracticeGenerateControllerTest -Dsurefire.failIfNoSpecifiedTests=false` | -1 | ⏳ pending — integration test requires Testcontainers; Spring context boot in progress at timeout | 0ms |

## Deviations

Added PalaceSearchService and ObjectMapper as new constructor dependencies to MentorService (required for practice prompt building and JSON parsing). Fixed 4 existing test files for new MentorProperties constructor parameter. PracticeGenerateControllerTest execution pending Docker availability.

## Known Issues

PracticeGenerateControllerTest integration test was not fully executed due to timeout during Testcontainers Spring context boot. Test compiles and 9 methods are structurally sound. Next task should run: mvn test -Dtest=com.zhangspaghetti.babytalk.web.PracticeGenerateControllerTest -Dsurefire.failIfNoSpecifiedTests=false to confirm all pass. Surefire requires -Dsurefire.failIfNoSpecifiedTests=false when running individual test classes with nested @Nested classes.

## Files Created/Modified

- `backend/src/main/java/com/zhangspaghetti/babytalk/palace/MemPalacePromptBuilder.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/MentorProperties.java`
- `backend/src/main/resources/application.yml`
- `backend/src/test/java/com/zhangspaghetti/babytalk/web/PracticeGenerateControllerTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/palace/MemPalacePromptBuilderTest.java`
