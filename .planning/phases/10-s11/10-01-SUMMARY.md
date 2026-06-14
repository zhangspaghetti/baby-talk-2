---
phase: "10"
plan: "01"
---

# T01: Added a `distribution:read`-protected admin stats contract with bounded release/share read queries and backend proof.

**Added a `distribution:read`-protected admin stats contract with bounded release/share read queries and backend proof.**

## What Happened

Added `AdminDistributionStatsReadRepository` in `backend/common` as the shared JDBC read seam over `release_distribution_events` and `share_landing_events`, exposing bounded release overview/trend, share overview/trend/funnel, share→release handoff, and normalized recent `detailRows[]` without leaking share tokens or any extra identifiers. Added `AdminDistributionStatsProperties`, `AdminDistributionStatsService`, and `AdminDistributionStatsController` in `admin-api`; the service normalizes `range=7d|30d|90d` and `channel=all|stable|beta`, defaults to `30d`/`all`, fixes the detail limit at 200, surfaces applied filters plus a release-only channel scope note, and returns stable 400 envelopes for malformed filters. Wired the new repository in `AdminDataAccessConfiguration`, documented the truthful filter/redaction semantics in `docs/runbooks/m006-s11-distribution-stats.md`, and added `AdminDistributionStatsWebTest` covering 200/400/403/401, empty windows, preset-window boundaries, release-only channel filtering, and share raw sections remaining unfiltered by channel.

## Verification

Ran `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminDistributionStatsWebTest` (pass), `./backend/mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=DistributionPageWebTest,ShareLandingWebTest` (pass), and `npm --prefix admin-web run build` (pass, with the existing chunk-size warning unchanged). The slice-level Playwright coverage for `distribution-stats.spec.ts` remains T02 work because this task only shipped the backend contract and runbook.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminDistributionStatsWebTest` | 0 | ✅ pass | 38900ms |
| 2 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=DistributionPageWebTest,ShareLandingWebTest` | 0 | ✅ pass | 50500ms |
| 3 | `npm --prefix admin-web run build` | 0 | ✅ pass | 8800ms |

## Deviations

None.

## Known Issues

`npm --prefix admin-web run build` still emits the pre-existing Vite chunk-size warning for the 811.16 kB main JS bundle; T01 did not change frontend bundling.

## Files Created/Modified

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsReadRepository.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsProperties.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminDistributionStatsWebTest.java`
- `docs/runbooks/m006-s11-distribution-stats.md`
