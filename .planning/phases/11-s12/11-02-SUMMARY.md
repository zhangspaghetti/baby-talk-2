---
phase: "11"
plan: "02"
---

# T02: Aligned `/overview` route auth with the four-domain backend contract and added browser proofs for forbidden deep-links plus hidden-domain fail-closed rendering.

**Aligned `/overview` route auth with the four-domain backend contract and added browser proofs for forbidden deep-links plus hidden-domain fail-closed rendering.**

## What Happened

I kept the fix surgical. In `admin-web/src/app/routes.tsx`, the Overview route now mirrors the admin-api overview envelope exactly by requiring only the four overview-domain permissions (`rag:read`, `kg:read`, `mentor:audit`, `distribution:read`) instead of also admitting `users:read`. That preserves the existing landing behavior in `default-landing.ts`: super admins and true multi-domain admins still land on `/overview`, single-domain overview readers still land on their own module first, and `users:read`/admin-only accounts no longer deep-link into Overview at all.

I then tightened the proof surface rather than refactoring already-correct runtime code. The existing `OverviewPage` + `overviewClient` flow already derived boss-strip truth from backend transport plus client connectivity, kept last-good snapshots during fallback, and rendered hidden domains fail-closed, so I left those files untouched after verification instead of rewriting working logic. I updated browser proofs to match the corrected contract: `auth-and-rbac.spec.ts` now proves a `users:read`-only admin is redirected to `/403` when deep-linking `/overview`, and `overview-control-plane.spec.ts` now proves a single-domain `distribution:read` admin can deep-link into `/overview` while only the distribution card renders and the other three domains stay hidden/fail-closed. I also updated the route-access unit proof in `access-and-landing.spec.ts` so users/admin-only identities no longer report Overview as an accessible route.

## Verification

`npm --prefix admin-web run build` passed, and because `admin-web/tsconfig.json` includes `tests/`, that typecheck covered the updated Playwright specs as well as the app code. `cmd.exe /c "backend\\mvnw.cmd -f backend\\pom.xml -q -pl admin-api -am test -Dtest=AdminOverviewWebTest"` passed once invoked through `cmd.exe /c`, confirming the backend overview contract still holds with the tightened frontend route envelope.

The compose-backed browser/runtime checks did not reach product assertions in this environment. `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts overview-control-plane.spec.ts` failed in Playwright global setup when `docker compose up -d --build` hit Docker Desktop Linux engine HTTP 500 responses while resolving images/containers. `dart run tool/verify_m006_s12_control_plane_freshness.dart` failed at its `overview browser proof pack` step for the same Docker Desktop 500 during compose boot, after re-running a successful admin-web build. No code-level browser assertion failure was surfaced before the runtime boot failure.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run build` | 0 | ✅ pass | 27400ms |
| 2 | `cmd.exe /c "backend\\mvnw.cmd -f backend\\pom.xml -q -pl admin-api -am test -Dtest=AdminOverviewWebTest"` | 0 | ✅ pass | 99200ms |
| 3 | `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts overview-control-plane.spec.ts` | 1 | ❌ fail | 99200ms |
| 4 | `dart run tool/verify_m006_s12_control_plane_freshness.dart` | 1 | ❌ fail | 129000ms |

## Deviations

None. I verified that `default-landing.ts`, `overviewClient.ts`, and `OverviewPage.tsx` already satisfied the planned landing and boss-strip/fallback contract, so I kept the implementation to route-metadata and proof updates only.

## Known Issues

Docker Desktop's `desktop-linux` engine is currently returning HTTP 500 during `docker compose up -d --build`, which blocks the Playwright proof pack and the slice verifier before app-level browser assertions run. This is an environment/runtime issue, not a reproduced app-contract failure.

## Files Created/Modified

- `admin-web/src/app/routes.tsx`
- `admin-web/tests/access-and-landing.spec.ts`
- `admin-web/tests/auth-and-rbac.spec.ts`
- `admin-web/tests/overview-control-plane.spec.ts`
