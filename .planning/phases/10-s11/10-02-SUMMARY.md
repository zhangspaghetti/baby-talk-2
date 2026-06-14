---
phase: "10"
plan: "02"
---

# T02: Added the distribution stats workspace, live workspace resolver, and browser proof for protected landing plus URL-backed filters.

**Added the distribution stats workspace, live workspace resolver, and browser proof for protected landing plus URL-backed filters.**

## What Happened

Implemented `admin-web/src/lib/distributionStatsClient.ts` as the browser-side contract parser for `GET /api/admin/distribution/stats`, validating the applied filters, section summaries, funnel/handoff payloads, and normalized detail rows before rendering. Added `admin-web/src/pages/DistributionStatsPage.tsx` using the existing page-local fetch + URL query pattern: it canonicalizes only missing `range`/`channel` params to `30d`/`all`, preserves invalid query values so backend 400s remain inspectable, renders current admin/query context, release/share overview cards, a lightweight SVG release trend, share funnel progress rows, share→release handoff summary/table, and the normalized detail table, while keeping section context visible across loading/error/empty states and showing the release-only channel scope note explicitly.

Generalized `admin-web/src/App.tsx` from the mentor-only shell into a live workspace resolver. The shell now refreshes `/api/admin/me`, resolves `/protected` to the first accessible workspace with `mentor:audit` priority and `distribution:read` fallback, exposes a visible workspace switcher, keeps direct unauthorized workspace hits in a warning state with the accessible switcher instead of dropping back to the old mentor-only stub, and clears local session state on malformed `/api/admin/me` identity payloads. This preserved the mentor audit workspace while letting distribution-only admins land directly in stats.

Added `admin-web/tests/distribution-stats.spec.ts` to seed truthful data through real public endpoints (`POST /api/v1/share-links`, `/share/{token}`, `/share/{token}/download`, `/download`, `/download/redirect`) and then verify the real browser flow: workspace switch into stats, URL-backed `range`/`channel` persistence across reload/back, the release-only channel note, redaction of raw share tokens from the admin table, distribution-only `/protected` landing, and recoverable local error UI for invalid filters. Updated `admin-web/tests/admin-login.spec.ts` so `/protected` now proves the generalized resolver lands super admins in mentor audit and shows both workspace switches, while the existing `mentor-audit.spec.ts` suite continued to pass unchanged against the new shell.

## Verification

Ran `npm --prefix admin-web run build` and confirmed the admin web bundle still builds successfully after the new stats client/page and generalized shell changes. Ran `npm --prefix admin-web run test:e2e -- admin-login.spec.ts mentor-audit.spec.ts distribution-stats.spec.ts`; all 10 Playwright tests passed against the real docker-compose stack, covering super-admin `/protected` landing, mentor audit regression coverage, distribution-only landing into `/distribution/stats`, truthful stats seeded via public app endpoints, URL filter persistence, invalid-filter recovery UI, and token redaction in the rendered admin stats workspace.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run build` | 0 | ✅ pass | 7730ms |
| 2 | `npm --prefix admin-web run test:e2e -- admin-login.spec.ts mentor-audit.spec.ts distribution-stats.spec.ts` | 0 | ✅ pass | 105900ms |

## Deviations

None.

## Known Issues

`npm --prefix admin-web run build` still emits the pre-existing Vite chunk-size warning for the main JS bundle; T02 kept the shell lightweight and did not change chunking strategy.

## Files Created/Modified

- `admin-web/src/App.tsx`
- `admin-web/src/lib/distributionStatsClient.ts`
- `admin-web/src/pages/DistributionStatsPage.tsx`
- `admin-web/tests/admin-login.spec.ts`
- `admin-web/tests/distribution-stats.spec.ts`
