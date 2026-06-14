---
phase: "19"
plan: "04"
---

# T04: Replaced the Knowledge Ops placeholder with a URL-backed, permission-scoped ingestion/KG workbench and a strict `/api/admin/knowledge/**` client.

**Replaced the Knowledge Ops placeholder with a URL-backed, permission-scoped ingestion/KG workbench and a strict `/api/admin/knowledge/**` client.**

## What Happened

I added `admin-web/src/lib/knowledgeOpsClient.ts` as the typed browser contract for `/api/admin/knowledge/**`, with strict response parsing so malformed payloads fail fast as `invalid_response_payload` instead of rendering partial state. I then rewrote `admin-web/src/pages/KnowledgeOpsPage.tsx` into a single-route workbench that keeps `view`, `status`, and `selected` in the URL, derives a permission-safe effective surface from the raw query, and renders real ingestion and KG review panels with `QueuePageShell` / `DetailContainer` instead of placeholder copy.

On the ingestion side, the page now reads the real queue/detail endpoints, exposes upload and retry actions only when `rag:write` is present, preserves the selected job even when the current filter no longer contains it, and adds bounded polling only for non-terminal rows plus stale/freshness diagnostics for operators. On the KG side, the page reads contradiction detail + notification lists, exposes resolve / mark-read only when `kg:review` is present, and preserves selection/filter context after resolve/read so operators see the resulting ‘selected row no longer in current filter’ state instead of a full reset.

To keep route/access metadata aligned with the page, I expanded the typed admin permission catalog to include `rbac:read`, `rag:write`, and `kg:review`, added a small access helper for known permission checks, and updated the route description to reflect the real workbench. I also upgraded browser coverage: `admin-web/tests/access-and-landing.spec.ts` now proves knowledge-only landings preserve typed write/review capability codes, and `admin-web/tests/knowledge-ops.spec.ts` now scripts real upload/retry plus KG resolve/read flows using compose-backed Playwright and SQL-seeded fixtures.

The implementation is in place and static/frontend + backend contract verification passed. The remaining gap is compose browser proof: the first Playwright run failed in globalSetup due a transient Maven Central SSL handshake during `docker compose up -d --build`; the retry got through image builds but still failed because the compose `admin-api` container never reached healthy state, so the browser spec could not actually execute despite the test file being present and type-checked.

## Verification

Passed: `npm --prefix admin-web run build` completed successfully, including TypeScript checks and Vite production build. Passed: `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminKnowledgeOpsWebTest` completed successfully using the Windows wrapper, which clears the verification gate’s original `./backend/mvnw` shell-path failure.

Attempted but not completed: `npm --prefix admin-web run test:e2e -- knowledge-ops.spec.ts` was run twice. Attempt 1 failed in Playwright globalSetup during `docker compose up -d --build` because the Docker Maven build hit a transient SSL/handshake failure against Maven Central while resolving the Spring Boot parent POM. Attempt 2 got past image dependency resolution and image builds, but globalSetup still failed because the compose `admin-api` container became unhealthy before Playwright could start the browser flow. As a result, compose-backed browser proof is still pending infrastructure stability rather than blocked by a TypeScript or backend contract failure.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run build` | 0 | ✅ pass | 25000ms |
| 2 | `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminKnowledgeOpsWebTest` | 0 | ✅ pass | 11044ms |
| 3 | `npm --prefix admin-web run test:e2e -- knowledge-ops.spec.ts` | 1 | ❌ fail | 660000ms |
| 4 | `npm --prefix admin-web run test:e2e -- knowledge-ops.spec.ts (retry)` | 1 | ❌ fail | 660000ms |

## Deviations

Because there is no tracked public seed API for KG contradictions/notifications or a deterministic browser-only way to manufacture a retryable FAILED ingestion row, the Playwright spec seeds minimal fixture data through `docker compose exec -T postgres psql` instead of relying on incidental local data. This keeps the browser proof deterministic without touching ignored artifacts.

## Known Issues

Compose-backed Playwright verification is not green yet. The browser spec itself is implemented and type-checked, but `admin-web` globalSetup currently fails before the spec body runs because `docker compose up -d --build` is unstable in this environment: first from transient Maven Central SSL during image build, then from `admin-api` staying unhealthy in compose. Re-run the Playwright verification once compose health is stable; the code-level build and focused backend web test already pass.

## Files Created/Modified

- `admin-web/src/lib/knowledgeOpsClient.ts`
- `admin-web/src/pages/KnowledgeOpsPage.tsx`
- `admin-web/src/app/routes.tsx`
- `admin-web/src/app/access.ts`
- `admin-web/tests/access-and-landing.spec.ts`
- `admin-web/tests/knowledge-ops.spec.ts`
