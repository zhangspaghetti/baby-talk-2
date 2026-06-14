---
phase: "26"
plan: "01"
---

# T01: Added MyBatisPlus, Druid, and Hutool wiring across backend modules, switched app/admin datasource config to Druid, and enabled mapper scanning in both Spring Boot entrypoints.

**Added MyBatisPlus, Druid, and Hutool wiring across backend modules, switched app/admin datasource config to Druid, and enabled mapper scanning in both Spring Boot entrypoints.**

## What Happened

Updated `backend/pom.xml` to manage MyBatisPlus, Druid, and Hutool versions, and additionally managed `mybatis-plus-core` because `common` consumes it directly and Maven would not inherit that version from the starter entry alone. Replaced `spring-jdbc` in `backend/common/pom.xml` with `mybatis-plus-core`, and replaced `spring-boot-starter-jdbc` in both runtime API modules with `mybatis-plus-spring-boot3-starter`, `druid-spring-boot-3-starter`, and `hutool-all`. Switched both main `application.yml` files from plain JDBC datasource config to explicit `DruidDataSource` with the requested pool sizing and slow-query stat filter, added shared `mybatis-plus` mapper configuration, preserved the MEM005 test-pool constraint by converting both `application-test.yml` files to Druid with `max-active: 3`, and annotated both Spring Boot main classes with `@MapperScan("com.zhangspaghetti.babytalk")`.

## Verification

Ran fresh module compiles for `backend/app-api` and `backend/admin-api`; both completed successfully after the dependency and configuration changes. Then ran explicit grep-based configuration checks to confirm `DruidDataSource` is present in both runtime `application.yml` files and `@MapperScan` is present in both application entrypoints. Slice-level runtime verification for slow-query logging and Druid metrics exposure was not exercised in this task and remains for later tasks in the slice.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn -pl backend/app-api -am clean compile -q` | 0 | ✅ pass | 14513ms |
| 2 | `mvn -pl backend/admin-api -am clean compile -q` | 0 | ✅ pass | 13297ms |
| 3 | `grep -q 'DruidDataSource' backend/app-api/src/main/resources/application.yml` | 0 | ✅ pass | 508ms |
| 4 | `grep -q 'DruidDataSource' backend/admin-api/src/main/resources/application.yml` | 0 | ✅ pass | 262ms |
| 5 | `grep -q 'MapperScan' backend/app-api/src/main/java/com/zhangspaghetti/babytalk/AppApiApplication.java` | 0 | ✅ pass | 261ms |
| 6 | `grep -q 'MapperScan' backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/AdminApiApplication.java` | 0 | ✅ pass | 281ms |

## Deviations

Added `com.baomidou:mybatis-plus-core` to parent `dependencyManagement` in addition to the planned starter entry, because the `common` module declares `mybatis-plus-core` directly and Maven requires an exact managed coordinate for versionless direct dependencies.

## Known Issues

None.

## Files Created/Modified

- `backend/pom.xml`
- `backend/common/pom.xml`
- `backend/app-api/pom.xml`
- `backend/admin-api/pom.xml`
- `backend/app-api/src/main/resources/application.yml`
- `backend/admin-api/src/main/resources/application.yml`
- `backend/app-api/src/test/resources/application-test.yml`
- `backend/admin-api/src/test/resources/application-test.yml`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/AppApiApplication.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/AdminApiApplication.java`
