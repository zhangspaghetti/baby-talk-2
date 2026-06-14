---
phase: "19"
plan: "03"
---

# T03: Added direct admin-api ingestion upload/retry endpoints on `/api/admin/knowledge/**` with shared runtime reuse, truthful failure envelopes, and focused MockMvc coverage.

**Added direct admin-api ingestion upload/retry endpoints on `/api/admin/knowledge/**` with shared runtime reuse, truthful failure envelopes, and focused MockMvc coverage.**

## What Happened

I imported the shared ingestion runtime into `admin-api` through `AdminDataAccessConfiguration` instead of proxying writes back through `app-api`, wiring `IngestionService`, `IngestionRepository`, async execution, embedding config, and MinIO properties directly from the shared seam. This kept the browser contract pinned to `/api/admin/knowledge/**` while reusing the existing in-process queue state machine.

I extended `AdminKnowledgeOpsController` and `AdminKnowledgeOpsService` with `rag:write`-guarded `POST /api/admin/knowledge/ingestion/upload` and `POST /api/admin/knowledge/ingestion/jobs/{jobId}/retry`. Upload now accepts real multipart form data without forcing JSON content types, returns a 202 body with `jobId`, `status`, `updatedAt`, `errorMessage`, and `canRetry`, and fails with standard admin envelopes for missing/empty files, invalid UUIDs, shared upload failures, and non-FAILED retry attempts. The failure envelope stays truthful by surfacing the persisted queue state (`FAILED`, latest `errorMessage`, retryability) instead of fabricating a generic success response.

I expanded `AdminKnowledgeOpsWebTest` to cover successful upload completion, a parse failure followed by in-place retry to `COMPLETED`, shared runtime upload failure envelopes, 401/403 write protection, missing/empty multipart input, invalid retry UUIDs, and 409 retry-on-non-FAILED behavior. To keep the test module self-contained, I added a tracked `knowledge-upload.pdf` fixture under `backend/admin-api/src/test/resources/` and mocked MinIO/vector-store edges while letting the shared ingestion seam drive the real state transitions. I also preserved the existing `app-api` regression contract by keeping the new typed dispatch exception message compatible with the prior integration test assertion.

## Verification

Ran the task-level verification command with the Windows-safe wrapper entrypoint `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminKnowledgeOpsWebTest`; it passed and exercised the new admin upload/retry contract, including success, failure, retry, and auth/authorization paths.

Ran the shared-seam regression command `backend/mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=IngestionControllerTest,IngestionServiceIntegrationTest,KgControllerTest`; it passed after preserving the legacy MinIO-failure message substring inside the new typed dispatch exception.

For slice-level verification at this intermediate task, the backend checks now pass; the remaining `admin-web` build and Playwright browser proof are intentionally left to T04/T05, where the actual UI workbench and e2e flow are introduced.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminKnowledgeOpsWebTest` | 0 | ✅ pass | 31439ms |
| 2 | `backend/mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=IngestionControllerTest,IngestionServiceIntegrationTest,KgControllerTest` | 0 | ✅ pass | 46510ms |

## Deviations

Added a tracked admin-api PDF fixture (`backend/admin-api/src/test/resources/knowledge-upload.pdf`) instead of reaching across modules into `app-api` test resources, and corrected the local Windows verification commands from `./backend/mvnw` to `backend/mvnw.cmd` in the task/slice plan artifacts. No scope or contract change was introduced.

## Known Issues

None. The remaining slice-level frontend build and e2e verification steps are downstream planned work for T04/T05, not regressions discovered in T03.

## Files Created/Modified

- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeOpsController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeOpsService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminKnowledgeOpsWebTest.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionService.java`
- `backend/admin-api/src/test/resources/knowledge-upload.pdf`
- `.gsd/milestones/M006/slices/S06/tasks/T03-PLAN.md`
- `.gsd/milestones/M006/slices/S06/S06-PLAN.md`
