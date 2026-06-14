---
phase: "16"
plan: "03"
---

# T03: Added admin RBAC/users management APIs with DB-backed permission enforcement and MockMvc matrix proof for 200/403/401 immediate-effect flows.

**Added admin RBAC/users management APIs with DB-backed permission enforcement and MockMvc matrix proof for 200/403/401 immediate-effect flows.**

## What Happened

I replaced the placeholder RBAC proof with a real backend implementation and kept the existing admin auth session semantics intact. On the transport side, I added `/api/admin/permissions`, `/api/admin/roles`, `/api/admin/admins`, `/api/admin/admins/{principalId}/disable`, and `/api/admin/users`, all backed by new `AdminRbacService` / `AdminUsersService` layers and permission-based `@PreAuthorize` checks for `rbac:*`, `admins:*`, and `users:read`.

On the data seam, I extended the shared JDBC repositories so admin-api can list/create roles, list/create/disable admin principals, and read the first minimal consumer users projection from `accounts` without pulling broader S05 scope back into this slice. I also introduced a shared `AdminApiContractException` and updated the global admin API advice so validation failures, contract 4xxs, and method-security denials all stay inside the existing JSON error envelope instead of leaking as 500s.

For proof, I rewrote `AdminRbacWebTest` as a SpringBootTest + MockMvc + Postgres fixture matrix that exercises the real login flow: bootstrap super_admin creates a `users_reader` role, creates a limited admin, the limited admin logs in and reads `/api/admin/users` with 200, admin/RBAC write attempts return 403, deleting the admin’s role assignment flips the same access token to 403 immediately, and disabling the principal flips the same access token to `401 admin_account_disabled`. The test suite also covers empty users list, missing fields, unknown role/permission, duplicate username, and disable-missing-principal contracts.

## Verification

Ran `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest,AdminRbacWebTest` and it passed with `AdminAuthWebTest` (8 tests) and `AdminRbacWebTest` (4 tests) both green. Ran `./backend/mvnw.cmd -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` and it passed, including the `db-migration completed successfully. currentVersion=17, appliedCount=15` runtime signal. Ran `docker compose up -d postgres && ./backend/mvnw.cmd -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` and then queried compose Postgres to verify `flyway_schema_history` reported version `17` with `15` applied migrations. The admin-api proof directly asserted the stable `forbidden`, `admin_account_disabled`, and existing `admin_session_invalid` envelopes.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest,AdminRbacWebTest` | 0 | ✅ pass | 30433ms |
| 2 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` | 0 | ✅ pass | 15760ms |
| 3 | `docker compose up -d postgres && ./backend/mvnw.cmd -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` | 0 | ✅ pass | 5703ms |

## Deviations

Used `./backend/mvnw.cmd` equivalents instead of the POSIX `./backend/mvnw` commands from the plan because this workspace is executing under Windows Git Bash and the original verification command fails with `'.' is not recognized as an internal or external command`.

## Known Issues

None.

## Files Created/Modified

- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminApiContractException.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUsersController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUsersService.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUserReadRepository.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminRbacWebTest.java`
