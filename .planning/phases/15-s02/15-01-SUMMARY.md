---
phase: "15"
plan: "01"
---

# T01: Added consumer JWT verify/refresh/logout contract, V16 refresh-token schema, and lifecycle proof coverage for app-api.

**Added consumer JWT verify/refresh/logout contract, V16 refresh-token schema, and lifecycle proof coverage for app-api.**

## What Happened

Added consumer-only `account_refresh_tokens` persistence in `V16__create_account_jwt_tables.sql` and wired app-api JWT config with dedicated consumer issuer/secret/TTL properties. Extended `JwtTokenService` with consumer issuance methods that carry `sid` + `rtid`, then upgraded `AuthConsentSyncController` / `AuthConsentSyncService` / `AuthConsentSyncRepository` so `/api/v1/auth/verify` now returns a token-first contract with session metadata, `/api/v1/auth/refresh` performs row-locked rotation against consumer refresh rows, `/api/v1/auth/logout` revokes the refresh row plus the bound session, and access validation reads refresh lifecycle state so old bearer tokens die immediately after refresh/logout. Added `JwtTokenLifecycleWebTest`, tightened `AuthConsentSyncWebTest` assertions, and updated shared integration-test table reset wiring so the new consumer auth state is observable in tests without rewriting the existing session-centric downstream services.

## Verification

Task-level verification passed: `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=JwtTokenLifecycleWebTest` and `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=JwtTokenLifecycleWebTest,AuthConsentSyncWebTest` both succeeded, proving verify → refresh rotation → logout revoke → old bearer rejection and stable malformed/rotated/expired/revoked codes. Slice-level partial verification also ran: the broader app-api suite `JwtTokenLifecycleWebTest,AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest` passed, and `docker compose up -d postgres && ./backend/mvnw -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` succeeded. Remaining slice checks failed for downstream reasons outside T01 scope: `cd mobile && flutter test test/features/account/jwt_session_refresh_test.dart test/features/account/account_repository_test.dart test/features/household/household_repository_test.dart test/features/mentor/mentor_view_model_test.dart` failed because `test/features/account/jwt_session_refresh_test.dart` does not exist yet (owned by T03), and `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` failed because the smoke assertion still expects 13 applied migrations instead of the new V16 total (owned by T05).

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=JwtTokenLifecycleWebTest` | 0 | ✅ pass | 33100ms |
| 2 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=JwtTokenLifecycleWebTest,AuthConsentSyncWebTest` | 0 | ✅ pass | 31100ms |
| 3 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=JwtTokenLifecycleWebTest,AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest` | 0 | ✅ pass | 31000ms |
| 4 | `cd mobile && flutter test test/features/account/jwt_session_refresh_test.dart test/features/account/account_repository_test.dart test/features/household/household_repository_test.dart test/features/mentor/mentor_view_model_test.dart` | 1 | ❌ fail | 32800ms |
| 5 | `docker compose up -d postgres && ./backend/mvnw -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` | 0 | ✅ pass | 15400ms |
| 6 | `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` | 1 | ❌ fail | 14200ms |

## Deviations

Added `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/ConsumerAuthConfiguration.java` and `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/ConsumerAuthProperties.java` because local app-api reality had no consumer JWT bean wiring; the written task listed only `application.yml`, but a real encoder/decoder seam was required to ship the contract.

## Known Issues

1. `mobile/test/features/account/jwt_session_refresh_test.dart` is still absent, so the slice-level mobile verification command fails until T03 creates the JWT refresh harness. 2. `DbMigrationSmokeTest` still asserts the pre-V16 migration count (`expected 13 but was 14`) and must be updated in T05 alongside the db-migration module proof closure.

## Files Created/Modified

- `backend/db-migration/src/main/resources/db/migration/V16__create_account_jwt_tables.sql`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/security/JwtTokenService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/ConsumerAuthConfiguration.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/ConsumerAuthProperties.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncRepository.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncController.java`
- `backend/app-api/src/main/resources/application.yml`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/JwtTokenLifecycleWebTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncWebTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/AbstractIntegrationTest.java`
