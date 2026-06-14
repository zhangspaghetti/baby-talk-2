---
phase: "30"
plan: "01"
---

# T01: Added AdminPalaceRagService and `/api/admin/knowledge/palace/*` endpoints with WebMvc coverage for projection, bridge review, and trace samples.

**Added AdminPalaceRagService and `/api/admin/knowledge/palace/*` endpoints with WebMvc coverage for projection, bridge review, and trace samples.**

## What Happened

Created `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminPalaceRagService.java` as a JdbcTemplate-only `@Service` for Palace RAG Ops. The service now exposes projection status lookup, bridge edge queue/detail lookup, approve/reject mutations, and query-trace sampling. For `listBridgeEdges`, I used two separate SQL branches (with and without `WHERE e.status = ?`) to avoid the PostgreSQL nullable-parameter inference bug called out in MEM098. For trace samples, JSONB columns are read via `rs.getString(...)` so the API returns the stored JSON payloads directly. Missing bridge-edge lookups and mutations now emit a WARN log and raise an explicit `palace_bridge_edge_not_found` 404.

Extended `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeOpsController.java` with six new `/api/admin/knowledge/palace/**` endpoints, constructor-injected the new service, added malformed-UUID guards for `{edgeId}`, defaulted palace list limits to 20 when omitted, and passed `Authentication.getName()` through to `reviewed_by` for approve/reject so JWT subject identity is persisted.

Updated `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminKnowledgeOpsWebTest.java` to cover the new backend contract: `{ notReady: true }` when no current projection exists, projection detail payloads once seeded, bridge queue/detail payloads with joined room metadata, trace sample ordering/limit behavior, approve/reject reviewer persistence, malformed UUID 400s, explicit bridge 404s, and read/write permission boundaries. This retires the backend slice checks for projection inspection, bridge queue visibility, trace sample visibility, and failure visibility; the remaining slice-level verification about Projection Status card surfacing S02 INFO logs is UI-side and belongs to later tasks in this slice.

## Verification

Ran `mvn compile -pl backend/admin-api -am` to ensure the new service/controller compiled cleanly across dependent modules, then ran `mvn test -pl backend/admin-api -Dtest=AdminKnowledgeOpsWebTest` to exercise the new palace endpoints end-to-end through Spring MVC, auth, PostgreSQL, and Flyway-backed schema setup. The web test suite verified projection `notReady` fallback, bridge queue/detail reads, trace JSONB sample reads, approve/reject mutations persisting reviewer identity, malformed UUID 400 handling, explicit missing-edge 404 handling, and permission enforcement for `rag:read` vs `rag:write`.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn compile -pl backend/admin-api -am` | 0 | ✅ pass | 14500ms |
| 2 | `mvn test -pl backend/admin-api -Dtest=AdminKnowledgeOpsWebTest` | 0 | ✅ pass | 31200ms |

## Deviations

Added targeted WebMvc coverage in the existing `AdminKnowledgeOpsWebTest` even though the task plan's Expected Output listed only production files, because this backend contract needed executable verification in the same task.

## Known Issues

None.

## Files Created/Modified

- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminPalaceRagService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeOpsController.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminKnowledgeOpsWebTest.java`
