---
phase: "20"
plan: "01"
---

# T01: Added the mentor/distribution closure proof pack and bounded repo-root verifier, plus fixed test-profile drift exposed by composed verification.

**Added the mentor/distribution closure proof pack and bounded repo-root verifier, plus fixed test-profile drift exposed by composed verification.**

## What Happened

Implemented `admin-web/tests/mentor-distribution-closure.spec.ts` to log a dual-permission admin through the real shell, seed live mentor + distribution data, and prove that mentor incident evidence, live rate-limit context, distribution release-only channel semantics, share-token redaction, and mentor URL context all remain truthful across mentor → distribution → mentor navigation. Added `tool/verify_m006_s07_mentor_distribution.dart` as a repo-root proof pack with explicit step labels, per-step timeouts, and non-zero exits on backend/build/browser failures. Composed verification exposed two local drifts, so I applied the smallest supporting fixes: `backend/admin-api/src/test/resources/application-test.yml` now pins `app.embedding.mode=dev-hash` so focused admin-api MockMvc suites boot deterministically after the EmbeddingConfiguration change, and `admin-web/tests/mentor-audit.spec.ts` now matches the mentor queue list response by exact pathname so a detail 404 cannot satisfy the queue waiter during negative-path proof. I kept scope bounded to proof assembly and minimal diagnostic/test hardening; no mentor audit or distribution runtime feature was reimplemented.

## Verification

Ran the slice verification contract end to end. `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminMentorAuditWebTest,AdminDistributionStatsWebTest` now passes after the admin-api test profile was switched to `dev-hash` embedding mode. `npm --prefix admin-web run test:e2e -- access-and-landing.spec.ts mentor-audit.spec.ts distribution-stats.spec.ts mentor-distribution-closure.spec.ts` passes with the new closure proof and the tightened mentor queue waiter. `dart run tool/verify_m006_s07_mentor_distribution.dart` passes from repo root and replays the focused backend tests, admin-web build, and composed browser pack with explicit failing-step output. During development, the first backend run surfaced the embedding-profile drift and the first verify-tool run hit a transient Maven Central handshake while Playwright’s compose rebuild was pulling dependencies; both issues were retired before the final passing proof run.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminMentorAuditWebTest,AdminDistributionStatsWebTest` | 0 | ✅ pass | 33684ms |
| 2 | `npm --prefix admin-web run build` | 0 | ✅ pass | 28077ms |
| 3 | `npm --prefix admin-web run test:e2e -- access-and-landing.spec.ts mentor-audit.spec.ts distribution-stats.spec.ts mentor-distribution-closure.spec.ts` | 0 | ✅ pass | 111469ms |
| 4 | `dart run tool/verify_m006_s07_mentor_distribution.dart` | 0 | ✅ pass | 189723ms |

## Deviations

Added one unplanned support fix in `backend/admin-api/src/test/resources/application-test.yml` to keep admin-api test boot deterministic after embedding validation landed, and tightened one existing negative-path waiter in `admin-web/tests/mentor-audit.spec.ts` so composed proof no longer races queue vs detail responses. These were minimal verification-driven corrections, not scope expansion.

## Known Issues

Playwright global setup still uses `docker compose up -d --build`, so external Maven Central handshake flakiness during image rebuilds can still cause transient verify-tool failures even though the final rerun passed. No product-surface issues remain open from this task.

## Files Created/Modified

- `admin-web/tests/mentor-distribution-closure.spec.ts`
- `tool/verify_m006_s07_mentor_distribution.dart`
- `admin-web/tests/mentor-audit.spec.ts`
- `backend/admin-api/src/test/resources/application-test.yml`
