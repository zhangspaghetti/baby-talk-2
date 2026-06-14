---
phase: "24"
plan: "01"
---

# T01: Added the Spring Cloud Gateway module scaffold with JWT config, WebFlux security, initial admin route, and health endpoint verification.

**Added the Spring Cloud Gateway module scaffold with JWT config, WebFlux security, initial admin route, and health endpoint verification.**

## What Happened

Updated `backend/pom.xml` to import Spring Cloud 2024.0.1 and register the new `gateway` reactor module. Added `backend/gateway/pom.xml` as a WebFlux-only Spring Cloud Gateway application with actuator, security, and the shared `common` module, plus `GatewayApplication` with explicit JDBC/JPA/Flyway auto-config exclusions so transitive `common` dependencies do not pull database runtime into the gateway process.

Implemented `GatewayJwtConfig` with `@ConfigurationProperties`-backed HS256 `JwtDecoder` construction and a hard fail for secrets shorter than 32 bytes, `GatewaySecurityConfig` with a minimal permissive WebFlux chain that still exposes `/actuator/health`, and `application.yml` with port 8090, the initial `/api/admin/**` route, Redis host/port bindings, actuator exposure, and YAML-level auto-config exclusions as backup. Added `GatewayJwtConfigTest` to cover valid decode, issuer rejection, and short-secret rejection.

For runtime verification, I first tried invoking `spring-boot:run` from the backend reactor and confirmed the failure was due to the goal landing on the aggregator POM rather than the gateway module. I then switched to packaging the module and verified the packaged gateway jar serves `/actuator/health` successfully. Slice-level observability items tied to `AdminJwtGlobalFilter`, rejected-request WARN logs with `error_code`, Redis counter increments, and smoke footer telemetry are not part of this scaffold task yet and remain for later tasks in S03.

## Verification

Ran `mvn -pl backend/gateway -am test -q` to compile the new module and execute the new JWT configuration tests. Re-ran the task-contract command `mvn -pl backend/gateway -am clean compile -q` after the final test adjustment. Built a runnable jar with `mvn -pl backend/gateway -am package -DskipTests -q`, started the packaged gateway process, and confirmed `curl -sf http://127.0.0.1:8090/actuator/health` returned `{\"status\":\"UP\"}`.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn -pl backend/gateway -am test -q` | 0 | ✅ pass | 10600ms |
| 2 | `mvn -pl backend/gateway -am clean compile -q` | 0 | ✅ pass | 11200ms |
| 3 | `mvn -pl backend/gateway -am package -DskipTests -q` | 0 | ✅ pass | 26300ms |
| 4 | `curl -sf http://127.0.0.1:8090/actuator/health` | 0 | ✅ pass | 380ms |

## Deviations

None.

## Known Issues

Later S03 tasks still need to add `AdminJwtGlobalFilter`, rejected-request WARN logging with named `error_code` values, Redis-backed rate limiting/counters, and smoke-script telemetry wiring; this task only establishes the scaffold those features will plug into.

## Files Created/Modified

- `backend/pom.xml`
- `backend/gateway/pom.xml`
- `backend/gateway/src/main/java/com/zhangspaghetti/babytalk/gateway/GatewayApplication.java`
- `backend/gateway/src/main/java/com/zhangspaghetti/babytalk/gateway/GatewayJwtConfig.java`
- `backend/gateway/src/main/java/com/zhangspaghetti/babytalk/gateway/GatewaySecurityConfig.java`
- `backend/gateway/src/main/resources/application.yml`
- `backend/gateway/src/test/java/com/zhangspaghetti/babytalk/gateway/GatewayJwtConfigTest.java`
