---
phase: "11"
plan: "03"
---

# T03: Centralized the S12 control-plane replay into a step-labeled verifier and taught Playwright to reuse verifier-owned compose boot.

**Centralized the S12 control-plane replay into a step-labeled verifier and taught Playwright to reuse verifier-owned compose boot.**

## What Happened

I rewrote `tool/verify_m006_s12_control_plane_freshness.dart` from a thin build-plus-Playwright wrapper into the S12 single-entry replay path the slice expects. The verifier now checks required artifacts, runs the focused `AdminOverviewWebTest` backend contract step, runs the admin-web build, owns `docker compose up -d --build postgres minio db-migration app-api admin-api admin-web`, verifies runtime truth from `docker compose ps --all --format json` plus actuator/admin-web health probes, and then launches the canonical browser proof pack with `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1`. It also removes stale Playwright reports, requires `admin-web/playwright-report/index.html` to materialize, and prints step labels (`required_artifacts`, `backend_contract`, `admin_web_build`, `compose_boot`, `runtime_truth`, `browser_proof_pack`) plus sanitized compose diagnostics when runtime boot/probes fail.

I also rewrote `admin-web/playwright.global-setup.ts` to preserve the required dual-mode behavior. Direct `npm --prefix admin-web run test:e2e -- ...` still owns compose boot itself, but verifier-owned runs now switch into a reuse mode that only validates runtime truth and no longer rebuilds or boots compose a second time. The setup logs the current mode and Docker API version, boots only the six runtime services needed by S12, and dumps sanitized `docker version` / `docker compose ps --all` / `docker compose logs --tail 120 ...` diagnostics on compose/runtime failures.

Finally, I updated `docs/runbooks/m006-s12-control-plane-freshness.md` so downstream slices and operators keep using the unchanged verifier path as the canonical drill-down entry. The runbook now documents the stable single-entry replay order, the first failing step label to inspect, the `admin-web/playwright-report/index.html` path for browser-proof failures, the direct-Playwright drill-down path, and why S13/S14/README/CONTRIBUTING must continue reusing this verifier path instead of introducing a new entrypoint.

The remaining red verification is environmental rather than contract drift. `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts overview-control-plane.spec.ts` now surfaces the intended `[compose_boot]` failure with explicit diagnostics showing the Docker Desktop Linux engine pipe is unavailable (`//./pipe/dockerDesktopLinuxEngine` missing), so the failure is no longer the old ambiguous double-boot drift. I attempted a local Docker Desktop restart path, but the engine remained unavailable and the unit entered hard timeout recovery before I could complete a fresh end-to-end rerun of the repo-root verifier after the final edits.

## Verification

Verified the rewritten verifier statically with `dart analyze tool/verify_m006_s12_control_plane_freshness.dart` and verified the frontend/setup changes with `npm --prefix admin-web run build`, which passed through TypeScript and Vite production build. I then reran `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts overview-control-plane.spec.ts`; it now reaches the new Playwright global setup logging, reports `mode=playwright-owned-boot docker_api_version=1.44`, and fails explicitly at `[compose_boot]` while dumping sanitized Docker diagnostics that show the local Docker Desktop Linux engine pipe is unavailable. No app-level browser assertion failure surfaced before the environment/runtime failure. I also confirmed locally that `Get-Service com.docker.service` reported the Docker Desktop service stopped and that `docker version` could not connect to `dockerDesktopLinuxEngine`, matching the compose boot failure. Because the task hit hard-timeout recovery while the Docker daemon was still unavailable, I did not get a clean post-edit rerun of `cmd.exe /c "backend\mvnw.cmd -f backend\pom.xml -q -pl admin-api -am test -Dtest=AdminOverviewWebTest"` or `dart run tool/verify_m006_s12_control_plane_freshness.dart`; those should be rerun first once Docker Desktop is healthy.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `dart analyze tool/verify_m006_s12_control_plane_freshness.dart — exit 0 — ✅ pass — no analyzer issues found.` | -1 | unknown (coerced from string) | 0ms |
| 2 | `npm --prefix admin-web run build — exit 0 — ✅ pass — TypeScript checks and Vite production build completed successfully.` | -1 | unknown (coerced from string) | 0ms |
| 3 | `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts overview-control-plane.spec.ts — shell harness timeout after surfacing `[compose_boot]` — ❌ fail — sanitized diagnostics show the `//./pipe/dockerDesktopLinuxEngine` Docker pipe was unavailable.` | -1 | unknown (coerced from string) | 0ms |
| 4 | `powershell -NoProfile -Command "Get-Service -Name com.docker.service | Format-List Status,Name,DisplayName" — exit 0 — ❌ fail context — reported `Status : Stopped`, matching the compose boot failure.` | -1 | unknown (coerced from string) | 0ms |
| 5 | `docker version — exit 1 — ❌ fail — Docker client could not connect to the `dockerDesktopLinuxEngine` endpoint in this environment.` | -1 | unknown (coerced from string) | 0ms |

## Deviations

The planned end-to-end rerun of both the focused backend web test and the repo-root verifier could not be completed after the final code edits because the local Docker Desktop Linux engine remained unavailable and the unit entered hard-timeout recovery. I finalized the durable code/doc changes and captured the environment failure explicitly instead of continuing to explore.

## Known Issues

Local Docker Desktop remained unhealthy for Docker-backed proofs during this task. `docker version` and compose commands reported the `dockerDesktopLinuxEngine` named pipe missing/unavailable, and the direct Playwright verification command timed out in the shell harness after already surfacing the new `[compose_boot]` failure. Re-run the backend test, direct Playwright proof pack, and `dart run tool/verify_m006_s12_control_plane_freshness.dart` once the Docker daemon is healthy.

## Files Created/Modified

- `tool/verify_m006_s12_control_plane_freshness.dart`
- `admin-web/playwright.global-setup.ts`
- `docs/runbooks/m006-s12-control-plane-freshness.md`
