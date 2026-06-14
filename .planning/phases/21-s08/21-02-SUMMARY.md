---
phase: "21"
plan: "02"
---

# T02: Rewired CI to run the M006/S08 runtime release verifier through a localhost:2375 Docker relay and always upload Playwright evidence.

**Rewired CI to run the M006/S08 runtime release verifier through a localhost:2375 Docker relay and always upload Playwright evidence.**

## What Happened

Updated `.github/workflows/ci.yml` by repurposing the old backend-only leg into a `release-runtime-gate` job so the workflow replays the repo-root M006/S08 release path instead of hand-assembling a second sequence in YAML. The new job now installs JDK 17, Node.js, Dart, and `admin-web` dependencies, runs `npx playwright install chromium --with-deps`, starts a short-lived `ci-docker-relay` container that exposes `/var/run/docker.sock` on `tcp://localhost:2375`, and then executes `dart run tool/verify_m006_s08_release.dart --runtime` with `DOCKER_HOST` pointed at that relay. To preserve browser evidence when the verifier fails in its Playwright leg, the workflow runs the verifier with `continue-on-error`, uploads `admin-web/playwright-report` plus `admin-web/test-results` under `if: always()`, emits relay diagnostics when the verifier outcome is non-success, tears the relay down, and finally fails the job in a dedicated enforcement step. `mobile-analyze` was left as its own separate job, and the three backend module POM files were deliberately left untouched so the CI-side relay, not POM churn, satisfies the existing Testcontainers `localhost:2375` contract.

## Verification

Verified the workflow wiring with `rg -n "setup-node|setup-dart|playwright install chromium --with-deps|2375|playwright-report|verify_m006_s08_release" .github/workflows/ci.yml`, which hit all expected setup, relay, artifact, and verifier lines. Confirmed the task respected the boundary condition with `git diff --quiet -- backend/app-api/pom.xml backend/admin-api/pom.xml backend/db-migration/pom.xml`, which returned clean. Ran the slice-level `bash ci/k8s-smoke.sh` check and it passed locally. Re-ran the repo-root runtime verifier with `dart run tool/verify_m006_s08_release.dart --runtime`; it still fails in the pre-existing canonical browser red path at `admin-web/tests/knowledge-ops.spec.ts:299` (`expectIngestionReadsToSettle`, expected 11 received 13), while still materializing `admin-web/playwright-report/index.html` and the failing trace/video/screenshot outputs that the new workflow is now configured to upload.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `rg -n "setup-node|setup-dart|playwright install chromium --with-deps|2375|playwright-report|verify_m006_s08_release" .github/workflows/ci.yml` | 0 | ✅ pass | 66ms |
| 2 | `git diff --quiet -- backend/app-api/pom.xml backend/admin-api/pom.xml backend/db-migration/pom.xml` | 0 | ✅ pass | 86ms |
| 3 | `bash ci/k8s-smoke.sh` | 0 | ✅ pass | 3532ms |
| 4 | `dart run tool/verify_m006_s08_release.dart --runtime` | 1 | ❌ fail | 319972ms |

## Deviations

Repurposed the existing `backend-test` slot into `release-runtime-gate` instead of keeping a second backend-only job, so CI has one release-order source of truth via the repo-root verifier rather than two partially overlapping legs.

## Known Issues

`dart run tool/verify_m006_s08_release.dart --runtime` remains red because `admin-web/tests/knowledge-ops.spec.ts` still fails in `expectIngestionReadsToSettle` at line 299 after the retry flow (`expected 11, received 13`). Also, although `bash ci/k8s-smoke.sh` passes today, the script still proves the split-stack chart by counting rendered `kind:` lines rather than asserting resource names, so that stricter slice stop condition remains for a later S08 task.

## Files Created/Modified

- `.github/workflows/ci.yml`
