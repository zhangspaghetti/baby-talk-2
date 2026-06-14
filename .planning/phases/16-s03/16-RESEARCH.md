# S03 RESEARCH — Admin RBAC + 权限 API

## Summary

- S02 already closed the **admin authentication** half: `admin-api` has working login / refresh / logout / `/me`, a dedicated `admin_principals` + `admin_roles` + `admin_principal_roles` + `admin_refresh_tokens` schema, and a session guard that invalidates old access tokens when refresh rows rotate/revoke. S03 should attach **authorization** to that seam, not rebuild token lifecycle.
- The next Flyway slot is **V17+**, not V16. This is already locked by D097 and by the fact that `V16__create_account_jwt_tables.sql` exists. `DbMigrationApplication` and `DbMigrationSmokeTest` currently hardcode `currentVersion=16` / `appliedCount=14`, so S03 must update both or migration proof will fail even if SQL is correct.
- The current admin authorization source is the **`roles` claim inside the access JWT**. That is the key seam to change. If S03 keeps authorizing from JWT claims, role/permission changes will **not** take effect immediately, which conflicts with R051.
- `backend/common` is still effectively a thin utility module (`JwtTokenService` only). If S03 moves RBAC repositories/models into `common`, the safest pattern is the one already used for `JwtTokenService`: keep common classes plain and wire them from `admin-api` config via `@Bean`, instead of relying on `AdminApiApplication` to component-scan sibling packages.
- There is plan drift: `M006-ROADMAP.md` still says `V16__create_rbac_tables.sql`, and `.gsd/milestones/M006/S03-TASKS.md` still includes browser route guard / runbook / verify tooling work. The current slice mission is backend-only (`common` / `admin-api` / `db-migration` / MockMvc proof). Push browser guard work to S04 unless scope is explicitly re-expanded.
- Applied `karpathy-guidelines` explicitly:
  - **Simplicity First:** extend existing admin auth seam; do not invent a unified consumer+admin auth framework.
  - **Surgical Changes:** keep existing table names (`admin_principals`, not a rename to `admin_users`), keep existing error envelope, keep refresh/logout semantics unchanged.
  - **Goal-Driven Execution:** make the slice proof a single concrete flow: `super_admin creates limited admin -> limited admin logs in -> users list 200 -> other protected admin APIs 403`.

## Recommendation

1. **Keep the existing admin auth tables and naming.**
   - Do **not** rename `admin_principals` / `admin_principal_roles` to match older `admin_users` wording in requirements/decisions.
   - Add only the missing RBAC tables in a new migration:
     - `admin_permissions`
     - `admin_role_permissions`
   - Reuse `admin_roles` and `admin_principal_roles` from V15.

2. **Put the permission catalog in `backend/common` as code, not only in SQL.**
   - Add one shared permission vocabulary under an admin-specific common package (for example a record/enum catalog), with stable codes that downstream slices can reuse.
   - Define the future-facing dictionary now, even if S03 only enforces the first gate. Minimum useful set:
     - `users:read`
     - `users:write`
     - `admins:read`
     - `admins:write`
     - `rbac:read`
     - `rbac:write`
     - `rag:read`
     - `rag:write`
     - `kg:read`
     - `kg:review`
     - `mentor:audit`
     - `distribution:read`
   - This gives S05/S06/S07 a backend-owned dictionary and avoids inventing a frontend-only permission model later.

3. **Do not authorize from JWT role claims. Load authorities from DB on each request.**
   - Right now `AdminSecurityConfig` turns `jwt.roles` into `ROLE_*` authorities.
   - That is acceptable for login-only S01, but it violates R051’s “role/permission change immediately生效” requirement.
   - Recommended seam: after JWT decode, build the `Authentication` from **current DB roles + permissions**, not from token claims.
   - The easiest surgical options are:
     - change the admin JWT converter so it queries current role/permission state by `principalId`, or
     - extend the existing admin session guard so it replaces the `Authentication` with DB-backed authorities after session validation.
   - Prefer whichever keeps `login/refresh/logout/validateAccessToken` untouched.

4. **Use existing method security and existing 403 handler; do not add a second authz framework.**
   - `@EnableMethodSecurity` is already on.
   - `AdminSecurityConfig.adminAccessDeniedHandler(...)` already emits stable JSON `403 { code: "forbidden", message: "权限不足。" }`.
   - S03 should simply add `@PreAuthorize(...)` to the first real controller/service surfaces.

5. **Make `/api/admin/me` the backend truth for admin permissions.**
   - Today `MeResponse` returns roles only.
   - Extend it to return current permissions too.
   - Also extend login/refresh responses to include that richer `me` payload.
   - That gives S04 a clean backend seam for route guards and nav filtering without decoding JWT claims in the browser.

6. **Preserve the role model; do not add `principal_permissions` unless the requirement changes.**
   - The committed design is `roles + permissions + role_permissions`.
   - The clean S03 proof flow is:
     1. `super_admin` creates a role (or uses a seeded limited role) that contains `users:read`
     2. `super_admin` creates an admin assigned to that role
     3. limited admin logs in and can call `GET /api/admin/users`
     4. limited admin gets `403` on admin management / RBAC endpoints

7. **Follow the existing `common` wiring pattern.**
   - `ConsumerAuthConfiguration` already shows the project’s pattern for common-module code: plain class in `common`, bean wiring in the runtime module.
   - Reuse that for RBAC repositories/catalog classes.
   - This is safer than widening `AdminApiApplication` component scan unless that wider scan is a deliberate choice.

## Requirements / Plan Drift

- **R051** (`.gsd/REQUIREMENTS.md` 150-158) still validates more than the current mission text: it mentions **create/disable admin accounts** and **immediate role/permission effect**. The mission text only names the create + `users:read` flow. Planner should decide this explicitly:
  - either include admin disable now, or
  - keep S03 scoped to create/read first gate and update requirement/plan text so the slice is not judged against a broader contract than it implements.
- **Roadmap drift:** `.gsd/milestones/M006/M006-ROADMAP.md` 86-89 still says `V16__create_rbac_tables.sql`; D097 and the actual repo say S03 must use **V17+**.
- **Task drift:** `.gsd/milestones/M006/S03-TASKS.md` 72-99 still includes browser route guard, runbook, and root verify tooling. The current slice mission and S04 boundary make that look stale. Keep S03 backend-only unless the planner intentionally pulls frontend work back in.
- **Naming drift:** D090 / R051 still say `admin_users`; the actual live schema is `admin_principals`. S03 should extend the actual repo, not rename it.

## Files / Seams

1. `.gsd/REQUIREMENTS.md` (150-158)
   - R051 current contract for S03: fine-grained admin permissions, `@PreAuthorize`, immediate effect, MockMvc matrix proof.

2. `.gsd/DECISIONS.md` (97-99, 105)
   - D089: backend split is `db-migration / common / app-api / admin-api`
   - D090: consumer vs admin JWT models stay separate
   - D091: RBAC model is `roles / permissions / role_permissions` + method security
   - D097: S03 migration numbering starts at `V17+`

3. `.gsd/milestones/M006/M006-ROADMAP.md` (41-42, 86-89)
   - S03 success target is still the correct high-level goal
   - boundary map is stale on migration slot (`V16`)

4. `.gsd/milestones/M006/S03-TASKS.md` (30-99)
   - useful for backend task decomposition
   - stale on browser / runbook scope under the current mission

5. `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminSecurityConfig.java` (123-128, 159-190, 207-213, 271-310)
   - current admin authz seam
   - JWT `roles` claim -> `ROLE_*` authorities
   - stable JSON `403 forbidden`
   - session guard already validates refresh row + account status after bearer auth

6. `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthService.java` (54-225, 378-612)
   - login / refresh / logout / `/me` / bootstrap seeding
   - inline repository currently owns admin principals, roles, and refresh tokens
   - the file is already a seam worth splitting before piling on permissions

7. `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthController.java` (34-50, 67-111)
   - existing `/api/admin/auth/*` + `/api/admin/me`
   - existing contract/error envelope worth preserving for new RBAC APIs

8. `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminAuthWebTest.java` (92-194)
   - current proof style for admin-api: SpringBootTest + MockMvc + Testcontainers + direct SQL assertions
   - new RBAC matrix proof should look like this, not like shallow controller unit tests

9. `backend/common/src/main/java/com/zhangspaghetti/babytalk/security/JwtTokenService.java` (29-111, 156-194)
   - already separates **admin token issuance** from **consumer token issuance**
   - S03 should preserve that split and avoid merging auth domains

10. `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/ConsumerAuthConfiguration.java` (21-53)
    - existing pattern for wiring a plain `common` class into a runtime module via `@Bean`
    - best model for new common RBAC repositories/catalog classes

11. `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/AdminApiApplication.java` (1-12)
    - component scan root is `com.zhangspaghetti.babytalk.admin`
    - common Spring components outside that package will not be auto-discovered unless explicitly wired/imported

12. `backend/db-migration/src/main/resources/db/migration/V15__create_admin_auth_tables.sql` (1-44)
    - current admin schema baseline: principals, roles, principal_roles, refresh_tokens

13. `backend/db-migration/src/main/resources/db/migration/V16__create_account_jwt_tables.sql` (1-29)
    - proves V16 is already consumed by S02

14. `backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java` (18-19, 33-51)
    - hardcoded schema closure constants that must be bumped for S03

15. `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java` (44-83)
    - current migration smoke asserts version/count and presence of key tables
    - must be updated for V17 and new RBAC tables

16. `backend/db-migration/src/main/resources/db/migration/V3__create_accounts_and_sync_tables.sql` (1-20)
    - source-of-truth schema for the first `Users` read path (`accounts`, `account_sessions`)

17. `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncRepository.java` (76-174, 518-549)
    - current consumer account/session row shapes that S03’s first users list can project from
    - cannot be imported directly into `admin-api` without breaking module boundaries; use a new common read repo or local JDBC read path instead

18. `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/AppSecurityConfig.java` (56-86, 122-151, 235-294) and `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncController.java` (39-91)
    - S02’s pattern is important: Bearer is canonical, but controller/service seams stayed intact
    - S03 should mirror that principle on admin authz: bolt authorization onto the proven seam rather than rewriting token lifecycle or controller contracts

## Key Code

**Current stale-authz seam (`AdminSecurityConfig`)**

```java
private Converter<Jwt, ? extends AbstractAuthenticationToken> adminJwtAuthenticationConverter() {
    return jwt -> new JwtAuthenticationToken(
            jwt,
            toAuthorities(jwt.getClaimAsStringList("roles")),
            jwt.getClaimAsString("username")
    );
}
```

Planner implication: this is fine for S01 login proof, but not for S03 if permissions must change immediately.

**Current token lifecycle seam already does the hard work (`AdminAuthService`)**

```java
@Transactional
public AccessValidationResult validateAccessToken(String principalId, String refreshTokenId) {
    if (principalId == null || principalId.isBlank() || refreshTokenId == null || refreshTokenId.isBlank()) {
        return AccessValidationResult.SESSION_INVALID;
    }
    var refreshToken = repository.findRefreshToken(refreshTokenId).orElse(null);
    if (refreshToken == null || !principalId.equals(refreshToken.principalId())) {
        return AccessValidationResult.SESSION_INVALID;
    }
    var status = resolveRefreshTokenStatus(refreshToken, Instant.now(clock));
    if (status != RefreshTokenStatus.ACTIVE) {
        return AccessValidationResult.SESSION_INVALID;
    }
    var principal = repository.findPrincipalById(principalId).orElse(null);
    if (principal == null || !"active".equals(principal.status())) {
        return AccessValidationResult.ACCOUNT_DISABLED;
    }
    return AccessValidationResult.ACTIVE;
}
```

Planner implication: account disable and refresh/logout invalidation are already solved. S03 should add **permission loading**, not another token invalidation system.

**Existing common-module wiring pattern (`ConsumerAuthConfiguration`)**

```java
@Bean
JwtTokenService jwtTokenService(
        JwtEncoder consumerJwtEncoder,
        @Qualifier("consumerTokenJwtDecoder") JwtDecoder consumerTokenJwtDecoder
) {
    return new JwtTokenService(consumerJwtEncoder, consumerTokenJwtDecoder, Clock.systemUTC());
}
```

Planner implication: common RBAC helpers/repositories can follow the same pattern instead of relying on component scan.

## Implementation Landscape

### 1. Current admin authentication is already real and should remain the root seam

- `AdminAuthService` already owns:
  - bootstrap `super_admin`
  - password validation
  - refresh rotation
  - logout revoke
  - `/me`
- `AdminSessionGuardFilter` already enforces:
  - refresh row must still be active
  - principal must still be active
- `AdminAuthWebTest` already proves:
  - missing bearer -> 401 `admin_authentication_required`
  - bad credentials -> stable 401
  - refresh rotation invalidates old access token immediately
  - logout invalidates refresh + access semantics

S03 should not change that contract unless the change is directly about authorities.

### 2. There is no permission model yet

Current live schema only has:

- `admin_principals`
- `admin_roles`
- `admin_principal_roles`
- `admin_refresh_tokens`

There is **no** `admin_permissions` table and no `role_permissions` join yet. So every new downstream module would otherwise hardcode role checks differently.

### 3. `common` is still thin, so S03 is the first real chance to shape that seam correctly

Current `common` module has only one source file: `JwtTokenService`.
That means S03 is free to establish the admin-common pattern cleanly:

- plain catalog / row / repository classes in `common`
- wiring in `admin-api`
- no accidental dependency from `admin-api` back into `app-api`

### 4. The first `Users` read surface should be a read-only projection from consumer tables

The first real proof target is not admin principals themselves; it is **consumer users list**.
The data already lives in:

- `accounts`
- `account_sessions`

The first users list API can stay intentionally small:

- `accountId`
- `phoneNumber`
- `status`
- `latestConsentStatus`
- `createdAt`
- optionally a cheap session aggregate if useful

That is enough for S03 proof and stable enough for S05 to extend into full user management.

### 5. Admin-api tests have the right module boundary already

- `admin-api` test scope depends on `db-migration`, so Flyway SQL is available during tests.
- `admin-api` does **not** depend on `app-api`, so tests cannot cheat by importing app-api services/repos.
- The current admin test style already uses `JdbcTemplate` directly for DB assertions and fixtures; S03 should do the same when seeding consumer `accounts` rows for the users-list proof.

## Natural Seams / Task Order

1. **Schema + migration closure**
   - Add `V17__...` migration with `admin_permissions` + `admin_role_permissions` (and any needed indexes / constraints).
   - Update `DbMigrationApplication.EXPECTED_CURRENT_VERSION` and `EXPECTED_APPLIED_MIGRATION_COUNT`.
   - Update `DbMigrationSmokeTest` table/version assertions.

2. **Common admin RBAC catalog + repositories**
   - Add one shared permission catalog under `backend/common`.
   - Add plain JDBC repositories/row records for:
     - permissions
     - role-permission mapping
     - admin principal read/write beyond auth-only needs
     - first consumer users list read path
   - Wire them in `admin-api` config, not via accidental scan.

3. **Admin authority hydration**
   - Change admin request authz so effective roles/permissions come from DB each request.
   - Keep `validateAccessToken` and refresh/logout semantics unchanged.
   - Extend `/api/admin/me` (and login/refresh payloads) to return current permissions.

4. **RBAC/admin/users API surface**
   - Add minimal APIs in `admin-api`:
     - `GET /api/admin/permissions`
     - `GET/POST /api/admin/roles`
     - `GET/POST /api/admin/admins` (and optionally detail/update if needed for proof)
     - `GET /api/admin/users`
   - Annotate with `@PreAuthorize` using the new permission authorities.
   - Keep super-admin-only APIs explicit; do not blur them into generic authenticated APIs.

5. **MockMvc matrix proof**
   - Add one integrated web test class (for example `AdminRbacWebTest`) that proves the whole flow.
   - Keep `AdminAuthWebTest` focused on auth lifecycle only.
   - If disable/downgrade stays in S03 scope, add same-token immediate-effect assertions there.

## Verification

### Commands

```bash
./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest,AdminRbacWebTest
```

```bash
./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest
```

```bash
docker compose up -d postgres && ./backend/mvnw -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk
```

### Proof cases that matter

- **Authn baseline stays intact**
  - no bearer -> `401 admin_authentication_required`
  - bad token -> `401 invalid_admin_access_token` or session-invalid variant
- **Authz works**
  - limited admin with `users:read` -> `GET /api/admin/users` returns `200`
  - same limited admin -> admin management / RBAC write APIs return `403 forbidden`
- **Super-admin setup flow works**
  - `super_admin` can create a role (or use a deterministic limited role) containing `users:read`
  - `super_admin` can create an admin assigned to that role
- **Immediate effect works**
  - if a role/permission assignment is removed after login, the same access token stops working on the protected users route immediately (`403`, not “works until refresh”)
  - if the admin account is disabled, the same access token is rejected immediately by the existing session/account guard (`401 admin_account_disabled`)

## Risks or Gotchas

- **Main design risk:** if S03 keeps using JWT role claims for authorities, R051 immediate-effect semantics are false. This is the planner’s biggest call.
- **Package/bean discovery risk:** `AdminApiApplication` scans from `com.zhangspaghetti.babytalk.admin`. Common-module Spring components outside that tree will not auto-load. Prefer plain common classes + explicit bean wiring, or consciously widen scan/import.
- **Dependency risk:** `backend/common/pom.xml` currently only carries JOSE support. Moving JDBC repositories into common means `common` must gain the right compile-time Spring/JDBC dependencies.
- **Migration closure risk:** forgetting to bump `DbMigrationApplication` constants or `DbMigrationSmokeTest` tracked-version assertions will fail proof after the SQL is added.
- **Test fixture risk:** `AdminAuthWebTest.resetTables()` currently truncates auth/role tables only. Once permissions tables exist, reset logic must either truncate them too or rely on strictly idempotent seeding.
- **Boundary drift risk:** `S03-TASKS.md` still tries to pull browser guard/docs/tooling into S03. Under the current mission, that is scope creep.
- **Naming drift risk:** requirements/decisions say `admin_users`, but the live code says `admin_principals`. Renaming now is churn with no proof value.
- **Module-boundary risk for users list:** admin-api tests cannot import app-api services. Seed consumer accounts via SQL fixtures or a new common read repo, not by making admin-api depend on app-api.
- **Role-model drift risk:** the design says `role_permissions`; avoid sneaking in `principal_permissions` just to make the first proof shorter.
