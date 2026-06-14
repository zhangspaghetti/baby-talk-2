---
phase: "16"
plan: "01"
---

# T01: Added V17 admin RBAC schema, shared permission/JDBC repositories, and explicit admin-api data-access wiring.

**Added V17 admin RBAC schema, shared permission/JDBC repositories, and explicit admin-api data-access wiring.**

## What Happened

I added `V17__create_admin_rbac_permissions.sql` to create `admin_permissions` and `admin_role_permissions`, seed the shared 12-permission catalog, and idempotently bind the seeded catalog to `super_admin`. I then bumped `DbMigrationApplication` schema closure to `currentVersion=17` / `appliedCount=15` and expanded `DbMigrationSmokeTest` to prove the new tables and seeded permission vocabulary exist on a fresh database.

In `backend/common` I added the shared plain-Java seam requested by the plan: `AdminPermissionCatalog`, `AdminRbacRepository`, and `AdminUserReadRepository`, with only a minimal `spring-jdbc` compile dependency added to the module. In `admin-api` I introduced `AdminDataAccessConfiguration` so these shared classes are wired explicitly as beans rather than via wider component scanning or any `app-api` dependency.

While verifying the change, I found that `AdminAuthWebTest` truncates `admin_roles` with `CASCADE`, which also deletes `admin_role_permissions`. To keep the slice’s future DB-backed authorization path valid, I updated `AdminAuthService.seedBootstrapPrincipalIfMissing()` to re-grant the shared permission catalog to `super_admin` during bootstrap. I also added an `AdminAuthWebTest` assertion that the migrated SQL seed and the shared Java catalog stay aligned, plus a deliberately failing `AdminRbacWebTest` placeholder so the slice-level verification command stays honestly red until T03 delivers the real RBAC API matrix.

## Verification

Task-level verification passed with fresh evidence: `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` reached `currentVersion=17` / `appliedCount=15` and proved `admin_permissions` / `admin_role_permissions` plus the seeded permission catalog. `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest` passed after the new shared seam and bootstrap permission reseed were wired in.

Slice-level verification was also exercised. `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest,AdminRbacWebTest` now fails only because `AdminRbacWebTest` is an intentional T03 placeholder proving the RBAC API matrix is still outstanding. `docker compose up -d postgres && ./backend/mvnw -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` passed, confirming the standalone Flyway migrate path still works from the module pom.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` | 0 | ✅ pass | 16300ms |
| 2 | `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest` | 0 | ✅ pass | 25000ms |
| 3 | `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest,AdminRbacWebTest` | 1 | ❌ fail | 21200ms |
| 4 | `docker compose up -d postgres && ./backend/mvnw -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` | 0 | ✅ pass | 6400ms |

## Deviations

I moved the code-vs-SQL catalog alignment proof into `AdminAuthWebTest` instead of making `db-migration` depend on `common`, because the standalone `backend/db-migration/pom.xml flyway:migrate` slice verification must remain runnable without reactor resolution. I also added a deliberately failing `AdminRbacWebTest` placeholder now so slice-level verification reflects unfinished T03 work instead of silently skipping the missing test.

## Known Issues

`backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminRbacWebTest.java` is intentionally failing until T03 implements `/api/admin/users` plus the RBAC 200/403/401 matrix. Because of that placeholder, the slice-level admin-api verification command is expected to stay red until T03 lands.

## Files Created/Modified

- `backend/db-migration/src/main/resources/db/migration/V17__create_admin_rbac_permissions.sql`
- `backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java`
- `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`
- `backend/common/pom.xml`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminPermissionCatalog.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUserReadRepository.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthService.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminAuthWebTest.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminRbacWebTest.java`
