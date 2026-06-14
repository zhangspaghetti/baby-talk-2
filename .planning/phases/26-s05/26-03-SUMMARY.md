---
phase: "26"
plan: "03"
---

# T03: Migrated admin auth, RBAC, and ingestion repositories to MyBatis mappers and removed JdbcTemplate wiring from AdminDataAccessConfiguration.

**Migrated admin auth, RBAC, and ingestion repositories to MyBatis mappers and removed JdbcTemplate wiring from AdminDataAccessConfiguration.**

## What Happened

Added `AdminRbacMapper`, `AdminAuthMapper`, and `IngestionMapper` plus XML SQL mappings, then moved `AdminRbacRepository` and `IngestionRepository` off `JdbcTemplate` onto mapper-backed implementations. I also extracted the inner auth repository from `AdminAuthService` into a standalone `AdminAuthRepository` so the refresh-token lock/rotate flow continues to run through a transactional repository boundary while using MyBatis `SELECT ... FOR UPDATE` SQL.

I cleaned `AdminDataAccessConfiguration` so the migrated beans now receive mapper dependencies instead of `JdbcTemplate`, and removed the remaining `JdbcTemplate` imports/parameters from the migrated admin wiring. The task-level migration contract is now satisfied: admin auth, admin RBAC, and shared ingestion CRUD all run through mapper interfaces plus XML rather than inline `JdbcTemplate` SQL.

During verification, two runtime issues surfaced that compile alone did not catch. First, `admin-api` web tests needed Flyway SQL available on the service test classpath even though `db-migration` remains the schema owner, so I wired `backend/admin-api/pom.xml` testResources to include `../db-migration/src/main/resources`. Second, Java 21 JDK proxies cannot expose package-private nested record types in mapper method signatures, so I made the mapper-exposed nested records in `AdminAuthRepository` and `AdminRbacRepository` public. I also added unexpected-exception logging in `AdminApiExceptionHandler` so future verification failures surface the actual stack trace instead of only returning `internal_error`.

## Verification

Ran `mvn -pl backend/admin-api -am clean compile -q` and it passed. Ran `mvn -pl backend/admin-api -am clean verify -q` and it passed, including the task-targeted `AdminAuthWebTest` and `AdminRbacWebTest`; downstream admin suites such as overview, users, knowledge, and mentor audit also executed cleanly, with expected timeout-degradation scenarios only emitting logs rather than failing the build. Finally, verified JdbcTemplate removal by searching the five migrated files and confirming no matches remained. As a supporting sanity check for the Flyway fix, `backend/admin-api/target/test-classes/db/migration/` contained the copied V15/V17 migration SQL during test execution.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn -pl backend/admin-api -am clean compile -q` | 0 | ✅ pass | 18200ms |
| 2 | `mvn -pl backend/admin-api -am clean verify -q` | 0 | ✅ pass | 87400ms |
| 3 | `rg -n "JdbcTemplate" backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacRepository.java backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthService.java backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthRepository.java backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java backend/common/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionRepository.java` | 1 | ✅ pass | 18ms |

## Deviations

Added `backend/admin-api/pom.xml` testResources wiring so admin-api tests load Flyway SQL from `../db-migration/src/main/resources`, and added unexpected-exception logging in `AdminApiExceptionHandler` to expose hidden runtime failures during verification.

## Known Issues

None.

## Files Created/Modified

- `backend/admin-api/pom.xml`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthRepository.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthMapper.java`
- `backend/admin-api/src/main/resources/mapper/admin/AdminAuthMapper.xml`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacMapper.java`
- `backend/common/src/main/resources/mapper/admin/AdminRbacMapper.xml`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionMapper.java`
- `backend/common/src/main/resources/mapper/ingestion/IngestionMapper.xml`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthController.java`
