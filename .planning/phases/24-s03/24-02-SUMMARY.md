---
phase: "24"
plan: "02"
---

# T02: Added AdminJwtGlobalFilter with named JWT rejection codes, structured WARN logging, and 9 unit tests.

**Added AdminJwtGlobalFilter with named JWT rejection codes, structured WARN logging, and 9 unit tests.**

## What Happened

Built `backend/gateway`'s admin edge JWT guard as a `GlobalFilter + Ordered` component under `com.zhangspaghetti.babytalk.gateway.filter`. The filter now short-circuits non-admin paths and the public admin auth endpoints, requires a `Bearer` token on protected `/api/admin/**` routes, decodes via the injected `JwtDecoder`, maps JWT failures to the six named gateway error codes (`missing_token`, `malformed_token`, `expired_token`, `invalid_issuer`, `wrong_token_type`, `permission_denied`), and returns consistent 401 JSON error bodies. Each rejection also emits a WARN log with structured `error_code` and `path` key-values so slice-level observability can see why the request was denied.

Added `AdminJwtFilterTest` as a pure unit test suite (no Spring context) with 9 cases covering non-admin bypass, public login/refresh bypass, missing token, malformed JWT, expired JWT, issuer mismatch, wrong token type, and valid access token pass-through. During verification I hit one real API mismatch: `JwtValidationException#getErrors()` returns `Collection<OAuth2Error>` in this Spring version, so the helper signature was narrowed from the initial `List` assumption to `Collection` and re-tested. I also had to bootstrap the sibling `common` module into the local Maven repository so the task plan's exact `-pl backend/gateway` command could resolve `com.zhangspaghetti:common` in this worktree.

## Verification

Verification progressed in three stages. First, the task-plan command `mvn -pl backend/gateway test -Dtest=AdminJwtFilterTest -q` failed before compilation because Maven could not resolve the sibling `common` artifact from the local repository in this fresh worktree. Second, I re-ran with `-am` to include upstream modules; that exposed the actual compile issue in the new filter (`Collection<OAuth2Error>` vs `List<OAuth2Error>`), which I fixed. Third, `mvn -pl backend/gateway -am test -Dtest=AdminJwtFilterTest -Dsurefire.failIfNoSpecifiedTests=false -q` passed, after which I installed `backend/common` and re-ran the exact task-plan command `mvn -pl backend/gateway test -Dtest=AdminJwtFilterTest -q`, which also passed. The surefire report at `backend/gateway/target/surefire-reports/com.zhangspaghetti.babytalk.gateway.filter.AdminJwtFilterTest.txt` confirms `Tests run: 9, Failures: 0, Errors: 0, Skipped: 0`. The passing test output also showed WARN lines from `AdminJwtGlobalFilter` with `error_code` values for rejected requests, partially satisfying the slice's gateway observability requirement. Slice-level checks for `/actuator/health`, Redis rate-limiter counters, and smoke-script telemetry were not exercised in this intermediate task.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn -pl backend/gateway test -Dtest=AdminJwtFilterTest -q` | 1 | ❌ fail | 7200ms |
| 2 | `mvn -pl backend/gateway -am test -Dtest=AdminJwtFilterTest -Dsurefire.failIfNoSpecifiedTests=false -q` | 1 | ❌ fail | 11300ms |
| 3 | `mvn -pl backend/gateway -am test -Dtest=AdminJwtFilterTest -Dsurefire.failIfNoSpecifiedTests=false -q` | 0 | ✅ pass | 15400ms |
| 4 | `mvn -pl backend/gateway test -Dtest=AdminJwtFilterTest -q` | 0 | ✅ pass | 9100ms |

## Deviations

Installed `backend/common` into the local Maven repository (`mvn -pl backend/common -am install -DskipTests -q`) so the task plan's exact module-scoped verification command could resolve the sibling dependency and run in this worktree.

## Known Issues

Mockito/ByteBuddy emits dynamic-agent warnings on this JDK during the test run. The warnings do not fail the suite, but the build should eventually add the recommended Mockito agent configuration before newer JDK defaults disallow dynamic attachment.

## Files Created/Modified

- `backend/gateway/src/main/java/com/zhangspaghetti/babytalk/gateway/filter/AdminJwtGlobalFilter.java`
- `backend/gateway/src/test/java/com/zhangspaghetti/babytalk/gateway/filter/AdminJwtFilterTest.java`
