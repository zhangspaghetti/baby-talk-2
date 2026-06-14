---
phase: "19"
plan: "01"
---

# T01: Added the /api/admin/knowledge/** read contract, idempotent KG review mutations, and admin-api web proof for Knowledge Ops.

**Added the /api/admin/knowledge/** read contract, idempotent KG review mutations, and admin-api web proof for Knowledge Ops.**

## What Happened

Implemented the admin-only Knowledge Ops backend surface under `/api/admin/knowledge/**` without exposing app-api or internal storage fields to the browser. I added shared JDBC read models in `backend/common/.../admin/knowledge` for bounded ingestion job reads and KG contradiction/notification reads, with explicit statement timeouts and no exposure of `minio_object_key` or raw file content.

On top of those repositories, I added `AdminKnowledgeOpsService` and `AdminKnowledgeOpsController` in `admin-api` to serve ingestion list/detail behind `rag:read`, contradiction list/detail plus contradiction-scoped notification reads behind `kg:read`, and idempotent `PATCH` review mutations for contradiction resolve / notification mark-read behind `kg:review`. The mutation responses return refreshed state (`status`, `resolvedAt`, `isRead`, `createdAt`, counts) so later workbench tasks can refresh in place instead of hard-resetting the page.

I added `AdminKnowledgeOpsWebTest` to cover contract shape, filter normalization, missing IDs, empty-state handling, 401/403 auth behavior, and idempotent resolve/read semantics. Because this is the first task in the slice and the slice verification contract already referenced a Playwright file, I also created `admin-web/tests/knowledge-ops.spec.ts` as a tracer-bullet spec so slice verification now fails on the missing Knowledge Ops UI surface itself instead of on “No tests found.”

## Verification

Passed the task-level verification command `backend\\mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminKnowledgeOpsWebTest`.

Ran the slice-level verification commands as well. `npm --prefix admin-web run build` passed. `backend\\mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=IngestionControllerTest,IngestionServiceIntegrationTest,KgControllerTest` failed for pre-existing app-api test expectations around unauthenticated `/api/v1/ingestion` and `/api/v1/kg` access (current runtime now returns 401/403). `npm --prefix admin-web run test:e2e -- knowledge-ops.spec.ts` now resolves a real spec file and fails at the intended future-workbench assertion (`knowledge-ingestion-queue` missing), which is the expected red state until subsequent UI tasks replace the placeholder page.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `backend\\mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminKnowledgeOpsWebTest` | 0 | ✅ pass | 31998ms |
| 2 | `backend\\mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=IngestionControllerTest,IngestionServiceIntegrationTest,KgControllerTest` | 1 | ❌ fail | 38800ms |
| 3 | `npm --prefix admin-web run build` | 0 | ✅ pass | 29487ms |
| 4 | `npm --prefix admin-web run test:e2e -- knowledge-ops.spec.ts` | 1 | ❌ fail | 89838ms |

## Deviations

Created `admin-web/tests/knowledge-ops.spec.ts` even though it was not listed in the task output block, because this is the first task in the slice and the slice-level verification contract already referenced that spec file. The added spec is a deliberate tracer bullet for the later UI tasks.

## Known Issues

`backend\\mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=IngestionControllerTest,IngestionServiceIntegrationTest,KgControllerTest` is currently red for reasons outside this task’s change set: the existing app-api tests still expect unauthenticated success paths on `/api/v1/ingestion` and `/api/v1/kg`, while current runtime/security behavior returns 401/403.

`npm --prefix admin-web run test:e2e -- knowledge-ops.spec.ts` is intentionally red after this task because the new tracer-bullet spec now asserts the real Knowledge Ops workbench containers (`knowledge-ingestion-queue`, `knowledge-contradiction-list`, `knowledge-notification-list`, `knowledge-inline-diagnostics`), and those UI surfaces are not implemented yet.

## Files Created/Modified

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeIngestionRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeKgRepository.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeOpsService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeOpsController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminKnowledgeOpsWebTest.java`
- `admin-web/tests/knowledge-ops.spec.ts`
