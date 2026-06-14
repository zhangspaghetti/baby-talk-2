---
phase: "08"
plan: "04"
---

# T04: Added the S14 release-closure verifier, CI handoff, and repo-front-door links for one-command M006 closure.

**Added the S14 release-closure verifier, CI handoff, and repo-front-door links for one-command M006 closure.**

## What Happened

Implemented `tool/verify_m006_s14_release_closure.dart` as a thin repo-root orchestrator that runs `S07 -> S08 --helm -> S12 -> S13`, checks each child verifier and drill-down runbook exists, bounds each child with its own timeout, and fails fast with explicit child-gate labels plus `drill_down_verifier` / `drill_down_runbook` / artifact hints instead of rebuilding compose, browser, or Helm logic. Rewired `.github/workflows/ci.yml` to call the same S14 gate under the existing `localhost:2375` Docker relay and keep `admin-web/playwright-report` + `admin-web/test-results` discoverable from CI even when the verifier fails. Added `docs/runbooks/m006-s14-release-closure.md` and updated `README.md`, `CONTRIBUTING.md`, and `docs/runbooks/k8s-deploy.md` so fresh readers and release reviewers land on S14 first while S08 remains the scoped Helm truth and `admin-api` stays internal-only.

## Verification

Ran `cmd /c dart analyze tool/verify_m006_s14_release_closure.dart` and got a clean analyzer result. Ran `dart run tool/verify_m006_s14_release_closure.dart`; the full S14 chain completed in 367s with S07 mentor/distribution proof, S08 Helm smoke (40 pass / 0 fail), S12 overview/auth proof, and S13 front-door contract all green. Re-ran the task-plan grep checks against `.github/workflows/ci.yml` and `docs/runbooks/m006-s14-release-closure.md README.md` to confirm the CI command, `2375` relay, artifact upload, and child-verifier links all point at S14, then verified `admin-web/playwright-report/index.html` exists for browser drill-down.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cmd /c dart analyze tool/verify_m006_s14_release_closure.dart` | 0 | ✅ pass | 3635ms |
| 2 | `dart run tool/verify_m006_s14_release_closure.dart` | 0 | ✅ pass | 367000ms |
| 3 | `rg -n "verify_m006_s14_release_closure|playwright-report|upload-artifact|2375" .github/workflows/ci.yml` | 0 | ✅ pass | 53ms |
| 4 | `rg -n "verify_m006_s14_release_closure|verify_m006_s08_release|verify_m006_s07_mentor_distribution|verify_m006_s12_control_plane_freshness|verify_m006_s13_demo_path" docs/runbooks/m006-s14-release-closure.md README.md` | 0 | ✅ pass | 16ms |
| 5 | `python -c "import os,sys; sys.exit(0 if os.path.exists('admin-web/playwright-report/index.html') else 1)"` | 0 | ✅ pass | 31ms |

## Deviations

Updated `CONTRIBUTING.md` in addition to the plan's explicit output list so no repo-front-door doc still advertised the old S08-only closure entrypoint.

## Known Issues

`tool/verify_m006_s12_control_plane_freshness.dart` and `tool/verify_m006_s13_demo_path.dart` still echo literal `$ ${step.renderedCommand}` / `$ ${gate.rerunCommand}` in their own per-step command banner because those scripts use raw-string logging; S14's `drill_down_verifier` fields remain truthful, so I left that cosmetic cleanup out of scope.

## Files Created/Modified

- `tool/verify_m006_s14_release_closure.dart`
- `.github/workflows/ci.yml`
- `docs/runbooks/m006-s14-release-closure.md`
- `README.md`
- `CONTRIBUTING.md`
- `docs/runbooks/k8s-deploy.md`
