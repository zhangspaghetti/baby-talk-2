# S09 Research — 端到端集成验证 + 部署更新

## Summary

- This unit is **not a normal implementation slice anymore**. The original roadmap-level “端到端集成验证 + 部署更新” scope has already been partially closed by completed follow-on slices:
  - **S07** now owns mentor/distribution shared-shell composition proof (`tool/verify_m006_s07_mentor_distribution.dart`).
  - **S08** now owns the split-stack release/deploy gate for users + knowledge (`tool/verify_m006_s08_release.dart`, `.github/workflows/ci.yml`, `ci/k8s-smoke.sh`, `docs/runbooks/k8s-deploy.md`).
- Biggest surprise: the milestone artifacts are **scope-drifted**.
  - `gsd_milestone_status` shows **S09, S12, S13, S14** all pending with **0 tasks**.
  - `.gsd/milestones/M006/S09-TASKS.md` is **stale saved-view / handoff** work and does **not** match the current roadmap/system-event scope.
  - The current auto-mode event still names S09 as the original umbrella, while the real remaining work already has better pending homes in `S12-TASKS.md`, `S13-TASKS.md`, and `S14-TASKS.md`.
- The actual remaining work now clusters into three natural seams:
  1. **S12** — Overview/control-plane freshness + SSE fallback.
  2. **S13** — golden-path demo + README/front-door truth + Windows parity + measurement.
  3. **S14** — final release-closure aggregation across the already-green S07/S08 proof packs.
- Per **Karpathy Guidelines**:
  - **Think Before Coding**: planner must first decide whether to treat S09 as an umbrella research label or a direct implementation slice.
  - **Simplicity First**: reuse the existing compose/Playwright/Helm verifiers; do not invent a second browser/deploy harness.
  - **Surgical Changes**: S12 is the only real greenfield code path. S13 should mostly add wrappers/docs. S14 should mostly compose existing proof surfaces.

## Requirement focus

- No active `REQUIREMENTS.md` payload was preloaded beyond the already-validated milestones notes in the system event.
- Treat this research as **residual roadmap closure** on top of already-validated **R052** and **R053**, not as a new product-surface invention.
- Practical implication for planner:
  - **Do not break the existing S07/S08 proof packs** while finishing the remaining closure work.
  - Any new S12/S13/S14 tasks should be judged against whether they preserve:
    - `dart run tool/verify_m006_s08_release.dart`
    - `dart run tool/verify_m006_s07_mentor_distribution.dart`

## Skills Discovered

- Already available and directly relevant:
  - `docker-expert`
  - `github-workflows`
  - `kubernetes-specialist`
  - `react-best-practices`
  - `write-docs`
  - `karpathy-guidelines`
- Newly installed for this research:
  - `currents-dev/playwright-best-practices-skill@playwright-best-practices`
- No further skill installation is necessary unless planner chooses a new technology outside the current stack.

## Recommendation

1. **Re-baseline slice identity before tasking.**
   - Treat the current “S09” auto-mode event as an **umbrella research label**, not as permission to implement the stale `S09-TASKS.md` saved-view/handoff scope.
   - For execution planning, align directly to the already-pending sketches:
     - `S12-TASKS.md`
     - `S13-TASKS.md`
     - `S14-TASKS.md`

2. **Use the existing proof packs as the substrate, not as references.**
   - `tool/verify_m006_s08_release.dart` is already the canonical split-stack release gate for users + knowledge + Helm truth.
   - `tool/verify_m006_s07_mentor_distribution.dart` is already the canonical mentor/distribution shared-shell closure proof.
   - Future S14 should **compose** these verifiers (and the future S12/S13 verifiers), not re-encode their steps from scratch.

3. **Treat S12 as the only genuinely risky new code path.**
   - `admin-web/src/pages/OverviewPage.tsx` is still a placeholder.
   - There is no current overview backend, no summary snapshot layer, and no SSE transport.
   - This is the only remaining area where planner should expect meaningful backend + frontend design work instead of mostly orchestration/doc glue.

4. **Treat S13 as new wrappers + docs, not as “fix the old scripts.”**
   - Existing root scripts are good pattern references for cross-platform shell style, but several are semantically stale and still describe the pre-split monolith.
   - The safest path is to add a new M006 admin demo/smoke pair and rewrite README around them.

5. **Keep deploy truth centralized.**
   - `docs/runbooks/k8s-deploy.md` is already the truthful split-stack deploy runbook.
   - S13 should link to it rather than duplicating Helm/deploy guidance.
   - S14 should only extend the proof/evidence chain if the milestone still needs one final release-closure command.

## Implementation Landscape

### 1) Milestone artifact drift / planning boundary

**What exists**

- `gsd_milestone_status("M006")`
  - shows `S09`, `S12`, `S13`, `S14` all **pending** with **0 tasks**.
- `.gsd/milestones/M006/slices/S09/`
  - currently empty.
- `.gsd/milestones/M006/S09-TASKS.md`
  - stale saved-view/handoff scope.
- `.gsd/milestones/M006/S12-TASKS.md`
  - matches the remaining Overview/control-plane freshness work.
- `.gsd/milestones/M006/S13-TASKS.md`
  - matches the remaining golden-path/README/Windows/devex work.
- `.gsd/milestones/M006/S14-TASKS.md`
  - matches the remaining final release-closure aggregation work.

**Planner implication**

- Do **not** decompose execution from `S09-TASKS.md`.
- If workflow tooling forces the `S09` label, planner should explicitly note that `S09` is being treated as a research umbrella and that actual execution will follow the S12/S13/S14 sketches.

### 2) Existing split-stack runtime/release substrate is already real

**Key files**

- `docker-compose.yml`
  - Already models the real split stack:
    - `postgres`
    - `minio`
    - `db-migration`
    - `app-api`
    - `admin-api`
    - `admin-web`
  - `app-api` and `admin-api` both depend on `db-migration: service_completed_successfully`.
  - `admin-web` depends on healthy `admin-api`.
  - Uses `BABY_TALK_EMBEDDING_MODE=dev-hash` by default, which is now the truthful local/admin runtime substrate.
- `tool/verify_m006_s08_release.dart`
  - Already sequences:
    1. `Runtime | compose boot`
    2. `Runtime | migration-first compose truth`
    3. `Runtime | backend reactor tests`
    4. `Runtime | canonical admin browser proof pack`
    5. `Helm | split-stack smoke proof`
- `.github/workflows/ci.yml`
  - Already runs the S08 verifier in CI.
  - Already installs Node/Dart/JDK, Playwright Chromium, and the `localhost:2375` Docker relay for Testcontainers.
  - Already uploads `admin-web/playwright-report` and `admin-web/test-results`.
- `tool/verify_m006_s07_mentor_distribution.dart`
  - Already replays:
    1. focused backend contracts,
    2. `admin-web` build,
    3. mentor/distribution browser closure pack.

**Planner implication**

- S14 should **aggregate** these proof packs.
- S13 demo wrappers should **call into** these verifiers or thin smoke layers rather than duplicating compose/health logic.
- Do not create a second compose boot path or a second Helm smoke path.

### 3) Overview / control-plane gap is still genuine greenfield (S12)

**Key files**

- `admin-web/src/pages/OverviewPage.tsx`
  - Still a placeholder. It literally says:
    - `Overview shell seed 已接线`
    - `这里先保留 truthful placeholder，不伪造 prioritized inbox、健康分数或跨域 KPI；后续切片会把真实待处理工作流挂进来。`
  - It also lists future items only:
    - prioritized inbox + domain counts
    - stale/freshness strip + recent activity
- `admin-web/src/app/routes.tsx`
  - Still presents `Overview` as the unified multi-domain entrypoint, but there is no matching backend overview contract.
- No current overview backend or realtime transport:
  - search over `admin-web/src`, `backend/admin-api`, `backend/common` found **no** `EventSource`, `SseEmitter`, `text/event-stream`, or `MediaType.TEXT_EVENT_STREAM_VALUE` usage.

**Existing freshness vocabulary worth reusing**

- `admin-web/src/pages/KnowledgeOpsPage.tsx`
  - Already has bounded polling + stale/resume semantics:
    - `MAX_INGESTION_POLL_ATTEMPTS = 8`
    - `INGESTION_POLL_INTERVAL_MS = 3000`
    - stale badge / resume polling control / inline diagnostics
- `admin-web/src/pages/MentorAuditPage.tsx`
  - Already demonstrates URL-backed queue/detail truth, explicit empty/error states, and calm operator-facing diagnostics.
- `admin-web/src/pages/DistributionStatsPage.tsx`
  - Already demonstrates bounded filters, query normalization warnings, and snapshot-like “keep last successful state visible while reloading.”

**Planner implication**

- S12 needs net-new backend work:
  - overview summary endpoint(s)
  - likely snapshot/pre-aggregation layer
  - notification/SSE adapter
  - fallback polling + degraded-state semantics
- But S12 should **reuse** existing UI language from Knowledge Ops instead of inventing a second freshness model.

### 4) Repo entrypoint / docs / Windows parity are far behind runtime truth (S13)

**Current root-doc state**

- `README.md`
  - has **zero** references to:
    - `admin-web`
    - `admin-api`
    - `/api/admin`
    - `super_admin`
    - `3000`
    - `8081`
  - still says the project does **not** include Maven Wrapper, even though:
    - `backend/mvnw`
    - `backend/mvnw.cmd`
    both exist.

  - still describes a single `backend` service/image/port path.
- `mobile/README.md`
  - still the default Flutter template.
- `CONTRIBUTING.md`
  - missing entirely.
- Missing runbook/verifier/docs for the pending DX slice:
  - `docs/runbooks/m006-s13-demo-path.md` — missing
  - `tool/verify_m006_s13_demo_path.dart` — missing

**Existing root helpers worth keeping in mind**

- `bash.cmd`
- `flutter.cmd`
- `grep.cmd`
- `sleep.cmd`
- `test.cmd`

These are useful **substrate** for Windows parity and repo-local command normalization.

**Existing stale scripts that should not be the new front door**

- `scripts/run-mobile-e2e.sh`
- `scripts/run-mobile-e2e.cmd`
  - still run `docker compose up -d postgres minio backend`
- `scripts/verify-e2e.sh`
  - still assumes a single backend on `http://localhost:8080`
  - still uses legacy `X-Session-Id`
- `scripts/verify-s02.sh`
  - still targets pre-admin/pre-split ingestion proof only

**Planner implication**

- S13 should add new files instead of trying to mutate the stale scripts into the new admin milestone entrypoint.
- Recommended files align directly with roadmap/context:
  - `scripts/dev-up-admin-demo.sh`
  - `scripts/dev-up-admin-demo.cmd`
  - `scripts/dev-verify-admin-demo.sh`
  - `scripts/dev-verify-admin-demo.cmd`
  - `README.md`
  - `CONTRIBUTING.md`
  - possibly one small quickstart/migration doc linked from README

### 5) Existing proof surfaces that can seed fast smoke / final closure

**Best current fast-smoke seed**

- `admin-web/tests/auth-and-rbac.spec.ts`
  - already proves:
    - unauth redirect
    - bad credentials
    - `super_admin` landing on `Overview`
    - limited-admin hidden navigation + `/403`
    - single refresh replay when access token is stale
    - revoked refresh forced logout
    - malformed local session reset

**Existing release-gate pack**

- `admin-web/tests/users-management.spec.ts`
- `admin-web/tests/knowledge-ops.spec.ts`
- already wired via `tool/verify_m006_s08_release.dart`

**Existing mentor/distribution closure pack**

- `admin-web/tests/mentor-audit.spec.ts`
- `admin-web/tests/distribution-stats.spec.ts`
- `admin-web/tests/mentor-distribution-closure.spec.ts`
- already wired via `tool/verify_m006_s07_mentor_distribution.dart`

**Shared browser harness**

- `admin-web/playwright.config.ts`
- `admin-web/playwright.global-setup.ts`
- `admin-web/playwright.global-teardown.ts`
  - already own compose boot / health waits / cleanup

**Planner implication**

- S13 fast smoke can be a thin wrapper around a minimal Playwright subset or a very small new smoke spec that reuses the current harness.
- S14 should compose the existing packs instead of inventing a second set of browser tests.

### 6) Helm/deploy truth is already materially closed; don’t re-solve it in docs work

**Key files**

- `deploy/helm/babytalk/values.yaml`
- `deploy/helm/babytalk/values-production.yaml`
  - already define split `appApi`, `adminApi`, `adminWeb`, and `dbMigration` surfaces.
- `ci/k8s-smoke.sh`
  - already asserts split-stack render truth.
- `docs/runbooks/k8s-deploy.md`
  - already documents:
    - split runtime shape
    - migration-first ordering
    - `admin-api` internal-only boundary
    - repo-root verifier entrypoint

**Planner implication**

- S13 README should link to this runbook.
- S14 should only add final evidence composition if the milestone still needs a single “release closure” proof path above S07 + S08.

### 7) One remaining release-closure gap still exists despite S08

**What is missing today**

- No `tool/verify_m006_s14_release_closure.dart`
- No `docs/runbooks/m006-s14-release-closure.md`
- CI does not yet compose:
  - S08 release gate
  - S07 mentor/distribution closure
  - future S12 overview/freshness proof
  - future S13 demo/front-door proof

**Planner implication**

- If the milestone still wants one final root-safe closure command, S14 should be a thin aggregator and documentation/evidence layer.
- Do not turn S14 into a second S08.

## What to build or prove first

1. **First, lock planning identity.**
   - Explicitly ignore stale `S09-TASKS.md` for this unit.
   - Plan against the pending S12/S13/S14 seams instead.

2. **Then tackle S12.**
   - It is the only remaining area with substantial backend/frontend implementation risk.
   - Until Overview stops being a placeholder, the milestone still lacks the promised control-plane freshness story.

3. **Do S13 next.**
   - Current README/scripts are actively misleading for new developers and future agents.
   - Fixing the repo front door after S12 prevents documenting a placeholder Overview state as if it were done.

4. **Do S14 last.**
   - Only after S12/S13 exist should planner wire one final aggregate closure verifier and evidence chain.

## Natural seams for planning

### Seam A — S12 multi-domain overview/freshness

**Likely files**

- `admin-web/src/pages/OverviewPage.tsx`
- `admin-web/src/app/routes.tsx` (copy/metadata only)
- new backend overview summary/snapshot/SSE files under `backend/common` and `backend/admin-api`
- new backend/browser tests
- `docs/runbooks/m006-s12-control-plane-freshness.md`
- `tool/verify_m006_s12_control_plane_freshness.dart`

**Risk**

- Highest. No existing overview backend or realtime transport.

### Seam B — S13 demo path / README / Windows parity

**Likely files**

- `scripts/dev-up-admin-demo.sh`
- `scripts/dev-up-admin-demo.cmd`
- `scripts/dev-verify-admin-demo.sh`
- `scripts/dev-verify-admin-demo.cmd`
- `README.md`
- `CONTRIBUTING.md`
- maybe one small migration/quickstart doc linked from README
- `mobile/README.md`
- `docs/runbooks/m006-s13-demo-path.md`
- `tool/verify_m006_s13_demo_path.dart`

**Risk**

- Medium. Mostly new files + front-door truth, but easy to drift if it duplicates runtime logic instead of wrapping existing verifiers.

### Seam C — S14 final closure / CI aggregation

**Likely files**

- `.github/workflows/ci.yml`
- `tool/verify_m006_s14_release_closure.dart`
- possibly a small CI helper script
- `docs/runbooks/m006-s14-release-closure.md`
- maybe a small README/runbook link update to the final gate

**Risk**

- Medium. Keep it compositional; avoid rebuilding S08 under a new name.

## Don’t Hand-Roll

- Do **not** trust `.gsd/milestones/M006/S09-TASKS.md` for this unit; it is stale saved-view/handoff scope.
- Do **not** extend `scripts/verify-e2e.sh` or `scripts/run-mobile-e2e.*` into the new M006 admin entrypoint; they still assume the old monolith and legacy auth paths.
- Do **not** invent a second compose/browser harness; reuse:
  - `docker-compose.yml`
  - `admin-web/playwright.global-setup.ts`
  - `tool/verify_m006_s08_release.dart`
  - `tool/verify_m006_s07_mentor_distribution.dart`
- Do **not** make `admin-api` public in docs or chart; the S08 deploy truth already locked it as internal-only.
- Do **not** claim final milestone release closure by pointing only at S08; mentor/distribution proof is still separate until S14 composes it.
- Do **not** introduce speculative abstractions. Per Karpathy, every new file in S12/S13/S14 should map directly to one of:
  - control-plane freshness
  - developer front-door truth
  - final proof composition

## Verification

**Current substrate to rerun before or during planning**

- `dart run tool/verify_m006_s08_release.dart`
- `dart run tool/verify_m006_s07_mentor_distribution.dart`

**Good current fast-smoke seed**

- `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts`

**Likely future exit proofs**

- S12: new repo-root verifier proving `overview summary -> freshness strip -> SSE disconnect -> polling fallback`
- S13: new repo-root verifier proving `golden path -> fast smoke -> README front door`
- S14: new repo-root verifier aggregating S08 + S07 + S12 + S13 into one closure chain

## Planner handoff

- Plan this as **three executor slices hiding under one stale umbrella**, not one giant implementation chunk.
- The only truly unknown code is **S12**. **S13** is mostly wrappers/docs. **S14** should mostly compose existing verifiers and evidence surfaces.
- If planner must keep the `S09` label for workflow reasons, explicitly note in the plan that `S09-TASKS.md` is ignored and that real implementation work is aligned to the pending `S12/S13/S14` sketches.
