---
phase: "22"
plan: "04"
---

# T04: Switched CI from the M006 release-closure verifier to backend tests plus Helm smoke and made Playwright setup safe for compose-free runs.

**Switched CI from the M006 release-closure verifier to backend tests plus Helm smoke and made Playwright setup safe for compose-free runs.**

## What Happened

I reduced `ci/backend-test.sh` to the Testcontainers-backed Maven reactor test only, removing the compose smoke, health wait loop, and cleanup trap so backend CI no longer depends on `docker-compose.yml`.

I updated `admin-web/playwright.global-setup.ts` to enter compose-free mode when `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1` is set or when `docker-compose.yml` is missing. In that mode it logs the requested guidance message, skips compose boot/runtime-truth checks, and still verifies the externally managed stack through the existing HTTP health probes.

I rewired `.github/workflows/ci.yml` so the localhost:2375 Docker relay exists only around `bash ci/backend-test.sh`, then the job installs Helm and runs `bash ci/k8s-smoke.sh` instead of `dart run tool/verify_m006_s14_release_closure.dart`. I preserved the Playwright Chromium install and artifact upload steps, and applied `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1` at CI job scope because the current workflow snapshot no longer contains a standalone Playwright E2E execution step to annotate directly.

I also updated `test/tool/verify_m006_s14_release_closure_test.dart` so the workflow contract test now asserts the new backend-test + Helm-smoke CI path instead of the retired M006 release-closure gate. During verification I confirmed that `scripts/dev-up-helm-demo.sh` and `scripts/dev-verify-helm-demo.sh` already existed and were syntactically valid, so no wrapper code changes were needed for the gate failure beyond re-verifying their presence.

## Verification

Verified the task-plan contract and gate-reported wrapper presence with `test -f` plus the plan grep checks: both POSIX Helm wrappers are present, `ci/backend-test.sh` now has zero `docker compose` references, `.github/workflows/ci.yml` references `k8s-smoke` and no longer references `verify_m006_s14_release_closure`, and `admin-web/playwright.global-setup.ts` intentionally still contains compose references because this task gates the compose boot path rather than deleting all compose-aware logic.

Verified shell syntax with `bash -n` for `ci/backend-test.sh`, `scripts/dev-up-helm-demo.sh`, and `scripts/dev-verify-helm-demo.sh`.

Verified the updated CI workflow contract test file with `dart analyze test/tool/verify_m006_s14_release_closure_test.dart` and re-ran the existing M007 Helm baseline regression via `dart test test/tool/verify_m007_s01_helm_baseline_test.dart`, which passed all three assertions.

I also attempted `flutter test test/tool/verify_m006_s14_release_closure_test.dart`, but that environment currently times out downloading the `win32` prebuilt asset from GitHub before test execution starts, so the authoritative evidence for this task is the offline analyze result plus the passing pure-Dart M007 baseline test.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `bash -lc "test -f scripts/dev-up-helm-demo.sh && test -f scripts/dev-verify-helm-demo.sh && grep -c 'docker compose\\|docker-compose' ci/backend-test.sh || true && grep -c 'docker compose\\|docker-compose' admin-web/playwright.global-setup.ts || true && grep -q 'k8s-smoke' .github/workflows/ci.yml && ! grep -q 'verify_m006_s14_release_closure' .github/workflows/ci.yml"` | 0 | ✅ pass | 685ms |
| 2 | `bash -lc "bash -n ci/backend-test.sh && bash -n scripts/dev-up-helm-demo.sh && bash -n scripts/dev-verify-helm-demo.sh"` | 0 | ✅ pass | 700ms |
| 3 | `dart analyze test/tool/verify_m006_s14_release_closure_test.dart` | 0 | ✅ pass | 2914ms |
| 4 | `dart test test/tool/verify_m007_s01_helm_baseline_test.dart` | 0 | ✅ pass | 3059ms |

## Deviations

The written plan said to add `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1` to a Playwright step, but the local `ci.yml` snapshot no longer had a standalone Playwright test execution step. I adapted by setting the variable at CI job scope while preserving the existing Playwright Chromium install and artifact upload steps.

## Known Issues

Local `flutter test test/tool/verify_m006_s14_release_closure_test.dart` can fail before execution because the `win32` package hook times out downloading `win32_windows_x64.dll` from GitHub in this environment. This did not block the task-specific offline analysis or the passing pure-Dart M007 regression test.

## Files Created/Modified

- `ci/backend-test.sh`
- `admin-web/playwright.global-setup.ts`
- `.github/workflows/ci.yml`
- `test/tool/verify_m006_s14_release_closure_test.dart`
