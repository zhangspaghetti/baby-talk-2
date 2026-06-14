# S04 — Research

**Date:** 2026-04-24

## Summary

`admin-web/` already exists in this worktree. S04 is **not** greenfield. The shipped baseline is a thin S01 browser proof: React 18 + Vite 5 + antd 5 + react-router + Playwright + nginx/Docker, with real login against `admin-api` and relative `/api/admin` calls. Dev proxy and nginx proxy are already aligned, and `docker-compose.yml` already exposes `:3000`.

What exists is still far short of the requested S04 shell. Missing today: `@ant-design/pro-components` / `@ant-design/icons`, axios instance with refresh interceptor, explicit TS config, ProLayout-based IA/navigation, 403 page, role/permission route metadata, default landing resolver, module placeholder pages, and Warm Paper Kindness tokenization. The current UI hardcodes a purple gradient and `colorPrimary: '#5b21b6'`, which conflicts with the milestone’s locked admin design constraints.

Planner caution: artifact drift is real. `M006-ROADMAP.md` defines S04 as the auth shell/login slice, but `.gsd/milestones/M006/S04-TASKS.md` is stale and describes a Users disable-account slice. Also S03/S04 are currently fuzzy at the auth/RBAC boundary: backend auth returns roles only, with no permission dictionary/API yet. Real hidden-nav/403-by-permission proof needs either a tiny S03 prerequisite or an explicit partial-proof decision.

## Recommendation

Applying karpathy-guidelines explicitly:

- **Think before coding:** reconcile plan drift first (`ROADMAP` vs `S04-TASKS.md`) and do not silently substitute roles for permissions.
- **Simplicity first:** keep S04 to shell/login/refresh/403/placeholder module entries. Explicitly defer `QueuePageShell`, `DetailContainer`, `ReasonRequiredConfirmation`, queue/detail behavior, and domain CRUD.
- **Surgical changes:** evolve the existing `admin-web/` + proxy + docker wiring. Do not replace Vite with Umi or create a second frontend runtime.
- **Goal-driven:** define four exit proofs now — unauthenticated redirect, successful login to role-aware home placeholder, expired access token single refresh+replay, authenticated unauthorized route to explicit 403.

Preferred plan shape:

1. Treat current `admin-web` as the seed, not throwaway.
2. Keep browser API calls relative to `/api/admin/*` and reuse S02/S01 token lifecycle exactly: single refresh/replay, terminal local sign-out on refresh failure, old bearer invalid after refresh/logout.
3. Introduce a route catalog as the single source of truth for:
   - path / title / icon / top-level module grouping
   - nav visibility
   - required roles/permissions
   - default landing eligibility
4. Use `ProLayout` directly inside Vite/React; do not adopt Umi.
5. If the planner needs truthful hidden-nav/403 proof in S04, pull forward a tiny backend prerequisite from S03: at least one limited admin fixture or permission-bearing `me` contract. Without that, S04 can still ship auth shell/refresh/403 infrastructure, but the permission proof is only scaffolded, not end-to-end.

## Implementation Landscape

### Key Files to Keep and Extend

- `admin-web/package.json` — current frontend workspace with `dev/build/test:e2e`; add `@ant-design/pro-components`, `@ant-design/icons`, `axios`; no ProComponents or axios yet.
- `admin-web/src/App.tsx` — current login/protected-stub router. Good place to shrink into router composition, but not to keep growing as one file.
- `admin-web/src/main.tsx` — current global `ConfigProvider`; currently sets `colorPrimary: '#5b21b6'`, which should be replaced by Warm Paper Kindness admin tokens.
- `admin-web/src/lib/authClient.ts` — current fetch-based auth seam + localStorage session. Reuse its contract types, but split raw auth endpoints from the future axios/interceptor client.
- `admin-web/vite.config.ts` — already standardizes local dev on `:3000` and proxies `/api` + `/actuator` to `http://127.0.0.1:8081`.
- `admin-web/nginx.conf` — already proxies `/api/` and `/actuator/` to `admin-api:8081` and serves SPA fallback.
- `docker-compose.yml` — already exposes `admin-web` on `3000:80` and keeps `admin-api` on `8081`; no new frontend container topology is needed for S04.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthController.java` — stable `/api/admin/auth/login`, `/refresh`, `/logout`, `/me` contract.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthService.java` — stable login/refresh/logout semantics and `validateAccessToken()` guard.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminSecurityConfig.java` — stable 401/403 JSON semantics and access-token validation against refresh-row lifecycle.
- `backend/db-migration/src/main/resources/db/migration/V15__create_admin_auth_tables.sql` — admin auth tables exist, but permissions tables do not.
- `DESIGN.md` + `.gsd/milestones/M006/M006-CONTEXT.md` — authoritative IA/theme constraints; current admin-web violates them visually.
- `.gsd/milestones/M006/S04-TASKS.md` — stale. Do not plan against it without reconciling.

### Missing Files / Seams S04 Likely Needs

Minimal suggested structure, without overcommitting later page primitives:

- `admin-web/tsconfig.json`
- `admin-web/tsconfig.node.json`
- `admin-web/src/app/theme.ts`
- `admin-web/src/app/routes.tsx`
- `admin-web/src/app/access.ts`
- `admin-web/src/app/default-landing.ts`
- `admin-web/src/auth/session-store.ts`
- `admin-web/src/auth/auth-api.ts`
- `admin-web/src/auth/http-client.ts`
- `admin-web/src/auth/auth-provider.tsx`
- `admin-web/src/layout/AdminLayout.tsx`
- `admin-web/src/pages/LoginPage.tsx`
- `admin-web/src/pages/ForbiddenPage.tsx`
- `admin-web/src/pages/OverviewPage.tsx`
- `admin-web/src/pages/UsersPage.tsx`
- `admin-web/src/pages/KnowledgeOpsPage.tsx`
- `admin-web/src/pages/MentorSafetyPage.tsx`
- `admin-web/src/pages/DistributionStatsPage.tsx`
- `admin-web/tests/auth-and-rbac.spec.ts`

Notes:

- `App.tsx` can remain as the root entry, but it should mostly delegate to router/provider composition.
- Placeholder module pages are enough for S04; do not pull business tables/forms into this slice.
- Keep `LoginPage` outside `ProLayout`; keep `403` inside the authenticated shell.

### Concrete Config/Dependency Work

- `package.json`
  - add `@ant-design/pro-components`
  - add `@ant-design/icons`
  - add `axios`
- TypeScript
  - add explicit `tsconfig.json` before route/meta/types grow
- Routing
  - switch from hardcoded `/protected` to named IA routes: `/overview`, `/users`, `/knowledge-ops`, `/mentor-safety`, `/distribution-stats`, `/403`, `/login`
- Theme
  - replace current purple gradient / purple primary with Warm Paper admin token mapping from `DESIGN.md`
  - keep restrained neutral surfaces; no KPI-card dashboard shell
- Auth client
  - keep current raw auth contract paths
  - move all non-auth API calls to one axios instance with:
    - request bearer injection
    - single in-flight refresh
    - single replay of the failed request
    - terminal local sign-out + redirect on refresh failure
- Access model
  - build `RouteSpec` metadata now with `requiredRoles` and/or `requiredPermissions`
  - planner should avoid baking permission strings into components or menu rendering code directly

### Clean Boundary Between S04 and S05+

S04 should include now:

- workspace/tooling baseline for a real admin SPA
- theme seed aligned to Warm Paper Kindness admin sub-theme
- `ProLayout` shell + IA placeholder pages
- login/logout/auth persistence
- axios refresh interceptor and session lifecycle handling
- auth guard vs access guard split
- 403 page
- route metadata and nav filtering hook
- role-aware default landing resolver
- placeholder pages that downstream slices can replace without touching shell/auth plumbing

Clearly defer to S05+:

- `QueuePageShell`
- `DetailContainer`
- `ReasonRequiredConfirmation`
- list/query/filter synchronization for real domain pages
- deep-link detail restore
- saved views / handoff
- SSE / freshness / boss strip
- OpenAPI/generated clients (can come later; do not block shell if not present yet)
- domain-specific DTO/query logic for Users / Knowledge Ops / Mentor / Distribution

## Natural Seams / Task Order

1. **Reconcile plan/source-of-truth**
   - Use `M006-ROADMAP.md` + actual shipped code as truth.
   - Treat `.gsd/milestones/M006/S04-TASKS.md` as stale until rewritten.
   - Decide whether S04 carries only shell/auth/403 infrastructure or also a tiny S03 permission prerequisite.

2. **Stabilize frontend baseline**
   - Add missing deps + TS config.
   - Split current monolithic `App.tsx` into pages/providers/layout.
   - Keep current Vite/nginx/compose topology unchanged.

3. **Install auth/session seam**
   - Keep current `/api/admin/auth/*` and `/api/admin/me`.
   - Replace scattered `fetch` usage with one axios instance plus refresh queue.
   - Persist session in one store only; do not let login flow and interceptor write separate truths.

4. **Install shell + route catalog**
   - Add `ProLayout` with IA placeholders.
   - Build nav from route metadata, not from hardcoded JSX.
   - Implement role-aware default landing function now so downstream slices only add metadata.

5. **Add access gating + 403**
   - `RequireAuth` → unauthenticated goes `/login`
   - `RequireAccess` → authenticated-but-not-authorized goes `/403`
   - Hide unauthorized modules from nav using the same route metadata used by guards

6. **Lock proof surfaces**
   - keep cheap build/auth smokes
   - add dedicated browser auth/RBAC spec
   - do not make S04 depend only on slow compose-backed Playwright to know anything is broken

## Verification

### Fresh research-time evidence

- `npm --prefix admin-web run build` ✅ pass
  - current output warns about a single JS chunk `647.51 kB`; adding ProComponents/pages without route splitting will worsen this.
- `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest` ✅ pass
  - confirms login / refresh rotation / logout revoke / old bearer invalidation still behave as expected.
- `npm --prefix admin-web run test:e2e -- admin-login.spec.ts` ⚠️ did not finish within 240s, then again within 420s
  - observed bottleneck was compose image build time, not an app assertion failure
  - current Playwright globalSetup does `docker compose up -d --build ...`; `backend/Dockerfile` runs `mvn -pl ${MODULE} -am dependency:go-offline -B`, so cold-cache E2E is currently minutes-long

### Useful S04 verification ladder

1. **Fast frontend smoke**
   - `npm --prefix admin-web run build`
2. **Fast backend auth contract smoke**
   - `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest`
3. **Browser auth/RBAC smoke (future S04)**
   - `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts`
4. **Real release-path E2E (later delivery slice)**
   - compose-backed Playwright against the full stack, but ideally after images are prebuilt/tagged rather than always `--build` inside globalSetup

### Minimum truthful browser scenarios for `auth-and-rbac.spec.ts`

- unauthenticated visit to protected route → redirected to `/login`
- good credentials → lands on resolved default home, not raw stub route
- expired access token during an action → refresh happens once, original request continues
- refresh expired / revoked → local sign-out + redirect to `/login`
- authenticated unauthorized route → `/403`
- restricted admin sees only allowed nav entries (requires real limited-admin/permission data, not a fake client-only condition)

## Don't Hand-Roll

| Problem | Existing Solution | Why Use It |
|---------|------------------|------------|
| admin shell / menu / breadcrumbs / layout | `@ant-design/pro-components` `ProLayout` | already chosen in milestone context; avoids inventing a parallel shell system |
| global theme tokens | Ant Design `ConfigProvider` theme tokens | current app already uses `ConfigProvider`; easiest place to map Warm Paper tokens |
| request retry after refresh | axios instance interceptors | simple instance-based retry model matches the required single-client refresh seam |
| menu visibility from routes | `ProLayout` route/menu data + `menuDataRender`/`postMenuData` | keeps nav filtering in one place instead of sprinkling `if` checks across sidebar JSX |

## Constraints

- Current backend auth contract exposes **roles only**, not a permission dictionary or permission-bearing `me` payload. Real permission-based nav hiding is therefore not fully provable from S02 alone.
- Current admin auth semantics are already fixed by shipped code:
  - access token bound to active refresh-token row
  - old bearer invalid immediately after refresh/logout
  - refresh failure should fail closed
- Relative `/api` proxying is already a repo convention in both dev (`vite.config.ts`) and runtime (`nginx.conf`). S04 should preserve this and avoid opening a CORS branch.
- Current repo CI and README are not yet admin-web aware; S04 should not assume frontend/Playwright gates already exist in shared automation.
- Current admin-web has no explicit `tsconfig.json`, no ProComponents, no axios, no 403 page, no module route tree, and no default landing resolver.

## Risks or Gotchas

- **Plan artifact drift** — `M006-ROADMAP.md` says S04 = auth shell/login, but `S04-TASKS.md` describes a Users disable flow. Planner should rewrite task artifacts before execution.
- **S03/S04 boundary drift** — roadmap puts shell in S04 and permissions in S03, but the desired S04 proof needs real permission-bearing identity or restricted-admin fixtures. Decide this before implementation.
- **Current theme is wrong for the locked design** — `admin-web/src/App.tsx` and `src/main.tsx` use purple gradient / purple primary; if S04 keeps building on this, downstream pages inherit the wrong visual foundation.
- **Compose-backed Playwright is slow** — cold-cache runs currently time out because globalSetup builds backend images with `dependency:go-offline`; use fast smoke + real E2E layers, not one giant gate.
- **Bundle size will grow quickly** — current build already warns at ~647 kB JS before ProComponents/RBAC pages. Start with route-level lazy imports or expect the shell to balloon immediately.
- **Single source of truth for session** — current code persists session in `localStorage` via `authClient.ts`. When adding axios refresh logic, keep one session store; do not split login state and interceptor state.
- **403 must be explicit** — do not collapse authenticated unauthorized access back to `/login`; that hides real RBAC failures and breaks the planner’s slice target.
- **README/CI lag** — admin-web exists in code, but repo docs and GitHub Actions still describe the pre-admin flow. This is not S04’s main job, but it is a trap for anyone expecting repo-level onboarding to already match the shell.

## Sources

- ProLayout can be used directly in React/Vite via a route-driven `ProLayout` and menu-data hooks; no Umi migration is required. (source: Ant Design Pro Components docs via Context7)
- Axios instance interceptors support `401 -> refresh -> retry original request` directly on the instance, which matches the required single-client refresh seam. (source: Axios docs via Context7)
