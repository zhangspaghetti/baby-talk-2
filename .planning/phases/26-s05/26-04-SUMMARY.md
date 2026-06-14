---
phase: "26"
plan: "04"
---

# T04: Migrated eight app-api repositories to MyBatis mappers and restored the app-api parity test path.

**Migrated eight app-api repositories to MyBatis mappers and restored the app-api parity test path.**

## What Happened

I migrated the T04 app-api persistence batch off direct JdbcTemplate usage by adding mapper interfaces/XMLs for the four KG repositories, PalaceKeyword, Distribution, and ShareLanding, plus an annotated ConversationSessionMapper for chat-memory timestamp lookups. The repository/service facades stayed stable while their internals switched to mapper injection, so callers like KG services, distribution/share flows, and conversation timeout handling kept the same contracts. For PalaceKeyword I deliberately kept logging, limit normalization, and metadata JSON parsing in the repository while moving the SQL to MyBatis XML, because the repository still owns the user-facing observability and malformed-metadata fallback behavior.

During verification I hit two non-task-local regressions that had to be fixed to make the planned parity suite runnable. First, broad `@MapperScan("com.zhangspaghetti.babytalk")` was registering ordinary interfaces like `MentorProvider` as mappers, so I narrowed both app-api and admin-api bootstraps to `annotationClass = Mapper.class`. Second, the `db-migration` module was being repackaged as a Spring Boot fat jar, which hid Flyway SQL under `BOOT-INF/classes` and made app-api tests see zero migrations; I changed that module to publish a normal dependency jar and attach the executable artifact with an `exec` classifier. I also updated the affected unit tests to mock mappers instead of JdbcTemplate so the new repository seams are covered directly.

## Verification

Ran `mvn -pl backend/app-api -am clean compile -q` on the final tree and it passed. Ran the task’s targeted parity suite with `mvn -pl backend/app-api -am clean verify -Dtest="KgEntityRepositoryTest,KgContradictionRepositoryTest,PalaceKeywordRepositoryTest,DistributionPageWebTest,ShareLandingWebTest,ShareLinkApiWebTest" -q`; all six named test classes finished with 0 failures and 0 errors. Verified the five required migrated files contain no `JdbcTemplate` references, and re-checked app-api Druid/MyBatis config markers (`DruidDataSource`, `slow-sql-millis: 2000`, `mapper-locations`) so this task did not regress the slice-level datasource wiring established earlier.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn -pl backend/app-api -am clean compile -q` | 0 | ✅ pass | 14900ms |
| 2 | `mvn -pl backend/app-api -am clean verify -Dtest="KgEntityRepositoryTest,KgContradictionRepositoryTest,PalaceKeywordRepositoryTest,DistributionPageWebTest,ShareLandingWebTest,ShareLinkApiWebTest" -q` | 0 | ✅ pass | 51900ms |
| 3 | `python scan for 'JdbcTemplate' in KgEntityRepository/KgContradictionRepository/PalaceKeywordRepository/DistributionRepository/ConversationSessionService` | 0 | ✅ pass | 0ms |
| 4 | `python scan for DruidDataSource, slow-sql-millis: 2000, and mapper-locations in backend/app-api/src/main/resources/application.yml` | 0 | ✅ pass | 0ms |

## Deviations

Besides the written T04 repository migration, I made two focused infrastructure fixes required for verification to work: narrowed `@MapperScan` to `@Mapper`-annotated interfaces, and changed `backend/db-migration` packaging to attach the executable jar under an `exec` classifier so Flyway migrations are visible on downstream test classpaths.

## Known Issues

None.

## Files Created/Modified

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgEntityRepository.java`
- `backend/app-api/src/main/resources/mapper/kg/KgEntityMapper.xml`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceKeywordRepository.java`
- `backend/app-api/src/main/resources/mapper/palace/PalaceKeywordMapper.xml`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/ShareLandingRepository.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/ConversationSessionMapper.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/AppApiApplication.java`
- `backend/db-migration/pom.xml`
