# S11 — Research

**Date:** 2026-04-24

## Summary

S11 directly advances **R052** (admin web distribution/share stats workspace), supports **R053** (new admin MockMvc + browser proof), consumes **R051** (`distribution:read` already exists and should be reused, not redefined), and sits under the **R046** non-regression boundary (existing PostgreSQL-backed distribution/share/invite surfaces must stay intact).

The good news: the core data truth already exists. `app-api` is already writing coarse-grained audit rows into `release_distribution_events` and `share_landing_events`, the public/runtime contract tests for those surfaces are already green, and the existing SQL query packs already spell out the exact trend/funnel/detail cuts the admin page wants. From a planner’s perspective, S11 is **not** inventing a new analytics domain; it is exposing an existing one inside `admin-api` + `admin-web`.

What does **not** exist yet is the admin seam. `AdminPermissionCatalog` defines `distribution:read`, but `admin-api` has no distribution controller/service/read repository, `AdminDataAccessConfiguration` wires no distribution read model, and `admin-web` is still a mentor-specific protected shell with no stats route/client/page.

Two constraints matter up front:

1. **Channel truth is asymmetric.** `release_distribution_events` has `release_channel`; `share_landing_events` does **not**. So a top-level `channel` filter is truthful for release distribution (and for release handoff rows like `source=share_card`), but **not** for raw share-card page views / open-app / download-fallback events. A single merged “one funnel for everything” would be dishonest.
2. **Performance guardrail vs current schema is the real planning choice.** Milestone context says Distribution Stats should read pre-aggregated data and avoid turning the raw event tables into a hotspot, but the repo currently has **only raw event tables + query packs**, no summary table/materialized view. So the planner must decide explicitly whether S11 is:
   - a **strict guardrail** slice that adds a small rollup table + backfill + app-api dual-write, or
   - a **bounded read-only** slice that queries raw tables directly with hard time-range caps and explicit indexes.

Also note: the legacy S01/S02 runbooks and root-safe proof wrappers still point at pre-modular `backend/src/...` paths. They remain useful as **metric-definition sources**, but not as trustworthy file-check automation until updated.

## Recommendation

Applying **karpathy-guidelines** explicitly:

- **Think before coding:** make two decisions explicit before tasking:
  1. Are trend/funnel aggregates allowed to read raw tables with a hard cap, or must S11 add real rollups now?
  2. Is S11 shipping a truthful **release + share workspace** now, or silently expanding into the broader invite/household funnel from older requirements?
- **Simplicity first:** keep S11 **read-only** and focused on existing coarse-grained analytics. Do not bundle invite accept/revoke/household conversion analytics unless the slice is explicitly re-scoped.
- **Surgical changes:** extend the current shipped stack (`plain antd`, `useEffect`, relative `/api/admin/*`, `/api/admin/me` as truth source). Do **not** pull in ProComponents, React Query, axios refresh work, or a heavy charting library just to render one stats page.
- **Goal-driven:** lock the proof ladder now — (1) public distribution/share runtime still writes the truth rows, (2) `distribution:read` backend contract is correct, (3) browser filters are URL-backed and permission-guarded, (4) distribution-only admins do not land on the mentor-denied stub.

### Preferred plan shape

1. **Keep the admin contract truthful by separating surfaces in the response.**
   - Release distribution and share landing have different dimensions, so the API should not pretend they are one unified funnel.
   - A practical shape is one read-only admin endpoint for aggregates plus one for detail rows, both driven by the same URL filters.
   - Return separate sections such as:
     - `releaseOverview` / `releaseTrend` / `releaseFunnel`
     - `shareOverview` / `shareTrend` / `shareHandoff`
     - `detailRows[]` normalized with a `surface` field

2. **Reuse `distribution:read` end to end.**
   - Backend: `@PreAuthorize("hasAuthority('distribution:read')")`
   - Frontend: keep `/api/admin/me` as the live truth and gate the page with `hasPermission(me, 'distribution:read')`
   - No new RBAC vocabulary is needed.

3. **Use fixed range presets in the URL instead of arbitrary date picking for the first slice.**
   - Prefer `range=7d|30d|90d` + `channel=all|stable|beta` over a free-form RangePicker.
   - This keeps queries bounded, avoids introducing `dayjs`/date-serialization complexity, and matches the milestone’s “time-range cap” guardrail.

4. **If the performance guardrail is treated strictly, pay the small write-path cost now.**
   - Add a lightweight rollup/backfill migration for release/share aggregates.
   - Update `DistributionRepository` and `ShareLandingRepository` to dual-write raw + rollup rows transactionally.
   - Keep the raw tables for the recent detail table only.
   - This is the option I recommend if the team wants to honor the milestone text literally.

5. **Do only the smallest App.tsx generalization required.**
   - Today `/protected` is mentor-specific, so a `distribution:read`-only admin would land on the wrong page after login.
   - Do not reopen full S04 shell work; just add a tiny workspace map + protected landing resolver so `/protected` picks the first allowed workspace (`mentor:audit` first if present, otherwise `distribution:read`, otherwise the existing denied state).

6. **Avoid a heavy chart dependency unless the visual requirement proves non-negotiable.**
   - Current production build is already one 811 kB JS chunk.
   - Prefer `Card` + `Statistic` + `Table` + `Progress` / small SVG bars over adding `@ant-design/charts`/Recharts for this slice.

## Skills Discovered

Existing relevant skills already present:

- `spring-boot-engineer`
- `react-best-practices`
- `supabase-postgres-best-practices`
- `karpathy-guidelines`

Installed during research for downstream units:

- `ant-design` (`ant-design/antd-skill@ant-design`)
- `playwright-best-practices` (`currents-dev/playwright-best-practices-skill@playwright-best-practices`)

## Implementation Landscape

### Existing backend truth surfaces

- `backend/db-migration/src/main/resources/db/migration/V5__create_release_distribution_tables.sql`
  - Defines `release_distribution_events(event_id, entrypoint, release_channel, source, platform, result, failure_reason, created_at)`.
  - Indexes already exist on `(release_channel, source, result, created_at)`, `(platform, result, created_at)`, and `(created_at)`.
- `backend/db-migration/src/main/resources/db/migration/V6__create_share_landing_tables.sql`
  - Defines `share_landing_events(event_id, token, source, entrypoint, platform, result, failure_reason, created_at)`.
  - Indexes already exist on `(token, result, created_at)`, `(source, platform, result, created_at)`, and `(created_at)`.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/DistributionService.java`
  - Real public/runtime writer for release distribution audit rows.
  - Good source of route semantics (`download` vs `upgrade`) and allowed failure/result vocabulary.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/DistributionRepository.java`
  - Current write seam for `release_distribution_events`.
  - If rollups are introduced, this is one of the natural dual-write points.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/ShareLandingService.java`
  - Real public/runtime writer for share-card audit rows.
  - Also performs the share -> release handoff via `/download?source=share_card`.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/ShareLandingRepository.java`
  - Current write seam for `share_landing_events`.
  - The second natural dual-write point if rollups are introduced.
- `backend/app-api/src/main/resources/application.yml`
  - Important truth source for current dimension vocabularies:
    - release sources: `public_link`, `version_gate`, `share_card`, `caregiver_invite`, `manual_retry`
    - release channels: currently `stable`, `beta`
    - share sources: `latest_impact`, `continuity_recommendation`, `paired_progress`
  - This is why a single cross-surface source/channel model would drift.
- `backend/app-api/src/main/resources/sql/s01_release_distribution_queries.sql`
  - Already contains the exact daily trend / route health / source breakdown / recent-detail SQL cuts for release distribution.
- `backend/app-api/src/main/resources/sql/s02_share_landing_queries.sql`
  - Already contains the exact daily trend / share funnel / share->release bridge / recent-detail SQL cuts for share landing.
- `docs/runbooks/s01-release-distribution.md`
- `docs/runbooks/s02-growth-share.md`
  - Canonical redaction and metric-language sources.
  - **But the file-path references inside them are stale after modularization** (`backend/src/...` instead of `backend/app-api/src/...` and `backend/db-migration/src/...`). Treat them as semantics sources, not automation truth.

### Existing admin/web seams to extend

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminPermissionCatalog.java`
  - Already defines `DISTRIBUTION_READ = "distribution:read"`.
  - No new permission catalog work is needed.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
  - Existing explicit wiring seam for new plain JDBC read repositories from `backend/common`.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditService.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditReadRepository.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminMentorAuditWebTest.java`
  - Best pattern to copy for S11: read-only admin repo in `common`, service/controller in `admin-api`, focused SpringBootTest + MockMvc + Postgres contract test.
- `admin-web/src/App.tsx`
  - Current protected shell already refreshes `/api/admin/me` and treats backend permissions as truth.
  - But it is still hardcoded to mentor copy / mentor permission / mentor page, so this is the main file that needs a small generalization.
- `admin-web/src/lib/authClient.ts`
  - Already persists the admin session and preserves backend `permissions` after `/api/admin/me` refresh.
  - No auth model expansion is required for a read-only stats page.
- `admin-web/src/pages/MentorAuditPage.tsx`
  - Best frontend pattern to reuse:
    - URL-backed filters
    - explicit loading / empty / error states
    - no new global state library
- `admin-web/tests/mentor-audit.spec.ts`
  - Best E2E pattern to copy:
    - login through the real UI
    - seed runtime truth through real `app-api` requests
    - assert URL-backed filters and protected page behavior

### Missing seams S11 likely needs

For the **bounded read-only** path:

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsReadRepository.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsProperties.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsController.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminDistributionStatsWebTest.java`
- `admin-web/src/lib/distributionStatsClient.ts`
- `admin-web/src/pages/DistributionStatsPage.tsx`
- `admin-web/src/App.tsx` (workspace map + `/protected` landing resolver + new route)
- `admin-web/tests/distribution-stats.spec.ts`

If the planner chooses the **strict guardrail / rollup** path, also expect:

- `backend/db-migration/src/main/resources/db/migration/V18__create_distribution_stat_rollups.sql`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/DistributionRepository.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/ShareLandingRepository.java`
- focused app-api tests proving raw + rollup writes stay aligned

### Response-shape guidance

A truthful normalized detail row can be shaped as:

- `surface` (`release_distribution` | `share_landing`)
- `createdAt`
- `channel` (nullable)
- `source`
- `entrypoint`
- `platform`
- `result`
- `failureReason`

Do **not** include `share_landing_events.token` in the general admin detail table. The page only needs coarse-grained reporting, and the older runbooks already treat token as a narrow troubleshooting surface, not default UI output.

### Optional later-expansion seam (do not silently pull into S11)

- `backend/app-api/src/main/resources/sql/s03_caregiver_invite_queries.sql`
- `docs/runbooks/s03-caregiver-invite.md`
- `caregiver_invite_events` / `release_distribution_events(source=caregiver_invite)`

These existing invite analytics surfaces can support a future broader `distribution/share/invite` report, but the current S11 roadmap text is narrower. Do not silently balloon this slice into household accept/revoke conversion analytics.

## Natural Seams / Task Order

1. **Resolve truth and scope first**
   - Decide whether S11 is allowed to read raw tables directly with hard caps, or must add rollups now.
   - Decide whether S11 is release+share only (recommended) or also includes the older invite funnel.
   - Decide whether channel filtering should be documented as release-only for some cards, instead of pretending share rows are channel-aware.

2. **Build the backend contract before touching UI**
   - Add `AdminDistributionStatsReadRepository` in `backend/common`.
   - Add admin-api properties/service/controller in `com.zhangspaghetti.babytalk.admin.distribution`.
   - Normalize range/channel inputs there, not in the page.
   - If the strict rollup path is chosen, do the migration/backfill + app-api dual-write **before** the admin read repo, otherwise the admin contract will be built on a truth surface that the milestone explicitly said not to depend on.

3. **Add focused MockMvc proof next**
   - Copy the `AdminMentorAuditWebTest` harness style.
   - Seed `release_distribution_events` and `share_landing_events` directly with JDBC fixtures in the admin-api test; this is fine for the admin contract layer.
   - Prove at least:
     - `distribution:read` => 200
     - missing permission => 403
     - disabled principal => 401 `admin_account_disabled`
     - bounded range validation / limit validation
     - stable empty 200 with zero rows
     - channel filtering affects release rows without inventing channel on share rows

4. **Then add the stats page + the smallest shell generalization**
   - Keep frontend data fetching page-local, matching `MentorAuditPage.tsx`.
   - Put `range` + `channel` in URL query params so reload/back-navigation stay deterministic.
   - Add only the smallest App.tsx workspace map needed so `/protected` can resolve to the first allowed workspace.
   - Do not turn this into a full S04 shell rewrite.

5. **Finish with browser integration**
   - Use Playwright `request` against real public `app-api` endpoints to create the data truth:
     - `GET /download`
     - `GET /download/redirect`
     - `POST /api/v1/share-links`
     - `GET /share/{token}`
     - `GET /share/{token}/download`
   - Then log into admin-web and verify the stats page reflects those events under the same filters.

## Verification

### Fresh research-time evidence

- `npm --prefix admin-web run build` ✅ pass
  - Current production build already ships a single `assets/index-Cq0--C8_.js` chunk at **811.16 kB** (256.75 kB gzip). This is the strongest concrete reason to avoid adding a heavy charting library casually.
- `./backend/mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=DistributionPageWebTest,ShareLandingWebTest` ✅ pass
  - Fresh research-time proof that the underlying public distribution/share runtime contracts are still green on the modularized app-api path, with schema closure at **v17 / appliedCount=15**.

### Useful S11 verification ladder

1. **If S11 adds a migration / rollup path**
   - `./backend/mvnw.cmd -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest`
2. **Public data truth still works**
   - `./backend/mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=DistributionPageWebTest,ShareLandingWebTest`
   - If invite is explicitly pulled into scope, add `CaregiverInviteLandingWebTest,CaregiverInviteApiWebTest` too.
3. **New admin contract**
   - `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminDistributionStatsWebTest`
4. **Frontend build smoke**
   - `npm --prefix admin-web run build`
5. **Browser integration**
   - `npm --prefix admin-web run test:e2e -- distribution-stats.spec.ts`

### Truthful seed strategy for browser tests

- Prefer creating stats data through the real public/runtime endpoints instead of DB fixtures in Playwright.
- Suggested seed pattern:
  - hit `/download?...` for release `page_view`
  - hit `/download/redirect?...` for release `redirect`
  - create a share link through `POST /api/v1/share-links`
  - open `/share/{token}` for share `page_view`
  - open `/share/{token}/download?platform=android` for share `download_fallback` plus release `source=share_card` handoff
- This keeps the admin stats page tied to the exact runtime semantics the app-api tests already prove.

## Don't Hand-Roll

| Problem | Existing Solution | Why Use It |
|---|---|---|
| release metric vocabulary | `s01_release_distribution_queries.sql` + `DistributionPageWebTest` | already defines truthful route/result/failure semantics |
| share metric vocabulary | `s02_share_landing_queries.sql` + `ShareLandingWebTest` | already defines truthful funnel/handoff semantics |
| admin read-repo/module split | `backend/common` plain JDBC repo + `AdminDataAccessConfiguration` wiring | matches S03/S10 and avoids cross-module runtime coupling |
| browser permission truth | `/api/admin/me` + `hasPermission()` | prevents the page from guessing off local roles |
| URL-backed filter pattern | `admin-web/src/pages/MentorAuditPage.tsx` | already proves reload/back-navigation-friendly page state |
| Playwright harness | current `playwright.config.ts`, global setup, and `mentor-audit.spec.ts` style | avoids inventing a second E2E stack |

## Constraints

- `share_landing_events` has **no `release_channel` column**. Any channel-aware share chart/funnel would be synthetic unless it is specifically about the release handoff rows (`source=share_card`) that land in `release_distribution_events`.
- `share_landing_events` includes `token`, but S11 should keep the workspace coarse-grained. Default detail rows should not expose raw tokens.
- `release_distribution_events` and `share_landing_events` have different `source`, `entrypoint`, and `result` vocabularies. The UI must keep that visible instead of flattening them into one fake taxonomy.
- Current `admin-web` is still plain `antd` + `react-router` + local `useEffect` data loading. There is no ProComponents, axios interceptor, React Query, or shared shell framework to lean on.
- Current `/protected` landing is mentor-specific. Without a tiny landing resolver, a `distribution:read`-only admin will sign in and land on the wrong page.
- Legacy S01/S02 runbooks and wrapper scripts still reference pre-module `backend/src/...` paths. Do not trust those file-check paths blindly.
- Public audit writes are best-effort today. If S11 introduces rollups, raw-event + rollup-row writes must succeed/fail together to avoid silent drift.

## Risks or Gotchas

- **The “one workspace” wording can push the implementation toward a dishonest merged funnel.** Resist that. The available truth supports adjacent release/share sections better than one grand funnel.
- **The milestone performance guardrail and the current schema do not agree yet.** If the team wants to honor the guardrail literally, S11 is not purely read-only; it needs a migration/backfill + app-api dual-write seam.
- **If the strict rollup path is chosen, backfill matters.** Without backfilling existing raw rows during migration, the new admin stats page will show an empty or partial history after deploy.
- **Bundle-size pressure is real.** The current admin-web build already warns at 811 kB. Adding a chart dependency or a large shell refactor inside S11 will compound this immediately.
- **Path drift can waste planner context.** The old S01/S02 docs/tools are still useful for definitions, but not for literal modularized file paths.
- **If S11 does nothing about `/protected`, it will look broken for limited admins.** This is small but important UX debt to pay inside the slice.
