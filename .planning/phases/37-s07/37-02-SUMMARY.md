---
phase: "37"
plan: "02"
---

# T02: Extracted IngestionSurface with URL-agnostic query patching, moved ingestion diagnostics into it, and slimmed ingestion queue rows.

**Extracted IngestionSurface with URL-agnostic query patching, moved ingestion diagnostics into it, and slimmed ingestion queue rows.**

## What Happened

Created `admin-web/src/components/workbench/IngestionSurface.tsx` and moved the ingestion queue/detail state, stale-aware polling, upload/retry actions, refs, derived freshness metadata, diagnostics card, stale banner, and queue/detail JSX out of `KnowledgeOpsPage.tsx` into the new surface. The extracted surface now owns the preserved `knowledge-inline-diagnostics` and `knowledge-ingestion-stale` testids, keeps the queue/detail error alerts local to the ingestion work area, and patches URL state only through the injected `onPatchQuery` callback so the page remains the sole `useSearchParams()` owner. In the queue row density pass, I removed the row-level `totalChunks` and `errorMessage` descriptions so those fields now live only in the detail pane. On the orchestrator side, I added `handlePatchQuery`, removed the ingestion-specific diagnostics/state/effects/handlers from the page, and replaced the inline ingestion block with `<IngestionSurface ... />` while keeping the readonly alert behavior intact.

## Verification

Verified the extraction with a successful `npm --prefix admin-web run typecheck` after materializing local admin-web dependencies in the worktree. Then ran source-level assertions proving that `IngestionSurface.tsx` does not reference `useSearchParams`, still contains the `knowledge-inline-diagnostics` and `knowledge-ingestion-stale` testids, that the orchestrator page dropped the old diagnostics card ownership, that `KnowledgeOpsPage.tsx` fell to 1314 lines from the pre-extraction 2171-line baseline, and that the row-density pass left exactly one `totalChunks` description (detail pane only) and zero row-level `errorMessage` description items. No live backend or browser runtime verification was attempted because this slice's proof level is source-level typecheck plus structural checks; runtime E2E remains deferred to S08.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run typecheck` | 0 | ✅ pass | 5473ms |
| 2 | `python -c "from pathlib import Path; text=Path('admin-web/src/components/workbench/IngestionSurface.tsx').read_text(encoding='utf-8'); print('useSearchParams' in text); raise SystemExit(0 if 'useSearchParams' not in text else 1)"` | 0 | ✅ pass | 179ms |
| 3 | `python -c "from pathlib import Path; text=Path('admin-web/src/components/workbench/IngestionSurface.tsx').read_text(encoding='utf-8'); print('knowledge-inline-diagnostics' in text); raise SystemExit(0 if 'knowledge-inline-diagnostics' in text else 1)"` | 0 | ✅ pass | 180ms |
| 4 | `python -c "from pathlib import Path; text=Path('admin-web/src/components/workbench/IngestionSurface.tsx').read_text(encoding='utf-8'); print('knowledge-ingestion-stale' in text); raise SystemExit(0 if 'knowledge-ingestion-stale' in text else 1)"` | 0 | ✅ pass | 184ms |
| 5 | `python -c "from pathlib import Path; count=len(Path('admin-web/src/pages/KnowledgeOpsPage.tsx').read_text(encoding='utf-8').splitlines()); print(count); raise SystemExit(0 if count < 2171 else 1)"` | 0 | ✅ pass | 179ms |
| 6 | `python -c "from pathlib import Path; text=Path('admin-web/src/pages/KnowledgeOpsPage.tsx').read_text(encoding='utf-8'); print('knowledge-inline-diagnostics' in text); raise SystemExit(0 if 'knowledge-inline-diagnostics' not in text else 1)"` | 0 | ✅ pass | 203ms |
| 7 | `python -c "from pathlib import Path; text=Path('admin-web/src/components/workbench/IngestionSurface.tsx').read_text(encoding='utf-8'); total=text.count('Descriptions.Item label=\"totalChunks\"'); err=text.count('Descriptions.Item label=\"errorMessage\"'); print({'totalChunksLabels': total, 'errorMessageLabels': err}); raise SystemExit(0 if total == 1 and err == 0 else 1)"` | 0 | ✅ pass | 181ms |

## Deviations

Used `cd admin-web && npm ci --workspaces=false` to materialize package-local `node_modules` in this worktree before re-running the plan's `npm --prefix admin-web run typecheck`; `npm --prefix admin-web ci` alone resolved through workspace semantics without leaving a usable local `tsc`. For the structural assertions that were written as `grep`, I used equivalent Python file-content assertions in the final evidence table so exit codes stayed stable under the Windows/bash shell mix.

## Known Issues

None. Remaining line-count reduction for `KnowledgeOpsPage.tsx` is expected follow-on work in T03–T05, not a regression from this task.

## Files Created/Modified

- `admin-web/src/components/workbench/IngestionSurface.tsx`
- `admin-web/src/pages/KnowledgeOpsPage.tsx`
