---
phase: "19"
plan: "05"
---

# T05: Added tracked Knowledge Ops browser proof and fixed admin-api compose runtime so upload/retry/resolve/read work end-to-end.

**Added tracked Knowledge Ops browser proof and fixed admin-api compose runtime so upload/retry/resolve/read work end-to-end.**

## What Happened

Implemented the final Knowledge Ops workbench write-path closure and canonical browser proof. On the UI side, `KnowledgeOpsPage` now surfaces terminal upload/retry feedback inline so operators can see when a queued mutation actually reaches `COMPLETED` or `FAILED` without losing selection or filters. For browser proof, added tracked valid/bad PDF fixtures under `admin-web/tests/fixtures/`, moved compose SQL knowledge fixture helpers into `admin-web/tests/helpers/admin-api.ts`, and rewrote `admin-web/tests/knowledge-ops.spec.ts` to prove success upload progression, bad-PDF terminal failure, retry back to success, KG mark-read/resolve, unread badge updates, and role-scoped visibility/deep-link `403` behavior against the real `/api/admin/knowledge/**` contract. During verification, compose-backed Playwright exposed that `admin-api` could not boot because the shared ingestion runtime now required `app.minio.*` and `app.embedding.*` wiring; fixed that by mirroring the shared runtime property mapping into `backend/admin-api/src/main/resources/application.yml` and giving `admin-api` the shared runtime env/dependencies in `docker-compose.yml`, then re-ran the full verification set to green.

## Verification

Passed the slice verification bar for this task by running `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminKnowledgeOpsWebTest`, `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=IngestionControllerTest,IngestionServiceIntegrationTest,KgControllerTest`, `npm --prefix admin-web run build`, and `npm --prefix admin-web run test:e2e -- knowledge-ops.spec.ts`. The final Playwright run passed both canonical Knowledge Ops tests in compose, proving real upload success, bad-PDF failure + retry recovery, KG resolve/mark-read, unread badge updates, and role-scoped visibility while keeping browser traffic on `/api/admin/knowledge/**`.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminKnowledgeOpsWebTest` | 0 | ✅ pass | 74200ms |
| 2 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=IngestionControllerTest,IngestionServiceIntegrationTest,KgControllerTest` | 0 | ✅ pass | 45500ms |
| 3 | `npm --prefix admin-web run build` | 0 | ✅ pass | 29800ms |
| 4 | `npm --prefix admin-web run test:e2e -- knowledge-ops.spec.ts` | 0 | ✅ pass | 115700ms |

## Deviations

Did not expand `ReasonRequiredConfirmation` into a generic knowledge-action modal because `KnowledgeOpsPage` already had local note entry and feedback surfaces; kept the UI change surgical. Also had to patch `backend/admin-api/src/main/resources/application.yml` plus `docker-compose.yml` so the shared ingestion runtime could boot in compose after the admin-api/runtime seam change from earlier tasks.

## Known Issues

None.

## Files Created/Modified

- `admin-web/src/pages/KnowledgeOpsPage.tsx`
- `admin-web/tests/helpers/admin-api.ts`
- `admin-web/tests/fixtures/knowledge-upload.pdf`
- `admin-web/tests/fixtures/knowledge-bad.pdf`
- `admin-web/tests/knowledge-ops.spec.ts`
- `backend/admin-api/src/main/resources/application.yml`
- `docker-compose.yml`
