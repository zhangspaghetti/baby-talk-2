---
phase: "26"
plan: "05"
---

# T05: Migrated AuthConsentSync, CaregiverInvite, and Mentor repositories to MyBatis mappers while preserving token locking, invite upsert, and Mentor rate-limit transaction semantics.

**Migrated AuthConsentSync, CaregiverInvite, and Mentor repositories to MyBatis mappers while preserving token locking, invite upsert, and Mentor rate-limit transaction semantics.**

## What Happened

I created `AuthConsentSyncMapper`, `CaregiverInviteMapper`, and `MentorMapper` with matching XML files, then rewrote the three repositories to delegate SQL execution to MyBatis while keeping the repository-facing contracts stable for existing services and web tests.

For `AuthConsentSyncRepository`, I moved all `sms_challenges`, `accounts`, `account_sessions`, `account_refresh_tokens`, `consent_audit_logs`, and `interaction_events` SQL into XML, preserved `lockRefreshToken` as a `FOR UPDATE` select, and kept the idempotent sync-event insert as `ON CONFLICT (event_key) DO NOTHING`.

For `CaregiverInviteRepository`, I moved the household/member/invite/shared-context SQL into XML, preserved the update-then-insert shared-context upsert in repository code with two mapper calls, and kept the household projection CTE in the mapper XML.

For `MentorRepository`, I kept the existing `ConcurrentHashMap<String, Object> rateLimitLocks` plus `TransactionTemplate(PROPAGATION_REQUIRES_NEW)` behavior intact and only swapped the underlying insert/count/select calls to `MentorMapper`, so the rate-limit concurrency and transaction-boundary semantics stayed unchanged.

During full-suite verification, `KgControllerTest` exposed a non-obvious regression: `@MapperScan` on the application entrypoint eagerly instantiated mapper beans in `@WebMvcTest` slices that do not provide a `SqlSessionFactory`. I fixed that by adding `lazyInitialization = "true"` to both app and admin `@MapperScan` declarations, then reran the targeted gate and the full app-api suite successfully.

## Verification

Verified the migration with the task’s compile and parity gates plus targeted static audits. `mvn -pl backend/app-api -am clean compile -q` passed, the critical targeted parity gate (`MentorRateLimitConcurrencyTest`, `MentorTransactionBoundaryTest`, `AuthConsentSyncWebTest`, `JwtTokenLifecycleWebTest`, `CaregiverInviteApiWebTest`, `CaregiverInviteLandingWebTest`, `MentorWebTest`) passed after the final `@MapperScan` lazy-init fix, and the full `mvn -pl backend/app-api -am clean verify -q` suite passed on rerun. I also confirmed the three migrated repositories contain no `JdbcTemplate` references, confirmed both application YAML files still declare Druid with `slow-sql-millis: 2000` / `log-slow-sql: true`, and compiled admin-api after changing its `@MapperScan` declaration for test-slice safety.

Slice-level Druid evidence is partial in this task: runtime test logs showed Druid datasource initialization, and config presence is confirmed in both app/admin `application.yml` files. Endpoint exposure remains limited to `health,info`, so this task verified Druid wiring/config rather than an externally reachable `/actuator/druid` endpoint.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn -pl backend/app-api -am clean compile -q` | 0 | ✅ pass | 14300ms |
| 2 | `mvn -pl backend/app-api -am verify -Dtest='MentorRateLimitConcurrencyTest,MentorTransactionBoundaryTest,AuthConsentSyncWebTest,JwtTokenLifecycleWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,MentorWebTest' -q` | 0 | ✅ pass | 49000ms |
| 3 | `mvn -pl backend/app-api -am clean verify -q` | 0 | ✅ pass | 94500ms |
| 4 | `python repository scan for JdbcTemplate in AuthConsentSyncRepository/CaregiverInviteRepository/MentorRepository` | 0 | ✅ pass | 0ms |
| 5 | `python config scan for DruidDataSource + slow-sql-millis in app/admin application.yml` | 0 | ✅ pass | 0ms |

## Deviations

Added `lazyInitialization = "true"` to both `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/AppApiApplication.java` and `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/AdminApiApplication.java` even though the task plan focused on the three app-api repositories. This was required to keep existing `@WebMvcTest` slices from instantiating MyBatis mapper beans without a `SqlSessionFactory` after the mapper set expanded.

One targeted rerun using `clean` failed because Windows could not delete a locked `backend/common/target/classes/...` path. I treated that as an environment/clean-step issue rather than a feature regression, reran the targeted verification without `clean`, and the parity gate passed.

## Known Issues

`management.endpoints.web.exposure.include` still exposes only `health,info`, so this task proved Druid startup/config presence but did not establish an externally reachable Druid actuator endpoint. That remaining slice-level runtime-audit question should be resolved in T06.

## Files Created/Modified

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncRepository.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncMapper.java`
- `backend/app-api/src/main/resources/mapper/service/AuthConsentSyncMapper.xml`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/CaregiverInviteRepository.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/CaregiverInviteMapper.java`
- `backend/app-api/src/main/resources/mapper/service/CaregiverInviteMapper.xml`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorRepository.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorMapper.java`
- `backend/app-api/src/main/resources/mapper/service/MentorMapper.xml`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/AppApiApplication.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/AdminApiApplication.java`
