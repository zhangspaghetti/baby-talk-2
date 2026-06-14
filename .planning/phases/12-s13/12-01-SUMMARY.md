---
phase: "12"
plan: "01"
---

# T01: Added explicit live-stack-only S12 replay mode and bounded front-door telemetry so S13 smoke reuses the live stack truthfully.

**Added explicit live-stack-only S12 replay mode and bounded front-door telemetry so S13 smoke reuses the live stack truthfully.**

## What Happened

I extended `tool/verify_m006_s12_control_plane_freshness.dart` with an explicit `--live-stack-only` mode while keeping the no-argument path as the canonical full replay. The thin mode reuses the existing runtime and reruns only `required_artifacts`, `runtime_truth`, and `browser_proof_pack`, which gives S13 smoke an explicit honest path instead of relying on `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT` alone.

I updated `tool/verify_m006_s13_demo_path.dart` so smoke delegates through that explicit thin command builder, and I added redaction-safe front-door telemetry persistence at `tmp/m006-s13-front-door-metrics.jsonl`. Demo and smoke now append bounded JSONL records with `mode`, `shell`, `success`, `tthw_seconds`, `first_failure_stage`, `likely_cause`, and `next_action`, then print bounded summary fields such as `telemetry_recent_entries`, `smoke_recent_pass_rate`, and `first_failure_hotspot`.

I added repo-root focused test coverage in `test/tool/verify_m006_s13_demo_path_test.dart` for S12 CLI parsing, the S13 smoke delegate contract, telemetry reduction, and redaction behavior. Because the local `flutter test test/tool/...` harness resolves under `mobile/test/...` in this worktree, I also added a tiny `mobile/test/tool/verify_m006_s13_demo_path_test.dart` delegate so the exact root verification command exercises the same repo-root assertions instead of duplicating logic.

During runtime verification, the first POSIX smoke rerun hit a transient Playwright timeout in the existing overview polling test (`overview-polling-alert`), but the immediate POSIX rerun and the Windows smoke rerun both passed without further code changes. The successful wrapper logs showed `live_stack_precondition -> fast_smoke`, and the nested S12 verifier printed `M006/S12 live-stack-only replay starting.` followed only by `required_artifacts`, `runtime_truth`, and `browser_proof_pack`, confirming that smoke no longer replays `backend_contract`, `admin_web_build`, or an outer `compose_boot`.

## Verification

- `flutter test test/tool/verify_m006_s13_demo_path_test.dart` passed after routing the exact Flutter harness path through the thin mobile delegate.
- `dart run tool/verify_m006_s13_demo_path.dart` passed the repo-root static contract check.
- `bash.cmd -lc "./scripts/dev-up-admin-demo.sh"` and `powershell.exe -NoProfile -Command "& './scripts/dev-up-admin-demo.cmd'"` both booted the split stack successfully and emitted telemetry.
- `bash.cmd -lc "./scripts/dev-verify-admin-demo.sh"` and `powershell.exe -NoProfile -Command "& './scripts/dev-verify-admin-demo.cmd'"` both exercised the live-stack smoke path; the successful runs showed the nested S12 verifier staying in live-stack-only mode and skipping the heavyweight replay stages.
- The slice telemetry check (`node -e ...`) passed and reported the latest successful demo/smoke entries with `demo_tthw_seconds=77`, `smoke_tthw_seconds=18`, and `first_failure_hotspot=none`.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `flutter test test/tool/verify_m006_s13_demo_path_test.dart` | 0 | ✅ pass | 12069ms |
| 2 | `dart run tool/verify_m006_s13_demo_path.dart` | 0 | ✅ pass | 2337ms |
| 3 | `bash.cmd -lc "./scripts/dev-up-admin-demo.sh"` | 0 | ✅ pass | 83614ms |
| 4 | `bash.cmd -lc "./scripts/dev-verify-admin-demo.sh"` | 0 | ✅ pass | 24323ms |
| 5 | `powershell.exe -NoProfile -Command "& './scripts/dev-up-admin-demo.cmd'"` | 0 | ✅ pass | 82192ms |
| 6 | `powershell.exe -NoProfile -Command "& './scripts/dev-verify-admin-demo.cmd'"` | 0 | ✅ pass | 20645ms |
| 7 | `node -e <m006-s13 telemetry check>` | 0 | ✅ pass | 639ms |

## Deviations

Added `mobile/test/tool/verify_m006_s13_demo_path_test.dart` as a thin delegate because this worktree's `flutter test test/tool/...` harness resolves under `mobile/test/...`; the actual assertions still live in the repo-root test file.

## Known Issues

No persistent issues. The first POSIX smoke rerun hit a transient `overview-polling-alert` Playwright timeout, but the immediate POSIX rerun and the Windows smoke rerun both passed.

## Files Created/Modified

- `tool/verify_m006_s12_control_plane_freshness.dart`
- `tool/verify_m006_s13_demo_path.dart`
- `test/tool/verify_m006_s13_demo_path_test.dart`
- `mobile/test/tool/verify_m006_s13_demo_path_test.dart`
