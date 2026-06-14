---
phase: "29"
plan: "02"
---

# T02: Published IngestionCompletedEvent from successful IngestionService completions and added unit coverage for success/failure event behavior.

**Published IngestionCompletedEvent from successful IngestionService completions and added unit coverage for success/failure event behavior.**

## What Happened

Added `backend/common/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionCompletedEvent.java` as the shared post-ingestion record carrying `jobId`, `bookTitle`, and `totalChunks`. Surgically updated `IngestionService` to inject `ApplicationEventPublisher` as the 7th constructor dependency, threaded `bookTitle` through `dispatchProcessing(...) -> completeProcessing(...)`, and published `new IngestionCompletedEvent(...)` only in the success branch after `repository.updateCompleted(jobId, outcome.totalChunks())`. The failure path remains isolated and still only records terminal failure state. Because `backend/common` had no existing test harness, I also added `spring-boot-starter-test` to the module and created `IngestionServiceTest` with reflection-based coverage that proves the success path updates the repository before publishing the event and the failure path does not publish anything. This task provides the stable completion-event seam that downstream S02 tasks can consume to populate `palace_rooms`, bump `palace_projection_version`, and enqueue bridge proposals. Slice-level projection/logging verification is not expected to pass until those downstream listeners are wired.

## Verification

Verified the change with `mvn -f C:/Users/zhang/.gsd/projects/67565506c51a/worktrees/M008/pom.xml -pl backend/common test` and `mvn -f C:/Users/zhang/.gsd/projects/67565506c51a/worktrees/M008/pom.xml -pl backend/common compile`. The test run compiled the module, executed `IngestionServiceTest`, and passed 2 assertions covering the success ordering (`updateCompleted` before `publishEvent`) and the failure guard (no event publication when processing fails). The required compile command also passed cleanly. As an intermediate task, the slice-level SQL/log verification for `palace_rooms`, `palace_bridge_edges`, and `palace_projection_version` remains pending for downstream runtime sync tasks.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn -f C:/Users/zhang/.gsd/projects/67565506c51a/worktrees/M008/pom.xml -pl backend/common test` | 0 | ✅ pass | 14448ms |
| 2 | `mvn -f C:/Users/zhang/.gsd/projects/67565506c51a/worktrees/M008/pom.xml -pl backend/common compile` | 0 | ✅ pass | 4797ms |

## Deviations

Added `backend/common` test support (`spring-boot-starter-test`) and a focused `IngestionServiceTest` even though the written task plan only required `mvn compile -pl backend/common`, because the module had no existing test harness and auto-mode requires fresh executable verification for the new event contract.

## Known Issues

Mockito emits the existing dynamic-agent warning under the current JDK during `backend/common` test execution. The tests still passed and this warning does not affect the shipped runtime behavior.

## Files Created/Modified

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionCompletedEvent.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionService.java`
- `backend/common/pom.xml`
- `backend/common/src/test/java/com/zhangspaghetti/babytalk/ingestion/IngestionServiceTest.java`
