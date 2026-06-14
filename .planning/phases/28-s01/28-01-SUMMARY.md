---
phase: "28"
plan: "01"
---

# T01: Added V18 palace projection tables and app-api JPA repositories for rooms, bridge edges, versions, and query traces.

**Added V18 palace projection tables and app-api JPA repositories for rooms, bridge edges, versions, and query traces.**

## What Happened

I added `backend/db-migration/src/main/resources/db/migration/V18__create_palace_projection_tables.sql` to create the four projection/query-trace tables required by the slice contract: `palace_rooms`, `palace_bridge_edges`, `palace_projection_version`, and `palace_query_traces`, along with the requested indexes and foreign-key relationships. I kept the migration aligned with existing schema conventions by using UUID primary keys with `uuid_generate_v4()` defaults and timestamp defaults that map cleanly to Java `Instant` fields.

In `backend/app-api`, I introduced a new `com.zhangspaghetti.babytalk.palace.projection` package containing four JPA entities (`PalaceRoom`, `PalaceBridgeEdge`, `PalaceProjectionVersion`, `PalaceQueryTrace`) and four Spring Data JPA repositories (`PalaceRoomRepository`, `PalaceBridgeEdgeRepository`, `PalaceProjectionVersionRepository`, `PalaceQueryTraceRepository`). The query-trace entity uses Hibernate JSON mapping so the future hybrid retrieval service can persist real JSONB payloads for entry rooms, candidate snapshots, and crossed bridge edges without a MyBatis placeholder layer.

Because `app-api` previously had no Spring Data JPA dependency, I added `spring-boot-starter-data-jpa` to `backend/app-api/pom.xml`; without that minimal dependency, the new entities and `JpaRepository` interfaces would not compile. I also updated `DbMigrationApplication` expected version/count constants and extended `DbMigrationSmokeTest` so it now proves V18 is present by checking all four new tables, the expected `palace_rooms`/projection/query-trace columns, and the required indexes via `information_schema`/`pg_indexes`.

## Verification

Verified the migration layer with `./backend/mvnw -f "$WORKTREE/backend/db-migration/pom.xml" -q test -Dtest=DbMigrationSmokeTest`, which applied schema version 18 on a fresh PostgreSQL Testcontainers instance and passed the new table/index assertions. Verified the application layer with `./backend/mvnw -f "$WORKTREE/backend/pom.xml" -q -pl app-api -am -DskipTests compile`, which compiled `app-api` successfully with the new projection entities/repositories and JPA dependency in place.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw -f "$WORKTREE/backend/db-migration/pom.xml" -q test -Dtest=DbMigrationSmokeTest` | 0 | ✅ pass | 17157ms |
| 2 | `./backend/mvnw -f "$WORKTREE/backend/pom.xml" -q -pl app-api -am -DskipTests compile` | 0 | ✅ pass | 9054ms |

## Deviations

Used `DbMigrationSmokeTest` schema assertions as the automated equivalent of the plan's manual `psql \d palace_rooms` inspection, because the test now verifies the same columns/indexes in a self-contained way. Also used `timestamp with time zone` in the migration so the schema matches the repo's existing operational-table conventions and the new Java `Instant` mappings.

## Known Issues

None.

## Files Created/Modified

- `backend/db-migration/src/main/resources/db/migration/V18__create_palace_projection_tables.sql`
- `backend/app-api/pom.xml`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/projection/PalaceRoom.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/projection/PalaceBridgeEdge.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/projection/PalaceProjectionVersion.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/projection/PalaceQueryTrace.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/projection/PalaceRoomRepository.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/projection/PalaceBridgeEdgeRepository.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/projection/PalaceProjectionVersionRepository.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/projection/PalaceQueryTraceRepository.java`
- `backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java`
- `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`
