---
phase: "21"
plan: "01"
---

# T01: Added the M006/S08 runtime verifier and compose-proof scaffolding, but the final canonical browser gate still fails in knowledge-ops polling.

**Added the M006/S08 runtime verifier and compose-proof scaffolding, but the final canonical browser gate still fails in knowledge-ops polling.**

## What Happened

Implemented the repo-root verifier at `tool/verify_m006_s08_release.dart` with explicit runtime step labels, cross-platform command wrappers, compose snapshot parsing, db-migration completion checks, actuator/admin-web reachability checks, stale Playwright report cleanup, and canonical browser-pack enforcement (`auth-and-rbac.spec.ts`, `users-management.spec.ts`, `knowledge-ops.spec.ts`). Updated `admin-web/playwright.global-setup.ts` to optionally reuse an already-started compose stack and to fail closed when `db-migration` has not completed successfully; updated `admin-web/playwright.config.ts` to pin the HTML report output folder. During verification, a real compose defect was found and fixed by changing the `admin-web` healthcheck in `docker-compose.yml` from `localhost` to `127.0.0.1` because wget inside the nginx container was resolving `localhost` to `::1` and keeping the service falsely unhealthy. A second real defect was found in admin-api test wiring: multiple admin web integration tests were still inheriting `app.embedding.mode=openai`, so five admin-api web test classes were updated to force `app.embedding.mode=dev-hash` just like the existing knowledge-ops web test. To keep the runtime verifier aligned with the documented contract of `LlmIntegrationTest` (explicit opt-in via `llm-it`), the backend reactor step in the verifier now runs Maven with `-DexcludedGroups=llm-it` instead of changing any module POM.

At wrap-up time, the runtime verifier reached the final canonical Playwright leg and proved the compose + backend closure up to that point, but the browser pack is still red: `admin-web/tests/knowledge-ops.spec.ts` fails in `expectIngestionReadsToSettle` because the ingestion GET tracker count keeps increasing (`expected 9, received 11`) after the retry flow. Because the unit hit hard timeout recovery, I stopped at the first still-red assertion and am leaving this as the precise resume point instead of continuing investigation.

## Verification

Executed staged verification while building the task. `dart analyze tool/verify_m006_s08_release.dart` passed after the verifier was added. `npm --prefix admin-web run typecheck` passed after the Playwright wiring changes. `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test` passed after the admin-api web tests were switched to `app.embedding.mode=dev-hash`. `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -DexcludedGroups=llm-it` passed, confirming the verifier-side exclusion of opt-in `llm-it` tests works without touching module POMs. The repo-root runtime verifier was run three times: first it failed on a real compose defect (`admin-web` unhealthy due to the localhost/IPv6 healthcheck mismatch), then it failed on the admin-api embedding-mode misconfiguration, and on the final retry it progressed through compose truth and backend reactor tests but failed in the canonical browser pack at `admin-web/tests/knowledge-ops.spec.ts` line 299 (`expectIngestionReadsToSettle`, expected settled poll count 9 but observed 11). No separate bare `npm --prefix admin-web run test:e2e -- ...` rerun was performed after the final verifier failure because the verifier already executes that exact canonical spec command and surfaced the same failing assertion with report, screenshot, video, and trace artifacts.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `dart run tool/verify_m006_s08_release.dart --runtime` | 1 | ❌ fail | 237007ms |
| 2 | `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test` | 0 | ✅ pass | 75000ms |
| 3 | `dart run tool/verify_m006_s08_release.dart --runtime` | 1 | ❌ fail | 261451ms |
| 4 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -DexcludedGroups=llm-it` | 0 | ✅ pass | 85502ms |
| 5 | `dart run tool/verify_m006_s08_release.dart --runtime` | 1 | ❌ fail | 320913ms |

## Deviations

Adjusted the verifier backend step to use `-DexcludedGroups=llm-it` so the runtime gate matches the documented contract of `LlmIntegrationTest` (explicit opt-in only) without modifying backend module POMs. Also updated `docker-compose.yml` to use `127.0.0.1` for the `admin-web` healthcheck after proving that `localhost` inside the nginx container resolved to `::1` and caused a false unhealthy state. Under hard-timeout recovery, I stopped after the first remaining red Playwright assertion instead of continuing investigation into the knowledge-ops polling behavior.

## Known Issues

`admin-web/tests/knowledge-ops.spec.ts` still fails in the happy-path test `handles real ingestion upload/failure/retry and KG mark-read/resolve while keeping context inline`. The failure is in `expectIngestionReadsToSettle` at line 299: after the retry path, the tracked ingestion GET count continues to increase during the second settle window (`expected 9, received 11`). The last successful inspection surface is `admin-web/playwright-report/index.html`; the associated screenshot/video/trace are in `admin-web/test-results/knowledge-ops-knowledge-op-a1125-hile-keeping-context-inline/`.

## Files Created/Modified

- `tool/verify_m006_s08_release.dart`
- `admin-web/playwright.global-setup.ts`
- `admin-web/playwright.config.ts`
- `docker-compose.yml`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminAuthWebTest.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminRbacWebTest.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminUsersWebTest.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminMentorAuditWebTest.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminDistributionStatsWebTest.java`
