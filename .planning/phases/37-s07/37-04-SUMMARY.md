---
phase: "37"
plan: "04"
---

# T04: Extracted KG review into KgSurface, restored KG surface fetching, and slimmed contradiction queue rows.

**Extracted KG review into KgSurface, restored KG surface fetching, and slimmed contradiction queue rows.**

## What Happened

Added `admin-web/src/components/workbench/KgSurface.tsx` and moved the KG contradiction queue/detail/notifications state, callbacks, refresh effect, action feedback, and JSX out of `KnowledgeOpsPage.tsx`. Kept the page as the URL/canonical-query orchestrator by passing `query`, `onPatchQuery`, `canRead`, `canReview`, and `needsCanonicalQuery` into the new surface, so the surface remains URL-agnostic and does not call `useSearchParams()`. The new surface owns the KG diagnostics card, restores the missing KG fetch trigger on active KG deep links/reloads, removes `detectedAt` and `adminNotes` from contradiction queue rows while preserving them in the detail pane, and updates the Playwright spec to assert the extracted diagnostics card plus the denser queue row contract.

## Verification

`npm --prefix admin-web run typecheck` passed, `npm --prefix admin-web run build` passed, and source-level checks confirmed that `KgSurface.tsx` contains no `useSearchParams`, the queue row no longer renders `detectedAt`/`adminNotes`, the detail pane still retains those fields, and `KnowledgeOpsPage.tsx` is down to 249 lines. I also attempted the slice-level real UI check with `npm --prefix admin-web run test:e2e -- tests/knowledge-ops.spec.ts`, but Playwright global setup failed before the spec could run because this worktree is in compose-free mode without a reusable stack; a follow-up `bash scripts/dev-up-helm-demo.sh` attempt failed immediately with `kind_missing`, so the remaining E2E gap is environmental rather than a code failure in the extracted surface.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run typecheck` | 0 | ✅ pass | 5638ms |
| 2 | `npm --prefix admin-web run build` | 0 | ✅ pass | 28687ms |
| 3 | `rg -n "useSearchParams" admin-web/src/components/workbench/KgSurface.tsx` | 1 | ✅ pass | 32ms |
| 4 | `python -c "from pathlib import Path; text=Path('admin-web/src/components/workbench/KgSurface.tsx').read_text(encoding='utf-8'); qs=text[text.index('title={`KG contradictions (${kgQueueItems.length})`}'):text.index('detail={')]; print('queue_has_detectedAt=', 'label=\"detectedAt\"' in qs); print('queue_has_adminNotes=', 'label=\"adminNotes\"' in qs); print('detail_has_detectedAt=', 'label=\"detectedAt\"' in text[text.index('detail={'):]); print('detail_has_adminNotes=', 'adminNotes=' in text or 'label=\"adminNotes\"' in text[text.index('detail={'):])"` | 0 | ✅ pass | 184ms |
| 5 | `python count KnowledgeOpsPage.tsx lines` | 0 | ✅ pass | 0ms |
| 6 | `npm --prefix admin-web run test:e2e -- tests/knowledge-ops.spec.ts` | 1 | ❌ fail | 183700ms |
| 7 | `bash scripts/dev-up-helm-demo.sh` | 2 | ❌ fail | 4600ms |

## Deviations

Imported `ApiError`/`toApiError` from `admin-web/src/lib/authClient.ts` instead of `knowledgeOpsClient.ts` because that is the real local export location after earlier slice work. Added a stable `knowledge-kg-diagnostics` test id plus two Playwright assertions so the extracted surface and row-density change have an explicit verification anchor.

## Known Issues

Real Playwright runtime verification is blocked in this worktree until a reusable stack exists or `kind` is installed. `npm --prefix admin-web run test:e2e -- tests/knowledge-ops.spec.ts` failed during Playwright global setup because compose-free mode could not reach `http://127.0.0.1:8080/actuator/health`, and `bash scripts/dev-up-helm-demo.sh` failed preflight with `kind_missing`.

## Files Created/Modified

- `admin-web/src/components/workbench/KgSurface.tsx`
- `admin-web/src/pages/KnowledgeOpsPage.tsx`
- `admin-web/tests/knowledge-ops.spec.ts`
