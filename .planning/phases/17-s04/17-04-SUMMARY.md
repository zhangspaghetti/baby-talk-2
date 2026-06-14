---
phase: "17"
plan: "04"
---

# T04: Swapped mentor/distribution workspaces onto the shared admin auth seam, preserved URL diagnostics with safe query normalization, and refreshed the workspace Playwright proof.

**Swapped mentor/distribution workspaces onto the shared admin auth seam, preserved URL diagnostics with safe query normalization, and refreshed the workspace Playwright proof.**

## What Happened

I finished the T04 seam swap by removing stale access-token prop plumbing from the admin route shell and making catalog-backed pages read their session/admin context directly from AuthProvider instead of through route props. That required updating `App.tsx`, `app/routes.tsx`, the two real workspaces, and the three placeholder route pages so the shell no longer carries a second auth truth for page rendering.

For `MentorAuditPage` and `DistributionStatsPage`, I kept the existing deep-link, retry, loading, empty, and local error UX, but changed the data fetches to rely only on the shared axios/http-client seam. Page-local 401 handling was deleted so refresh/replay/fail-closed behavior now comes exclusively from the shared auth pipeline. I also made malformed filter query state truthful-but-safe: raw query params remain visible in the page diagnostics, while outbound requests normalize to safe defaults, and the distribution reset path avoids an unnecessary refetch when the normalized request state does not actually change.

I also updated the workspace Playwright specs to match the shipped shell semantics instead of the older proof assumptions. The mentor spec now expects explicit `/403` routing for RBAC denial and the current returnTo+refresh-failure login banner behavior; the distribution/mentor negative-path specs now assert safe query normalization instead of backend-400-on-boot behavior. After those assertions were corrected, the full mentor/distribution browser suite ran green against the compose-backed stack.

## Verification

Verified the implementation with three layers of evidence. `npm --prefix admin-web run build` passed after the route/page seam cleanup, confirming the React/Vite/TypeScript shell still compiles with the new auth-context contract and updated workspace tests. `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest,AdminRbacWebTest` passed on Windows, proving the shared login/refresh/RBAC backend contracts the shell depends on are still intact. Finally, `npm --prefix admin-web run test:e2e -- mentor-audit.spec.ts distribution-stats.spec.ts` passed end-to-end against the compose stack, covering seeded mentor/distribution data, `/403` for restricted admins, stale-session fail-closed redirect, and malformed-query normalization with preserved URL diagnostics.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run build` | 0 | ✅ pass | 20110ms |
| 2 | `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest,AdminRbacWebTest` | 0 | ✅ pass | 31200ms |
| 3 | `npm --prefix admin-web run test:e2e -- mentor-audit.spec.ts distribution-stats.spec.ts` | 0 | ✅ pass | 104500ms |

## Deviations

Extended the cleanup to `OverviewPage`, `UsersPage`, `KnowledgeOpsPage`, and the workspace Playwright specs because removing route-level auth props safely required all catalog-backed pages and their browser proof to consume the same AuthProvider semantics. I inspected `AdminLayout.tsx` per the task plan but left it unchanged because local reality showed no stale access-token plumbing remained there.

## Known Issues

None. The canonical `auth-and-rbac.spec.ts` slice-proof file remains owned by pending task T05, but T04’s workspace-specific seam and browser proof are complete.

## Files Created/Modified

- `admin-web/src/App.tsx`
- `admin-web/src/app/routes.tsx`
- `admin-web/src/lib/mentorAuditClient.ts`
- `admin-web/src/lib/distributionStatsClient.ts`
- `admin-web/src/pages/MentorAuditPage.tsx`
- `admin-web/src/pages/DistributionStatsPage.tsx`
- `admin-web/src/pages/OverviewPage.tsx`
- `admin-web/src/pages/UsersPage.tsx`
- `admin-web/src/pages/KnowledgeOpsPage.tsx`
- `admin-web/tests/mentor-audit.spec.ts`
- `admin-web/tests/distribution-stats.spec.ts`
- `admin-web/src/auth/http-client.ts`
