# S12 Research — Multi-domain freshness + boss strip + SSE fallback

## Summary

- This is no longer greenfield. The repo already contains a candidate S12 implementation across backend overview contract, frontend control plane, Playwright proof, runbook, and verifier.
- Planning should therefore be **closure-oriented**: audit the existing seams, resolve one route/permission inconsistency, and stabilize proof. Do **not** design a second realtime bus or a KPI dashboard.
- This slice primarily advances **R052** (truthful admin-web Overview over knowledge/mentor/distribution domains) and secondarily **R053** (focused backend/browser proof for overview freshness/fallback).

## Prior context / durable constraints

- Memory confirms the intended split: **bounded summary contract + metadata-only transport stream**. The UI gets multi-domain freshness and transport state without broadcasting raw mentor or distribution payloads over realtime channels.
- Because `admin-api` is stateless Bearer-auth, browser-native `EventSource` is not a workable seam here; **`fetch` + SSE parsing** is the established pattern.
- Per-domain reads must stay isolated. Do **not** wrap all overview domain queries in one JDBC transaction, or a single Postgres statement timeout will abort the whole transaction instead of degrading one domain.

## Skills Discovered

- Activated: `karpathy-guidelines`.
- Already-installed relevant skills: `react-best-practices`, `observability`, `spring-boot-engineer`, `springboot-security`.
- No extra `npx skills add` work was needed; the core technologies already have relevant installed skills.

## Existing implementation landscape

### Backend overview contract already exists

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/overview/AdminOverviewReadRepository.java`
  - Delegates overview reads to the existing S06/S10/S11 repositories instead of inventing a new read model.
  - Emits only four domains: `knowledge_ingestion`, `knowledge_kg`, `mentor_audit`, `distribution`.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/overview/AdminOverviewService.java`
  - Runs each visible domain in its own read-only `TransactionTemplate.execute(...)`.
  - Computes `queue`, `attention`, `allClear`, freshness windows, `nextAction`, and cached-snapshot fallback.
  - Degrades timed-out domains to `degraded` using cached state and marks backend transport `polling_required`.
  - Fails loud with `overview_snapshot_unavailable` if a timeout happens before any last-good snapshot exists for the current permission selection.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/overview/AdminOverviewStreamService.java`
  - SSE is **transport-only**, not a domain-payload stream.
  - Sends `transport` + `heartbeat` events and tracks `eventId`, `connectionCount`, `reconnectCount`, `activeSubscriberCount`, `replayed`.
  - `sinceEventId` only affects reconnect/replay metadata; it does **not** replay a history of domain changes.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/overview/AdminOverviewController.java`
  - Exposes `GET /api/admin/overview/summary` and `GET /api/admin/overview/stream`.
  - Rejects unknown query params; only `sinceEventId` is allowed on the stream.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
  - Wires `AdminOverviewReadRepository` from the already-shipped knowledge / mentor / distribution read repositories.

### Frontend control plane already exists

- `admin-web/src/lib/overviewClient.ts`
  - Parses the full overview contract and requires all four domain keys to exist even when hidden.
  - Uses `fetch(... Authorization: Bearer ...)` + a custom SSE parser + refresh-token retry path.
  - This matches the intended auth seam: no native `EventSource`.
- `admin-web/src/pages/OverviewPage.tsx`
  - Implements the thin boss strip / control plane: transport mode, source (`streaming` vs polling fallback), last good snapshot, diagnostics, recovery actions.
  - Keeps last-good summary visible during stream failure or malformed-summary refresh failure.
  - Renders only visible domain cards; hidden domains stay fail-closed.
- Shell / landing integration is already wired through:
  - `admin-web/src/app/routes.tsx`
  - `admin-web/src/app/access.ts`
  - `admin-web/src/app/default-landing.ts`
  - `admin-web/src/App.tsx`
  - `admin-web/src/layout/AdminLayout.tsx`
  - Super admins and multi-domain admins land on `/overview`; single-domain admins land on their own workspace.

### Proof and docs already exist

- Backend proof: `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminOverviewWebTest.java`
  - Covers summary aggregation, permission visibility, invalid query params, cached-snapshot degradation on timeout, malformed payload rejection, and reconnect-count surfacing.
- Browser proof:
  - `admin-web/tests/overview-control-plane.spec.ts`
  - `admin-web/tests/auth-and-rbac.spec.ts`
  - Covers super-admin landing, stale-domain rendering, offline -> polling fallback -> recovery, and malformed summary refresh while preserving the last-good snapshot.
- Verifier + docs:
  - `tool/verify_m006_s12_control_plane_freshness.dart`
  - `docs/runbooks/m006-s12-control-plane-freshness.md`
- Downstream coupling already exists:
  - `tool/verify_m006_s13_demo_path.dart`
  - `tool/verify_m006_s14_release_closure.dart`
  - S12’s verifier path is already referenced by later slice tooling/docs, so renaming it will ripple into S13/S14.

## Natural seams for planning

1. **Backend overview control-plane contract**
   - Files: `AdminOverviewReadRepository.java`, `AdminOverviewService.java`, `AdminOverviewStreamService.java`, `AdminOverviewController.java`, `AdminDataAccessConfiguration.java`
   - Scope: preserve summary+transport split, per-domain timeout isolation, fail-closed permission visibility, metadata-only stream.
2. **Frontend boss strip + fallback UX**
   - Files: `overviewClient.ts`, `OverviewPage.tsx`, route/access/landing/shell files
   - Scope: preserve fetch-SSE auth path, truthful `live` / `polling` / `recovered` strip, last-good snapshot preservation, fail-closed hidden domains.
3. **Proof / release seam**
   - Files: `AdminOverviewWebTest.java`, `overview-control-plane.spec.ts`, `auth-and-rbac.spec.ts`, `playwright.global-setup.ts`, `tool/verify_m006_s12_control_plane_freshness.dart`, `docs/runbooks/m006-s12-control-plane-freshness.md`
   - Scope: stabilize verification and preserve downstream S13/S14 references.

## Key risks / unknowns

- **Route-permission mismatch needs an explicit decision**
  - `admin-web/src/app/routes.tsx` currently includes `users:read` in Overview route permissions.
  - `access.ts` uses OR semantics (`matchedPermissions.length > 0`), so a `users:read`-only admin can deep-link to `/overview` in the browser.
  - Backend overview API only authorizes `rag:read | kg:read | mentor:audit | distribution:read`, and the summary contract only emits four non-user domains.
  - Planner should decide whether to:
    - remove `users:read` from the Overview route metadata, or
    - deliberately keep browser-side access broader and accept backend 403 on direct `/overview`.
  - Do **not** leave this implicit; it is the clearest scope/contract mismatch I found.
- **Do not mistake the stream for a full replay/event bus**
  - `sinceEventId` only marks reconnect/replay metadata; it does not replay missed domain updates.
  - The established pattern is summary snapshot + transport metadata, not a generic realtime pipeline.
- **Current verifier is frontend-heavy**
  - `tool/verify_m006_s12_control_plane_freshness.dart` only runs `admin-web build` + Playwright.
  - It does **not** run `AdminOverviewWebTest`.
  - If the planner wants a single-command slice replay, that verifier is the obvious place to extend — but per Karpathy’s simplicity rule, only do it if the extra backend leg is truly needed; otherwise keep backend proof separate.
- **Compose/browser verification is currently environment-red**
  - Fresh run of `dart run tool/verify_m006_s12_control_plane_freshness.dart` failed before Playwright assertions.
  - `admin-web build` passed, then Playwright global setup failed inside `docker compose up -d --build`.
  - Failure signature:
    - Docker Desktop Linux engine returned 500 on compose container listing.
    - concurrent Java image builds for `app-api` / `admin-api` / `db-migration` hit JVM `SIGBUS`.
    - global setup threw from `admin-web/playwright.global-setup.ts`.
  - This looks like a Docker/WSL/build-environment problem, not an Overview contract assertion failure.
- **Build warning remains**
  - Fresh build still warns on very large chunks (`UsersPage` ~799 kB, main index ~1.12 MB). This is pre-existing and not S12-specific.

## Don’t hand-roll

- Don’t replace the current `fetch` + SSE parser with a second auth pathway or a native `EventSource` hack.
- Don’t widen S12 into a generic realtime event bus or raw payload stream.
- Don’t duplicate knowledge / mentor / distribution SQL into a second overview-specific store when the current repo already composes the existing read repositories.
- Don’t redesign Overview into an equal-weight KPI dashboard; the current control-plane/boss-strip framing matches the slice brief much better.

## Recommendation

- Treat S12 as a **closure slice on top of an already-landed candidate implementation**, not as greenfield.
- Plan smallest-first, per Karpathy:
  1. Audit/resolve the Overview route-permission mismatch.
  2. Keep the existing summary+transport architecture; do **not** widen into a second dashboard, raw payload stream, or generic SSE bus.
  3. Reuse the existing verifier/runbook paths because S13/S14 already depend on them.
  4. Spend proof effort on the current red edge: compose build stability in the Playwright boot path.
- If an executor touches backend logic, keep every change surgical:
  - preserve per-domain `TransactionTemplate` calls
  - preserve metadata-only stream contract
  - preserve the four-domain envelope shape and fail-closed hidden domains

## Verification

- **Backend contract (fresh run)**
  - `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminOverviewWebTest`
  - Completed successfully locally. Logs showed the expected timeout-path warning inside the degradation test, followed by transport transition to `polling_required`.
- **Frontend build (fresh run)**
  - Ran as part of `dart run tool/verify_m006_s12_control_plane_freshness.dart`
  - Passed.
- **Canonical verifier (fresh run)**
  - `dart run tool/verify_m006_s12_control_plane_freshness.dart`
  - Failed at step `overview browser proof pack`.
  - Immediate blocker was `docker compose up -d --build` in `admin-web/playwright.global-setup.ts`, not a browser assertion.

## Planner notes

- Because the code already exists, the main decomposition question is **what still needs to change** versus **what only needs proof / summary**.
- The safest likely task split is:
  - **T01**: overview backend + route-contract audit (permission mismatch, no architecture rewrite)
  - **T02**: browser proof boot-path stabilization / verifier adjustment
  - **T03**: slice summary + proof/runbook closure once verification turns green
