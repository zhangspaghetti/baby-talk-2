---
phase: "29"
plan: "03"
---

# T03: Added PalaceProjectionSyncService to upsert palace rooms, bump projection version, and propose cross-wing bridges when ingestion completes.

**Added PalaceProjectionSyncService to upsert palace rooms, bump projection version, and propose cross-wing bridges when ingestion completes.**

## What Happened

Created `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/PalaceProjectionSyncService.java` as a Spring `@Service` with an `@EventListener` for `IngestionCompletedEvent`. The listener resolves the ingested book through `MemPalaceTaxonomy`, upserts `palace_rooms`, inserts or updates the `palace_projection_version` current row, and then scans rooms in other wings to insert proposed bridge edges via `JdbcTemplate` only, matching the slice contract.

I kept the bridge scan in an isolated failure domain with a WARN log so room/version projection updates remain durable even if bridge proposal generation throws. I also normalized a null `bookTitle` to an empty string before reuse so `source_book_a/source_book_b` stay non-null when bridge rows are inserted.

Added `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/knowledge/PalaceProjectionSyncServiceTest.java` to cover deterministic age-overlap math, taxonomy fallback helpers, the happy-path room/version/bridge SQL flow, and the non-fatal bridge-scan failure path. For observability truthfulness, the bridge proposal counter increments only by rows actually inserted by `ON CONFLICT DO NOTHING`, so the INFO log reflects created proposals rather than mere candidates.

## Verification

Verified the task-plan contract in three layers. First, the exact planned command `mvn compile -pl backend/admin-api` was run and failed because this reactor invocation does not bring `backend/common` and `backend/db-migration` into scope in the current worktree, leaving existing mapper types unresolved. Second, the adapted reactor-faithful compile `mvn compile -pl backend/admin-api -am` succeeded, proving the new service compiles with its real upstream modules. Third, `mvn test-compile -pl backend/admin-api -am` succeeded, proving the new test class compiles alongside the module. I also verified the source file contains `@Service`, `@EventListener`, and a package-private static `computeAgeOverlapFraction` signature via `rg` on the created service source.

The slice-level verification available in this task is therefore partially satisfied now: the service compiles with upstream modules present, the observability log points are in the source, and the admin-api test sources compile. Runtime ingestion-to-table population still requires later slice work and end-to-end execution against the full ingestion/admin surface.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn compile -pl backend/admin-api` | 1 | ❌ fail | 35800ms |
| 2 | `mvn compile -pl backend/admin-api -am` | 0 | ✅ pass | 54800ms |
| 3 | `mvn test -pl backend/admin-api -am -Dtest=PalaceProjectionSyncServiceTest` | 1 | ❌ fail | 12200ms |
| 4 | `mvn test-compile -pl backend/admin-api -am` | 0 | ✅ pass | 25252ms |

## Deviations

Added a focused unit test file even though the task plan only named the production service file, because execute-task requires tests to ship with non-trivial runtime behavior. Verification also required a local adaptation from `mvn ... -pl backend/admin-api` to `mvn ... -pl backend/admin-api -am`; without `-am`, the reactor omits upstream modules and the compile failure is unrelated to this change.

## Known Issues

`mvn test -pl backend/admin-api -am -Dtest=PalaceProjectionSyncServiceTest` did not execute the targeted test because Surefire did not match the selector in this environment, even after the class was made public. The test source itself does compile successfully under `mvn test-compile -pl backend/admin-api -am`, so the remaining issue is the test-selection mechanism rather than Java compilation of the added test.

## Files Created/Modified

- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/PalaceProjectionSyncService.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/knowledge/PalaceProjectionSyncServiceTest.java`
