# S05 Research — 用户账号管理页面

**Research depth:** Targeted

## Summary

- **Primary requirement focus:** S05 directly advances **R052** from shell/login/authz foundation into the first real admin workbench: `Users` accounts table, detail surface, destructive disable flow, and the `Admin Accounts` page for `super_admin`. It also **consumes R051**’s RBAC catalog and admin CRUD APIs rather than redefining authz vocabulary.
- This slice is mostly straightforward CRUD/workbench work, but there is **one important architecture constraint**: `admin-api` currently depends on `common` only (`backend/admin-api/pom.xml`) and **cannot call `app-api`’s `AuthConsentSyncService` directly**. The existing consumer-account delete/session-revoke semantics live only in `app-api`, so S05 must expose the needed shared-table command seam in `common` (or re-implement the same JDBC contract in `admin-api`) instead of trying to wire `app-api` services across modules.
- Frontend shell/auth is already good enough to build on. The main missing pieces are: real `UsersPage`, URL-backed filters/detail state, a reason-required destructive confirmation, and a hidden child route for `Admin Accounts` plus a stable deep-link detail route.

## Skills Discovered

- Installed during research:
  - `ant-design` (`ant-design/antd-skill@ant-design`) — relevant because S05 will lean on Ant Design Pro table/form/drawer patterns already present in the codebase.
  - `playwright-best-practices` (`currents-dev/playwright-best-practices-skill@playwright-best-practices`) — relevant because S05’s strongest proof is a compose-backed browser flow that disables a user then verifies the old mobile token fails against `app-api`.
- Already available and directly relevant:
  - `karpathy-guidelines`
  - `react-best-practices`

## Recommendation

1. **Do backend command/read seams first.**
   - Extend the existing admin users backend from a minimal list endpoint into a full users workbench contract.
   - Keep it **surgical** (Karpathy: *Simplicity First*): reuse the existing tables and deletion semantics; do **not** invent a second account lifecycle model just for admin.
2. **Mirror the existing mobile delete semantics exactly.**
   - The current source of truth is `AuthConsentSyncService.deleteAccount()` + `AuthConsentSyncRepository` in `app-api`.
   - Admin-side disable should preserve the same shared-table effects so old mobile sessions fail immediately:
     - delete `interaction_events`
     - set all `account_sessions.status = 'deleted'` / `revoked_at = now`
     - tombstone `accounts.phone_number`, set `accounts.status = 'deleted'`, `latest_consent_status = 'deleted'`, `deleted_at = now`
     - append `consent_audit_logs` entry with `action='delete'`, `result='applied'|'duplicate'`, `reason=<admin reason>`
   - This is the lowest-risk path because `app-api` token validation already treats deleted accounts as invalid.
3. **Reuse existing admin account APIs; do not build new backend CRUD there.**
   - `GET/POST /api/admin/admins`, `PATCH /api/admin/admins/{principalId}/disable`, and `GET /api/admin/roles` already exist and are enough for the `Admin Accounts` page.
   - S05 should mostly add **frontend UI** for those APIs, not second-copy backend logic.
4. **Define the workbench primitives, but only to the extent S05 uses them.**
   - Per milestone context, S05 should establish:
     - `QueuePageShell`
     - `DetailContainer`
     - `ReasonRequiredConfirmation`
   - Follow Karpathy’s *Surgical Changes*: build them for the Users workspace first; **do not** refactor Mentor/Distribution pages in the same slice just because the abstraction now exists.
5. **Use URL query/route state as the truth source for filters and deep links.**
   - Existing `MentorAuditPage` / `DistributionStatsPage` already prove the right pattern: query params drive the fetch, drafts sync from URL, reload/back keeps state.
   - S05 should copy that pattern for users filters/detail instead of introducing local-only table state.

## Implementation Landscape

### 1) Existing frontend seams

- `admin-web/src/pages/UsersPage.tsx`
  - Pure placeholder today.
  - No table, no filters, no detail surface, no destructive actions.
  - Safe place to replace with the real workspace.

- `admin-web/src/app/routes.tsx`
  - Single source of truth for shell nav/permissions/default landing.
  - **Important gap:** `ADMIN_ROUTE_PERMISSION_CODES` only includes:
    - `users:read`
    - `rag:read`
    - `kg:read`
    - `mentor:audit`
    - `distribution:read`
  - Backend already knows more permissions (`users:write`, `admins:read`, `admins:write`, `rbac:*`), but frontend route typing does not. S05 must extend this list before adding admin-account subroutes or action gating.

- `admin-web/src/App.tsx`
  - Protected shell is already correct: bootstrap via `/api/admin/me`, redirect unauthenticated to `/login`, show `/403` for authz failure, and render hidden routes fine.
  - **Important routing constraint:** `findAdminWorkspaceRouteByPath()` is an exact-path lookup, so dynamic detail paths like `/users/123` will not resolve to route metadata today.
  - Simplest S05-safe options:
    - add **static hidden routes** such as `/users/admins` and `/users/detail` with query params, **or**
    - upgrade route lookup to pattern matching if you really want param routes.
  - For this slice, static hidden routes are the lower-risk option.

- `admin-web/src/auth/http-client.ts`, `admin-web/src/auth/auth-provider.tsx`, `admin-web/src/lib/authClient.ts`
  - Shared request/refresh/session seam is already in place.
  - New users/admins clients should go through `requestJson()`; do not introduce a second fetch/auth stack.

- `admin-web/src/pages/MentorAuditPage.tsx`
- `admin-web/src/pages/DistributionStatsPage.tsx`
  - Good reference implementations for:
    - URL-backed filters
    - loading/error/empty/partial states
    - page-local fetch orchestration
    - explicit diagnostics in the UI
  - S05 should copy these patterns, not invent a new page-state style.

- `admin-web/tests/auth-and-rbac.spec.ts`
- `admin-web/tests/helpers/admin-api.ts`
  - Canonical auth/RBAC proof and helper seam already exist.
  - S05 can add user/account seeding helpers alongside the existing admin helpers.

### 2) Existing backend seams

- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUsersController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUsersService.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUserReadRepository.java`
  - Current contract is only:
    - `GET /api/admin/users`
    - no filters
    - no pagination
    - no detail payload
    - no disable command
  - Repository SQL is a straight `select ... from accounts order by account_id asc`.
  - This is the natural seam to expand.

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminPermissionCatalog.java`
  - Already contains the full relevant vocabulary:
    - `users:read`
    - `users:write`
    - `admins:read`
    - `admins:write`
    - `rbac:read`
    - `rbac:write`
  - Frontend should align to this existing catalog instead of hardcoding a second list.

- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacService.java`
  - `Admin Accounts` backend is effectively already done:
    - `GET /api/admin/admins`
    - `POST /api/admin/admins`
    - `PATCH /api/admin/admins/{principalId}/disable`
    - `GET /api/admin/roles`
  - Existing behavior is already idempotent for disable and already covered by `AdminRbacWebTest`.
  - S05 should not redesign these endpoints.

- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
  - Admin shared repositories are wired explicitly from `common` into `admin-api`.
  - If S05 adds new shared JDBC repositories/beans for account detail/history/disable, they should be added here.

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncRepository.java`
  - This is the current source of truth for consumer delete semantics.
  - `deleteAccount()` already performs the exact table mutations admin disable should mirror.
  - `validateAccessToken()` already rejects deleted accounts/sessions, so S05 does **not** need a separate invalidation mechanism if it updates the same tables correctly.

- `backend/admin-api/pom.xml`
  - `admin-api` depends on `common`, not `app-api`.
  - This is the main architectural constraint and the reason the disable command seam should move into `common` or be re-expressed as a shared JDBC repository there.

### 3) What should be built first

#### First prove the riskiest part: consumer-account disable semantics

This is the only part that crosses the admin/mobile boundary.

Recommended backend shape:

- keep admin-specific HTTP/controller/service in `admin-api`
- add shared JDBC repository/seams in `common` for:
  - filtered user list
  - user detail summary
  - session history
  - consent audit history
  - disable/tombstone command

Why this first:

- it retires the main architecture risk (`admin-api` cannot call `app-api` service)
- it unlocks both the Users table and the detail drawer/page
- it makes the browser proof meaningful because the destructive action actually changes mobile auth state

#### Then add the frontend Users workspace

Recommended shape:

- keep `/users` as the top-level visible route
- add hidden child/detail routes only as needed:
  - `/users/admins` (static hidden route, super_admin-facing)
  - `/users/detail` (static hidden route + query param) **or** a param route if route matching is upgraded intentionally
- inside `/users`, build:
  - accounts ProTable with URL-backed filters
  - account detail drawer for list-originated flows
  - standalone detail page/container for deep links
  - reason-required disable confirmation
  - admin accounts subpage reusing existing RBAC APIs

#### Keep workbench primitives minimal and real

Natural new frontend files (names may vary):

- `admin-web/src/components/workbench/QueuePageShell.tsx`
- `admin-web/src/components/workbench/DetailContainer.tsx`
- `admin-web/src/components/workbench/ReasonRequiredConfirmation.tsx`
- `admin-web/src/lib/usersClient.ts`
- `admin-web/src/lib/adminAccountsClient.ts` (optional; can also stay in one users client)

But only introduce components actually used by Users S05. Do not pre-abstract future slices beyond that.

### 4) Likely contract additions

Recommended additions under `/api/admin/users`:

- `GET /api/admin/users` with server-side filter/pagination/sort inputs
- `GET /api/admin/users/{accountId}` or equivalent detail endpoint
- detail should include at least:
  - profile/account summary
  - recent sessions
  - consent audit history
- `POST`/`PATCH` disable endpoint with required reason
  - returning stable applied/duplicate semantics is preferable to branching 409s, because the mobile delete contract already behaves that way

Recommended admin-account UI consumption:

- reuse existing:
  - `GET /api/admin/admins`
  - `GET /api/admin/roles`
  - `POST /api/admin/admins`
  - `PATCH /api/admin/admins/{principalId}/disable`

## Natural Task Seams for the Planner

1. **Backend shared account-management seam**
   - expand/add `common` JDBC repository for account detail/history/disable
   - wire it in `AdminDataAccessConfiguration`

2. **Admin API users contract**
   - expand `AdminUsersService` / `AdminUsersController`
   - add focused MockMvc coverage with DB assertions

3. **Users workspace primitives + accounts table/detail/disable UI**
   - replace placeholder page
   - use URL-backed query state
   - add reason-required confirmation

4. **Admin Accounts subroute UI**
   - hidden child route under Users
   - consume existing RBAC/admin endpoints
   - gate actions by `admins:write`

5. **Compose-backed browser proof**
   - new Playwright spec for:
     - accounts table
     - detail surface
     - disable reason required
     - same-page success
     - old mobile token now failing against `app-api`
     - admin-accounts create/disable flow

## Risks / Constraints

- **Exact-path route matching** means param detail routes are not plug-and-play today.
  - Lowest-risk slice move: static hidden detail route with query param.

- **Frontend permission typing is behind backend reality.**
  - `AdminPermissionCatalog` already supports `users:write` and `admins:*`, but `routes.tsx`/`access.ts` do not.
  - Extend the typed permission list first.

- **Do not accidentally fork consumer delete semantics.**
  - If admin disable mutates different fields/tables than `AuthConsentSyncService.deleteAccount()`, mobile access invalidation will drift and the slice may appear to work in UI while failing the acceptance criterion.

- **Do not over-refactor existing pages.**
  - Karpathy: *Surgical Changes*.
  - S05 should create the shared primitives but should not spend the slice rewriting `MentorAuditPage` or `DistributionStatsPage` just to “make things consistent.”

## Verification

Recommended proof set for this slice:

1. **Backend contract + DB-effect proof**
   - `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminUsersWebTest,AdminRbacWebTest`
   - `AdminUsersWebTest` should prove:
     - filtered/list/detail contract
     - disable with required reason
     - duplicate disable stability
     - sessions marked deleted/revoked
     - consent audit row written

2. **Frontend compile proof**
   - `npm --prefix admin-web run build`

3. **Browser golden-path proof**
   - `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts users-disable-account.spec.ts`
   - `users-disable-account.spec.ts` should prove:
     - login → `/users`
     - accounts table renders truthful seeded data
     - detail surface shows sessions + consent audit
     - disable requires reason
     - success keeps current context (filters/scroll/current module)
     - old mobile token fails against `app-api` after disable (`account_deleted` / equivalent invalid-session contract)
     - `super_admin` can open Admin Accounts, create admin, then disable admin

4. **Optional safety proof if delete semantics are extracted from app-api code instead of mirrored carefully**
   - `./backend/mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=AuthConsentSyncWebTest`
   - Only necessary if shared delete logic is physically moved/refactored in a way that could regress existing mobile behavior.

## Key file references

- `admin-web/src/pages/UsersPage.tsx`
- `admin-web/src/app/routes.tsx`
- `admin-web/src/App.tsx`
- `admin-web/src/auth/http-client.ts`
- `admin-web/src/pages/MentorAuditPage.tsx`
- `admin-web/src/pages/DistributionStatsPage.tsx`
- `admin-web/tests/auth-and-rbac.spec.ts`
- `admin-web/tests/helpers/admin-api.ts`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUsersController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUsersService.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUserReadRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminPermissionCatalog.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncRepository.java`
- `backend/admin-api/pom.xml`
