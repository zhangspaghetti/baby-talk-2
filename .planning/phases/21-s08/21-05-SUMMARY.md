---
phase: "21"
plan: "05"
---

# T05: Rewrote the Kubernetes deploy runbook around the split-stack admin release path and migration-first verification gates.

**Rewrote the Kubernetes deploy runbook around the split-stack admin release path and migration-first verification gates.**

## What Happened

Rewrote `docs/runbooks/k8s-deploy.md` in place so the existing README entry and `ci/k8s-smoke.sh` runbook check continue to point at the canonical deployment document. Replaced the outdated single-`babytalk/backend` story with the actual split-stack topology: public `app-api`, public `admin-web`, internal-only `admin-api`, and `db-migration` as the `pre-install,pre-upgrade` schema owner. Added fresh-reader-oriented sections for required secrets/config, chart preflight, repo-root release gating, Helm upgrade flow, cluster acceptance, signal-first troubleshooting, and rollback rules. Documented the non-obvious hook-delete-policy behavior so operators do not misread a missing post-success `db-migration` Job as a deployment failure. Kept the task within deploy-truth scope and did not expand into root README quickstart, onboarding, or Windows parity work.

## Verification

Verified both the task-level documentation contract and the slice-level release closure contract. `rg -n "db-migration|app-api|admin-api|admin-web|verify_m006_s08_release|ci/k8s-smoke.sh|internal-only" docs/runbooks/k8s-deploy.md` confirmed the runbook now captures the split-stack workloads, repo-root verifier, Helm smoke script, and internal-only boundary. `rg -c "^## " docs/runbooks/k8s-deploy.md` returned `10`, confirming the runbook is a structured operational document rather than a stub. `dart run tool/verify_m006_s08_release.dart` passed end-to-end: compose migration-first truth, backend Maven tests, canonical Playwright admin proof pack (13 passing specs), and the embedded Helm smoke proof. `bash ci/k8s-smoke.sh` then passed independently with 40 PASS / 0 FAIL / 0 SKIP, confirming named split-stack resources, hook annotations, NOTES truth, and runbook presence. `rg -n "setup-node|playwright install chromium --with-deps|2375|playwright-report|verify_m006_s08_release" .github/workflows/ci.yml` confirmed the CI wiring still points at the expected Node/Playwright/Docker relay/report/verifier steps.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `rg -n "db-migration|app-api|admin-api|admin-web|verify_m006_s08_release|ci/k8s-smoke.sh|internal-only" docs/runbooks/k8s-deploy.md` | 0 | ✅ pass | 276ms |
| 2 | `rg -c "^## " docs/runbooks/k8s-deploy.md` | 0 | ✅ pass | 305ms |
| 3 | `rg -n "setup-node|playwright install chromium --with-deps|2375|playwright-report|verify_m006_s08_release" .github/workflows/ci.yml` | 0 | ✅ pass | 266ms |
| 4 | `bash ci/k8s-smoke.sh` | 0 | ✅ pass | 6032ms |
| 5 | `dart run tool/verify_m006_s08_release.dart` | 0 | ✅ pass | 326899ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `docs/runbooks/k8s-deploy.md`
