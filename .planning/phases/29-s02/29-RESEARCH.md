# S02 Research — Ingestion-Driven Projection Population and Bridge Discovery

**Date:** 2026-04-27
**Researcher:** auto-mode
**Calibration:** Targeted — known Spring patterns, new wiring in a specific module boundary

---

## Summary

S02 wires palace projection population (rooms, version bump, bridge proposals) into the ingestion completion path. The architectural challenge is that **ingestion runs in `admin-api`**, while the palace projection JPA entities live in `app-api`. These are two separate Spring contexts sharing one PostgreSQL database. The solution is a Spring `ApplicationEventPublisher` in `IngestionService` (common) + a `@EventListener` in `admin-api` using `JdbcTemplate` — no JPA needed in admin-api.

All three projection outcomes (rooms populated, version incremented, bridge proposals queued) are achievable without a live LLM call using deterministic taxonomy-based bridge detection.

---

## Recommendation

**Publish IngestionCompletedEvent from common; handle it in admin-api with JdbcTemplate.** This is the minimum-code path that avoids adding JPA to admin-api, avoids cross-module dependency inversion, and stays compatible with the existing dual-ORM convention (JPA in app-api, MyBatis in admin-api).

---

## Implementation Landscape

### Module ownership of key code

| Module | Relevant code | Notes |
|--------|--------------|-------|
| `common` | `IngestionService` | Runs in admin-api context. Has `spring-context` dep — `ApplicationEventPublisher` available. No JPA. |
| `common` | `MemPalaceTaxonomy` | Wing/Room/Hall enum catalog + `resolve(bookTitle)` — deterministic room coords for any book |
| `common` | `IngestionJob`, `IngestionRepository` | MyBatis-backed. `updateCompleted()` commits immediately (no outer tx) |
| `app-api` | `PalaceRoom`, `PalaceBridgeEdge`, `PalaceProjectionVersion` (JPA entities) | Schema already in V18. Lives in `app-api` only. |
| `app-api` | `PalaceRoomRepository`, `PalaceBridgeEdgeRepository`, `PalaceProjectionVersionRepository` | JPA repos. NOT accessible from admin-api context. |
| `admin-api` | `AdminKnowledgeOpsService` → `IngestionService.uploadAndIngest()` | Real ingestion entry point. All book uploads go through admin-api. |
| `admin-api` | `AdminDataAccessConfiguration` | `@Import({AsyncConfiguration.class, EmbeddingConfiguration.class, IngestionService.class})` — AsyncConfiguration brings `@EnableAsync` → `@Async` works in admin-api. |
| `db-migration` | `V18__create_palace_projection_tables.sql` | Creates palace_rooms, palace_bridge_edges, palace_projection_version, palace_query_traces. No UNIQUE constraint on palace_rooms(wing,room) yet. |

### Key gap: no UNIQUE(wing, room) on palace_rooms

V18 creates only a non-unique index `idx_palace_rooms_wing_room`. The `ON CONFLICT (wing, room) DO UPDATE` pattern requires a unique constraint. **V19 migration needed** to add `ALTER TABLE palace_rooms ADD CONSTRAINT uq_palace_rooms_wing_room UNIQUE (wing, room)`.

### IngestionCompletedEvent approach (chosen)

1. **New event record in `common`** (`IngestionCompletedEvent`): carries `jobId: UUID`, `bookTitle: String`, `totalChunks: int`.
2. **IngestionService modification**: inject `ApplicationEventPublisher`; call `publisher.publishEvent(new IngestionCompletedEvent(...))` immediately after `repository.updateCompleted(jobId, outcome.totalChunks())` in `completeProcessing()`.
   - `@Async` is NOT needed on the listener — `completeProcessing()` already runs on the `ingestionExecutor` thread pool (via `CompletableFuture.supplyAsync()`), so the event fires from a worker thread, not the HTTP thread. Running the listener synchronously there is fine and keeps the flow simple.
3. **New `PalaceProjectionSyncService` in `admin-api`**: `@Service` + `@EventListener`. Uses `JdbcTemplate` (Spring Boot auto-configures it in admin-api — confirmed by JdbcTemplate use in `AdminKnowledgeOpsWebTest`).

### PalaceProjectionSyncService responsibilities

**Step 1 — Upsert room:**

```sql
INSERT INTO palace_rooms (id, wing, room, hall, last_updated, source_book_count)
VALUES (uuid_generate_v4(), ?, ?, ?, now(), 1)
ON CONFLICT (wing, room) DO UPDATE SET
    source_book_count = palace_rooms.source_book_count + 1,
    last_updated = now()
```

Uses `MemPalaceTaxonomy.resolve(bookTitle)` to get `wing`, `room`, `hall`.

**Step 2 — Upsert projection version:**

- SELECT current 'current' row. If absent: INSERT (version_num=1, status='current', room_count=1, last_ingestion_batch_id=jobId).
- If present: UPDATE version_num = version_num + 1, room_count, last_ingestion_batch_id.
- This matches `PalaceProjectionVersionRepository.incrementVersion()` semantics already proven in app-api.

**Step 3 — Bridge proposal detection (deterministic):**

```
newRoom = MemPalaceTaxonomy.resolve(bookTitle)  // wing A, room A
existingRooms = SELECT * FROM palace_rooms WHERE wing != ?  // cross-wing only
for each existingRoom:
    overlapFraction = ageRangeOverlap(newRoom.ageRange, existingRoomAgeRange)
    if overlapFraction >= BRIDGE_CONFIDENCE_THRESHOLD (0.3):
        roomAId = SELECT id FROM palace_rooms WHERE wing=? AND room=?  // new room
        roomBId = SELECT id FROM palace_rooms WHERE wing=? AND room=?  // existing
        INSERT INTO palace_bridge_edges ... ON CONFLICT DO NOTHING
```

**Age range overlap**: `MemPalaceTaxonomy.BookMapping.ageRange()` is a string like "0-3" (years). Parse to month spans, compute intersection fraction = intersection / min(span1, span2). Cross-wing pairs with fraction >= 0.3 get proposed.

**Gotcha — insert order**: Room upsert must complete before bridge scan so the new room's UUID is available via SELECT.

**Confidence formula** (example pairs from catalog):

- `EARLY_COMMUNICATION` (0-24mo) in LANGUAGE_DEVELOPMENT + `MOTOR_DEVELOPMENT` (0-12mo) in PHYSICAL → overlap 12mo / min(24,12) = 1.0 → high confidence
- `DISCIPLINE_GUIDANCE` (12-72mo) in PARENTING_SKILLS + `BILINGUAL` (0-72mo) in LANGUAGE_DEVELOPMENT → overlap 60mo / min(60,72) = 1.0 → high confidence

Multiple bridge proposals will be generated for any book in the catalog — the "at least one bridge proposal" success criterion is easily met.

### DbMigrationApplication / SmokeTest updates

`EXPECTED_CURRENT_VERSION` changes from `"18"` → `"19"` and `EXPECTED_APPLIED_MIGRATION_COUNT` from `16` → `17`. The `trackedVersions` assertion also needs `'19'` added. The smoke test also needs to assert the new unique constraint exists.

### Integration test additions

`AdminKnowledgeOpsWebTest.java` already has `awaitIngestionJobStatus(...)` and uploads a real PDF via MockMvc + Testcontainers. S02 integration test adds assertions after `COMPLETED`:

1. `SELECT count(*) FROM palace_rooms WHERE wing = ?` ≥ 1
2. `SELECT version_num FROM palace_projection_version WHERE status = 'current'` is NOT NULL
3. `SELECT count(*) FROM palace_bridge_edges WHERE status = 'proposed'` ≥ 1

The TRUNCATE in `beforeEach` must also clear `palace_rooms, palace_bridge_edges, palace_projection_version` to avoid test ordering pollution.

---

## Files to Create or Modify

| File | Action | Notes |
|------|--------|-------|
| `backend/db-migration/src/main/resources/db/migration/V19__add_palace_rooms_unique_constraint.sql` | CREATE | `ALTER TABLE palace_rooms ADD CONSTRAINT uq_palace_rooms_wing_room UNIQUE (wing, room);` |
| `backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java` | MODIFY | `EXPECTED_CURRENT_VERSION = "19"`, `EXPECTED_APPLIED_MIGRATION_COUNT = 17` |
| `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java` | MODIFY | Add `'19'` to trackedVersions in-set, count 7; assert `uniqueConstraintExists("uq_palace_rooms_wing_room")` |
| `backend/common/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionCompletedEvent.java` | CREATE | `record IngestionCompletedEvent(UUID jobId, String bookTitle, int totalChunks)` |
| `backend/common/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionService.java` | MODIFY | Inject `ApplicationEventPublisher`; add `publisher.publishEvent(...)` after `repository.updateCompleted()` in `completeProcessing()` |
| `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/PalaceProjectionSyncService.java` | CREATE | `@Service`, `@EventListener` for `IngestionCompletedEvent`; JdbcTemplate upserts for rooms + version + bridge proposals |
| `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/knowledge/PalaceProjectionSyncServiceTest.java` | CREATE | Unit tests for age-range overlap formula and bridge proposal detection logic |
| `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminKnowledgeOpsWebTest.java` | MODIFY | Add palace_rooms/palace_bridge_edges/palace_projection_version to TRUNCATE; add post-ingestion projection assertions |

---

## Task Decomposition (for planner)

### T01 — V19 Migration + DbMigration constant updates

- **Files**: `V19__add_palace_rooms_unique_constraint.sql` (new), `DbMigrationApplication.java` (modify), `DbMigrationSmokeTest.java` (modify)
- **Verify**: `mvn test -pl backend/db-migration` → DbMigrationSmokeTest green, version="19", count=17
- **Risk**: None — trivial DDL + constant update

### T02 — IngestionCompletedEvent + IngestionService publisher

- **Files**: `IngestionCompletedEvent.java` (new in common), `IngestionService.java` (modify)
- **Key constraint**: `IngestionService` constructors must remain source-compatible — use constructor injection for `ApplicationEventPublisher`; no impact on existing callers.
- **Verify**: `mvn compile -pl backend/common` + `mvn test -pl backend/app-api -Dtest=IngestionServiceIntegrationTest` still passes (event fires, no listener registered in app-api — Spring silently drops it)
- **Risk**: Low — `ApplicationEventPublisher` is a standard Spring interface

### T03 — PalaceProjectionSyncService in admin-api

- **Files**: `PalaceProjectionSyncService.java` (new in admin-api)
- **Depends on**: T01 (unique constraint), T02 (event exists)
- **Algorithm**: `onIngestionCompleted(@EventListener IngestionCompletedEvent event)` → resolve taxonomy → upsert room → upsert version → bridge scan + proposals
- **Bridge confidence threshold**: 0.30 as private constant; configurable via constructor for test injection
- **JdbcTemplate SQL**: standard; all 3 operations in one event handler method (sequential, not transactional — failure in bridge step logs warning, doesn't roll back room upsert)
- **Verify**: `mvn compile -pl backend/admin-api`

### T04 — Tests

- **Files**: `PalaceProjectionSyncServiceTest.java` (new, unit), `AdminKnowledgeOpsWebTest.java` (modify)
- **Unit test cases**:
  1. `ageRangeOverlapFraction("0-1", "0-3")` = 1.0 (12mo overlap / min(12,36))
  2. `ageRangeOverlapFraction("3-6", "0-1")` = 0.0 (no overlap)
  3. `proposeBridgesFor("language_development", "early_communication", "0-3")` with one cross-wing room "physical/motor_development/0-1" → 1 proposal at confidence 1.0
  4. `proposeBridgesFor(...)` with zero cross-wing rooms → 0 proposals
- **Integration additions to AdminKnowledgeOpsWebTest**: After existing `uploadAndIngestCompletesWithChunks` test, assert projection rows. Add palace tables to TRUNCATE.
- **Verify**: `mvn test -pl backend/admin-api -Dtest=PalaceProjectionSyncServiceTest,AdminKnowledgeOpsWebTest`

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| admin-api's `@EventListener` not firing because `PalaceProjectionSyncService` not scanned | `@Service` annotation ensures component scan picks it up; admin-api uses `@SpringBootApplication` so full component scan is active |
| `IngestionService` constructor change breaks admin-api wiring | Use an overloaded no-`ApplicationEventPublisher` constructor for backwards compatibility, OR inject via the existing constructor — the bean is `@Service` in common so Spring injects it |
| V19 UNIQUE constraint conflicts with existing data in dev/prod | Migration is safe — `palace_rooms` is empty until S02 (V18 only created the table); idempotent by default since first ingestion post-V19 populates it |
| Bridge proposals piling up across test runs | Adding palace tables to the TRUNCATE in `AdminKnowledgeOpsWebTest.setUp()` ensures clean state |
| DbMigrationSmokeTest `EXPECTED_APPLIED_MIGRATION_COUNT` off-by-one | V19 increments to 17; `trackedVersions` in-set must add `'19'` |

---

## Karpathy Rule Applied

**Surgical changes** — `IngestionService` gains exactly one new constructor parameter and one call to `publisher.publishEvent()`. Nothing else changes in the ingestion pipeline. The bridge detection logic lives entirely in the new `PalaceProjectionSyncService` without touching `PalaceHybridRetrievalService` (which already handles traversal of approved edges).

**Minimum code** — JdbcTemplate SQL is the minimum data-access mechanism for admin-api context (no JPA, no new ORM). Bridge algorithm is O(n) over `palace_rooms` count, bounded by the taxonomy (~18 rooms max).
