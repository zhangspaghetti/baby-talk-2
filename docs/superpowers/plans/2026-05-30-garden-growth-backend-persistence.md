# Garden/Growth Backend Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make fertilizer state and growth summaries cross-device consistent with backend authority, and remove stale share snapshot behavior.

**Architecture:** Use domain-split business APIs. Fertilizer becomes backend-authoritative with idempotent write operations. Growth summaries are read from backend aggregation. Share draft construction reads live authority data instead of long-lived local snapshot copies.

**Tech Stack:** Spring Boot 3.4.4, Flyway, Flutter (Riverpod), Isar (as cache only), Dart test + JUnit.

---

## File Structure Map

### Backend (create)
- Create: `backend/db-migration/src/main/resources/db/migration/V5__create_garden_growth_persistence_tables.sql`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GardenFertilizerController.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GrowthSummaryController.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GardenFertilizerService.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GrowthSummaryService.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GardenFertilizerRepository.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GrowthSummaryRepository.java`

### Backend (modify)
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncController.java`

### Backend tests
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GardenFertilizerControllerTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GrowthSummaryControllerTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/GardenFertilizerServiceTest.java`

### Mobile (modify)
- Modify: `mobile/lib/features/garden/data/repositories/garden_fertilizer_repository.dart`
- Modify: `mobile/lib/features/garden/domain/services/garden_fertilizer_service.dart`
- Modify: `mobile/lib/features/garden/presentation/garden_fertilizer_notifier.dart`
- Modify: `mobile/lib/features/growth/domain/services/growth_stats_service.dart`
- Modify: `mobile/lib/features/share/presentation/share_notifier.dart`
- Modify: `mobile/lib/app/di/repository_providers.dart`

### Mobile (create)
- Create: `mobile/lib/features/garden/data/remote/garden_fertilizer_api_service.dart`
- Create: `mobile/lib/features/growth/data/remote/growth_summary_api_service.dart`

### Mobile tests
- Create: `mobile/test/features/garden/data/remote/garden_fertilizer_api_service_test.dart`
- Create: `mobile/test/features/garden/presentation/garden_fertilizer_notifier_remote_test.dart`
- Create: `mobile/test/features/growth/domain/growth_stats_service_remote_fallback_test.dart`
- Create: `mobile/test/features/share/presentation/share_notifier_live_snapshot_test.dart`

## Task 1: Backend Schema + Idempotency Constraints

**Files:**
- Create: `backend/db-migration/src/main/resources/db/migration/V5__create_garden_growth_persistence_tables.sql`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/GardenFertilizerServiceTest.java`

- [ ] **Step 1: Write the failing migration-verification test**

```java
@Test
void shouldRejectDuplicateClaimByUserAndEventKey() {
    assertThrows(DataIntegrityViolationException.class, () -> {
        repository.insertClaim(userId, "event-1", "req-1");
        repository.insertClaim(userId, "event-1", "req-2");
    });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && mvn -pl app-api -Dtest=GardenFertilizerServiceTest#shouldRejectDuplicateClaimByUserAndEventKey test`
Expected: FAIL because table/constraint does not exist yet.

- [ ] **Step 3: Add migration with exact constraints**

```sql
create table if not exists garden_fertilizer_state (
  user_id varchar(128) primary key,
  applied_count integer not null default 0,
  last_claimed_at timestamptz,
  last_applied_at timestamptz,
  version bigint not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists garden_fertilizer_claim_log (
  id bigserial primary key,
  user_id varchar(128) not null,
  event_key varchar(128) not null,
  request_id varchar(128) not null,
  claimed_at timestamptz not null default now(),
  unique (user_id, event_key),
  unique (user_id, request_id)
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && mvn -pl app-api -Dtest=GardenFertilizerServiceTest#shouldRejectDuplicateClaimByUserAndEventKey test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/db-migration/src/main/resources/db/migration/V5__create_garden_growth_persistence_tables.sql backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/GardenFertilizerServiceTest.java
git commit -m "feat(db): add fertilizer persistence schema with idempotent constraints"
```

## Task 2: Backend Fertilizer APIs (GET/claim/apply)

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GardenFertilizerController.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GardenFertilizerService.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GardenFertilizerControllerTest.java`

- [ ] **Step 1: Write failing controller tests**

```java
@Test
void claimShouldBeIdempotent() throws Exception {
    mockMvc.perform(post("/api/v1/garden/fertilizer/claim")
        .contentType(APPLICATION_JSON)
        .content("{\"eventKey\":\"e1\",\"requestId\":\"r1\"}"))
      .andExpect(status().isOk());

    mockMvc.perform(post("/api/v1/garden/fertilizer/claim")
        .contentType(APPLICATION_JSON)
        .content("{\"eventKey\":\"e1\",\"requestId\":\"r1\"}"))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.idempotent").value(true));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && mvn -pl app-api -Dtest=GardenFertilizerControllerTest test`
Expected: FAIL (endpoint missing).

- [ ] **Step 3: Implement minimal controller/service**

```java
@PostMapping("/api/v1/garden/fertilizer/claim")
public ClaimResponse claim(@AuthenticationPrincipal UserPrincipal user,
                           @RequestBody ClaimRequest request) {
  return service.claim(user.userId(), request.eventKey(), request.requestId(), request.clientTime());
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && mvn -pl app-api -Dtest=GardenFertilizerControllerTest test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GardenFertilizerController.java backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GardenFertilizerService.java backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GardenFertilizerControllerTest.java
git commit -m "feat(api): add fertilizer state claim/apply endpoints"
```

## Task 3: Backend Growth Summary API

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GrowthSummaryController.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GrowthSummaryService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GrowthSummaryControllerTest.java`

- [ ] **Step 1: Write failing API test for period query**

```java
@Test
void shouldReturnWeekSummary() throws Exception {
  mockMvc.perform(get("/api/v1/growth/summary").param("period", "week"))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.period").value("week"));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && mvn -pl app-api -Dtest=GrowthSummaryControllerTest test`
Expected: FAIL (endpoint missing).

- [ ] **Step 3: Implement endpoint and aggregator bridge**

```java
@GetMapping("/api/v1/growth/summary")
public GrowthSummaryResponse getSummary(@RequestParam String period,
                                        @AuthenticationPrincipal UserPrincipal user) {
  return service.loadSummary(user.userId(), period);
}
```

- [ ] **Step 4: Run tests**

Run: `cd backend && mvn -pl app-api -Dtest=GrowthSummaryControllerTest,AuthConsentSyncServiceTest test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/GrowthSummaryController.java backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GrowthSummaryService.java backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GrowthSummaryControllerTest.java
git commit -m "feat(api): add growth summary query endpoint"
```

## Task 4: Mobile Remote API Integration for Fertilizer

**Files:**
- Create: `mobile/lib/features/garden/data/remote/garden_fertilizer_api_service.dart`
- Modify: `mobile/lib/features/garden/data/repositories/garden_fertilizer_repository.dart`
- Modify: `mobile/lib/features/garden/presentation/garden_fertilizer_notifier.dart`
- Test: `mobile/test/features/garden/data/remote/garden_fertilizer_api_service_test.dart`
- Test: `mobile/test/features/garden/presentation/garden_fertilizer_notifier_remote_test.dart`

- [ ] **Step 1: Write failing remote service test**

```dart
test('claim sends eventKey and requestId', () async {
  final service = GardenFertilizerApiService(client: fakeClient);
  await service.claim(eventKey: 'e1', requestId: 'r1');
  expect(fakeClient.lastRequest.path, '/api/v1/garden/fertilizer/claim');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile; ..\flutter.cmd test test/features/garden/data/remote/garden_fertilizer_api_service_test.dart`
Expected: FAIL (service missing).

- [ ] **Step 3: Implement service + repository fallback strategy**

```dart
Future<ClaimResult> claim({required String eventKey}) async {
  try {
    return await _remote.claim(eventKey: eventKey, requestId: _requestId());
  } catch (_) {
    return _local.claim(eventKey: eventKey);
  }
}
```

- [ ] **Step 4: Run targeted tests**

Run: `cd mobile; ..\flutter.cmd test test/features/garden/data/remote/garden_fertilizer_api_service_test.dart test/features/garden/presentation/garden_fertilizer_notifier_remote_test.dart`
Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/garden/data/remote/garden_fertilizer_api_service.dart mobile/lib/features/garden/data/repositories/garden_fertilizer_repository.dart mobile/lib/features/garden/presentation/garden_fertilizer_notifier.dart mobile/test/features/garden/data/remote/garden_fertilizer_api_service_test.dart mobile/test/features/garden/presentation/garden_fertilizer_notifier_remote_test.dart
git commit -m "feat(mobile): integrate fertilizer remote authority with local fallback"
```

## Task 5: Mobile Growth Remote Read + Share Snapshot Fix

**Files:**
- Create: `mobile/lib/features/growth/data/remote/growth_summary_api_service.dart`
- Modify: `mobile/lib/features/growth/domain/services/growth_stats_service.dart`
- Modify: `mobile/lib/features/share/presentation/share_notifier.dart`
- Modify: `mobile/lib/app/di/repository_providers.dart`
- Test: `mobile/test/features/growth/domain/growth_stats_service_remote_fallback_test.dart`
- Test: `mobile/test/features/share/presentation/share_notifier_live_snapshot_test.dart`

- [ ] **Step 1: Write failing tests for remote-first growth and live share snapshot**

```dart
test('growth summary reads backend first', () async {
  final stats = await service.loadSummary(period: GrowthPeriod.week);
  expect(stats.source, GrowthStatsSource.remote);
});

test('share draft uses live notifier values', () {
  final draft = notifier.buildDraft();
  expect(draft.growthSnapshot, currentGrowthNotifier.snapshot);
});
```

- [ ] **Step 2: Run test to verify failures**

Run: `cd mobile; ..\flutter.cmd test test/features/growth/domain/growth_stats_service_remote_fallback_test.dart test/features/share/presentation/share_notifier_live_snapshot_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement minimal fixes**

```dart
// growth_stats_service.dart
Future<GrowthSummary> loadSummary({required GrowthPeriod period}) async {
  try {
    return await _remoteApi.loadSummary(period: period);
  } catch (_) {
    return _computeLocal(period: period);
  }
}

// share_notifier.dart
ShareDraft buildDraft() {
  final growth = _growthNotifier.currentSnapshot;
  final continuity = _continuityNotifier.currentSnapshot;
  return ShareDraft.fromSnapshots(growth: growth, continuity: continuity);
}
```

- [ ] **Step 4: Run targeted tests**

Run: `cd mobile; ..\flutter.cmd test test/features/growth/domain/growth_stats_service_remote_fallback_test.dart test/features/share/presentation/share_notifier_live_snapshot_test.dart`
Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/growth/data/remote/growth_summary_api_service.dart mobile/lib/features/growth/domain/services/growth_stats_service.dart mobile/lib/features/share/presentation/share_notifier.dart mobile/lib/app/di/repository_providers.dart mobile/test/features/growth/domain/growth_stats_service_remote_fallback_test.dart mobile/test/features/share/presentation/share_notifier_live_snapshot_test.dart
git commit -m "fix(share): read live snapshots and add remote-first growth summary"
```

## Task 6: Verification, Docs, and Rollout Guardrails

**Files:**
- Modify: `docs/superpowers/specs/2026-05-30-garden-growth-backend-persistence-design.md`
- Create: `docs/superpowers/reports/2026-05-30-garden-growth-persistence-verification.md`

- [ ] **Step 1: Add release checklist report template**

```markdown
- [ ] Backend fertilizer APIs healthy
- [ ] Growth summary week/month/year parity verified
- [ ] Share draft no stale snapshot reproduction
- [ ] Fallback rate < threshold
```

- [ ] **Step 2: Run verification commands**

Run:
- `cd backend && mvn -pl app-api test`
- `cd mobile; ..\flutter.cmd test test/features/garden test/features/growth test/features/share`
Expected: tests green.

- [ ] **Step 3: Capture rollout metrics baseline**

```text
Metrics: idempotent_conflict_rate, fallback_to_local_rate, share_stale_snapshot_reports
```

- [ ] **Step 4: Commit docs/report only**

```bash
git add docs/superpowers/specs/2026-05-30-garden-growth-backend-persistence-design.md docs/superpowers/reports/2026-05-30-garden-growth-persistence-verification.md
git commit -m "docs: add persistence rollout verification checklist"
```

## Self-Review

### 1. Spec coverage
- Fertilizer backend authority: covered by Tasks 1, 2, 4.
- Growth backend summary: covered by Tasks 3, 5.
- Share stale snapshot fix: covered by Task 5.
- Migration/gray rollout: covered by Tasks 4 and 6.

### 2. Placeholder scan
- No TODO/TBD placeholders left.
- Every code-changing step includes sample code and command.

### 3. Type consistency
- Fertilizer request identity: `requestId` used consistently in backend and mobile.
- Growth period enum: `week|month|year` consistent across API and client.
- Share fix uses live notifier snapshot in all tasks.
