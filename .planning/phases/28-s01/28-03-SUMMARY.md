---
phase: "28"
plan: "03"
---

# T03: Added PalaceHybridRetrievalService with deterministic hybrid merge, age-aware ranking, and persisted palace query traces.

**Added PalaceHybridRetrievalService with deterministic hybrid merge, age-aware ranking, and persisted palace query traces.**

## What Happened

Added four retrieval value objects (`RetrievalRequest`, `HybridCandidate`, `QueryTrace`, `RetrievalResult`) and implemented `PalaceHybridRetrievalService` as the deterministic retrieval owner for vector + keyword merge. The service now merges candidates by chunk ID, preserves channel scores, applies age-aware soft boosting with the widened-floor fallback, uses best-effort KG month ranges when chunk metadata has no parsable age window, performs projection traversal when palace rooms are populated, and emits one persisted `palace_query_traces` row per call with entry rooms, bridge edges, top candidates, temporal rule, projection version, and timestamp.

To support deterministic keyword scoring, I minimally extended the Palace keyword mapper/repository boundary so `ts_rank` flows through as `keywordScore`. I also added focused unit tests for deterministic merge ordering, age-sensitive ranking differences, temporal fallback behavior, and empty-projection graceful fallback, then updated the existing keyword/tool-provider tests for the new DTO signature without changing their external behavior.

## Verification

Verified the new retrieval service with a focused module-level Maven run: `./backend/mvnw -f backend/pom.xml -q -pl app-api test -Dtest=PalaceHybridRetrievalServiceTest` passed all 4 required unit tests covering merge deduplication, age-differentiated effective scoring, temporal fallback widening, and empty-projection fallback behavior. Also ran `./backend/mvnw -f backend/pom.xml -q -pl app-api test -Dtest=PalaceKeywordRepositoryTest,PalaceToolProviderTest` to confirm the `keywordScore` signature change did not break existing palace keyword/tool-provider tests.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw -f backend/pom.xml -q -pl app-api test -Dtest=PalaceHybridRetrievalServiceTest` | 0 | ✅ pass | 11221ms |
| 2 | `./backend/mvnw -f backend/pom.xml -q -pl app-api test -Dtest=PalaceKeywordRepositoryTest,PalaceToolProviderTest` | 0 | ✅ pass | 11222ms |

## Deviations

Adjusted the age-differentiation unit fixture from the planner text's `age_range='0-3'` to `age_range='0-1'` because both 6 and 24 months are inside a 0-3 year window, so the planned assertion could not prove differentiated age boosting. For runnable verification, used the module-only Maven command (`-pl app-api test`) after installing dependent modules because the root `-am` variant propagated `-Dtest` into upstream modules and failed with Surefire's 'No tests matching pattern' error before reaching `app-api`.

## Known Issues

`PalaceHybridRetrievalService` is implemented and trace persistence works, but this task did not wire the service into `SpringAiMentorProvider`, so `installation_id` is still persisted as `null` until the downstream provider-integration task lands.

## Files Created/Modified

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceHybridRetrievalService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/RetrievalRequest.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/HybridCandidate.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/QueryTrace.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/RetrievalResult.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceKeywordRepository.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceKeywordMapper.java`
- `backend/app-api/src/main/resources/mapper/palace/PalaceKeywordMapper.xml`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/palace/PalaceHybridRetrievalServiceTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/palace/PalaceKeywordRepositoryTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/palace/PalaceToolProviderTest.java`
