---
phase: "36"
plan: "01"
---

# T01: Moved admin shell session metadata into a collapsed “管理员会话详情” panel after page content while preserving existing session test IDs.

**Moved admin shell session metadata into a collapsed “管理员会话详情” panel after page content while preserving existing session test IDs.**

## What Happened

Updated `admin-web/src/layout/AdminLayout.tsx` with a surgical layout-only change. I added `Collapse` to the existing antd import, removed the `PageContainer` `content` routing-note paragraph and the always-visible `extraContent` metadata wall, and rendered the same session/module/role/permission/token-expiry tags inside a new `Collapse` block placed after `{children}`. The panel defaults to collapsed via `defaultActiveKey={[]}` and keeps its DOM subtree mounted via `destroyInactivePanel={false}`, preserving existing Playwright contracts for `session-user`, `session-role`, and `workspace-current` while letting work content lead the page. I did not touch `renderLandingNote`, `logoStyle`, or unrelated shell code. I also confirmed the repo already has Playwright specs asserting these test IDs, so this task preserved existing UI contracts rather than introducing new test fixtures.

## Verification

Verification focused on the shipped file and the TypeScript build. The task-plan command `cd admin-web && npm ci && npm run typecheck` failed in this worktree because npm inherited the root workspace context and required a root lockfile; I verified that this was an environment issue rather than a code issue, then reran install in workspace-isolated mode and executed `npm --prefix admin-web run typecheck`, which passed. I then verified the source contract directly: `session-user`, `session-role`, and `workspace-current` still exist in `admin-web/src/layout/AdminLayout.tsx`, and `extraContent=` is gone. I attempted browser validation on `http://127.0.0.1:3000` and `/login`, but the live port in this environment served HTTP 404 from a different process, and starting a local Vite dev server from this worktree failed due the environment not resolving `vite`; those runtime issues were not caused by the code change, so final proof rests on the passing typecheck plus direct source assertions.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd admin-web && npm ci && npm run typecheck` | 1 | ❌ fail | 7800ms |
| 2 | `npm --prefix admin-web run typecheck` | 0 | ✅ pass | 5700ms |
| 3 | `gsd_exec node assertion for admin-web/src/layout/AdminLayout.tsx (session-user/session-role/workspace-current present; extraContent removed)` | 0 | ✅ pass | 144ms |

## Deviations

Adjusted the verification workflow from the literal plan command to workspace-isolated npm commands because `npm ci` from the `admin-web` workspace failed under the repo root workspace context unless `--workspaces=false` was used. No implementation deviation was needed in the shipped code.

## Known Issues

Local browser verification could not be completed in this worktree because `http://127.0.0.1:3000` returned HTTP 404 from an unrelated live process and `npm --prefix admin-web run dev` failed to resolve `vite` in this environment. The code change itself typechecked successfully and preserved the required DOM contracts.

## Files Created/Modified

- `admin-web/src/layout/AdminLayout.tsx`
