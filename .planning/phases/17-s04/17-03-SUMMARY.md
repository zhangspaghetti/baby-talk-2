---
phase: "17"
plan: "03"
---

# T03: Unified admin-web auth around a shared session store, axios refresh retry, and explicit /login /403 guard pages.

**Unified admin-web auth around a shared session store, axios refresh retry, and explicit /login /403 guard pages.**

## What Happened

I split the monolithic `App.tsx` auth logic into a real auth seam under `admin-web/src/auth/`: `auth-api.ts` now owns API contracts/error parsing, `session-store.ts` owns the single `babytalk.admin.session` storage key plus reset banners, `http-client.ts` injects bearer tokens and serializes 401 refresh into a single in-flight replay, and `auth-provider.tsx` exposes shared session/login/logout/reset operations to the React tree. I moved the inline login UI into `pages/LoginPage.tsx`, added a new `pages/ForbiddenPage.tsx`, rewired `App.tsx` to use `RequireAuth` and `RequireAccess`, and changed route helpers so unauthenticated redirects carry a sanitized `returnTo` query while denied routes land on `/403` with explicit query diagnostics. To avoid a large same-task import churn, `src/lib/authClient.ts` now acts as a compatibility facade over the new auth modules, and the existing mentor/distribution clients were switched to the shared protected request pipeline rather than passing ad-hoc Authorization headers from page props. I also updated `admin-login.spec.ts` and `access-and-landing.spec.ts` so the new redirect/query semantics are covered by lightweight browser/helper checks.

## Verification

Verified the task contract with a production front-end build and the backend auth web test, then ran a real browser smoke via Playwright against the compose stack. `npm --prefix admin-web run build` passed after the auth seam refactor, `backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest` passed against Testcontainers-backed admin auth contracts, and `npm --prefix admin-web run test:e2e -- admin-login.spec.ts` passed after updating the redirect expectation from bare `/login` to `/login?returnTo=%2Fprotected`, confirming unauthenticated redirect, visible login banner, bad-credential error, and successful super_admin landing still work with the new provider/guard flow. Because this is an intermediate task, the heavier slice-level `auth-and-rbac.spec.ts` proof is still pending.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run build` | 0 | ✅ pass | 31019ms |
| 2 | `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest` | 0 | ✅ pass | 32770ms |
| 3 | `npm --prefix admin-web run test:e2e -- admin-login.spec.ts` | 0 | ✅ pass | 80062ms |

## Deviations

Kept `admin-web/src/lib/authClient.ts` as a compatibility facade that re-exports the new auth seam so existing placeholder pages/clients did not need a full import migration in the same task. Also updated lightweight route/browser smoke tests to lock the new query-encoded `returnTo` behavior; the heavier `auth-and-rbac.spec.ts` canonical proof remains for the later task that owns full refresh/403 browser evidence.

## Known Issues

`admin-web/tests/auth-and-rbac.spec.ts` is still the slice-level placeholder, so full browser proof for explicit `/403` deep links, refresh replay counting, and revoked-refresh fail-closed behavior remains to the later task that owns the canonical auth/RBAC e2e spec.

## Files Created/Modified

- `admin-web/src/App.tsx`
- `admin-web/src/auth/auth-api.ts`
- `admin-web/src/auth/session-store.ts`
- `admin-web/src/auth/http-client.ts`
- `admin-web/src/auth/auth-provider.tsx`
- `admin-web/src/pages/LoginPage.tsx`
- `admin-web/src/pages/ForbiddenPage.tsx`
- `admin-web/src/app/routes.tsx`
- `admin-web/src/app/access.ts`
- `admin-web/src/lib/authClient.ts`
- `admin-web/src/lib/mentorAuditClient.ts`
- `admin-web/src/lib/distributionStatsClient.ts`
- `admin-web/tests/admin-login.spec.ts`
- `admin-web/tests/access-and-landing.spec.ts`
