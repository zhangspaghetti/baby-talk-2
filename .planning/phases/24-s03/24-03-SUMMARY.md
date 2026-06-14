---
phase: "24"
plan: "03"
---

# T03: Cut admin-web and Helm gateway wiring over to Spring Cloud Gateway and updated smoke coverage for gateway health and release notes.

**Cut admin-web and Helm gateway wiring over to Spring Cloud Gateway and updated smoke coverage for gateway health and release notes.**

## What Happened

Updated the admin-web runtime and dev proxy contract so admin traffic now goes through the gateway edge on port 8090: `admin-web/nginx.conf` forwards `/api/` to `gateway:8090`, `admin-web/vite.config.ts` now falls back to `http://127.0.0.1:8090`, and both runtime/dev configs no longer expose a separate `/actuator` proxy path.

Updated the Helm chart to deploy the real gateway instead of the nginx stub. The admin-web nginx helper now proxies `/api/` to the gateway service, `values.yaml` now ships `babytalk/gateway:1.0.0` with `/actuator/health` liveness/readiness probes and higher memory limits, and the gateway Deployment now receives `BABY_TALK_ADMIN_API_URI` plus the shared config/secret via `envFrom` so the gateway can route to the cluster-internal `admin-api`.

Updated downstream operational surfaces to match the new edge reality: NOTES.txt now describes Spring Cloud Gateway instead of the nginx stub, the Helm test hook probes `gateway:8090/actuator/health`, and `ci/k8s-smoke.sh` now asserts the health path, the absence of `nginx:alpine`, and the new release-note wording. During verification I briefly hit an executor-environment issue where a Python subprocess resolved `bash` to `/bin/bash`; rerunning the same smoke command directly in the shell passed, so no code change was needed for that.

## Verification

Ran `helm lint deploy/helm/babytalk-app` and it passed cleanly. Ran the slice verification gate `bash ci/k8s-smoke.sh`; it passed with 58 PASS / 0 FAIL / 0 SKIP, including the updated gateway health probe assertion, the new `assert_not_contains` check for `nginx:alpine`, and the release-note truth checks for Spring Cloud Gateway wording and admin-api remaining internal-only. Ran one additional targeted contract check using `rg`, `helm template`, and `helm install --dry-run --debug` to confirm the admin-web proxy target moved to gateway:8090, the dedicated `/actuator` proxy was removed, the rendered gateway Deployment includes `BABY_TALK_ADMIN_API_URI` plus shared config/secret env refs, and the rendered release notes contain the Spring Cloud Gateway wording.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `helm lint deploy/helm/babytalk-app` | 0 | ✅ pass | 314ms |
| 2 | `bash ci/k8s-smoke.sh` | 0 | ✅ pass | 6070ms |
| 3 | `rg -n "proxy_pass http://gateway:8090|127\\.0\\.0\\.1:8090" admin-web/nginx.conf admin-web/vite.config.ts && ! rg -n "location /actuator/|'/actuator'|admin-api:8081|127\\.0\\.0\\.1:8081" admin-web/nginx.conf admin-web/vite.config.ts >/dev/null && helm template babytalk-app deploy/helm/babytalk-app && helm install babytalk-app deploy/helm/babytalk-app -f deploy/helm/babytalk-app/values-production.yaml --dry-run --debug` | 0 | ✅ pass | 867ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `admin-web/nginx.conf`
- `admin-web/vite.config.ts`
- `deploy/helm/babytalk-app/templates/_helpers.tpl`
- `deploy/helm/babytalk-app/values.yaml`
- `deploy/helm/babytalk-app/templates/deployment.yaml`
- `deploy/helm/babytalk-app/templates/NOTES.txt`
- `deploy/helm/babytalk-app/templates/tests/test-connection.yaml`
- `ci/k8s-smoke.sh`
