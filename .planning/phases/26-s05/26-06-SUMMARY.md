---
phase: "26"
plan: "06"
---

# T06: Added a pipefail-safe Step 11 JdbcTemplate runtime audit to k8s smoke verification and revalidated the full MyBatisPlus+Druid migration with green app-api and full-repo builds.

**Added a pipefail-safe Step 11 JdbcTemplate runtime audit to k8s smoke verification and revalidated the full MyBatisPlus+Druid migration with green app-api and full-repo builds.**

## What Happened

I finished the final runtime audit for the JdbcTemplate→MyBatisPlus migration and kept the change surface minimal. In `ci/k8s-smoke.sh` I added a reusable `assert_eq` helper plus Step 11, which counts owned `JdbcTemplate` usages outside the Spring AI carve-outs and fails the smoke gate if any remain. During verification I found the first Step 11 implementation could false-fail under the script’s existing `set -euo pipefail` policy because `grep -v` returns exit code 1 when the success case is zero matching lines; I fixed that by grouping the filter pipeline and adding `|| true` before `wc -l` so the audit counts zero matches correctly instead of aborting the script. I also re-ran the runtime audit directly and confirmed only `EmbeddingConfiguration.java` and `ChatMemoryConfiguration.java` still reference `JdbcTemplate`, while the migrated owned repositories stayed clean. Both `backend/app-api` and `backend/admin-api` still point to `com.alibaba.druid.pool.DruidDataSource` with the Druid stat filter configured for slow SQL logging, and the app-api/admin-api test logs showed `DruidDataSourceAutoConfigure` and `DruidDataSource` initialization during the verification runs. Finally, I checked the migration directory count remained 15 files (V3–V17), so `docs/schema-compatibility-matrix.md` did not require any update for this task.

## Verification

Verified the direct audit and config facts first, then reran the gate commands without the Windows-incompatible inline comment lines that had broken the prior verification attempt. `mvn -pl backend/app-api -am clean compile -q` passed, the targeted parity suite (`MentorRateLimitConcurrencyTest`, `MentorTransactionBoundaryTest`, `AuthConsentSyncWebTest`, `JwtTokenLifecycleWebTest`, `CaregiverInviteApiWebTest`, `CaregiverInviteLandingWebTest`, `MentorWebTest`) passed, the full `backend/app-api` verify passed, and the full repository `mvn clean verify -q` passed. After fixing the Step 11 pipefail issue, `bash ci/k8s-smoke.sh` passed end-to-end with 63 PASS / 0 FAIL / 0 SKIP and Step 11 reporting `own-jdbctemplate-count` as a pass. Static spot checks also confirmed one `DruidDataSource` entry in each application.yml, 64 smoke assertions/PASS markers in `ci/k8s-smoke.sh`, and 15 Flyway migration files, matching the existing schema matrix.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn -pl backend/app-api -am clean compile -q` | 0 | ✅ pass | 14501ms |
| 2 | `mvn -pl backend/app-api -am clean verify -Dtest="MentorRateLimitConcurrencyTest,MentorTransactionBoundaryTest,AuthConsentSyncWebTest,JwtTokenLifecycleWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,MentorWebTest" -q` | 0 | ✅ pass | 50817ms |
| 3 | `mvn -pl backend/app-api -am clean verify -q` | 0 | ✅ pass | 118422ms |
| 4 | `mvn clean verify -q` | 0 | ✅ pass | 173596ms |
| 5 | `bash ci/k8s-smoke.sh` | 0 | ✅ pass | 6734ms |
| 6 | `grep -c "DruidDataSource" backend/app-api/src/main/resources/application.yml && grep -c "DruidDataSource" backend/admin-api/src/main/resources/application.yml` | 0 | ✅ pass | 314ms |
| 7 | `grep -c "step_pass\|PASS\|assert" ci/k8s-smoke.sh | head -1` | 0 | ✅ pass | 304ms |
| 8 | `find backend/db-migration/src/main/resources/db/migration -name "V*.sql" | wc -l | tr -d " "` | 0 | ✅ pass | 349ms |

## Deviations

The planner’s Step 11 shell snippet needed one local hardening change for this repository’s `set -euo pipefail` discipline: the zero-match `grep -v` path had to be wrapped with `|| true` before `wc -l` so a successful audit would not abort the smoke script.

## Known Issues

None.

## Files Created/Modified

- `ci/k8s-smoke.sh`
