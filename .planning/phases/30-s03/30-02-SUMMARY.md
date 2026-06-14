---
phase: "30"
plan: "02"
---

# T02: Extended knowledgeOpsClient.ts with Palace RAG view constants, typed payload parsers, and admin client methods.

**Extended knowledgeOpsClient.ts with Palace RAG view constants, typed payload parsers, and admin client methods.**

## What Happened

Updated `admin-web/src/lib/knowledgeOpsClient.ts` to extend the knowledge-ops contract with the new Palace RAG surface. I added `palace-rag` to `KNOWLEDGE_OPS_VIEWS`, introduced `PALACE_RAG_SUBVIEWS` / `PALACE_BRIDGE_EDGE_STATUSES`, and exported the corresponding `PalaceRagSubview` / `PalaceBridgeEdgeStatus` unions so downstream UI code can deep-link and branch on a stable typed contract.

Added the three Palace response interfaces from the task plan — `PalaceProjectionStatusView`, `PalaceBridgeEdgeView`, and `PalaceQueryTraceSampleView` — and implemented parser functions for each response shape. To keep the file on the existing parser-boundary pattern, I added a small `readOptionalNumber` helper rather than using ad-hoc casts for optional numeric backend fields like `versionNum`, `roomCount`, and `projectionVersionUsed`.

Extended `knowledgeOpsClient` with the six Palace RAG endpoints T03 depends on: projection status, bridge-edge list/detail, approve/reject mutations, and trace-sample list. The list endpoints reuse the existing query-string builder; bridge-edge status parsing is enum-validated against `PALACE_BRIDGE_EDGE_STATUSES`, so malformed backend payloads still fail fast at the client boundary with `invalid_response_payload`.

The verification gate failure was environmental rather than a code regression: the first `npx tsc --noEmit` ran before local `admin-web/node_modules` existed, so `npx` resolved the placeholder npm `tsc` package instead of the real TypeScript compiler. I installed worktree-local dependencies with `npm ci` and reran verification successfully. Slice-level operator UI/runtime checks remain for later tasks in S03, but this task now retires the client-contract dependency for those UI steps.

## Verification

After the gate failure, I verified the root cause by checking that `admin-web` had no local `node_modules/.bin/tsc`; I then installed the worktree-local frontend dependencies with `npm ci`. With the real compiler present, I ran `cd admin-web && npm run typecheck` to validate both `tsconfig.json` and `tsconfig.node.json`, then reran the task plan’s exact command `cd admin-web && npx tsc --noEmit`. Both commands passed, confirming the new Palace RAG constants, interfaces, parser functions, and client methods compile cleanly in the existing admin web app.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd admin-web && npm run typecheck` | 0 | ✅ pass | 5823ms |
| 2 | `cd admin-web && npx tsc --noEmit` | 0 | ✅ pass | 5338ms |

## Deviations

Installed `admin-web` dependencies in the worktree before verification because the local TypeScript binary was absent. The source-code implementation still stayed within the planned target file.

## Known Issues

None.

## Files Created/Modified

- `admin-web/src/lib/knowledgeOpsClient.ts`
