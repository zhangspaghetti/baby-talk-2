---
phase: "21"
plan: "04"
---

# T04: Hardened named Helm smoke assertions, switched CI/verifier wiring to the full gate, and stabilized flaky admin Playwright release checks.

**Hardened named Helm smoke assertions, switched CI/verifier wiring to the full gate, and stabilized flaky admin Playwright release checks.**

## What Happened

I rewrote `ci/k8s-smoke.sh` from kind-count placebo checks into named split-stack assertions. The script now proves `Service/Deployment` truth for `babytalk-app-api`, `babytalk-admin-api`, and `babytalk-admin-web`; rejects the legacy single-workload `babytalk` resources; asserts production-only ingresses for `app-api` and `admin-web` while keeping `admin-api` internal; checks the `db-migration` pre-install/pre-upgrade hook; validates the Helm test pod targets the split services; and inspects rendered release notes for the public/internal service contract. I then wired `tool/verify_m006_s08_release.dart` so the no-flag path is the full release gate and `--runtime` / `--helm` are retained only as scoped debug subpaths, then switched `.github/workflows/ci.yml` from `--runtime` to the no-flag verifier while preserving the localhost:2375 relay and always-uploaded Playwright evidence path.

Local reality differed slightly from the plan: `deploy/helm/babytalk/templates/tests/test-connection.yaml` and `deploy/helm/babytalk/templates/NOTES.txt` were already aligned with the split service truth, so I preserved those files and moved the closure proof into the smoke/verifier path instead of editing template text just to satisfy the checklist.

During final verification, the previously recorded browser flake reappeared. `admin-web/tests/knowledge-ops.spec.ts` was assuming ingestion GETs must go fully idle, but the page legitimately keeps polling while unrelated live queue items exist. `admin-web/tests/users-management.spec.ts` was assuming the newly seeded consumer always appears on the default first page, which is brittle against persistent compose data and sorting drift. I hardened those tests so Knowledge Ops now proves selected-context stability + non-stale behavior across a poll window, and Users now proves deterministic query-hit behavior instead of page-one ordering.

## Verification

Passed the task-plan verification commands: `bash ci/k8s-smoke.sh`, `dart run tool/verify_m006_s08_release.dart --helm`, and `rg -n "verify_m006_s08_release" .github/workflows/ci.yml && ! rg -n -- "--runtime" .github/workflows/ci.yml`. I also reran the canonical admin browser proof pack with `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts users-management.spec.ts knowledge-ops.spec.ts`, which passed 13/13 after stabilizing the two flaky browser assumptions. An earlier no-flag `dart run tool/verify_m006_s08_release.dart` run proved compose boot + backend reactor tests and surfaced the browser assumptions fixed here; a final fresh no-flag rerun after the last users-management stabilization was not captured before hard-timeout recovery.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `bash ci/k8s-smoke.sh` | 0 | ✅ pass | 5422ms |
| 2 | `dart run tool/verify_m006_s08_release.dart --helm` | 0 | ✅ pass | 6310ms |
| 3 | `rg -n "verify_m006_s08_release" .github/workflows/ci.yml && ! rg -n -- "--runtime" .github/workflows/ci.yml` | 0 | ✅ pass | 175ms |
| 4 | `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts users-management.spec.ts knowledge-ops.spec.ts` | 0 | ✅ pass | 139300ms |

## Deviations

Preserved `deploy/helm/babytalk/templates/tests/test-connection.yaml` and `deploy/helm/babytalk/templates/NOTES.txt` unchanged because local reality already had the correct split-service truth; the actual gap was missing enforcement in smoke/verifier/CI. Under hard-timeout recovery, I stopped after re-validating the canonical Playwright proof pack instead of running one more fresh no-flag verifier pass.

## Known Issues

A final post-fix no-flag `dart run tool/verify_m006_s08_release.dart` rerun was not captured before timeout recovery. Re-run that single command before slice completion if you need one-command end-to-end evidence after the last browser-test stabilization.

## Files Created/Modified

- `ci/k8s-smoke.sh`
- `tool/verify_m006_s08_release.dart`
- `.github/workflows/ci.yml`
- `admin-web/tests/knowledge-ops.spec.ts`
- `admin-web/tests/users-management.spec.ts`
