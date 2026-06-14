---
phase: "11"
plan: "01"
---

# T01: Locked overview per-domain read isolation and unified sinceEventId validation, with MockMvc proofs for cached degradation and metadata-only replay.

**Locked overview per-domain read isolation and unified sinceEventId validation, with MockMvc proofs for cached degradation and metadata-only replay.**

## What Happened

I kept the backend seam surgical and within the four-domain S12 boundary. In `AdminOverviewService`, the overview read transaction template is now explicitly `readOnly + REQUIRES_NEW`, which locks in per-domain transaction isolation so each repository’s `set local statement_timeout` can only degrade the timed-out domain instead of leaking across sibling reads or any future outer transaction. In `AdminOverviewController`, I moved `sinceEventId` validation into the controller helper so both the query parameter and `Last-Event-ID` header reject blank and overlong values with the same `invalid_overview_since_event_id` contract. I then expanded `AdminOverviewWebTest` to cover the fixed four-domain envelope under partial visibility, explicit 403s for non-overview permissions, unknown stream params, overlong replay ids, `overview_snapshot_unavailable` when no cached selection exists, cached timeout degradation, and SSE replay transport payloads that expose reconnect metadata without replaying domain data or sensitive tokens.

## Verification

`./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am -DskipTests test-compile` passed, confirming the updated admin-api code and tests compile. `npm --prefix admin-web run build` passed. The task-level and slice-level Docker-backed checks did not reach product assertions in this environment: `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminOverviewWebTest` failed during Testcontainers startup because Docker Desktop returned HTTP 500 for the desktop-linux engine, `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts overview-control-plane.spec.ts` failed in Playwright global setup when `docker compose up -d --build` hit the same Docker API 500, and `dart run tool/verify_m006_s12_control_plane_freshness.dart` failed at its browser proof-pack step for the same reason after re-running a successful admin-web build.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am -DskipTests test-compile` | 0 | ✅ pass | 13700ms |
| 2 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminOverviewWebTest` | 1 | ❌ fail | 21700ms |
| 3 | `npm --prefix admin-web run build` | 0 | ✅ pass | 30200ms |
| 4 | `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts overview-control-plane.spec.ts` | 1 | ❌ fail | 99300ms |
| 5 | `dart run tool/verify_m006_s12_control_plane_freshness.dart` | 1 | ❌ fail | 129200ms |

## Deviations

None.

## Known Issues

Docker-backed verification is currently blocked on this machine: `docker version`, Testcontainers, and Playwright compose setup all receive HTTP 500 responses from the Docker Desktop `desktop-linux` engine before app code starts. No code-level assertion failures were observed beyond that environment blocker.

## Files Created/Modified

- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/overview/AdminOverviewService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/overview/AdminOverviewController.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminOverviewWebTest.java`
