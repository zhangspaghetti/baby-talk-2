---
phase: "28"
plan: "04"
---

# T04: Switched SpringAiMentorProvider to PalaceHybridRetrievalService pre-retrieval and prompt evidence injection for rag/agentic chat.

**Switched SpringAiMentorProvider to PalaceHybridRetrievalService pre-retrieval and prompt evidence injection for rag/agentic chat.**

## What Happened

Updated `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProvider.java` so mentor chat now performs a pre-LLM `PalaceHybridRetrievalService.retrieve(...)` for `rag` and `agentic`, converts ranked candidates into L1 evidence strings, logs trace metadata, and falls back to empty evidence on retrieval failure instead of failing the chat call. Added a `MemPalacePromptBuilder` overload that accepts pre-retrieved evidence while leaving the existing document/search-based practice prompt path intact, and rewired `MentorProviderConfiguration` to inject `PalaceHybridRetrievalService` instead of `PalaceSearchService`. Updated `SpringAiMentorProviderTest`, `AgenticMentorIntegrationTest`, and `MemPalacePromptBuilderTest` so the provider hot path is covered for rag/agentic evidence injection, tool retention in agentic mode, and failure fallback behavior.

## Verification

Verified three layers. (1) Build: `mvn -q -f "$(cygpath -aw backend/pom.xml)" -pl app-api -am compile` completed successfully. (2) Targeted test: `mvn -f "$(cygpath -aw backend/pom.xml)" -pl app-api -am clean test -Dtest=SpringAiMentorProviderTest -Dsurefire.failIfNoSpecifiedTests=true` passed with 17 worktree-authored test methods covering rag/agentic/none paths, retrieval request construction, prompt injection, and fallback/tool behavior. (3) Source-level verification: a Python assertion script checked the active worktree files to confirm the provider now uses `PalaceHybridRetrievalService`, no longer references `PalaceSearchService` on the chat hot path, uses the new prompt-builder evidence overload, rewires configuration injection, and contains the new hybrid prompt-injection tests. Due to a worktree Maven path quirk, I used an absolute `-f` path plus the source assertion script instead of trusting relative-wrapper invocations alone.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn -q -f "$(cygpath -aw backend/pom.xml)" -pl app-api -am compile` | 0 | ✅ pass | 5700ms |
| 2 | `mvn -f "$(cygpath -aw backend/pom.xml)" -pl app-api -am clean test -Dtest=SpringAiMentorProviderTest -Dsurefire.failIfNoSpecifiedTests=true` | 0 | ✅ pass | 22800ms |
| 3 | `python source assertion script via gsd_exec: verify worktree T04 source wiring` | 0 | ✅ pass | 18125ms |

## Deviations

Used absolute `-f` Maven invocations with local `mvn` for verification instead of the task-plan’s relative `./backend/mvnw -f backend/pom.xml ...` form, because relative-wrapper execution in this GSD worktree can resolve against the main checkout rather than the active worktree.

## Known Issues

Maven/Surefire output in this environment still prints canonical source paths under `C:\code\AI\baby-talk-2\backend\...`, which makes worktree-vs-main-checkout verification easy to misread. The implemented source-level assertion script was used as an additional guard, but the underlying path-reporting quirk remains.

## Files Created/Modified

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProvider.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/MemPalacePromptBuilder.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/MentorProviderConfiguration.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProviderTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/AgenticMentorIntegrationTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/palace/MemPalacePromptBuilderTest.java`
