# S03 Research — Palace RAG Ops Admin Surface

**Date:** 2026-04-27
**Researcher:** auto-mode
**Slice:** S03 — Palace RAG Ops Admin Surface
**Complexity:** Moderate — known patterns, new surface added to existing framework

---

## Summary

S03 extends KnowledgeOpsPage.tsx (admin-web) with a third surface "Palace RAG Ops" and adds the backend endpoints that feed it. All schema, data, and projection machinery was delivered by S02. This slice is purely integration: wire the data into a frontend operator surface. There are no novel architectural decisions — only extending established patterns.

**Karpathy Rule applicable:** Surgical changes only. The `as const` pattern in `KnowledgeOpsPage.tsx` has ~10 discriminant sites. Each must be extended exactly, without refactoring the existing ingestion/kg-review surfaces.

---

## Skills Discovered

No new skills installed. `ant-design` and `spring-boot-engineer` are available but not needed — the existing codebase already demonstrates the correct patterns for both.

---

## Implementation Landscape

### Schema (from V18 + V19, already migrated)

```
palace_rooms          — wing, room, hall, source_book_count, last_updated
palace_bridge_edges   — room_a_id, room_b_id, confidence, status (proposed/approved/rejected),
                        source_book_a, source_book_b, created_at, reviewed_by, reviewed_at
palace_projection_version — version_num, last_ingestion_batch_id, status (current/rebuilding/stale),
                            room_count, created_at
palace_query_traces   — entry_rooms JSONB, temporal_rule_applied, candidates_json JSONB,
                        bridge_edges_crossed JSONB, projection_version_used, queried_at, installation_id
```

`palace_bridge_edges.status` check constraint: `'proposed' | 'approved' | 'rejected'`
`palace_projection_version.status` check constraint: `'current' | 'rebuilding' | 'stale'`

### Backend: admin-api

**Critical constraint:** admin-api has **no JPA**. It uses MyBatis mappers (via `@MapperScan`) and JdbcTemplate. The palace JPA entities (`PalaceBridgeEdge`, `PalaceQueryTrace`, `PalaceProjectionVersion`) live in app-api and are NOT available in admin-api.

**Established palace access pattern (from S02):** `PalaceProjectionSyncService` uses `JdbcTemplate` directly. Same pattern must be used for palace RAG reads.

**Existing controller:** `AdminKnowledgeOpsController` at `/api/admin/knowledge/**`. New palace RAG endpoints go there (or a sibling controller) at `/api/admin/knowledge/palace/**`.

**Permissions model (already wired in Spring Security):**

- `rag:read` → read bridge list, projection status, trace samples
- `rag:write` → approve/reject bridge edges (mutations)
- No new permissions required

**Service pattern:**

- `AdminKnowledgeOpsService` holds all record view types and service methods
- `AdminPalaceRagService` (new) follows same structure: JdbcTemplate queries, `AdminApiContractException` for errors, record view types defined as inner records
- Alternatively: add palace RAG methods directly to `AdminKnowledgeOpsService` (simpler, fewer files). Since the service is already 573 LOC, a new `AdminPalaceRagService` is cleaner.

**JSONB column handling:** JdbcTemplate returns JSONB columns as `PGobject` (value = JSON string). Use `rs.getString("column_name")` and return the raw JSON string to the frontend — the browser can parse it. Alternatively deserialize with ObjectMapper to `JsonNode`, then serialize back. The simplest approach: return the raw JSONB string in the view record as `String`; frontend renders it as-is.

**Bridge edge list endpoint:** must JOIN `palace_rooms` to get wing/room name for each room ID, otherwise the queue shows meaningless UUIDs.

```sql
SELECT
  e.id, e.confidence, e.status,
  e.source_book_a, e.source_book_b,
  e.created_at, e.reviewed_by, e.reviewed_at,
  ra.wing AS room_a_wing, ra.room AS room_a_name,
  rb.wing AS room_b_wing, rb.room AS room_b_name
FROM palace_bridge_edges e
JOIN palace_rooms ra ON ra.id = e.room_a_id
JOIN palace_rooms rb ON rb.id = e.room_b_id
WHERE (:status IS NULL OR e.status = :status)
ORDER BY e.created_at DESC
LIMIT :limit
```

**Projection status endpoint:** simple scalar query against `palace_projection_version WHERE status = 'current' ORDER BY version_num DESC LIMIT 1`. Returns 200 with null-body-safe response (no projection row = `notReady: true` field).

**Trace samples endpoint:** most recent N rows from `palace_query_traces ORDER BY queried_at DESC LIMIT :limit`. Return `candidates_json`, `entry_rooms`, `bridge_edges_crossed` as raw JSON strings for frontend display.

**Approve/reject mutation:** `UPDATE palace_bridge_edges SET status = ?, reviewed_by = ?, reviewed_at = now() WHERE id = ?` — uses the authenticated admin's username as `reviewed_by` (accessible from Spring Security context via `@AuthenticationPrincipal`).

### Frontend: admin-web

**Key files:**

- `admin-web/src/lib/knowledgeOpsClient.ts` — add `'palace-rag'` to `KNOWLEDGE_OPS_VIEWS`, add palace types and client methods
- `admin-web/src/pages/KnowledgeOpsPage.tsx` — add palace-rag surface (view button, status controls, queue, detail)

**Existing patterns to follow precisely:**

- `KNOWLEDGE_OPS_VIEWS = ['ingestion', 'kg-review'] as const` → extend to `['ingestion', 'kg-review', 'palace-rag'] as const`
- `KNOWLEDGE_INGESTION_STATUSES`, `KNOWLEDGE_CONTRADICTION_STATUSES` pattern → add `PALACE_BRIDGE_EDGE_STATUSES = ['proposed', 'approved', 'rejected'] as const`
- Sub-view filter for palace-rag: `PALACE_RAG_SUBVIEWS = ['bridge-review', 'trace-samples', 'projection'] as const`
  - In palace-rag mode, the `status` URL param holds the sub-view name
  - Default: `'bridge-review'`
- `KnowledgeOpsView` union type expands to include `'palace-rag'`

**~10 guard sites in KnowledgeOpsPage.tsx that need updating:**

1. `KNOWLEDGE_OPS_VIEWS` const in knowledgeOpsClient.ts
2. `KnowledgeOpsView` type derivation (implicit from const)
3. `accessibleViews` useMemo — add `palace-rag` when `canReadIngestion` (rag:read)
4. `canShowIngestionSurface` / `canShowKgSurface` → add `canShowPalaceRagSurface = query.view === 'palace-rag'`
5. `readQueryState` — add `palaceRagSubview: PalaceRagSubview` field and normalization
6. `statusWasNormalized` logic — add palace-rag branch
7. `readStatusBadge` function — add palace-rag branch
8. "Workbench surfaces" card buttons — add palace-rag button
9. inline diagnostics card — add palace-rag loading/error tags
10. Readonly-note Alert condition — add palace-rag branch with `rag:write` gating

**Frontend new state needed:**

```typescript
// bridge review state
const [bridgeEdges, setBridgeEdges] = useState<PalaceBridgeEdgeView[]>([]);
const [bridgeLoading, setBridgeLoading] = useState(false);
const [bridgeError, setBridgeError] = useState<ApiError | null>(null);
const [bridgeDetail, setBridgeDetail] = useState<PalaceBridgeEdgeView | null>(null);

// projection status state
const [projectionStatus, setProjectionStatus] = useState<PalaceProjectionStatusView | null>(null);
const [projectionLoading, setProjectionLoading] = useState(false);

// trace samples state
const [traceItems, setTraceItems] = useState<PalaceQueryTraceSampleView[]>([]);
const [tracesLoading, setTracesLoading] = useState(false);

// palace RAG action state
type PalaceRagActionState = ...
```

**URL-state deep-link test (from S03 success criterion):**
`/knowledge-ops?view=palace-rag&status=pending&selected=<bridge-id>` must survive page reload. This is guaranteed by the existing `readQueryState` + `setSearchParams({ replace: false })` pattern — as long as `palace-rag` is added to `KNOWLEDGE_OPS_VIEWS` so `normalizeView()` accepts it, and `bridge-review`/`pending` (or the actual bridge status string) are valid `PalaceRagSubview` values.

Note on "pending" in success criteria: The success criterion uses `status=pending` but bridge edges have statuses `proposed/approved/rejected`. The URL param `status=pending` in the milestone success criterion likely refers to the generic URL template showing the deep-link format, not a literal status value. Implementation should use `status=proposed` as the default/pending bridge sub-state.

---

## Natural Seams / Task Decomposition

### T01 — Backend: AdminPalaceRagService + controller endpoints

**Files touched:**

- `backend/admin-api/src/main/java/.../knowledge/AdminPalaceRagService.java` (new)
- `backend/admin-api/src/main/java/.../knowledge/AdminKnowledgeOpsController.java` (extend)
- `backend/admin-api/src/main/java/.../config/AdminDataAccessConfiguration.java` (register new service bean)

**What to build:**

1. `AdminPalaceRagService` with JdbcTemplate:
   - `getProjectionStatus()` → query `palace_projection_version WHERE status='current'`; if no row, return `{ notReady: true }`
   - `listBridgeEdges(status, limit)` → JOIN palace_rooms, return list of `BridgeEdgeView` with room names
   - `getBridgeEdge(id)` → single row JOIN palace_rooms
   - `approveBridgeEdge(id, reviewedBy)` → UPDATE status='approved'
   - `rejectBridgeEdge(id, reviewedBy)` → UPDATE status='rejected'
   - `listTraceSamples(limit)` → recent query traces, JSONB cols as raw strings
2. Controller endpoints under `/api/admin/knowledge/palace/**` with proper `@PreAuthorize`
3. Record view types as inner records in `AdminPalaceRagService`

**Verify:** `mvn test -pl backend/admin-api -am -Dtest=AdminKnowledgeOpsWebTest` — existing tests still pass (new endpoints don't break anything)

### T02 — Frontend client types

**Files touched:**

- `admin-web/src/lib/knowledgeOpsClient.ts` (extend)

**What to build:**

- Extend `KNOWLEDGE_OPS_VIEWS` to include `'palace-rag'`
- Add `PALACE_RAG_SUBVIEWS`, `PALACE_BRIDGE_EDGE_STATUSES` constants
- Add `PalaceProjectionStatusView`, `PalaceBridgeEdgeView`, `PalaceQueryTraceSampleView` interfaces
- Add parser functions (`parseBridgeEdge`, `parseProjectionStatus`, `parseTraceSample`)
- Add client methods: `getProjectionStatus`, `listBridgeEdges`, `getBridgeEdge`, `approveBridgeEdge`, `rejectBridgeEdge`, `listTraceSamples`

**Verify:** `cd admin-web && npx tsc --noEmit` — TypeScript compiles with no errors

### T03 — Frontend KnowledgeOpsPage.tsx extension

**Files touched:**

- `admin-web/src/pages/KnowledgeOpsPage.tsx` (extend ~400 LOC)

**What to build:**

- Extend `QueryState` type with `palaceRagSubview` field
- Update `readQueryState` / `normalizePalaceRagFilter`
- Update all ~10 guard sites
- Add palace-rag surface (bridge-review queue + detail, projection status card, trace-samples list)
- Bridge review: list of proposed bridge edges with queue-row card, detail panel showing room names + confidence + source books + approve/reject buttons
- Trace samples: chronological list of recent query traces with entry rooms, temporal rule, candidate count
- Projection: simple status card (version_num, room_count, last_ingestion_batch_id, status)
- Permission gating: approve/reject buttons visible only when `canWriteIngestion` (rag:write)

**Verify:** `cd admin-web && npx tsc --noEmit` + reload test at `/knowledge-ops?view=palace-rag&status=bridge-review&selected=<uuid>` showing correct context

### T04 — Integration tests (backend + frontend)

**Files touched:**

- `backend/admin-api/src/test/.../web/AdminKnowledgeOpsWebTest.java` (extend)

**What to build:**

- Extend `resetTables()` (already truncates palace tables in S02)
- Seed palace_rooms + palace_bridge_edges + palace_query_traces rows
- Test: `GET /api/admin/knowledge/palace/projection` → 200 with version fields; no-row case → 200 `notReady: true`
- Test: `GET /api/admin/knowledge/palace/bridge-edges?status=proposed` → list with room names joined
- Test: `PATCH /api/admin/knowledge/palace/bridge-edges/{id}/approve` → status flips to approved
- Test: `PATCH /api/admin/knowledge/palace/bridge-edges/{id}/reject` → status flips to rejected, requires `rag:write`
- Test: `GET /api/admin/knowledge/palace/traces` → list with JSONB fields as strings

**Verify:** `mvn test -pl backend/admin-api -am -Dtest=AdminKnowledgeOpsWebTest`

---

## Key Risks and Constraints

| Risk | Mitigation |
|------|-----------|
| JSONB column handling in JdbcTemplate | Use `rs.getString()` on JSONB columns; PG JDBC driver returns them as Strings. No PGobject casting required. |
| admin-api has no JPA — cannot reuse app-api palace repositories | Use JdbcTemplate exclusively (S02 established pattern) |
| ~10 TypeScript guard sites for `as const` pattern | Enumerate each site explicitly in T03; compile verification catches missed sites |
| "pending" in success criterion vs actual bridge status "proposed" | UI uses "proposed" filter; the `status=pending` in the requirement is illustrative of deep-link format. Implementation uses `proposed` as the proposed-state filter |
| `reviewed_by` in approve/reject mutation | Read from Spring Security principal: `((JwtAuthenticationToken) principal).getName()` — already used in `AdminAuthService` |

---

## Forward Intelligence for the Planner

1. **AdminPalaceRagService uses JdbcTemplate, not MyBatis.** No `@Mapper` interface needed. Register as `@Service` and inject `JdbcTemplate` directly (same as `PalaceProjectionSyncService`). AdminDataAccessConfiguration does NOT need a new @Bean for it (Spring auto-detects `@Service`).

2. **Don't add `AdminPalaceRagService` to `AdminDataAccessConfiguration`** — `@Service` makes it auto-discovered. Only MyBatis repository wrappers go in `AdminDataAccessConfiguration`.

3. **Trace JSONB columns:** `jdbcTemplate.queryForList("SELECT ... FROM palace_query_traces ...")` returns `Map<String, Object>` rows. Cast JSONB columns with `String candidatesJson = (String) row.get("candidates_json");` — this works with PostgreSQL JDBC returning JSONB as String.

4. **Bridge edge approval/rejection needs the current admin's username.** The controller method receives the `JwtAuthenticationToken` as `@AuthenticationPrincipal Authentication authentication` and calls `authentication.getName()` for the subject (username). Pattern: `((JwtAuthenticationToken) authentication).getName()`.

5. **`accessibleViews` for palace-rag:** palace-rag view should be accessible to any admin with `rag:read` (same permission as ingestion). Add `if (canReadIngestion) nextViews.push('palace-rag')` in the `accessibleViews` useMemo in KnowledgeOpsPage.tsx.

6. **Palace RAG default sub-view:** When navigating to palace-rag for the first time (no `status` param), canonicalize to `bridge-review`. The `needsCanonicalQuery` useEffect already handles this pattern.

7. **Existing `AdminKnowledgeOpsWebTest.resetTables()` already truncates palace tables** — no change needed there. Just seed test data in the new test methods.

8. **`readStatusBadge` function** needs a palace-rag branch: when `view === 'palace-rag'`, show `palaceRagSubview` instead of `ingestionStatus`/`kgStatus`.

9. **`statusWasNormalized` in `readQueryState`**: add `|| (normalizedView === 'palace-rag' && normalizePalaceRagFilter(rawStatus) == null)` branch.

10. **The success criterion says `status=pending`** in the deep-link URL. If the frontend uses `proposed` for bridge review but the URL must accept `pending` for backward compat with the spec — map `pending` as an alias for `proposed` in `normalizePalaceRagFilter`. Simpler: just use `proposed` everywhere and satisfy the spirit of the spec.
