---
phase: "29"
plan: "04"
---

# T04: Added age-overlap/bridge unit coverage and post-ingestion palace projection assertions in admin-api tests.

**Added age-overlap/bridge unit coverage and post-ingestion palace projection assertions in admin-api tests.**

## What Happened

Rewrote the pre-existing `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/knowledge/PalaceProjectionSyncServiceTest.java` to match the task contract with five focused tests: three package-local `computeAgeOverlapFraction` cases and two bridge-proposal branching cases that exercise cross-wing proposal emission vs. skip behavior. Updated `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminKnowledgeOpsWebTest.java` so `resetTables()` now truncates `palace_rooms`, `palace_bridge_edges`, and `palace_projection_version`, then added `ingestionCompletedPopulatesProjectionAndBridgeProposal()` to seed a cross-wing room, run a real ingestion for `Baby Talk`, and assert the projection room row, current version row, and proposed bridge row are all persisted. During verification I also confirmed the production service still satisfies the gate’s signature expectations: `@Service` at line 14, `@EventListener` at line 26, and package-private static `computeAgeOverlapFraction` at line 125 of `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/PalaceProjectionSyncService.java`. Because this worktree’s standalone `admin-api` test command depends on sibling test artifacts, I locally installed `backend/common` and `backend/db-migration` once so the exact planned Maven command could run successfully afterward.

## Verification

Verified the gate compile command directly with `mvn compile -pl backend/admin-api`, which now succeeds cleanly. Verified the task-plan test command directly with `mvn test -pl backend/admin-api -Dtest=PalaceProjectionSyncServiceTest,AdminKnowledgeOpsWebTest`; all 14 targeted tests passed, including all 5 PalaceProjectionSyncService unit tests and 9 AdminKnowledgeOpsWebTest integration tests with the new ingestion projection assertion. Source inspection also confirmed the production annotations and package-private static method signature remained intact in `PalaceProjectionSyncService`.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn compile -pl backend/admin-api` | 0 | ✅ pass | 12611ms |
| 2 | `mvn test -pl backend/admin-api -Dtest=PalaceProjectionSyncServiceTest,AdminKnowledgeOpsWebTest` | 0 | ✅ pass | 39830ms |

## Deviations

Rewrote an already-existing `PalaceProjectionSyncServiceTest.java` instead of creating a brand-new file, and installed sibling Maven modules (`backend/common`, `backend/db-migration`) locally so the exact standalone `admin-api` test command from the plan could resolve its test-scope dependency in this worktree.

## Known Issues

None.

## Files Created/Modified

- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/knowledge/PalaceProjectionSyncServiceTest.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminKnowledgeOpsWebTest.java`
