---
phase: "30"
plan: "03"
---

# T03: Extended KnowledgeOpsPage with Palace RAG bridge review, trace samples, and projection subviews driven by canonical URL state.

**Extended KnowledgeOpsPage with Palace RAG bridge review, trace samples, and projection subviews driven by canonical URL state.**

## What Happened

Updated `admin-web/src/pages/KnowledgeOpsPage.tsx` to add the third Knowledge Ops surface, `palace-rag`, without refactoring the existing ingestion or KG review workbenches. The page now treats `status` as a surface-specific secondary state: ingestion and KG keep their existing filters, while Palace RAG uses it for `bridge-review`, `trace-samples`, and `projection` subviews. I added Palace RAG query normalization so invalid deep links such as `status=pending` canonicalize to `bridge-review`, preserving reload-safe operator context instead of introducing a new query key.

For the new surface, I added frontend state/effects for bridge queue loading, selected bridge detail loading, projection status, trace samples, and approve/reject mutation feedback. Bridge Review renders the proposed-edge queue plus detail actions, Trace Samples renders recent query traces with temporal-rule and candidate-count visibility, and Projection shows either projection metadata or an explicit `notReady` empty state. Read-only `rag:read` operators now get a Palace-specific gating note, bridge 404s are surfaced explicitly in the detail pane, and inline diagnostics include Palace loading/error tags alongside the existing ingestion/KG diagnostics.

## Verification

Verified the frontend contract with `cd admin-web && npx tsc --noEmit`, which passed after the Palace RAG wiring and helper updates. Also ran a browser smoke check against a local Vite dev server by navigating to `http://127.0.0.1:3000/knowledge-ops?view=palace-rag&status=pending&selected=test-edge`; because the admin route is auth-gated, the app redirected to `/login`, but the `returnTo` parameter preserved the Palace deep link and the page rendered without a client-side crash. Browser assertions for the login redirect URL, login heading, and visible form inputs all passed.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd admin-web && npx tsc --noEmit` | 0 | ✅ pass | 5311ms |

## Deviations

Did not add a dedicated frontend unit-test file because `admin-web` currently has no in-repo unit-test harness configured; verification for this task used the slice-prescribed TypeScript compile plus a browser smoke check against the local dev server.

## Known Issues

None.

## Files Created/Modified

- `admin-web/src/pages/KnowledgeOpsPage.tsx`
