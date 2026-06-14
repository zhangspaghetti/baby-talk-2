# S13 Research — Golden path demo + README + Windows parity

## Summary

- S13 is **mostly already implemented in the worktree**. The full front-door surface exists:
  - `README.md`
  - `CONTRIBUTING.md`
  - `mobile/README.md`
  - `scripts/dev-up-admin-demo.(sh|cmd)`
  - `scripts/dev-verify-admin-demo.(sh|cmd)`
  - `docs/runbooks/m006-s13-demo-path.md`
  - `tool/verify_m006_s13_demo_path.dart`
  - S14 already references the S13 verifier (`tool/verify_m006_s14_release_closure.dart:50-52`).
- `gsd_milestone_status(M006)` still shows **S13 pending with 0 tasks**, but `.gsd/milestones/M006/slices/S09/S09-SUMMARY.md` explicitly says the S09 umbrella already landed the S13 surfaces and roadmap/state should be reassessed. Per **Karpathy / Think Before Coding**, planner should resolve **state drift vs real remaining work** before inventing more tasks.
- The one real behavior mismatch I found is the **fast smoke semantics**:
  - `tool/verify_m006_s13_demo_path.dart:285-341` smoke mode shells into `dart run tool/verify_m006_s12_control_plane_freshness.dart` and sets `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1` (`:319-323`).
  - But `tool/verify_m006_s12_control_plane_freshness.dart` still always runs `backend_contract` (`:62`), `admin_web_build` (`:76`), and outer `compose_boot` (`:81`) before browser proof.
  - The env var only changes the **Playwright** layer boot/teardown (`admin-web/playwright.global-setup.ts:380-397`, `admin-web/playwright.global-teardown.ts:18-19`).
  - So the smoke wrapper preserves the live stack for browser reuse, but it is **not a truly thin live-stack-only smoke** even though `README.md` and the S13 runbook describe it that way.
- Fresh evidence from this session:
  - `dart run tool/verify_m006_s13_demo_path.dart` → **pass**.
  - Windows `.cmd` demo wrapper via PowerShell → **pass**, `demo_status=ready`, `tthw_seconds=80`, `first_failure_stage=none`.
  - Windows `.cmd` smoke wrapper via PowerShell → **pass**, `smoke_status=passed`, `tthw_seconds=181`, `first_failure_stage=none`.
- One more drift signal: `.gsd/milestones/M006/slices/S09/S09-SUMMARY.md:44,96,142` claims `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1` means "do not boot compose" and reports smoke at `47s`; current code no longer matches that claim, and the fresh run confirms the heavier path.

## Requirement focus

- No new unvalidated product requirement ID was preloaded specifically for S13.
- Treat S13 as **developer-onboarding / proof-surface closure** that supports the already-validated admin requirements:
  - **R052** — the admin runtime must be practically reachable from repo root, not only theoretically present in feature slices.
  - **R053** — the admin/browser proof surfaces must remain reproducible and drill-down friendly from the top of the repo.
- Acceptance from the milestone context is still the useful target:
  1. `<2 min` to a usable admin demo via `.sh/.cmd` golden path.
  2. README is the single fresh-reader front door.
  3. Windows/POSIX stage vocabulary is identical.
  4. failure output is actionable.
  5. minimal DevEx measurement exists.
- Current state against that target:
  - **Demo TTHW:** met in this run (`80s`).
  - **Docs/front door:** met.
  - **Windows/POSIX vocabulary parity:** met at the wrapper/verifier contract level.
  - **Fast smoke honesty:** only partially met; it passes, but it is not actually a thin live-stack-only path.
  - **Measurement persistence:** ambiguous; current implementation emits `tthw_seconds` and `first_failure_stage` to stdout, but I found no persisted repo-local pass-rate / hotspot artifact.

## Skills Discovered

- Already installed and directly relevant:
  - `write-docs`
  - `docker-expert`
  - `karpathy-guidelines`
- Newly installed during this research:
  - `mindrally/skills@bash-scripting` → `bash-scripting`
- No further skill installation is necessary unless planner decides to change technologies beyond shell wrappers/docs/runtime verifiers.

## Recommendation

1. **First decide whether S13 is a real implementation slice or a state-reconciliation slice.**
   - The codebase already contains the full S13 surface.
   - GSD DB/roadmap state still says `pending`.
   - Per **Think Before Coding**, do not silently invent more work before resolving that mismatch.

2. **If S13 stays active, make the smoke semantics truthful before touching docs again.**
   - Per **Simplicity First**, do not create a second smoke harness.
   - The smallest correct fix is to make the S12 verifier expose a thinner mode (or a shared internal helper) that skips `backend_contract`, `admin_web_build`, and outer `compose_boot` when smoke is supposed to reuse an already-healthy stack.
   - Per **Surgical Changes**, if this is the chosen fix, touch only the S13→S12 seam plus any doc copy that becomes inaccurate.
   - Per **Goal-Driven Execution**, the success check is concrete: the smoke wrapper must still emit the same contract fields, but wall-clock behavior should materially drop because the outer build/test/compose steps no longer rerun.

3. **Treat docs/wrappers as already landed unless the smoke contract changes.**
   - README / CONTRIBUTING / mobile README / runbook are already coherent and pass the static verifier.
   - Planner should not burn tasks “rewrite docs” unless a behavior change forces doc drift.

4. **If the DevEx measurement requirement is interpreted strictly, add one tiny persisted artifact rather than an external system.**
   - Current stdout is enough for one-run evidence.
   - It is not enough for a repo-local “first smoke pass rate / common first failure hotspot” story unless another system is explicitly declared authoritative.
   - A lightweight JSON/JSONL append-only file under `.gsd/runtime/` (or similarly local location) would satisfy the intent without overbuilding.

5. **Do not rely on S14 alone to prove runtime front-door behavior.**
   - `tool/verify_m006_s14_release_closure.dart:50-52` only runs the default S13 verifier (static docs/wrapper contract).
   - If runtime demo/smoke behavior is the thing being closed, explicit wrapper runs still need to be in the slice evidence.

## Natural seams

1. **State/bookkeeping seam**
   - Decide whether to skip/fold S13 because S09 already implemented it, or keep S13 as a thin closure slice.

2. **Smoke-thinning seam**
   - Files: `tool/verify_m006_s13_demo_path.dart`, `tool/verify_m006_s12_control_plane_freshness.dart`, `admin-web/playwright.global-setup.ts`, `admin-web/playwright.global-teardown.ts`.
   - This is the only meaningful behavior mismatch I found.

3. **Measurement seam**
   - Files: likely only `tool/verify_m006_s13_demo_path.dart` plus docs/runbook if planner wants persisted DevEx telemetry.
   - Keep it tiny.

Everything else is already present and passing.

## Implementation Landscape

### 1) The front-door docs and wrappers are already assembled

**Docs**

- `README.md`
  - demo/smoke as the first commands (`README.md:12-55`)
  - role-based quickstarts (`README.md:88-137`)
  - copy-paste auth/API examples through the `admin-web` proxy (`README.md:139-184`)
  - old-monolith → split-stack migration table (`README.md:187-195`)
- `CONTRIBUTING.md`
  - daily workflow split by full-stack/backend/admin-web/mobile (`CONTRIBUTING.md:12-58`)
  - verification ladder anchored on S13/S12/S14 (`CONTRIBUTING.md:61-81`)
  - module boundary + review checklist (`CONTRIBUTING.md:83-103`)
- `mobile/README.md`
  - now explicitly says mobile is not the admin front door and points back to repo-root wrappers (`mobile/README.md:1-51`)
- `docs/runbooks/m006-s13-demo-path.md`
  - stage vocabulary, failure semantics, parity rules, and sensitive-output rules are all spelled out (`docs/runbooks/m006-s13-demo-path.md:11-126`)

**Wrappers**

- `scripts/dev-up-admin-demo.sh` / `.cmd`
  - only do repo-root resolution + `dart` preflight + shell-flavor export + delegation.
- `scripts/dev-verify-admin-demo.sh` / `.cmd`
  - same pattern for smoke.
- This is good architecture: the wrappers stay tiny and all actual contract logic lives in one Dart verifier.

### 2) `tool/verify_m006_s13_demo_path.dart` is the true S13 control plane

- Required artifact/doc contract lives at `tool/verify_m006_s13_demo_path.dart:28-46`.
- Static docs/link/wrapper parity verifier is `_runStaticVerification()` at `:88-206`.
- Runtime demo boot / health / handoff contract is `_runDemoMode()` at `:210-283`.
- Smoke mode is `_runSmokeMode()` at `:285-341`.
- Shell-aware `next_action` handling is `_nextWrapperCommand()` at `:929-935`.
- This file is already the right single source of truth for S13. If work remains, add it here instead of creating another repo-root verifier.

### 3) The smoke path currently delegates to a heavier S12 verifier than the docs imply

- `tool/verify_m006_s13_demo_path.dart:319-323` runs:
  - `dart run tool/verify_m006_s12_control_plane_freshness.dart`
  - with `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1`
- But S12 itself still always runs:
  - `backend_contract` (`tool/verify_m006_s12_control_plane_freshness.dart:62`)
  - `admin_web_build` (`:76`)
  - `compose_boot` (`:81`)
  - then browser proof (`:422`)
- The env var only affects Playwright layer boot/teardown:
  - `admin-web/playwright.global-setup.ts:380-397`
  - `admin-web/playwright.global-teardown.ts:18-19`
- Result:
  - smoke preserves the live stack for browser reuse,
  - but it is **not** a true thin live-stack smoke from repo root,
  - and current observed runtime (`181s`) reflects that.
- `README.md:49-56` and `docs/runbooks/m006-s13-demo-path.md:48-76` describe this as a fast live-stack smoke; that copy will remain overstated until the implementation is thinned or the docs are relaxed.

### 4) S13 state is drifted relative to the actual codebase

- `gsd_milestone_status(M006)` still reports:
  - `S13` pending
  - `taskCounts.total = 0`
- But `.gsd/milestones/M006/slices/S09/S09-SUMMARY.md`
  - explicitly says the S09 umbrella already landed the S13 surfaces and that roadmap reassess should fold S12/S13/S14 rather than treat them as fresh implementation gaps.
- Planner should not ignore this drift. It changes tasking strategy:
  - either plan only the remaining behavior mismatch(s),
  - or treat S13 as closure/bookkeeping and move straight to completion evidence.

### 5) Final release closure only catches static S13 drift, not runtime wrapper regressions

- `tool/verify_m006_s14_release_closure.dart:50-52`
  - wires S13 via `verifierPath: 'tool/verify_m006_s13_demo_path.dart'`
  - with no `demo` or `smoke` mode args
- So S14 currently proves:
  - docs truth
  - required artifact presence
  - wrapper delegation parity
- It does **not** prove:
  - demo runtime boot still works
  - smoke runtime still behaves as intended
- If S13 is being closed as a runtime contract, the explicit wrapper commands must still be part of the final slice evidence.

### 6) DevEx measurement is output-only today

- Search hits for `tthw_seconds` / `first_failure_stage` are all in:
  - wrapper stdout
  - runbook/docs
  - verifier stdout
- I did **not** find repo-local persistence or aggregation for:
  - first smoke pass rate
  - common first-failure hotspot across runs
- This is the only other possible residual gap against the original DevEx review, and it is much smaller than the smoke-thinning issue.

## Verification

Use this order if planner/executor needs to prove current reality before deciding whether to change code:

1. **Static front-door contract**
   ```bash
   dart run tool/verify_m006_s13_demo_path.dart
   ```

2. **Windows `.cmd` demo wrapper in this harness**
   ```powershell
   powershell.exe -NoProfile -Command "& '.\\scripts\\dev-up-admin-demo.cmd'"
   ```

   - Fresh run in this session: passed
   - `demo_status=ready`
   - `tthw_seconds=80`
   - `first_failure_stage=none`

3. **Windows `.cmd` smoke wrapper in this harness**
   ```powershell
   powershell.exe -NoProfile -Command "& '.\\scripts\\dev-verify-admin-demo.cmd'"
   ```

   - Fresh run in this session: passed
   - `smoke_status=passed`
   - `tthw_seconds=181`
   - `first_failure_stage=none`

4. **If smoke behavior is under investigation**
   ```bash
   dart run tool/verify_m006_s12_control_plane_freshness.dart
   rg -n "backend_contract|admin_web_build|compose_boot|browser_proof_pack" tool/verify_m006_s12_control_plane_freshness.dart
   rg -n "BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT|reuseComposeBoot" admin-web/playwright.global-setup.ts admin-web/playwright.global-teardown.ts
   ```

5. **If slice-state drift is under investigation**
   - inspect:
     - `gsd_milestone_status(M006)`
     - `.gsd/milestones/M006/slices/S09/S09-SUMMARY.md`

**Harness-specific gotcha:** in this Windows/bash tool environment, the `.cmd` wrappers were easiest to exercise through PowerShell. Direct `cmd /c ...` did not actually run the wrapper here.

## Open Questions / Planner Decisions

1. Should S13 now be treated as **already implemented, pending only DB/roadmap closure**?
2. If not, is the only code change needed to make smoke truly thin/live-stack-only?
3. Does the team want **persisted** DevEx measurement, or is stdout + outer GSD logs accepted as the measurement surface?
