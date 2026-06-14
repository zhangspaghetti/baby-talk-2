---
phase: "15"
plan: "02"
---

# T02: Added Spring Security bearer auth to app-api, bridged protected controllers back to JWT `sid`, and refreshed app-api WebTests for protected vs public route behavior.

**Added Spring Security bearer auth to app-api, bridged protected controllers back to JWT `sid`, and refreshed app-api WebTests for protected vs public route behavior.**

## What Happened

Implemented `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/AppSecurityConfig.java` to turn app-api into a stateless Spring Security resource server for consumer access tokens. The new configuration adds an access-token-only decoder, a session/refresh guard backed by `AuthConsentSyncService.validateAccessToken(...)`, stable 401 JSON failure codes/reasons, and a path-aware bearer resolver so public routes (`/invite/**`, `/share/**`, `/download*`, `/api/v1/auth/**`, `/api/v1/share-links`, `/api/v1/mentor/practice/generate`) do not regress while `/api/v1/mentor/chat` keeps its anonymous path unless a bearer token is present.

Updated `AuthConsentSyncController`, `CaregiverInviteController`, and `MentorController` so protected routes now read the existing session seam from JWT `sid` claims instead of `X-Session-Id`, while the downstream services/repositories remain session-centric. `MentorController` now supports bearer-authenticated requests and still preserves anonymous chat behavior via optional principal injection.

Reworked the relevant MockMvc integration tests (`AuthConsentSyncWebTest`, `MentorWebTest`, `CaregiverInviteApiWebTest`, `CaregiverInviteLandingWebTest`, `CaregiverPracticeAttributionWebTest`, `JwtTokenLifecycleWebTest`) to use real Bearer tokens issued by `/api/v1/auth/verify`, prove that old header-only calls no longer authorize protected routes, prove wrong-token-type / rotated / revoked bearer failures surface as 401s, and prove public invite landing pages remain accessible even when an invalid Authorization header is present. Local adaptation: the plan expected `application.yml` edits, but the workspace already had `app.auth` issuer/secret/TTL config plus `spring.flyway.enabled=false`, so no config file change was needed.

## Verification

Passed the task-plan verification suites with bash-executed Maven wrapper runs:

- `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest`
- `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=JwtTokenLifecycleWebTest,AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest`

These runs verified: protected app-api routes now require/accept Bearer tokens instead of `X-Session-Id`; anonymous mentor chat and public invite landing/download/open-app routes still work; wrong token type and missing bearer fail closed with 401 auth codes; rotated/revoked consumer access tokens are rejected at HTTP level; and the updated WebTests pass together in the same surefire invocation.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest` | 0 | ✅ pass | 23349ms |
| 2 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=JwtTokenLifecycleWebTest,AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest` | 0 | ✅ pass | 32134ms |

## Deviations

The written task plan expected edits in `backend/app-api/src/main/resources/application.yml`, but the local baseline already contained the required `app.auth` issuer/secret/TTL settings and kept `spring.flyway.enabled=false`, so no application.yml change was required. I also expanded the permit-all matcher set to include the already-public local routes `/api/v1/share-links`, `/api/v1/mentor/chat` (anonymous optional-auth), and `/api/v1/mentor/practice/generate` to avoid regressing existing public/anonymous behavior.

## Known Issues

None.

## Files Created/Modified

- `backend/app-api/pom.xml`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/AppSecurityConfig.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncController.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/CaregiverInviteController.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncWebTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/MentorWebTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/CaregiverInviteApiWebTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/CaregiverInviteLandingWebTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/CaregiverPracticeAttributionWebTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/JwtTokenLifecycleWebTest.java`
