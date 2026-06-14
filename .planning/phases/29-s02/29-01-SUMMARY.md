---
phase: "29"
plan: "01"
---

# T01: Added Flyway V19 unique constraints for palace room/bridge upserts and advanced db-migration smoke coverage to schema version 19.

**Added Flyway V19 unique constraints for palace room/bridge upserts and advanced db-migration smoke coverage to schema version 19.**

## What Happened

Added Flyway V19 to make the palace projection schema safe for the ON CONFLICT writes planned in S02: `palace_rooms` now gets `uq_palace_rooms_wing_room` on `(wing, room)`, and `palace_bridge_edges` now gets `uq_palace_bridge_edges_room_pair` on `(room_a_id, room_b_id)`. Advanced `DbMigrationApplication` to expect schema version `19` with `17` applied migrations, then extended `DbMigrationSmokeTest` so it tracks version `19`, expects seven tracked milestone migrations (`3,14,15,16,17,18,19`), and asserts both new unique-constraint-backed indexes exist. During verification I found the mount-path worktree view could surface stale Maven outputs, so I reran the final build against the resolved M008 worktree root to get authoritative classpath and surefire evidence. This task provides the schema precondition for later ingestion-driven room upserts and bridge proposal dedupe; the slice’s runtime ingestion/projection verification remains for downstream tasks.

## Verification

Ran `mvn -f C:/Users/zhang/.gsd/projects/67565506c51a/worktrees/M008/pom.xml -pl backend/db-migration clean test` against the resolved M008 worktree. The build copied 17 SQL resources, recompiled `DbMigrationApplication` and `DbMigrationSmokeTest`, validated 17 Flyway migrations, applied migrations through `V19 - add palace rooms unique constraint`, and logged `db-migration completed successfully. currentVersion=19, appliedCount=17`. Surefire reported `Tests run: 2, Failures: 0, Errors: 0, Skipped: 0` for `DbMigrationSmokeTest`, which covers the tracked-version count and the two new unique-index assertions. Slice-level ingestion population/logging verification is not expected to pass until later S02 tasks wire the runtime sync service.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn -f C:/Users/zhang/.gsd/projects/67565506c51a/worktrees/M008/pom.xml -pl backend/db-migration clean test` | 0 | ✅ pass | 15174ms |

## Deviations

Verification used `mvn -f C:/Users/zhang/.gsd/projects/67565506c51a/worktrees/M008/pom.xml -pl backend/db-migration clean test` instead of the mount-path-relative Maven invocation because the mount view produced stale target outputs for the same worktree. This did not change code scope; it only ensured the authoritative M008 worktree artifacts were exercised.

## Known Issues

Pre-existing test warnings remain: Testcontainers first probes `tcp://localhost:2375` before falling back to the local npipe Docker socket, and Mockito emits dynamic-agent warnings on JDK 21. They did not affect pass/fail for this task.

## Files Created/Modified

- `backend/db-migration/src/main/resources/db/migration/V19__add_palace_rooms_unique_constraint.sql`
- `backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java`
- `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`
