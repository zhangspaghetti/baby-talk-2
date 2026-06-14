---
phase: "28"
plan: "05"
---

# T05: Added S01 hybrid retrieval unit and HTTP integration coverage, fixed constructor/source propagation regressions, and documented the remaining llm-it full-suite failure.

**Added S01 hybrid retrieval unit and HTTP integration coverage, fixed constructor/source propagation regressions, and documented the remaining llm-it full-suite failure.**

## What Happened

I aligned `PalaceHybridRetrievalServiceTest` with the four contractual scenarios for deterministic hybrid merge, 6mo vs 24mo age-aware ordering, temporal fallback, and projection-not-ready fallback. Because the planned `MentorChatIntegrationTest` did not exist locally, I created a new MockMvc + Testcontainers integration test that exercises `/api/v1/mentor/chat` through a mocked `MentorProvider` bean delegating to a real `SpringAiMentorProvider`, so the request still flows through the real `PalaceHybridRetrievalService` and persists `palace_query_traces` rows without depending on an external LLM. During verification I also repaired a stale `MentorProviderConfigurationTest` that still referenced `PalaceSearchService`, annotated the production constructor on `PalaceHybridRetrievalService` so Spring can instantiate it reliably with the extra clock-testing constructor present, and propagated `source_book` through `HybridCandidate` into `SpringAiMentorProvider` pre-retrieved evidence formatting so RAG prompt injection no longer strips book attribution. Targeted new tests and the M005 regression subset passed; the remaining gap is a deterministic failure in `LlmRagIntegrationTest`, which now returns `provider_malformed_response` (HTTP 502) under the live llm-it profile even after the source-book restoration.

## Verification

Ran targeted Maven verification for the new/changed tests and for the named M005 regression suite. `PalaceHybridRetrievalServiceTest` and the new `MentorChatIntegrationTest` pass, including the DB-backed assertions that `palace_query_traces` rows are created and that `temporal_rule_applied` is populated or `skipped` as expected. The named regression suite (`AgenticMentorIntegrationTest`, `SpringAiMentorProviderTest`, `PalaceKeywordRepositoryTest`, `PalaceToolProviderTest`, `MemPalacePromptBuilderTest`) also passes. Full `app-api` test execution does not fully pass yet: the only remaining red report is `LlmRagIntegrationTest`, which now fails with `provider_malformed_response` / HTTP 502 in the live llm-it environment. Grepping surefire reports confirms that this is the sole failing report after the full run.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest="PalaceHybridRetrievalServiceTest,MentorChatIntegrationTest"` | 0 | ✅ pass | 44000ms |
| 2 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest="AgenticMentorIntegrationTest,SpringAiMentorProviderTest,PalaceKeywordRepositoryTest,PalaceToolProviderTest,MemPalacePromptBuilderTest"` | 0 | ✅ pass | 13000ms |
| 3 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test` | 1 | ❌ fail | 149000ms |
| 4 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest="LlmRagIntegrationTest#ragMentorChatIncludesSourceCitationFromSeededContent"` | 1 | ❌ fail | 33000ms |
| 5 | `grep -r "Tests run:" backend/app-api/target/surefire-reports/ | grep -v "Failures: 0, Errors: 0"` | 0 | ❌ fail | 0ms |

## Deviations

The repo did not contain the planned `MentorChatIntegrationTest`, so I created it from scratch in `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/MentorChatIntegrationTest.java`. I also had to fix adjacent broken tests and bean wiring (`MentorProviderConfigurationTest`, `PalaceHybridRetrievalService` constructor selection, and source-book propagation) because they blocked compilation or exposed a real regression while verifying this task.

## Known Issues

`./backend/mvnw -f backend/pom.xml -q -pl app-api -am test` still fails on `com.zhangspaghetti.babytalk.LlmRagIntegrationTest`. In repeated runs the endpoint returns `provider_malformed_response` (HTTP 502) under the live llm-it profile, so the full-suite verification bar is not yet green. `backend/app-api/target/surefire-reports/com.zhangspaghetti.babytalk.LlmRagIntegrationTest.txt` is the single non-green report after the full run.

## Files Created/Modified

- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/palace/PalaceHybridRetrievalServiceTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/MentorChatIntegrationTest.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/HybridCandidate.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceHybridRetrievalService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProvider.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/MentorProviderConfigurationTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProviderTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/AgenticMentorIntegrationTest.java`
