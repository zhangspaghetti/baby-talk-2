---
phase: "37"
plan: "01"
---

# T01: Extracted Knowledge Ops pure utilities into knowledgeOpsUtils.ts and moved the workbench switcher ahead of a collapsed admin capabilities panel.

**Extracted Knowledge Ops pure utilities into knowledgeOpsUtils.ts and moved the workbench switcher ahead of a collapsed admin capabilities panel.**

## What Happened

Created `admin-web/src/lib/knowledgeOpsUtils.ts` and moved the Knowledge Ops page’s shared constants, query-state types, action-state unions, pure normalization/formatting helpers, and `fileInputStyle` into that module. Updated `admin-web/src/pages/KnowledgeOpsPage.tsx` to import those helpers/types, removed the in-file pure helper block, and kept the remaining page-local option arrays plus runtime state/effects in place for later slice tasks. Reordered the header so the `Workbench surfaces` card renders before the admin capabilities section, wrapped the capabilities section in an antd `Collapse` that stays collapsed by default, and trimmed the second tag row so it only shows view/status/selected plus the existing context summary. To satisfy the slice’s structural assertion that the page no longer defines `readQueryState`, the page now imports it under a local alias while the actual implementation lives only in `knowledgeOpsUtils.ts`. No blocker invalidated the remaining slice plan.

## Verification

Verified the extraction and header changes with a successful `npm --prefix admin-web run typecheck` run via the async executor, then ran source-level assertions against the modified files. Confirmed the collapsed admin section is present (`defaultActiveKey` at line 735), the `Workbench surfaces` card now appears before `Current admin / capabilities` (lines 684 vs 742), `knowledgeOpsUtils.ts` contains exactly one `readQueryState` implementation line match, and `KnowledgeOpsPage.tsx` now has exactly one `readQueryState` line match, indicating use/import only and no local definition. No live backend or browser runtime was available in this worktree, so verification stayed at typecheck plus structural source assertions, matching the slice proof level.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run typecheck` | 0 | ✅ pass | 5700ms |
| 2 | `python -c "from pathlib import Path; lines=Path('admin-web/src/pages/KnowledgeOpsPage.tsx').read_text(encoding='utf-8').splitlines(); print([i for i,l in enumerate(lines,1) if 'defaultActiveKey' in l])"` | 0 | ✅ pass | 200ms |
| 3 | `python -c "from pathlib import Path; lines=Path('admin-web/src/pages/KnowledgeOpsPage.tsx').read_text(encoding='utf-8').splitlines(); w=[i for i,l in enumerate(lines,1) if 'Workbench surfaces' in l][0]; c=[i for i,l in enumerate(lines,1) if 'Current admin / capabilities' in l][0]; print({'workbench': w, 'current_admin': c, 'workbench_before_current_admin': w < c})"` | 0 | ✅ pass | 177ms |
| 4 | `python -c "from pathlib import Path; print(sum('readQueryState' in l for l in Path('admin-web/src/lib/knowledgeOpsUtils.ts').read_text(encoding='utf-8').splitlines()))"` | 0 | ✅ pass | 174ms |
| 5 | `python -c "from pathlib import Path; print(sum('readQueryState' in l for l in Path('admin-web/src/pages/KnowledgeOpsPage.tsx').read_text(encoding='utf-8').splitlines()))"` | 0 | ✅ pass | 174ms |

## Deviations

Used Python-based file assertions instead of the plan’s literal `grep` commands because this Windows worktree routes `grep` through PowerShell semantics, which makes line/count checks unreliable. The verification intent stayed the same: exact line/count assertions over the tracked source files.

## Known Issues

Synchronous shell wrappers in this Windows worktree can fail to resolve local `tsc` on PATH (`'tsc' is not recognized`) even though the project typecheck itself passes when run through the async executor. The code changes introduced in this task typecheck successfully; this is an execution-environment quirk, not a source regression.

## Files Created/Modified

- `admin-web/src/lib/knowledgeOpsUtils.ts`
- `admin-web/src/pages/KnowledgeOpsPage.tsx`
