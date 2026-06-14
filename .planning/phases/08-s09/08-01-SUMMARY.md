---
phase: "08"
plan: "01"
---

# T01: Added the admin Overview summary and SSE transport contracts with timeout-aware cached fallback

**Added the admin Overview summary and SSE transport contracts with timeout-aware cached fallback**

## What Happened

Implemented the missing Overview runtime seam across `backend/common` and `backend/admin-api`. In `common`, I added `AdminOverviewReadRepository` plus focused overview summary methods on the existing ingestion, KG, mentor, and distribution read repositories so the new contract reuses current truth sources instead of inventing rollups or placeholder counts. In `admin-api`, I added `AdminOverviewService`, `AdminOverviewController`, and `AdminOverviewStreamService` to expose `/api/admin/overview/summary` and `/api/admin/overview/stream`. The summary contract now returns four stable domain envelopes (`knowledge_ingestion`, `knowledge_kg`, `mentor_audit`, `distribution`) with permission-derived visibility, per-domain freshness state/timestamp, bounded queue counts, and operator-safe next-action routes. The stream contract intentionally emits transport metadata only (mode, degraded reason, last successful snapshot timestamp, connection/reconnect counters) so T02 can build live/polling/recovered UI without leaking raw mentor/share payloads or widening the public `admin-api` boundary.

For failure handling, I used a `TransactionTemplate` per visible domain fetch so PostgreSQL `statement_timeout` can degrade only the timed-out domain instead of aborting the whole summary transaction. Successful domain snapshots are cached in-memory; if a later domain fetch times out, the service serves the last good snapshot for that domain, marks the domain freshness as `degraded`, keeps the last successful selection snapshot timestamp visible, and flips transport mode to `polling_required`. Non-timeout storage errors still fail closed. I also wired the new common repository bean into `AdminDataAccessConfiguration` and added `AdminOverviewWebTest` to cover happy-path aggregation, permission-derived visibility / fail-closed auth, timeout fallback, malformed payload rejection, and reconnect counter visibility.

## Verification

Ran the task-specific backend contract suite and the required regression suite from the task plan. `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminOverviewWebTest` passed with 4 tests covering multi-domain aggregation, permission visibility, timeout fallback, malformed visible-domain payload rejection, and reconnect counter visibility. Then `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminKnowledgeOpsWebTest,AdminMentorAuditWebTest,AdminDistributionStatsWebTest` passed with 20 total tests (8 + 7 + 5), confirming the new overview summary methods and added statement-timeout seams did not regress the existing knowledge, mentor, or distribution admin contracts.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminOverviewWebTest` | 0 | ✅ pass | 38700ms |
| 2 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminKnowledgeOpsWebTest,AdminMentorAuditWebTest,AdminDistributionStatsWebTest` | 0 | ✅ pass | 44500ms |

## Deviations

Minor local adaptation only: instead of querying raw admin tables directly from `admin-api`, I added bounded overview summary methods to the existing `common` read repositories and wrapped each visible-domain fetch in its own read-only transaction so timeout fallback can stay truthful. This preserved the task’s reuse/boundary requirement rather than changing scope.

## Known Issues

None.

## Files Created/Modified

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/overview/AdminOverviewReadRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeIngestionRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeKgRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditReadRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsReadRepository.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/overview/AdminOverviewService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/overview/AdminOverviewController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/overview/AdminOverviewStreamService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminOverviewWebTest.java`
