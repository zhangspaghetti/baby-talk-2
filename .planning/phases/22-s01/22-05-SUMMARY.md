---
phase: "22"
plan: "05"
---

# T05: Repointed README/CONTRIBUTING and the admin-demo wrapper aliases to the M007 Helm-first front door, and removed docker-compose.yml.

**Repointed README/CONTRIBUTING and the admin-demo wrapper aliases to the M007 Helm-first front door, and removed docker-compose.yml.**

## What Happened

Rewrote `README.md` so the top-level onboarding path is now the Helm baseline introduced in S01: it adds one-time prerequisites (`kind`, `helm`, `kubectl`, `dart`/`flutter`), promotes `./scripts/dev-up-helm-demo.sh` / `scripts\dev-up-helm-demo.cmd` as the primary quickstart, updates the output contract to the real M007 fields (`demo_status`, `tthw_seconds`, `gateway_url`, `next_action`), switches fast smoke to the Helm verifier wrapper, and replaces the old M006 release-closure front-door guidance with `bash ci/k8s-smoke.sh` as the current S01 CI-equivalent gate plus `dart run tool/verify_m007_s01_helm_baseline.dart demo` as the local full verifier. I also updated the split-stack map to include the gateway stub at port 8090 and removed all root-level compose quickstart guidance from the document.

Rewrote `CONTRIBUTING.md` to make the Helm wrappers the only promoted front door, updated the backend-only instructions to either use `./scripts/dev-up-helm-demo.sh` or the explicit `helm upgrade --install babytalk-infra ...` / `helm upgrade --install babytalk-app ...` flow, and replaced the M006 verification ladder references with the M007 verifier and `ci/k8s-smoke.sh` truth. The four legacy `dev-up-admin-demo.*` and `dev-verify-admin-demo.*` scripts were preserved as compatibility shims only: they still do the local Dart preflight check, but now delegate directly to the Helm wrappers instead of invoking the compose-era M006 verifier. Finally, I removed the repo-root `docker-compose.yml` file so the repository no longer advertises a second local bootstrap path.

## Verification

Verified the documentation and wrapper cutover with targeted contract checks: the repo no longer contains `docker-compose.yml`, README/CONTRIBUTING contain no `docker compose`/`docker-compose` references and no M006 front-door verifier references, `.github/workflows/ci.yml` still contains no `verify_m006_s14_release_closure` reference, both POSIX admin-demo shims pass `bash -n` and print the M007 verifier usage on `--help`, and both CMD shims also resolve to the M007 verifier on `--help`. I re-ran `dart analyze tool/verify_m007_s01_helm_baseline.dart` to confirm the canonical verifier still compiles cleanly after the doc/wrapper cutover, re-ran `bash ci/k8s-smoke.sh` to satisfy the slice-level Helm verification bar, and checked `tmp/m007-s01-helm-metrics.jsonl` to confirm the bounded telemetry file still exists with the required M007 keys (`mode`, `shell`, `success`, `tthw_seconds`, `first_failure_stage`, `likely_cause`, `next_action`, `timestamp`).

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `bash -lc "! test -f docker-compose.yml && grep -q 'dev-up-helm-demo' README.md && ! rg -n 'docker compose|docker-compose' README.md CONTRIBUTING.md && ! rg -n 'verify_m006|dev-up-admin-demo|dev-verify-admin-demo' README.md CONTRIBUTING.md"` | 0 | ✅ pass | 699ms |
| 2 | `bash -lc "! rg -n 'verify_m006_s14_release_closure' .github/workflows/ci.yml"` | 0 | ✅ pass | 585ms |
| 3 | `bash -lc "set -o pipefail && bash -n scripts/dev-up-admin-demo.sh && bash -n scripts/dev-verify-admin-demo.sh && ./scripts/dev-up-admin-demo.sh --help | grep -q 'verify_m007_s01_helm_baseline.dart' && ./scripts/dev-verify-admin-demo.sh --help | grep -q 'verify_m007_s01_helm_baseline.dart'"` | 0 | ✅ pass | 7305ms |
| 4 | `bash -lc 'start=$(date +%s%3N); cmd /c "scripts\\dev-up-admin-demo.cmd --help | findstr /c:verify_m007_s01_helm_baseline.dart >nul && scripts\\dev-verify-admin-demo.cmd --help | findstr /c:verify_m007_s01_helm_baseline.dart >nul"; status=$?; end=$(date +%s%3N); printf "status=%s durationMs=%s\n" "$status" "$((end-start))"; exit "$status"'` | 0 | ✅ pass | 89ms |
| 5 | `dart analyze tool/verify_m007_s01_helm_baseline.dart` | 0 | ✅ pass | 1511ms |
| 6 | `bash ci/k8s-smoke.sh` | 0 | ✅ pass | 4896ms |
| 7 | `python telemetry schema check (tmp/m007-s01-helm-metrics.jsonl)` | 0 | ✅ pass | 1ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `README.md`
- `CONTRIBUTING.md`
- `scripts/dev-up-admin-demo.sh`
- `scripts/dev-up-admin-demo.cmd`
- `scripts/dev-verify-admin-demo.sh`
- `scripts/dev-verify-admin-demo.cmd`
- `docker-compose.yml`
