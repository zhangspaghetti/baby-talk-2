---
phase: "08"
plan: "02"
---

# T02: Replaced the Overview placeholder with a real freshness control plane and polling/recovery proof pack

**Replaced the Overview placeholder with a real freshness control plane and polling/recovery proof pack**

## What Happened

Implemented the missing S12 frontend seam that T01 was waiting on. I added `admin-web/src/lib/overviewClient.ts` as a strict Overview contract client: it parses `/api/admin/overview/summary`, validates domain/transport payloads, and subscribes to `/api/admin/overview/stream` via `fetch` + SSE parsing so the stateless Bearer-auth admin shell can keep using refresh/session-reset semantics. Then I replaced the placeholder `OverviewPage.tsx` with a real control-plane surface: a boss strip that shows `live` / `polling` / `recovered`, visible last-good snapshot time, transport counters, and inline diagnostics; per-domain cards for ingestion, KG, mentor audit, and distribution; bounded polling fallback that preserves the last successful snapshot; and explicit resume actions for realtime and polling recovery instead of silently freezing the page.

I also tightened the proof pack around that surface. `admin-web/tests/auth-and-rbac.spec.ts` now proves super admins land on a truthful Overview instead of a placeholder. The new `admin-web/tests/overview-control-plane.spec.ts` covers the S12 browser contract directly: super-admin Overview rendering, one stale domain among fresh domains via summary refresh override, realtime loss to polling fallback using browser offline mode, recovery back to `recovered`, and malformed summary payload handling that surfaces `invalid_response_payload` while preserving the last good snapshot. Finally, I added `docs/runbooks/m006-s12-control-plane-freshness.md` as the operator/reference doc and `tool/verify_m006_s12_control_plane_freshness.dart` as the canonical single-command verifier that reruns the build plus the auth/Overview proof pack.

## Verification

Ran the required admin-web build, the combined auth + Overview Playwright proof pack, and the canonical S12 Dart verifier. `npm --prefix admin-web run build` passed after type-checking the new Overview client/page and bundling the updated admin shell. `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts overview-control-plane.spec.ts` passed with 11 Playwright checks covering login/RBAC regressions plus the new Overview control-plane truth, stale-domain contract, realtime loss → polling fallback → recovery, and malformed summary handling. `dart run tool/verify_m006_s12_control_plane_freshness.dart` then reran the build plus the same browser proof pack successfully, proving the new verifier artifact is wired correctly.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run build` | 0 | ✅ pass | 29000ms |
| 2 | `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts overview-control-plane.spec.ts` | 0 | ✅ pass | 101300ms |
| 3 | `dart run tool/verify_m006_s12_control_plane_freshness.dart` | 0 | ✅ pass | 131400ms |

## Deviations

Used a fetch-based SSE client instead of the browser’s native `EventSource` because `/api/admin/overview/stream` is protected by Bearer auth and must reuse the existing refresh/session-reset semantics. For the realtime-loss proof, I used Playwright’s browser-offline toggle to trigger an actual stream drop after login rather than depending on a brittle first-mount route mock.

## Known Issues

Pre-existing Vite chunk-size warnings still appear during `npm --prefix admin-web run build`; this task did not change bundle-splitting strategy.

## Files Created/Modified

- `admin-web/src/lib/overviewClient.ts`
- `admin-web/src/pages/OverviewPage.tsx`
- `admin-web/src/app/routes.tsx`
- `admin-web/tests/auth-and-rbac.spec.ts`
- `admin-web/tests/overview-control-plane.spec.ts`
- `docs/runbooks/m006-s12-control-plane-freshness.md`
- `tool/verify_m006_s12_control_plane_freshness.dart`
