# S07 Research: Knowledge Ops Workbench Decomposition

**Slice goal:** KnowledgeOpsPage still restores `view/status/selected` on reload and deep link; operators reach queue/detail work faster; page ownership is smaller and row density is lower.

**Calibration:** Targeted research — known technology (React/TypeScript/antd), new to this specific file. The code is well-understood React patterns applied to a large monolith. Primary risks are mechanical: preserving URL truth invariant and all `data-testid` contracts through structural decomposition.

---

## Requirements Coverage

- **R008** (failure visibility): S07 must not regress failure state surfaces. The inline diagnostics card, stale-poll banner, and per-surface error Alerts are all critical. All must land in the extracted surface components.
- **R034** (continuity): URL truth preservation means the operator's deep-link context is always recoverable. This is the critical non-functional requirement for this slice.

---

## Memory Context (relevant prior captures)

- **MEM384**: `view`, `status`, `selected` query params are a hard invariant; decomposition must preserve deep-link and reload behavior.
- **MEM369**: `view` selects the surface; `status` is surface-specific (ingestion filter, kg filter, palace-rag subview). Invalid `status` must canonicalize.
- **MEM109**: `/knowledge-ops` stays a single route; permission-safe effective surface derived from URL.
- **MEM370**: Run `npm ci` before any TypeScript verification in admin-web worktrees. Use `npm --prefix admin-web run typecheck` from repo root.
- **MEM368**: Missing local `node_modules/.bin/tsc` → `npx tsc --noEmit` resolves wrong package. Use the npm script.

---

## File Inventory

### `admin-web/src/pages/KnowledgeOpsPage.tsx` — 2171 lines

The target. A monolithic component structured as:

| Section | Lines | Notes |
|---|---|---|
| Imports | 1–33 | antd, react, react-router, internal lib |
| Module-level constants | 36–65 | DEFAULT_* values, QUERY_PARAM_KEYS, view option arrays |
| Type definitions | 67–100 | QueryState, KnowledgeQueryPatch, *ActionState discriminated unions |
| Component `KnowledgeOpsPage()` | 102–~1750 | 20+ useState, 2 useRef, 10 useEffect, fetch callbacks, handlers, JSX |
| Sub-components | ~1750–2090 | IngestionActionFeedback, PalaceRagActionFeedback, KgActionFeedback |
| Pure helper functions | ~2090–2171 | readQueryState, patchKnowledgeQuery, normalize*, format*, color* |

**State breakdown inside the component:**

- Ingestion surface: 11 useState + 2 useRef (ingestionJobs, ingestionDetail, loading/error pairs, actionState, poll state, upload form state)
- KG surface: 7 useState (kgQueueItems, kgDetail, notifications, loading/error pairs, kgActionState, resolveDraft)
- Palace RAG surface: 8 useState (bridgeEdges, bridgeDetail, projectionStatus, traceItems, loading/error pairs, palaceRagAction)
- Top-level: 0 new state — URL state is derived via `useMemo` from `useSearchParams`

**JSX structure (work surfaces section, ~1100 lines):**

1. Header: title + description (`<Space>`)
2. `<Card>` "Current admin / capabilities" — 2 `<Space wrap>` rows of tags + context summary text
3. `<Card>` "Workbench surfaces" — view switcher buttons
4. Four alert conditionals (view normalized, status normalized, rag readonly, kg readonly)
5. `<Card>` "Inline diagnostics" — per-surface error/loading tags
6. `canShowIngestionSurface` block (~400 lines): controls card + `<QueuePageShell>` with queue + detail
7. `canShowPalaceRagSurface` block (~430 lines): controls card + 3 conditional sub-views (bridge QueuePageShell, trace list, projection card)
8. `canShowKgSurface` block (~300 lines): controls card + `<QueuePageShell>` with queue + detail + notifications

### `admin-web/src/components/workbench/QueuePageShell.tsx` — 28 lines

Thin grid layout (1.35fr left, 0.95fr right). No state. Accepts `{ queue, detail }` ReactNode props. Already well-extracted — no changes needed.

### `admin-web/src/components/workbench/DetailContainer.tsx` — 20 lines

Thin antd `Card` wrapper. Accepts `{ title, extra, children, size, testId }`. No changes needed.

### `admin-web/src/lib/knowledgeOpsClient.ts` — 460 lines

Stable API client. Exports all view types, filter constants, and async API methods. No changes needed.

### `admin-web/tests/knowledge-ops.spec.ts` — 240 lines

Playwright E2E suite with 2 tests that verify:

1. Full ingestion upload/failure/retry cycle with `selected` URL param tracking
2. RBAC scoped-surface test with deep-link navigation (`?view=kg-review&status=escalated&selected=<id>`)

Both tests use `data-testid` attributes extensively — all must survive decomposition exactly.

---

## URL Truth Mechanism (critical invariant)

```tsx
// These 4 lines are the page's entire URL truth machinery — they MUST stay in the top-level component
const [searchParams, setSearchParams] = useSearchParams();
const query = useMemo(() => readQueryState(searchParams, accessibleViews), [accessibleViews, searchParams]);
const needsCanonicalQuery = !searchParams.has('view') || !searchParams.has('status') || query.viewWasNormalized || query.statusWasNormalized;
const contextSummary = searchParams.toString() || `view=${query.view}&status=${readCanonicalStatus(query)}`;
```

`readQueryState()` normalizes invalid view/status values and sets `viewWasNormalized`/`statusWasNormalized` flags that drive warning alerts. The `needsCanonicalQuery` flag guards ALL data-fetch useEffects — they short-circuit until the URL is canonical. This is the core deep-link restore mechanism.

**Rule for decomposition:** `useSearchParams()` must be called **exactly once** in `KnowledgeOpsPage`. Extracted surface components receive `query: QueryState` and `onPatchQuery: (patch: KnowledgeQueryPatch) => void` as props. They MUST NOT call `useSearchParams()` themselves.

The `patchKnowledgeQuery()` function closes over `searchParams` + `setSearchParams` — the page creates a memoized callback:

```tsx
const handlePatchQuery = useCallback(
  (patch: KnowledgeQueryPatch) => patchKnowledgeQuery(searchParams, setSearchParams, patch),
  [searchParams, setSearchParams]
);
```

This callback is passed to surface components as `onPatchQuery`.

---

## Natural Seams for Decomposition

The 3 surfaces share ONLY:

- The `query` object (read-only derived value)
- The `onPatchQuery` callback (URL mutation)
- Permission flags (`canRead*`, `canWrite*`)

Each surface's state, effects, and handlers are fully independent. The `needsCanonicalQuery` guard must be passed as a prop to each surface (or checked inside each surface's useEffect).

**Proposed file layout:**

```
admin-web/src/
  lib/
    knowledgeOpsUtils.ts           [NEW] pure helpers + types (extracted from page)
  components/workbench/
    IngestionSurface.tsx           [NEW] ingestion controls + QueuePageShell
    PalaceRagSurface.tsx           [NEW] palace-rag controls + sub-views
    KgSurface.tsx                  [NEW] kg controls + QueuePageShell + notifications
  pages/
    KnowledgeOpsPage.tsx           [MODIFIED] orchestrator only (~250 lines after extraction)
```

No `src/hooks/` directory currently exists. Keeping extracted logic colocated in `src/components/workbench/` follows the existing component pattern. Surface files can contain both the hook logic and the component in one file (same pattern as the current monolith, just smaller).

---

## Queue Row Density Analysis

Current queue rows show 4 `Descriptions.Item` entries each. Lower-priority items move to the detail pane (they already appear there):

| Surface | Current queue items | Drop from row (detail has it) |
|---|---|---|
| Ingestion | filename, totalChunks, updatedAt, errorMessage | `totalChunks` (rarely actionable in queue); `errorMessage` (already in detail) |
| KG Contradiction | entityTopic, sourceA/sourceB, detectedAt, adminNotes | `adminNotes` (already in detail); `detectedAt` (secondary) |
| Bridge Edge | room A, room B, source books, createdAt | `source books` (already in detail) |

Target: 2–3 items per queue row. This makes the queue scannable and drives operators to the detail pane for full context — which is the correct queue/detail rhythm.

**data-testid note:** Queue row cards use `data-testid={knowledge-*-row-${id}}` — preserving these is mandatory. The `Descriptions.Item` elements inside are not directly tested in the E2E spec, so trimming them is safe.

---

## Page Header UX ("work content leads")

Currently the page shows, in order:

1. Title + description paragraph
2. **"Current admin / capabilities" card** — 2 rows of tags, context summary text
3. **"Workbench surfaces" card** — view switcher buttons
4. Alert banners (normalized view/status, readonly notes)
5. **"Inline diagnostics" card**
6. Work surfaces (controls + queue + detail)

"Operators reach queue/detail work faster" → reorder so view switcher comes **before** the admin caps card. Then collapse the admin caps card using the same antd `Collapse` pattern established in S06 (`defaultActiveKey={[]}`, `destroyInactivePanel={false}` to preserve any testids inside it).

**data-testid audit for the admin caps card:** The `knowledge-ops-page` testid is on the outer `<Space>` — not inside the admin caps card. Scanning the E2E tests: no test targets a testid *inside* the admin capabilities card body (the tags: `knowledge-view-ingestion`, etc. are in the view switcher card below it). So `destroyInactivePanel={false}` is a precaution but the panel can be collapsed without breaking current tests.

The "Inline diagnostics" card (`data-testid="knowledge-inline-diagnostics"`) is targeted in the E2E test. It must stay rendered and visible.

---

## Karpathy Guidelines Applied

- **Surgical changes**: Do not change `knowledgeOpsClient.ts` (stable API client). Do not change `QueuePageShell.tsx` or `DetailContainer.tsx` (already thin). Do not touch the routing configuration in `routes.tsx`.
- **Simplicity first**: Surface components receive props, not their own `useSearchParams` calls. No new state container architectures (no Context, no Zustand, no new state owners).
- **Goal-driven verification**: Each task ends with `npm --prefix admin-web run typecheck` from repo root. Final task verifies URL truth by checking the `readQueryState` path in the orchestrator still receives valid `searchParams`.
- **Do not improve adjacent code**: The `knowledgeOpsClient.ts` pure functions are fine as-is. The existing `QueuePageShell` grid ratios are fine. Match existing antd/theme patterns.

---

## Implementation Landscape (5 Tasks)

### T01: Extract shared utilities + reorder page header

**Files:** `admin-web/src/lib/knowledgeOpsUtils.ts` (NEW), `KnowledgeOpsPage.tsx` (header section only)
**What:** Move pure functions (readQueryState, patchKnowledgeQuery, normalize*, format*, color*, readIngestionFreshnessTag, readCanonicalStatus, etc.) and module-level constants + type definitions out of the page file and into `knowledgeOpsUtils.ts`. Then reorder the page header so view switcher card comes before admin caps card, and wrap admin caps card in `Collapse` with `defaultActiveKey={[]}`.
**Verify:** `npm --prefix admin-web run typecheck` exits 0. `grep "defaultActiveKey" admin-web/src/pages/KnowledgeOpsPage.tsx` finds the collapse. `grep "Workbench surfaces" admin-web/src/pages/KnowledgeOpsPage.tsx` appears before `Current admin`.

### T02: Extract IngestionSurface component + row density pass

**Files:** `admin-web/src/components/workbench/IngestionSurface.tsx` (NEW), `KnowledgeOpsPage.tsx` (remove ingestion block)
**What:** Move all ingestion state (11 useState + 2 useRef), effects (fetch + polling), handlers (handleUpload, handleRetry, resetIngestionPolling), `IngestionActionFeedback` sub-component, and the ingestion JSX section (controls card + QueuePageShell) into `IngestionSurface.tsx`. Props: `{ query: QueryState; onPatchQuery: (p: KnowledgeQueryPatch) => void; canRead: boolean; canWrite: boolean; needsCanonicalQuery: boolean }`. Reduce ingestion queue row to: filename + status (remove totalChunks + errorMessage from row items — both remain in detail).
**Verify:** `npm --prefix admin-web run typecheck` exits 0. `wc -l admin-web/src/pages/KnowledgeOpsPage.tsx` decreases by ~600 lines.

### T03: Extract PalaceRagSurface component + row density pass

**Files:** `admin-web/src/components/workbench/PalaceRagSurface.tsx` (NEW), `KnowledgeOpsPage.tsx` (remove palace-rag block)
**What:** Move all palace-rag state (8 useState), effects, handlers (handleBridgeReview), `PalaceRagActionFeedback`, and the palace-rag JSX section into `PalaceRagSurface.tsx`. Props: same pattern as IngestionSurface. Reduce bridge edge queue row: remove `source books` row item (keep room A, room B, confidence tag — confidence is already in the card title via Tag).
**Verify:** `npm --prefix admin-web run typecheck` exits 0.

### T04: Extract KgSurface component + row density pass

**Files:** `admin-web/src/components/workbench/KgSurface.tsx` (NEW), `KnowledgeOpsPage.tsx` (remove kg block)
**What:** Move all KG state (7 useState), effects, handlers (handleResolve, handleMarkNotificationRead), `KgActionFeedback`, and the kg-review JSX section into `KgSurface.tsx`. Props: `{ query, onPatchQuery, canRead, canReview, needsCanonicalQuery }`. Reduce kg queue row: remove `adminNotes` and `detectedAt` rows (keep entityTopic + sourceA/sourceB + unread count which is already in the Card title via Tag).
**Verify:** `npm --prefix admin-web run typecheck` exits 0.

### T05: Final orchestrator reduction + URL truth validation + typecheck

**Files:** `KnowledgeOpsPage.tsx` (final wire-up + cleanup)
**What:** With the 3 surfaces extracted, the page should now be ~250 lines. Verify the `handlePatchQuery` callback is correctly memoized with `[searchParams, setSearchParams]`. Confirm `needsCanonicalQuery` is passed as a prop to each surface. Clean up any orphaned imports. Run final typecheck.
**Verify:**

- `npm --prefix admin-web run typecheck` exits 0
- `wc -l admin-web/src/pages/KnowledgeOpsPage.tsx` is ≤ 300 lines
- `grep -c "useState" admin-web/src/pages/KnowledgeOpsPage.tsx` is 0 (all state lives in surfaces)
- Deep-link verification grep: `grep "useSearchParams" admin-web/src/pages/KnowledgeOpsPage.tsx` — appears exactly once
- `grep "useSearchParams" admin-web/src/components/workbench/IngestionSurface.tsx` — must NOT appear (no direct URL access in surfaces)

---

## Risks and Constraints

1. **Polling ref capture**: The ingestion polling mechanism uses `ingestionJobsRef` and `ingestionDetailRef` to avoid stale closures inside the timer callback. These refs must move with the ingestion state into `IngestionSurface.tsx`. The timer-based polling effect depends on both refs being in the same closure scope. This is the single highest-risk extraction — test with `knowledge-ops.spec.ts` first.

2. **`needsCanonicalQuery` guard threading**: Every surface's data-fetch `useEffect` checks `needsCanonicalQuery` before firing. This value comes from the top-level page (it depends on `searchParams` which must stay top-level). Pass it as a prop to each surface. Do NOT recompute it inside surface components.

3. **data-testid preservation**: All `knowledge-*` data-testids are tested in the E2E spec. They must survive extraction exactly. The easiest way to verify: grep both old page and new surface files for the full testid list and confirm none are missing.

4. **`patchKnowledgeQuery` signature**: The function takes `(currentSearchParams, setSearchParams, patch)`. When it moves to `knowledgeOpsUtils.ts`, the surface components call it as `onPatchQuery(patch)` where `onPatchQuery` is the memoized callback from the page. Do NOT pass raw `searchParams` or `setSearchParams` to surface components.

5. **E2E test environment**: `knowledge-ops.spec.ts` requires a live backend (docker compose with postgres + admin-api). This test cannot run in the worktree environment. Typecheck + source-level grep verification is the available proof level.

---

## Skills Discovered

None installed — React/TypeScript/antd are already in the codebase. No new libraries or frameworks involved. The `karpathy-guidelines` skill is directly applicable (surgical changes, no speculative abstraction, goal-driven verification).
