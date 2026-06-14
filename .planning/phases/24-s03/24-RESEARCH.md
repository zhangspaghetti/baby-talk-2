# S03 — Research

**Date:** 2026-04-26

## Summary

The existing backend is a 4-module Maven reactor (common, app-api, admin-api, db-migration) on Spring Boot 3.4.4. S01 installed an nginx:alpine stub Deployment/Service in the `babytalk-app` Helm chart at port 8090 (`gateway.enabled: true`) to satisfy the S01 health check contract. Admin-web currently proxies `/api/` and `/actuator/` directly to `admin-api:8081` in both the Nginx ConfigMap (via `_helpers.tpl` `adminWebNginxConfig` helper) and the local `admin-web/nginx.conf`. Vite's dev proxy defaults to `http://127.0.0.1:8081`. There is no Spring Cloud Gateway Maven module anywhere in the codebase yet.

S03 must build a 5th Maven module `backend/gateway/` using Spring Cloud Gateway 4.x (WebFlux), add it to the parent reactor, and replace the nginx:alpine stub in the Helm chart with the real `babytalk/gateway` image. The gateway is the only public-facing entry point for admin traffic: it validates admin JWTs and maps failures to 6 named error codes before forwarding to the internal `admin-api` service. Admin-web's proxy target (both Helm ConfigMap and local Nginx, plus Vite's dev proxy default) must shift from `admin-api:8081` to `gateway:8090`. The smoke script at `ci/k8s-smoke.sh` currently asserts the nginx:alpine stub string in NOTES.txt — those 2-3 assertions must be updated.

Key risks: Spring Cloud Gateway requires adding a Spring Cloud BOM to the parent pom (Spring Cloud 2024.0.x for Spring Boot 3.4.x); gateway is WebFlux while all other modules are Servlet-based (no cross-module runtime conflict but the gateway module must not pull in `spring-boot-starter-web`); the SSE streaming endpoint (`/api/admin/overview/stream`) and multipart upload (`/api/admin/knowledge/ingestion/upload`) must route cleanly through SCG without buffering or path stripping.

## Recommendation

Build the gateway module as a standalone Spring Boot WebFlux app with Spring Cloud Gateway. It owns JWT validation at the edge for all `/api/admin/**` requests and maps the 6 error categories to named JSON envelopes. The gateway forwards the original `Authorization: Bearer` header unchanged so admin-api can continue doing its own Spring Security validation (defense in depth, no admin-api changes required in S03). Routes for `/api/admin/**` are configured declaratively in `application.yml`; the JWT filter is a `GlobalFilter` that applies to admin routes only, skipping the 3 public auth endpoints. Rate limiting with Redis (from infra-release) is configured via Spring Cloud Gateway's built-in Redis rate limiter with a per-principal key resolver.

## Implementation Landscape

### Key Files

- `backend/pom.xml` — add `<module>gateway</module>` (5th module), add `spring-cloud-dependencies` BOM under `dependencyManagement`
- `backend/gateway/pom.xml` — **new**: Spring Cloud Gateway module; deps: `spring-cloud-starter-gateway`, `spring-boot-starter-actuator`, `common`, `spring-boot-starter-test`; no `spring-boot-starter-web` (conflicts with WebFlux)
- `backend/gateway/src/main/java/.../GatewayApplication.java` — **new**: `@SpringBootApplication` entry point
- `backend/gateway/src/main/java/.../filter/AdminJwtGlobalFilter.java` — **new**: `GlobalFilter` + `Ordered`; checks `Authorization` header on `/api/admin/**` routes (excluding public auth paths); maps to 6 error codes
- `backend/gateway/src/main/java/.../GatewaySecurityConfig.java` — **new**: minimal `SecurityWebFilterChain` (WebFlux); permits actuator/health, blocks direct actuator on upstream paths; disables form login, CSRF
- `backend/gateway/src/main/java/.../GatewayJwtConfig.java` — **new**: `@ConfigurationProperties`-backed `NimbusJwtDecoder` (HS256) seeded from `app.gateway.admin-jwt-secret` + `app.gateway.admin-jwt-issuer`; reuses `JwtTokenService.TokenType` enum for claim checks
- `backend/gateway/src/main/resources/application.yml` — **new**: routes (`/api/admin/**` → `http://admin-api:8081`), actuator health exposure, Redis rate limiter config
- `backend/common/src/main/java/.../security/JwtTokenService.java` — **reuse** `decode()` + `TokenType.fromClaim()` in the gateway filter to distinguish `expired` vs `malformed`; no changes to this file
- `admin-web/nginx.conf` — change `/api/` and `/actuator/` proxy target from `admin-api:8081` to `gateway:8090`; drop `/actuator/` location (admin-api actuator stays internal-only, gateway exposes its own)
- `admin-web/vite.config.ts` — change default `VITE_ADMIN_API_PROXY_TARGET` from `http://127.0.0.1:8081` to `http://127.0.0.1:8090`
- `deploy/helm/babytalk-app/templates/_helpers.tpl` — update `adminWebNginxConfig` helper: change `/api/` and `/actuator/` proxy from `admin-api:{{ .Values.adminApi.service.port }}` to `gateway:{{ .Values.gateway.service.port }}`; drop the actuator location
- `deploy/helm/babytalk-app/values.yaml` — update `gateway.image.repository: babytalk/gateway`, `gateway.image.tag: "1.0.0"`; update gateway probes from path `/` to `/actuator/health`; add `gateway.resources.limits` (SCG needs more memory than nginx)
- `deploy/helm/babytalk-app/templates/deployment.yaml` — add `envFrom` (configMapRef + secretRef) to gateway container so it reads `BABY_TALK_ADMIN_JWT_SECRET`, `BABY_TALK_ADMIN_JWT_ISSUER`, and `BABY_TALK_REDIS_HOST` from the shared ConfigMap/Secret
- `deploy/helm/babytalk-app/templates/NOTES.txt` — remove "stub — nginx:alpine, to be replaced by Spring Cloud Gateway in S03" in both locations; replace with "Spring Cloud Gateway（edge filter: JWT auth + rate limiting）"
- `ci/k8s-smoke.sh` — update 2–3 assertions that `assert_contains` for the nginx:alpine stub string; add new assertions verifying gateway image is `babytalk/gateway` and admin-web proxy target is gateway (not direct admin-api)
- `backend/gateway/src/test/java/.../AdminJwtFilterTest.java` — **new**: unit tests for each of the 6 error code paths using `WebTestClient` + mock `JwtDecoder`

### Build Order

1. Parent pom — add Spring Cloud BOM and gateway module (unblocks compilation)
2. `backend/gateway/` module — application, config, JWT filter, routes (core deliverable)
3. admin-web proxy change — nginx.conf, vite.config.ts, _helpers.tpl (cutover admin-web to gateway)
4. Helm values + deployment — update image, probes, envFrom (gateway goes live in chart)
5. NOTES.txt update — remove stub references
6. ci/k8s-smoke.sh — update assertions to match new gateway reality
7. Unit tests for JWT filter (proof of the 6 error codes)

### Verification Approach

```bash

# 1. Maven build (gateway module compiles and tests pass)

cd backend && mvn -pl gateway -am clean verify -q

# 2. Helm dry-run: gateway image is babytalk/gateway (not nginx:alpine)

helm template babytalk-app deploy/helm/babytalk-app | grep 'image:.*gateway'

# Expected: babytalk/gateway:1.0.0

# 3. Smoke script: all 57+ assertions pass, no nginx:alpine stub references remain

bash ci/k8s-smoke.sh

# 4. Production render: no Ingress for admin-api, gateway present

helm template babytalk-app deploy/helm/babytalk-app -f deploy/helm/babytalk-app/values-production.yaml \
  | grep -c 'kind: Ingress'  # should be ≤1 (only app-api or admin-web, not admin-api)

# 5. JWT filter unit test coverage (all 6 categories)

cd backend && mvn -pl gateway test -Dtest=AdminJwtFilterTest -q
```

## Don't Hand-Roll

| Problem | Existing Solution | Why Use It |
|---------|------------------|------------|
| JWT decode + claim extraction | `JwtTokenService.decode()` + `DecodedToken` in `backend/common` | Already tested, wraps `NimbusJwtDecoder`, exposes `tokenType()`, `expiresAt()`, `refreshTokenId()` |
| HS256 key construction | `NimbusJwtDecoder.withSecretKey(...).macAlgorithm(MacAlgorithm.HS256).build()` (same pattern as `AdminSecurityConfig`) | Proven pattern already in admin-api; copy the key construction, not the security chain |
| Rate limiting | `spring-cloud-starter-gateway` built-in Redis rate limiter (`RequestRateLimiter` filter) | Zero-code rate limiting with per-key Redis counters; Redis is already provisioned by infra-release (S02) |
| SSE passthrough | Spring Cloud Gateway routes passthrough SSE natively | No special config needed for `text/event-stream` — SCG doesn't buffer by default |
| Multipart upload passthrough | SCG routes multipart natively | No `MultipartResolver` needed on the gateway; upstream admin-api handles it |
| Reactive JWT error responses | `ServerHttpResponse` + `DataBuffer` write in `GlobalFilter` | Standard SCG pattern; no servlet-based `HttpServletResponse` |

## Constraints

- Spring Boot 3.4.4 requires Spring Cloud 2024.0.x BOM — must not use Spring Cloud 2023.x or earlier
- Gateway module must **not** include `spring-boot-starter-web` — Spring Cloud Gateway uses WebFlux; mixing web + webflux in the same module causes startup failure (`Ambiguous ApplicationContextInitializer`)
- The `common` module depends on `spring-security-oauth2-jose` (servlet-neutral) — safe to use in gateway's `JwtDecoder` construction but do not pull `common`'s Spring AI / MinIO / Tika dependencies into the gateway fat jar; those are only referenced by admin-api/app-api
- Gateway deployment needs `envFrom` for the shared Secret (to read `BABY_TALK_ADMIN_JWT_SECRET`) — currently the gateway stub (nginx:alpine) has no `envFrom`; this is a required addition
- Admin-api must remain `ClusterIP` with no Ingress; the smoke script already asserts this but S03 must not accidentally add one
- admin-web Vite proxy: the `VITE_ADMIN_API_PROXY_TARGET` env var name is fine to keep; only the default value changes from `8081` to `8090`
- `/api/admin/auth/login`, `/api/admin/auth/refresh`, `/api/admin/auth/logout` must be pass-through at gateway (no JWT required) — the JWT filter must skip these paths
- `actuator/` proxy in admin-web Nginx should be dropped in S03; gateway exposes its own `/actuator/health` which is what the Helm probe uses

## Common Pitfalls

- **`spring-boot-starter-web` in gateway pom** — causes context startup failure due to WebMvc + WebFlux ambiguity. SCG transitively brings `spring-boot-starter-webflux`; do not add `spring-boot-starter-web`.
- **`NimbusJwtDecoder` vs `ReactiveJwtDecoder`** — Spring Cloud Gateway's reactive security uses `ReactiveJwtDecoder`; the `NimbusJwtDecoder` in the gateway module must be wrapped as `ReactiveJwtDecoder` if used in `SecurityWebFilterChain`. For the custom `GlobalFilter`, using `NimbusJwtDecoder` directly (synchronous call wrapped in `Mono.fromCallable`) is simpler and avoids this.
- **Missing BOM version** — if the Spring Cloud BOM is added after the Spring Boot parent in `<dependencyManagement>`, Spring Boot version wins; this is the correct ordering (Spring AI BOM already follows this pattern).
- **Path stripping** — if `StripPrefix=0` is not set (or equivalent), SCG may strip `/api` from forwarded requests. Routes must use exact URI mapping: `lb://admin-api` with `path=/api/admin/**` and no `StripPrefix` filter.
- **Helm probe path** — nginx:alpine default probe is `/` (returns 200); SCG's default `/` returns 404. Must update `gateway.livenessProbe.httpGet.path` and `readinessProbe.httpGet.path` from `/` to `/actuator/health`.
- **Helm test pod** — `test-connection.yaml` probes `gateway:8090/` with `wget -qO-`; after S03 this path returns 404 (no route to `/`). Must update test pod to probe `gateway:8090/actuator/health`.
- **`admin-api` actuator in smoke script** — `ci/k8s-smoke.sh` line 503 asserts `http://${APP_RELEASE_NAME}-admin-api:8081/actuator/health` is still probed by the test pod; this is fine (test pod probes admin-api directly for health, internal service). Do not remove this probe.
- **NOTES.txt dual occurrence** — the nginx:alpine stub string appears in 2 places in NOTES.txt (top section and internal services section). Both must be updated.

## Open Risks

- **Spring Cloud 2024.0.x availability** — Spring Cloud 2024.0.1 is the stable release for Spring Boot 3.4.x. Verify `spring-cloud-dependencies:2024.0.1` resolves in the project's Maven mirror (`.mvn/settings.xml` uses a custom mirror); if not, may need to add the Spring Milestones/Release repo.
- **`common` module fat-jar avoidance** — `common/pom.xml` has Spring AI, MinIO, Tika; these will be on the gateway classpath since `gateway` depends on `common`. At runtime this is wasted memory and may trigger bean auto-config for AI/MinIO/Tika in the gateway context. Mitigation: use `@SpringBootApplication(exclude = {...})` in `GatewayApplication` to exclude unwanted auto-configs, or restructure common into a security-only sub-artifact (out of scope for S03).
- **Redis rate limiter opt-in timing** — Redis from infra-release is available but the gateway Redis config needs `BABY_TALK_REDIS_HOST` in the Helm ConfigMap (already has conditional `{{- if hasKey .Values.config "BABY_TALK_REDIS_HOST" }}` section). If Redis is not reachable, rate limiter must degrade gracefully (`deny-empty-key: false`).
- **Playwright admin-web E2E tests** — `admin-web/tests/` likely uses `ADMIN_API_URL` or similar env vars that point at admin-api directly. These must be updated to point to gateway in CI, otherwise E2E tests will bypass the gateway cutover proof.
