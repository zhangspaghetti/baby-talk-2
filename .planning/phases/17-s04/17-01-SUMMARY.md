---
phase: "17"
plan: "01"
---

# T01: Added Warm Paper admin tokens, a typed route catalog, and truthful module placeholders to seed the S04 shell.

**Added Warm Paper admin tokens, a typed route catalog, and truthful module placeholders to seed the S04 shell.**

## What Happened

Updated `admin-web/package.json` and regenerated `package-lock.json` to add the S04 baseline dependencies (`@ant-design/pro-components`, `@ant-design/icons`, `axios`, `@types/node`) plus an explicit `typecheck` gate in the build script. I then added `tsconfig.json` and `tsconfig.node.json` so both app code and Vite/Playwright config files compile under a stable TypeScript baseline instead of implicit defaults.

Added `admin-web/src/app/theme.ts` to map the Warm Paper admin sub-theme from `DESIGN.md` / `M006-CONTEXT.md` into Ant Design tokens, then wired `src/main.tsx` and the existing mentor/distribution pages to that palette so the previous purple primary/gradient foundation is gone. The mentor/distribution pages still keep their truthful page-local data behavior, but their user tags, selected-card borders, progress bars, and charts now inherit the warm neutral/orange/teal admin palette instead of hard-coded purple accents.

Added `admin-web/src/app/routes.tsx` as the typed route catalog for Overview, Users, Knowledge Ops, Mentor & Safety, and Distribution Stats. The catalog stores path/title/icon/required-permission/nav-visibility/default-landing metadata, validates duplicate keys/paths at module load time, and reuses the backend permission vocabulary directly. I also added truthful placeholder pages for Overview, Users, and Knowledge Ops that deliberately show only real identity/permission context and future module scope, not fake queues or KPI cards.

Finally, I rewired `admin-web/src/App.tsx` so the existing login + `/protected` proof now resolves module buttons, titles, default-route behavior, and page rendering from the typed route catalog instead of the old inline workspace array. That keeps the current shell simple for T01 while retiring the main path/title/permission duplication ahead of the later ProLayout/auth-provider tasks. Per the slice-first testing rule, I also created `admin-web/tests/auth-and-rbac.spec.ts` as an intentionally failing placeholder for the later canonical browser proof file.

## Verification

Ran the slice task verification command `npm --prefix admin-web run build` after installing the new dependencies. The build now executes the explicit TypeScript baseline first (`tsc --noEmit -p tsconfig.json && tsc --noEmit -p tsconfig.node.json`) and then completes a Vite production build successfully, proving the new package baseline, route catalog, theme wiring, placeholder pages, and App integration all compile together.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run build` | 0 | ✅ pass | 25841ms |

## Deviations

I extended `admin-web/src/App.tsx` in T01 to consume the new route catalog immediately so path/title/permission metadata no longer stays duplicated in JSX while we wait for the ProLayout task. I also created `admin-web/tests/auth-and-rbac.spec.ts` as an intentionally red placeholder because this is the first task in the slice and the canonical browser-proof file must exist before the later auth/RBAC tasks make it green.

## Known Issues

`npm --prefix admin-web run build` now succeeds, but the production bundle warning regressed to a single ~1.13 MB JS chunk after adding ProComponents baseline dependencies. That is acceptable for this seed task, but T02/T04 should keep shell work thin and start preparing route-level lazy loading before the admin shell grows further.

## Files Created/Modified

- `admin-web/package.json`
- `admin-web/package-lock.json`
- `admin-web/tsconfig.json`
- `admin-web/tsconfig.node.json`
- `admin-web/src/app/theme.ts`
- `admin-web/src/app/routes.tsx`
- `admin-web/src/App.tsx`
- `admin-web/src/main.tsx`
- `admin-web/src/pages/OverviewPage.tsx`
- `admin-web/src/pages/UsersPage.tsx`
- `admin-web/src/pages/KnowledgeOpsPage.tsx`
- `admin-web/src/pages/MentorAuditPage.tsx`
- `admin-web/src/pages/DistributionStatsPage.tsx`
- `admin-web/tests/auth-and-rbac.spec.ts`
