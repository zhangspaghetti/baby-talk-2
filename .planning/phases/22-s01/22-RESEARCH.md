# M007/S01 — Research

**Date:** 2026-04-26

## Summary

S01 primarily owns **R054** and directly advances the milestone’s Helm-first/local-baseline requirements behind **R009** and **R038**. The repo already has a strong Helm proof nucleus: `deploy/helm/babytalk` renders cleanly and `bash ci/k8s-smoke.sh` currently passes, proving split-stack naming, `db-migration` hook ordering, internal-only `admin-api`, and NOTES truth. But that proof is still render/release oriented, not a local developer baseline: there is no `kind` config, no local values/secrets bootstrap surface, no infra chart, no image-load workflow, no local ingress convention, and no gateway surface anywhere in the repo. `backend/pom.xml` still has only `common`, `app-api`, `admin-api`, and `db-migration`, and repo-wide `rg gateway backend deploy README.md CONTRIBUTING.md docs/runbooks admin-web` returns no hits.

Local/front-door truth is still compose-shaped. `docker-compose.yml`, `scripts/dev-up-admin-demo.*`, `scripts/dev-verify-admin-demo.*`, `tool/verify_m006_s13_demo_path.dart`, `tool/verify_m006_s12_control_plane_freshness.dart`, `tool/verify_m006_s08_release.dart`, `admin-web/playwright.global-setup.ts`, `ci/backend-test.sh`, `README.md`, `CONTRIBUTING.md`, and `.github/workflows/ci.yml` all assume Docker Compose. A compose inventory excluding `.gsd/` found **20 live repo files** with compose references, so “remove compose from the repo” is not just docs cleanup; it touches wrappers, verifiers, Playwright setup, backend smoke, and CI.

The strongest path is Karpathy-guidelines rule 2/3/4: keep the change simple, surgical, and goal-driven. Reuse the existing Helm proof surface (`ci/k8s-smoke.sh`) and existing front-door UX contract (stage label + `likely_cause` + `next_action` + bounded telemetry), but put them behind a new M007 local baseline instead of teaching raw `kind`/`helm`/`kubectl` incantations as the only truth. The biggest planning risk is the acceptance text “reach gateway health” while the repo currently has no gateway module/service at all; planner must decide whether S01 introduces a minimal gateway service skeleton now or whether “gateway health” is satisfied by a stub/front-door contract that S03 later deepens.

## Recommendation

- **Do not mutate the M006 compose verifiers into a dual-truth monster.** `tool/verify_m006_s13_demo_path.dart` and friends are deeply compose-specific and also statically verify M006 doc/file names. Safer seam: add a new M007-scoped local verifier/wrapper path, preserve the contract, then repoint stable wrapper names to it.
- **Do reuse the current Helm chart mechanically.** `deploy/helm/babytalk/templates/{deployment,service,configmap,secret,NOTES,tests}` is the obvious seed for a future `babytalk-app` chart. S01 should keep this mechanical so S02 can deepen release-boundary semantics later.
- **Freeze the local baseline before docs deletion.** Lock cluster name, namespace, ingress pattern, host convention, image-tag/load strategy, and local secrets path first; otherwise README/CONTRIBUTING edits will drift again.
- **Prefer upstream chart dependencies for infra, not bespoke StatefulSets.** Postgres/Redis/MinIO are stateful primitives; S01 value is locking the baseline and proof path, not hand-authoring storage operators.
- **Preserve the current DX contract.** Existing front-door docs/runbooks promise named stage failures. New local Helm wrappers should stop at `preflight | cluster | infra | app | gateway | smoke` and print one `likely_cause` plus one `next_action`, not raw Helm/Kubectl dumps.

## Implementation Landscape

### Key Files

- `deploy/helm/babytalk/Chart.yaml` — current single app-only chart seed; likely source material for a new `deploy/helm/babytalk-app/` skeleton.
- `deploy/helm/babytalk/templates/deployment.yaml` — currently renders `app-api`, `admin-api`, `admin-web`, and `db-migration` Job; this is the mechanical split point for app chart resources.
- `deploy/helm/babytalk/templates/service.yaml` / `ingress.yaml` / `configmap.yaml` / `secret.yaml` / `templates/tests/test-connection.yaml` / `templates/NOTES.txt` — existing split-stack truth already encoded here; reuse instead of rewriting from scratch.
- `deploy/helm/babytalk/values.yaml` — current default app values reference external DB/MinIO endpoints; no local kind values, no Redis, no gateway, no infra services.
- `deploy/helm/babytalk/values-production.yaml` — production override seed; useful for preserving prod shape while local values diverge into kind-specific truth.
- `deploy/` — currently has **no** kind config directory and **no** infra chart; safest new seam is a new `deploy/kind/` config plus new `deploy/helm/babytalk-infra/`.
- `backend/pom.xml` — confirms no `gateway` module exists yet; S01 cannot honestly claim live gateway health without adding at least a gateway skeleton/service contract.
- `backend/Dockerfile` / `admin-web/Dockerfile` — current local build inputs for `app-api`, `admin-api`, `db-migration`, and `admin-web`; these are the images a kind-based local path must build/tag/load.
- `scripts/dev-up-admin-demo.sh` / `scripts/dev-up-admin-demo.cmd` — current stable front-door names; they only preflight `dart` and delegate into the compose verifier. Good commands to preserve, bad implementation to keep.
- `scripts/dev-verify-admin-demo.sh` / `scripts/dev-verify-admin-demo.cmd` — same story for fast smoke.
- `tool/verify_m006_s13_demo_path.dart` — richest existing implementation of stage/telemetry contract; use as a reference, not as the long-term multi-truth home.
- `tool/verify_m006_s08_release.dart` — existing Helm child gate wrapper around `ci/k8s-smoke.sh`; compose runtime half will break once compose is removed.
- `ci/k8s-smoke.sh` — current authoritative Helm render/NOTES/hook truth; today it is dry-run only, so it is the best extension point for kind install + live smoke, not a disposable script.
- `tool/verify_m006_s12_control_plane_freshness.dart` and `admin-web/playwright.global-setup.ts` — both currently assume compose boot; planner must account for these before deleting compose or CI/browser proofs will regress.
- `ci/backend-test.sh` — compose-based backend smoke; another compose removal blocker.
- `.github/workflows/ci.yml` — current CI calls `dart run tool/verify_m006_s14_release_closure.dart`, which in turn still depends on compose-based child gates.
- `README.md` / `CONTRIBUTING.md` / `.env.example` / `docker-compose.yml` — explicit user-facing compose truth that S01 must replace/remove only after the Helm path proves green.
- `docs/runbooks/m006-s13-demo-path.md` / `docs/runbooks/k8s-deploy.md` — current operator/developer truth surfaces; `k8s-deploy` is useful source material, but `m006-s13-demo-path` encodes the front-door contract that new Helm docs should preserve.
- `docs/reviews/m007-autoplan-2026-04-25.md` — locked planning input for Issue 1; it already says S01 must keep one official baseline, one `up` + one `verify` command, checked-in local values/bootstrap, and the compose-era error contract.

### Build Order

1. **Lock baseline inputs first**
   - Add kind cluster config, ingress/host convention, namespace convention, and local values/secrets bootstrap path.
   - Decide the local image-loading rule (`kind load docker-image` vs local registry) before touching wrappers/docs.
   - This is the irreducible substrate every later script/doc/verifier needs.

2. **Carve chart skeletons mechanically**
   - Split current `deploy/helm/babytalk` into app/infrastructure skeletons with minimal semantic change.
   - App chart should initially preserve current services/job/test-hook truth.
   - Infra chart should provision Postgres + Redis + MinIO under local kind-friendly names that app values can consume.
   - Do not over-design S02 rollback/compatibility logic here; just make both charts render/install locally.

3. **Add a new M007 local verifier/wrapper path**
   - Preserve stable human-facing commands, but back them with kind/helm/kubectl stages.
   - Reuse the stage contract from S13 docs, updated to `preflight | cluster | infra | app | gateway | smoke`.
   - Preserve bounded telemetry/TTHW output; this is existing repo muscle, not optional polish.

4. **Only after live local proof passes, rewrite docs and remove compose**
   - Update README/CONTRIBUTING first-path instructions.
   - Then delete `docker-compose.yml` and retire/repoint compose-based helper surfaces.
   - If compose is removed earlier, CI/Playwright/backend smoke will fail before the replacement path exists.

5. **Resolve the gateway-health gap explicitly**
   - There is no gateway module/service today.
   - Planner must either:
     a) add a minimal gateway skeleton in S01 purely to satisfy local health/front-door proof, or
     b) treat S01 as producing the gateway slot/ingress contract and record the acceptance ambiguity for slice planning.

   - Do not hand-wave this; current repo state cannot satisfy “gateway health” as written.

### Verification Approach

- **Static/render proof**
  - `bash ci/k8s-smoke.sh` (kept as baseline child gate, then extended for dual-chart truth)
  - `helm lint deploy/helm/babytalk-app`
  - `helm lint deploy/helm/babytalk-infra`
  - `helm template ... | kubectl apply --dry-run=client -f -`

- **Local cluster/bootstrap proof**
  - `kind create cluster --config <new-kind-config>`
  - install ingress controller if the chosen baseline needs one
  - build/tag/load local images from `backend/Dockerfile` and `admin-web/Dockerfile`
  - `helm upgrade --install babytalk-infra ...`
  - `helm upgrade --install babytalk-app ...`

- **Live proof**
  - `kubectl wait` / `kubectl rollout status` for infra and app workloads
  - verify `db-migration` completed before app workloads are considered healthy
  - `helm test babytalk-app`
  - curl the frozen local front-door health URL (gateway if present; otherwise the explicitly chosen S01 placeholder contract)
  - curl one admin-web/front-door URL to prove the README path is real

- **Contract proof**
  - wrapper stdout must include `tthw_seconds`, `first_failure_stage`, `likely_cause`, `next_action`
  - rerun smoke must reuse the live stack and stay under the `smoke` stage vocabulary
  - README/CONTRIBUTING must reference the same command names the wrappers actually expose

## Don't Hand-Roll

| Problem | Existing Solution | Why Use It |
|---------|------------------|------------|
| Postgres / Redis / MinIO local Kubernetes resources | Helm chart dependencies on maintained upstream charts | S01’s value is baseline lock + proof tooling; hand-written StatefulSets/PVC wiring would add storage/security churn with little milestone value |

## Constraints

- `backend/pom.xml` has no `gateway` module, and repo-wide `rg gateway backend deploy README.md CONTRIBUTING.md docs/runbooks admin-web` returns no hits.
- Current app chart only knows external DB/MinIO endpoints via `secret.*`; it does not provision infra or local service DNS.
- Redis is a required M007 target dependency, but current runtime does not yet reference Redis anywhere in backend config/code; S01 must provision it without existing live usage as proof.
- Compose removal is broad: a non-`.gsd` inventory found **20 live repo files** with compose references, including wrappers, verifiers, Playwright setup, backend smoke, docs, and CI.
- `ci/k8s-smoke.sh` currently proves render truth only; it does not create a cluster or perform a live install.
- Current front-door wrappers only check `dart` and then delegate into compose-specific verifier logic.

## Common Pitfalls

- **Turning M006 verifiers into dual-truth compatibility layers** — this violates Karpathy “simplicity first” and “surgical changes”; add M007-scoped Helm-path tooling instead of stuffing kind/helm logic into compose-era verifier branches.
- **Deleting compose before the Helm path is actually green** — README cleanup alone is insufficient; `ci/backend-test.sh`, `tool/verify_m006_s12_control_plane_freshness.dart`, `tool/verify_m006_s13_demo_path.dart`, `tool/verify_m006_s08_release.dart`, `admin-web/playwright.global-setup.ts`, and CI all currently depend on compose.
- **Letting raw Helm/Kubectl errors leak to fresh readers** — the repo’s existing DX bar is named stage + likely cause + next action; losing that would be a regression even if Kubernetes works.
- **Forcing manual hosts-file or ad-hoc port-forward workflows** — the local baseline should freeze one ingress/localhost convention and make wrappers own it.

## Open Risks

- **Gateway health vs no gateway implementation** — S01 acceptance language and current repo state do not line up; this must be resolved during slice planning, not mid-execution.
- **S01 vs S02 boundary blur** — dual-chart skeletons are needed now, but full independent lifecycle/rollback semantics belong to S02. Planner should keep S01 mechanical and defer compatibility matrix depth.
- **Compose references outside README/CONTRIBUTING** — if the slice truly deletes `docker-compose.yml`, downstream historical/mobile runbooks may need explicit retirement or migration notices, not silent breakage.

## Skills Discovered

| Technology | Skill | Status |
|------------|-------|--------|
| Kubernetes | `kubernetes-specialist` | available |
| Helm | `wshobson/agents@helm-chart-scaffolding` | installed |

## Sources

- kind supports both `extraPortMappings` for localhost ingress and `kind load docker-image` / local registry flows, which fits the required single-machine Windows baseline without hand-rolled port-forwards (source: Kind docs — `/kubernetes-sigs/kind`, topics: “ingress”, “quick start”, “local registry”)
