---
phase: "13"
plan: "02"
---

# T02: Locked S14 CI/docs handoff to the canonical repo-root release command and added static drift assertions.

**Locked S14 CI/docs handoff to the canonical repo-root release command and added static drift assertions.**

## What Happened

Extended `test/tool/verify_m006_s14_release_closure_test.dart` from pure gate-contract coverage into repo-root handoff coverage. The new assertions mechanically lock `.github/workflows/ci.yml` to the existing S14 invocation shape (`localhost:2375` relay, `continue-on-error`, `if: always()` Playwright uploads, and upload-before-final-fail ordering) and also verify that README / CONTRIBUTING / the S14 runbook / the k8s runbook keep pointing at the same canonical `dart run tool/verify_m006_s14_release_closure.dart` command plus resolvable drill-down references.

To make that static proof stable, I tightened wording in `README.md`, `CONTRIBUTING.md`, `docs/runbooks/m006-s14-release-closure.md`, and `docs/runbooks/k8s-deploy.md`: they now explicitly call S14 the sole repo-root final release command and keep `admin-api` framed as internal-only. `.github/workflows/ci.yml` itself did not need source changes — the workflow already matched the required relay/artifact-preserving structure, so the main implementation value here was turning that contract into executable drift guards.

I also replayed the slice-level full gate for fresh evidence. `dart run tool/verify_m006_s14_release_closure.dart` completed successfully, emitted the final S14 success marker, and traversed S07 / S08 / S12 / S13 end to end without reopening any child boundary.

## Verification

Ran `./flutter.cmd test test/tool/verify_m006_s14_release_closure_test.dart` on Windows so the repo wrapper could enter `mobile/` and execute the thin forwarder for the canonical root test; all focused contract + handoff assertions passed. Ran `dart run tool/verify_m006_s14_release_closure.dart --help`; the usage contract stayed stable. Replayed `dart run tool/verify_m006_s14_release_closure.dart`; the full release-closure chain passed and printed `All M006/S14 release-closure verification steps passed.`

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./flutter.cmd test test/tool/verify_m006_s14_release_closure_test.dart` | 0 | ✅ pass | 5744ms |
| 2 | `dart run tool/verify_m006_s14_release_closure.dart --help` | 0 | ✅ pass | 2308ms |
| 3 | `dart run tool/verify_m006_s14_release_closure.dart` | 0 | ✅ pass | 506900ms |

## Deviations

Used `./flutter.cmd test test/tool/verify_m006_s14_release_closure_test.dart` instead of bare `flutter test ...` because this Windows worktree relies on the repo wrapper to `cd` into `mobile/`; without the wrapper, the root invocation failed before reaching the focused test logic. I also replayed the full S14 gate during T02 to satisfy slice-level verification and capture fresh runtime evidence, even though T03 is the task that formally owns the expensive replay.

## Known Issues

None.

## Files Created/Modified

- `test/tool/verify_m006_s14_release_closure_test.dart`
- `README.md`
- `CONTRIBUTING.md`
- `docs/runbooks/m006-s14-release-closure.md`
- `docs/runbooks/k8s-deploy.md`
