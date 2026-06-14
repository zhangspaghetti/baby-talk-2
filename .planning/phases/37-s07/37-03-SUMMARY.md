---
phase: "37"
plan: "03"
---

# T03: Extracted PalaceRagSurface, moved palace diagnostics/failure UI into it, and slimmed bridge queue rows while keeping KnowledgeOpsPage as the URL orchestrator.

**Extracted PalaceRagSurface, moved palace diagnostics/failure UI into it, and slimmed bridge queue rows while keeping KnowledgeOpsPage as the URL orchestrator.**

## What Happened

Created `admin-web/src/components/workbench/PalaceRagSurface.tsx` and moved the palace-rag state, fetch callbacks, refresh effect, action feedback, and all bridge/trace/projection JSX out of `KnowledgeOpsPage.tsx`. The new surface receives `query`, `onPatchQuery`, `canRead`, `canWrite`, and `needsCanonicalQuery`, so deep-link/reload state still flows from the page while the palace diagnostics and per-surface error states now live with the surface itself. I also reduced bridge queue density by removing the `source books` row-level field while keeping source-book detail in the detail pane, then updated the existing Playwright readonly coverage to hit a `view=palace-rag&status=projection` deep link.

## Verification

Code-level verification passed: `npm --prefix admin-web run typecheck` exited 0; `PalaceRagSurface.tsx` contains no `useSearchParams`; `IngestionSurface.tsx` still owns `knowledge-inline-diagnostics` and `knowledge-ingestion-stale`; `KnowledgeOpsPage.tsx` dropped to 762 lines; and the bridge queue no longer renders the `source books` label. I also attempted a targeted Playwright readonly regression for the new palace surface path, but the run failed before tests executed because compose-free E2E mode expected a reusable stack and `app-api` health at `127.0.0.1:8080` never became ready.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run typecheck` | 0 | ✅ pass | 5431ms |
| 2 | `Select-String -Path admin-web/src/components/workbench/PalaceRagSurface.tsx -Pattern 'useSearchParams' -SimpleMatch (expect no matches)` | 0 | ✅ pass | 52ms |
| 3 | `Select-String -Path admin-web/src/components/workbench/IngestionSurface.tsx -Pattern 'knowledge-inline-diagnostics' -SimpleMatch` | 0 | ✅ pass | 4ms |
| 4 | `Select-String -Path admin-web/src/components/workbench/IngestionSurface.tsx -Pattern 'knowledge-ingestion-stale' -SimpleMatch` | 0 | ✅ pass | 2ms |
| 5 | `Get-Content admin-web/src/pages/KnowledgeOpsPage.tsx | Measure-Object -Line (expect < 2171)` | 0 | ✅ pass | 47ms |
| 6 | `Select-String -Path admin-web/src/components/workbench/PalaceRagSurface.tsx -Pattern 'source books' -SimpleMatch (expect no matches)` | 0 | ✅ pass | 3ms |
| 7 | `npm --prefix admin-web run test:e2e -- --grep "keeps sub-surface visibility scoped to the admin capability actually granted and forbids deep-link mutations"` | 1 | ❌ fail | 184600ms |

## Deviations

Used `ApiError`/`toApiError` from `authClient` inside `PalaceRagSurface` instead of `knowledgeOpsClient`, because that is the actual export location in this codebase. Added a minimal readonly Playwright deep-link assertion for `view=palace-rag&status=projection` so the extracted surface has explicit regression coverage.

## Known Issues

Targeted Playwright browser verification is currently environment-blocked in auto-mode: compose-free setup could not find a reusable stack and timed out waiting for `http://127.0.0.1:8080/actuator/health`. The code changes themselves passed type/structure verification.

## Files Created/Modified

- `admin-web/src/components/workbench/PalaceRagSurface.tsx`
- `admin-web/src/pages/KnowledgeOpsPage.tsx`
- `admin-web/tests/knowledge-ops.spec.ts`
