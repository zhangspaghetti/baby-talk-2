---
phase: "13"
plan: "01"
---

# T01: Expose S14 release-closure contract helpers and add focused Dart tests.

**Expose S14 release-closure contract helpers and add focused Dart tests.**

## What Happened

I kept `tool/verify_m006_s14_release_closure.dart` composition-only and exposed the minimum read-only contract surface needed for cheap proof: public immutable child-gate metadata, a CLI parse helper, and pure fail-closed validators for gate contract and child output. I added `test/tool/verify_m006_s14_release_closure_test.dart` to lock the fixed child order (S07 -> S08 `--helm` -> S12 -> S13), exact step labels, verifier/runbook paths, scoped Playwright artifact hints, and malformed-input / malformed-child-output semantics without booting Docker, Playwright, or child verifiers. Because this repo’s `./flutter.cmd` wrapper changes cwd into `mobile/`, I also added `mobile/test/tool/verify_m006_s14_release_closure_test.dart` as a thin forwarder so the canonical root test stays under `test/tool` while the planned Flutter entrypoint remains runnable in this environment. After the focused proof went green, I also probed the slice-level repo-root gate: `--help` stayed green, while the full S14 runtime chain failed fast at the first red child (`S07`) and surfaced the expected drill-down hints rather than continuing to later gates.

## Verification

Verified the new focused contract seam with the planned Flutter test entrypoint (using the repo’s `flutter.cmd` wrapper in place of bare `flutter` in this shell) and confirmed the added root test stays green without booting runtime dependencies. Verified the real CLI help path with the bundled Flutter Dart executable at `C:\software\flutter\bin\dart.bat`, confirming the `dart run tool/verify_m006_s14_release_closure.dart --help` path still prints the usage contract. Also ran the full repo-root S14 verifier to record intermediate-task slice status: it failed fast at `Release closure | S07 mentor + distribution gate`, preserving the expected drill-down/runbook/artifact semantics while exposing an existing S07 compose/build red path outside T01 scope.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `flutter.cmd test test/tool/verify_m006_s14_release_closure_test.dart` | 0 | ✅ pass | 5865ms |
| 2 | `C:\software\flutter\bin\dart.bat run tool/verify_m006_s14_release_closure.dart --help` | 0 | ✅ pass | 2244ms |
| 3 | `C:\software\flutter\bin\dart.bat run tool/verify_m006_s14_release_closure.dart` | 1 | ❌ fail | 182226ms |

## Deviations

Added `mobile/test/tool/verify_m006_s14_release_closure_test.dart` as a local forwarding file because the repo’s Windows `./flutter.cmd` wrapper executes from `mobile/`; the canonical focused test source remains `test/tool/verify_m006_s14_release_closure_test.dart`.

## Known Issues

`C:\software\flutter\bin\dart.bat run tool/verify_m006_s14_release_closure.dart` is still red at the first child gate (`S07`). The observed failure is inside the S07-owned Playwright/compose path: `docker compose up -d --build postgres minio db-migration app-api admin-api admin-web` aborted during the compose boot/build flow with `target app-api: failed to receive status: rpc error: code = Unavailable desc = error reading from server: EOF`, and S14 correctly stopped without running S08/S12/S13.

## Files Created/Modified

- `tool/verify_m006_s14_release_closure.dart`
- `test/tool/verify_m006_s14_release_closure_test.dart`
- `mobile/test/tool/verify_m006_s14_release_closure_test.dart`
