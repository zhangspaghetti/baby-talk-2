---
phase: "17"
plan: "02"
---

# T02: Replaced the `/protected` proof with a ProLayout admin shell that derives landing and navigation from the typed route catalog.

**Replaced the `/protected` proof with a ProLayout admin shell that derives landing and navigation from the typed route catalog.**

## What Happened

Added `admin-web/src/app/access.ts` and `admin-web/src/app/default-landing.ts` so route visibility, overview exposure, and role-aware default landing all come from one access snapshot over the typed route catalog instead of being recomputed in ad-hoc JSX branches. I also tightened `admin-web/src/app/routes.tsx` with route key/path lookup helpers plus duplicate landing-weight validation, and switched route components to lazy imports so the shell now starts moving toward route-level splitting instead of one eager page bundle.

Added `admin-web/src/layout/AdminLayout.tsx` and rewired `admin-web/src/App.tsx` from the old card-style `/protected` switcher into a nested route shell. `/protected` is now only a compatibility alias that resolves into real module routes, while `/overview`, `/users`, `/knowledge-ops`, `/mentor/audits`, and `/distribution/stats` are the truthful mounted workspaces. The layout now owns the left nav, current page title, current identity, roles/permissions, visible-module set, token expiry timestamps, and logout action in header/page chrome; bootstrap failures on `/api/admin/me` fail closed and keep logout visible instead of leaking every module.

To keep verification attached to the new helpers and UI behavior, I added `admin-web/tests/access-and-landing.spec.ts` for pure route-access / default-landing cases, and updated the existing Playwright smoke specs to reflect the new shell semantics: super_admin now lands on Overview, while a single-domain distribution admin lands directly in Distribution Stats with mentor navigation hidden.

## Verification

Verified the T02 shell through both compile-time and browser-facing checks. `npm --prefix admin-web run build` passed, proving the new access helpers, route catalog, lazy page wiring, AdminLayout shell, and nested App routing compile and bundle together. `npm --prefix admin-web run test:e2e -- access-and-landing.spec.ts` passed all 5 checks covering single-domain landing, multi-domain overview landing, fail-closed unknown permissions, duplicate landing-weight rejection, and safe unknown route lookup. `npm --prefix admin-web run test:e2e -- admin-login.spec.ts` passed all 3 smoke tests covering unauthenticated redirect to `/login`, visible bad-credential failure, and super_admin landing on `/overview` with shell navigation visible. `npm --prefix admin-web run test:e2e -- distribution-stats.spec.ts --grep "lands distribution-only admins"` passed, proving a single-domain admin lands in `/distribution/stats` and does not see mentor-only navigation.

As expected for an intermediate slice task, I did not run the slice-level backend auth tests (`AdminAuthWebTest`, `AdminRbacWebTest`) or the canonical `auth-and-rbac.spec.ts`; those belong to T03/T05 once the shared auth seam, explicit `/403`, and refresh replay behavior are in place.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run build` | 0 | ✅ pass | 24000ms |
| 2 | `npm --prefix admin-web run test:e2e -- access-and-landing.spec.ts` | 0 | ✅ pass | 140500ms |
| 3 | `npm --prefix admin-web run test:e2e -- admin-login.spec.ts` | 0 | ✅ pass | 85300ms |
| 4 | `npm --prefix admin-web run test:e2e -- distribution-stats.spec.ts --grep "lands distribution-only admins"` | 0 | ✅ pass | 87300ms |

## Deviations

Added `admin-web/tests/access-and-landing.spec.ts` plus updated existing Playwright smoke specs even though the written task verification only required `npm --prefix admin-web run build`; this kept the new access/landing rules executable instead of implicit. I also retained `/protected` as a redirect-only compatibility alias rather than deleting it outright, so existing entry points and pending tests can transition without reintroducing a second landing implementation.

## Known Issues

Vite still reports one large shared shell chunk (`dist/assets/index-BoMUGm_m.js` ~1.05 MB) even after moving page modules to lazy imports; further chunking/manual split work is still warranted in later tasks. Also, the current Playwright config always runs compose-backed global setup, so even the new pure helper spec pays full container boot cost until a lighter-weight test config exists.

## Files Created/Modified

- `admin-web/src/App.tsx`
- `admin-web/src/layout/AdminLayout.tsx`
- `admin-web/src/app/access.ts`
- `admin-web/src/app/default-landing.ts`
- `admin-web/src/app/routes.tsx`
- `admin-web/tests/access-and-landing.spec.ts`
- `admin-web/tests/admin-login.spec.ts`
- `admin-web/tests/mentor-audit.spec.ts`
- `admin-web/tests/distribution-stats.spec.ts`
