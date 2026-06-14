---
phase: "16"
plan: "02"
---

# T02: Switched admin-api to DB-backed authority snapshots and returned current permissions from login, refresh, and /api/admin/me.

**Switched admin-api to DB-backed authority snapshots and returned current permissions from login, refresh, and /api/admin/me.**

## What Happened

Updated `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacRepository.java` with a single-query `findAuthoritySnapshot` read so effective roles and permissions are hydrated from the current database snapshot instead of JWT issuance-time claims.

Added `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthorityService.java` plus `AdminJwtAuthenticationConverter.java`, and rewired `AdminSecurityConfig` so resource-server authentication builds `ROLE_*` and permission authorities from live RBAC rows on every authenticated request while preserving the existing `admin_session_invalid` / `admin_account_disabled` split in `AdminSessionGuardFilter`.

Expanded `AdminAuthService.MeResponse` so login, refresh, and `/api/admin/me` now all return current `roles` + `permissions`, while keeping bootstrap seeding, refresh rotation, logout invalidation, and the existing error envelope semantics intact. No direct `AdminAuthController` transport change was needed beyond the richer serialized response record.

Extended `AdminAuthWebTest` to prove: `/api/admin/me` returns permissions; removing roles after login empties `/me` permissions on the same access token; the authentication converter ignores stale JWT `roles` claims and uses the current DB snapshot; disabling the principal makes the same access token fail immediately with `401 admin_account_disabled`; and auth error responses do not echo passwords or tokens.

## Verification

Ran the task-level admin auth suite and it passed with the new DB-backed authority hydration and richer auth payload contract.

Ran the db-migration smoke test with the Windows-compatible Maven entrypoint and confirmed the expected runtime signal `db-migration completed successfully. currentVersion=17, appliedCount=15`.

Ran the slice-level compose+Flyway migrate check successfully.

Ran the combined `AdminAuthWebTest,AdminRbacWebTest` slice command as required; it still fails only because `AdminRbacWebTest` is the intentional T03 placeholder, so the protected-endpoint `forbidden` proof remains pending downstream while this task’s auth contract and `admin_account_disabled` / `admin_session_invalid` signals are verified now.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest` | 0 | ✅ pass | 24496ms |
| 2 | `backend/mvnw.cmd -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` | 0 | ✅ pass | 18066ms |
| 3 | `docker compose up -d postgres && backend/mvnw.cmd -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` | 0 | ✅ pass | 4994ms |
| 4 | `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest,AdminRbacWebTest` | 1 | ❌ fail | 28362ms |

## Deviations

Did not edit `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthController.java` directly. Updating the serialized `AdminAuthService` response records was sufficient to align the transport contract without changing controller routing or error handling.

## Known Issues

`backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest,AdminRbacWebTest` still exits 1 because `AdminRbacWebTest` is a deliberate T03 placeholder that fails until `/api/admin/users` RBAC protection and the permission matrix are implemented.

## Files Created/Modified

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacRepository.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthorityService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminJwtAuthenticationConverter.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminSecurityConfig.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthService.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminAuthWebTest.java`
