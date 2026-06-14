# S08 Research — 端到端集成验证 + 部署更新

## Summary

- This slice should primarily close **R053**: the focused admin proof pack only becomes release-grade when the already-shipped MockMvc + compose-backed Playwright seams are wired into repeatable compose/CI/Helm gates. **R052** is already materially delivered by S05/S06/S07 runtime surfaces; this slice operationalizes them rather than adding new product UI.
- Biggest surprise: roadmap state is currently **ambiguous**. `gsd_milestone_status` shows both pending `S08` and pending `S09`, while the roadmap excerpt duplicates the “端到端集成验证 + 部署更新” title and later also splits README/Windows/CI/Helm work into S13/S14. Planner should lock the canonical slice boundary before tasking, or this slice will accidentally absorb the broader README/golden-path agenda.
- Local runtime is already ahead of deployment artifacts: `docker-compose.yml` models the real M006 stack (`postgres`, `minio`, one-shot `db-migration`, `app-api`, `admin-api`, `admin-web`), but Helm, CI, and multiple scripts/docs still describe a single `backend` service/image.
- Current CI/release verification is structurally insufficient:
  - `.github/workflows/ci.yml` only runs `ci/backend-test.sh` and `ci/mobile-analyze.sh`.
  - `ci/backend-test.sh` does full reactor `mvn test`, then a compose smoke for `app-api` + `admin-api`, but **omits `admin-web`** and puts compose `db-migration` proof **after** tests instead of before.
  - `ci/k8s-smoke.sh` and the Helm chart can both stay green while `app-api`, `admin-api`, and `admin-web` are completely missing.
- Per Karpathy Guidelines **“Simplicity First”** and **“Surgical Changes”**, the planner should **reuse the existing compose/Playwright harness and add a small release-gate layer around it**, not invent a second browser harness or a speculative infra framework.

## Requirement focus

- Primary requirement likely closed here: **R053** — the admin proof pack becomes release-grade only when the existing focused backend/browser seams are replayable in CI and supported by deploy artifacts.
- Secondary support: **R052** is already materially delivered by the shipped admin workspaces; S08 mainly prevents regression by proving those surfaces through compose health, CI ordering, and Helm/deploy updates.

## Skills Discovered

- Already available and directly relevant:
  - `docker-expert`
  - `github-workflows`
  - `kubernetes-specialist`
- Newly installed for this slice:
  - `playwright-testing` (installed from `alinaqi/claude-bootstrap@playwright-testing`)
- Searched but not installed:
  - `bobmatnyc/claude-mpm-skills@playwright-e2e-testing` surfaced in discovery, but that repo did not expose a matching installable skill when attempted.

## Recommendation

1. **Freeze the slice boundary first.**
   - Treat this unit as **integration/release closure**, not full README/Windows/DX polish. Those broader onboarding items already have a better home in S13 per the replanned roadmap.
   - The only docs that need to move in this slice are deployment-truth docs that would otherwise lie after Helm/CI changes.

2. **Define one canonical release gate, then point CI and docs at it.**
   - Follow the existing repo-root verification pattern (`tool/verify_s06.dart`, `tool/verify_m006_s07_mentor_distribution.dart`) and add a new M006 release verifier that runs:
     1. migration-first compose check,
     2. full backend reactor tests,
     3. canonical admin Playwright pack,
     4. Helm lint/template assertions.
   - This gives the planner one truth source for CI wiring, local replay, and slice-close evidence.

3. **Keep the canonical Playwright pack minimal and truthful.**
   - The five admin scenarios in the roadmap are already covered by:
     - `admin-web/tests/auth-and-rbac.spec.ts` — login + permission guard + refresh
     - `admin-web/tests/users-management.spec.ts` — user disable
     - `admin-web/tests/knowledge-ops.spec.ts` — ingestion retry + KG resolve
   - Do **not** make the CI pack pay for duplicate legacy files like `admin-login.spec.ts` or `admin-accounts.spec.ts`.
   - Also avoid `access-and-landing.spec.ts` in the core release gate unless needed: it is pure route logic, but the shared Playwright config still boots the full compose stack for it.

4. **Treat Helm as a real chart rewrite, not a values tweak.**
   - The current chart renders exactly one `Deployment`/`Service` named `babytalk`.
   - M006 needs at least:
     - `app-api` workload
     - `admin-api` workload
     - `admin-web` workload
     - a migration story that matches ADR/MEM020 (`db-migration` is the only Flyway owner)
   - Because `admin-web/nginx.conf` hardcodes `http://admin-api:8081`, chart work must explicitly solve the internal DNS/proxy target instead of assuming release-prefixed service names will “just work”.

5. **Handle the Testcontainers CI trap explicitly.**
   - All backend module poms hardcode `DOCKER_HOST=tcp://localhost:2375` in surefire for the Windows workaround.
   - A stock Linux GitHub Actions runner does not provide this by default.
   - Planner should choose one of two explicit paths:
     - provision a localhost:2375 relay in CI (smallest operational change), or
     - make the Maven test env conditional by platform (cleaner but more invasive across three poms).
   - Do not pretend current `mvn test` is portable in CI until one of these is addressed.

## Implementation Landscape

### 1) Slice identity is currently ambiguous; lock scope before tasking

- `gsd_milestone_status` currently shows **both** pending `S08` and pending `S09`.
- The roadmap excerpt duplicates the title “端到端集成验证 + 部署更新”, while later slices S13/S14 also absorb README/Windows/Playwright/Helm closure.
- Planner implication:
  - If this unit is the operational closure slice, keep it on compose/CI/Helm/release-gate work.
  - Do not silently absorb the broader README/golden-path/Windows-parity agenda unless the roadmap is explicitly re-merged.

### 2) Local compose/runtime substrate already exists and is the right truth source

- `docker-compose.yml`
  - Defines the current local stack:
    - `postgres`
    - `minio`
    - `db-migration`
    - `app-api`
    - `admin-api`
    - `admin-web`
  - `app-api` and `admin-api` both depend on `db-migration: service_completed_successfully`.
  - `admin-web` depends on healthy `admin-api`.
  - Persistent long-lived runtime = five containers; migration is a sixth one-shot service.
- `backend/Dockerfile`
  - Already supports module-specific images via `ARG MODULE=...`; this is the backend image seam Helm/CI should reuse.
- `admin-web/Dockerfile`
  - Builds a static Vite bundle and serves it from nginx.
- `admin-web/nginx.conf`
  - Proxies `/api/` and `/actuator/` to `http://admin-api:8081`.
  - This works in Compose because service DNS name is literally `admin-api`.
  - In Kubernetes, this becomes a deployment constraint: either preserve a compatible internal service name or render nginx config from the chart.
- `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`
  - Already proves the SQL migration set on a fresh Testcontainers Postgres database.
  - Planner should reuse this as the **contract** proof, then add a separate **operational** proof that the containerized `db-migration` service/job runs before the split runtimes.

### 3) Browser proof substrate is already real and should be reused, not replaced

- `admin-web/playwright.config.ts`
  - Shared Playwright config for the whole admin-web pack.
- `admin-web/playwright.global-setup.ts`
  - Already uses **full-stack** `docker compose up -d --build` from repo root.
  - Waits for:
    - `app-api` health
    - `admin-api` health
    - `admin-web` root page
  - This matches the existing memory/gotcha: keep full-stack bring-up, especially on Windows, instead of service-list variants.
- `admin-web/playwright.global-teardown.ts`
  - Stops/removes the compose services after each run.
- `admin-web/tests/helpers/admin-api.ts`
  - Seeds fixtures through a mix of real admin-api calls and `docker compose exec -T postgres psql`.
  - This means the E2E job must have **Docker CLI + local compose** access; it is intentionally not a remote-preview harness.
- `admin-web/tests/helpers/mobile-api.ts`
  - Uses real app-api auth/bootstrap flows for consumer token proof; this is the bridge that makes user-disable regression truthful.

**Canonical release-gate spec pack already exists**

- `admin-web/tests/auth-and-rbac.spec.ts`
- `admin-web/tests/users-management.spec.ts`
- `admin-web/tests/knowledge-ops.spec.ts`

**Important duplicates / non-canonical files**

- `admin-web/tests/admin-login.spec.ts` — redundant legacy compatibility smoke
- `admin-web/tests/admin-accounts.spec.ts` — overlaps with admin-account flows already covered inside `users-management.spec.ts`
- `admin-web/tests/access-and-landing.spec.ts` — good cheap route logic, but not worth full compose boot in the core gate
- `admin-web/tests/mentor-audit.spec.ts`
- `admin-web/tests/distribution-stats.spec.ts`
- `admin-web/tests/mentor-distribution-closure.spec.ts`
  - valuable, but already packaged behind `tool/verify_m006_s07_mentor_distribution.dart`; better reused by the later broader release slice than forced into the minimal S08 gate unless scope says otherwise.

### 4) CI wiring exists only partially and currently misses the actual M006 closure

- `.github/workflows/ci.yml`
  - Only two jobs today:
    - `backend-test`
    - `mobile-analyze`
  - No Node setup, no Playwright install, no E2E artifact upload, no Helm check, no explicit migration gate.
- `ci/backend-test.sh`
  - Runs:
    1. `"$BACKEND_DIR/mvnw" -f "$BACKEND_DIR/pom.xml" -B test`
    2. `docker compose up -d postgres minio db-migration app-api admin-api`
    3. health waits for `app-api` and `admin-api`
  - Gaps relative to slice acceptance:
    - migration smoke is after backend tests, not before
    - no `admin-web` health or browser proof
    - no explicit assertion that `db-migration` finished successfully other than downstream services coming up
- `admin-web/package.json`
  - `test:e2e` is already the right entrypoint.
  - `pretest:e2e` installs Chromium, but **CI should still add** Playwright’s recommended `npx playwright install chromium --with-deps` step before running the pack.
- Playwright docs (Context7) explicitly recommend GitHub Actions steps:
  - checkout
  - setup-node
  - `npm ci`
  - `npx playwright install --with-deps`
  - `npx playwright test`
  - upload `playwright-report/`

### 5) Helm/deploy artifacts are still pre-M006 and need real multi-workload closure

- `deploy/helm/babytalk/Chart.yaml`
- `deploy/helm/babytalk/values.yaml`
- `deploy/helm/babytalk/values-production.yaml`
- `deploy/helm/babytalk/templates/*.yaml`
  - Everything is single-workload:
    - one ConfigMap
    - one Secret
    - one Service
    - one Deployment
    - one optional Ingress
    - one helm test pod
  - `helm template babytalk deploy/helm/babytalk` currently renders **no** `app-api`, `admin-api`, or `admin-web` named resources.
- Current values model is also pre-split:
  - only one `image.repository` / `image.tag`
  - docs still assume one `babytalk/backend` image
  - there is no published image-naming contract yet for `app-api`, `admin-api`, and `admin-web`
- `ci/k8s-smoke.sh`
  - Verifies only:
    - `helm lint`
    - resource-count thresholds from `helm template`
    - presence of one test template and one runbook
  - It does **not** assert that app/admin/admin-web resources exist.
- `docs/runbooks/k8s-deploy.md`
  - Still documents a single `babytalk/backend` image and single service/ingress.
  - It does not mention:
    - separate `app-api` vs `admin-api`
    - `admin-web`
    - `db-migration` ownership
    - JWT/admin bootstrap config needed by the split runtimes

**Operational gaps the chart now has to solve**

- `app-api` and `admin-api` both have `spring.flyway.enabled=false`, so Helm needs a migration story (job/hook or explicit external step contract).
- `backend/app-api/src/main/resources/application.yml` introduces consumer JWT env vars not surfaced in chart values.
- `backend/admin-api/src/main/resources/application.yml` introduces admin JWT/bootstrap env vars not surfaced in chart values.
- `admin-web` needs either:
  - a compatible internal service DNS target for `admin-api`, or
  - a templated nginx config mounted from the chart.

### 6) There are stale scripts/docs, but they are not a good base for S08

- `scripts/verify-e2e.sh`
  - still assumes a single `backend` service and pre-JWT/pre-admin endpoints.
- `scripts/run-mobile-e2e.sh`
- `scripts/run-mobile-e2e.cmd`
  - still call `docker compose up -d postgres minio backend`
- `README.md`
  - still describes a single backend service
  - still claims Maven Wrapper is absent, while `backend/mvnw`/`mvnw.cmd` exist
  - still points at `docker compose logs -f backend`
- `mobile/README.md`
  - default Flutter template; not a trustworthy M006 module doc

Planner guidance:

- Do **not** extend these stale wrappers as the base of the release closure.
- Prefer a new M006-specific verifier / CI script and only then decide which stale docs/scripts should be updated versus explicitly deferred to S13.

## What to prove first

1. **Lock the canonical M006 release gate**
   - Decide the exact command sequence and the minimal browser spec pack.
   - This unblocks CI, local replay, and slice-close verification.
2. **Prove the CI runner can execute backend tests at all**
   - Resolve the hardcoded `DOCKER_HOST=tcp://localhost:2375` assumption before counting on GitHub Actions.
3. **Only then rewrite Helm**
   - Once the runtime/verification contract is stable, update the chart to mirror the split stack instead of guessing.
4. **Update deploy-truth docs last**
   - `k8s-deploy.md` must match the shipped chart/commands.
   - Broader onboarding/root README work can stay with the DX slice unless roadmap is explicitly re-merged.

## Natural seams for planning

### Task A — Canonical release verifier + compose closure

Files likely touched:

- new repo-root verifier under `tool/` (prefer Dart to match existing pattern)
- maybe a dedicated `ci/` shell wrapper if workflow wants a plain bash entrypoint
- `ci/backend-test.sh` if reusing rather than adding a new script

Goal:

- One replayable command that enforces:
  1. compose migration-first proof
  2. full reactor backend tests
  3. canonical Playwright pack
  4. Helm lint/template assertions

Why this should go first:

- Every later task (CI, docs, slice close) can point at this command.

### Task B — CI workflow wiring + runner plumbing

Files likely touched:

- `.github/workflows/ci.yml`
- maybe new helper script under `ci/`
- possibly backend module poms **or** workflow-level Docker relay setup

Goal:

- Make GitHub Actions execute the verifier in the required order.
- Add Node setup + Playwright browser install + artifact upload.
- Explicitly solve the Testcontainers `localhost:2375` assumption.

### Task C — Helm multi-workload update + smoke hardening

Files likely touched:

- `deploy/helm/babytalk/Chart.yaml`
- `deploy/helm/babytalk/values.yaml`
- `deploy/helm/babytalk/values-production.yaml`
- `deploy/helm/babytalk/templates/_helpers.tpl`
- `deploy/helm/babytalk/templates/deployment.yaml`
- `deploy/helm/babytalk/templates/service.yaml`
- `deploy/helm/babytalk/templates/ingress.yaml`
- `deploy/helm/babytalk/templates/configmap.yaml`
- `deploy/helm/babytalk/templates/secret.yaml`
- `deploy/helm/babytalk/templates/tests/test-connection.yaml`
- `deploy/helm/babytalk/templates/NOTES.txt`
- possibly `admin-web/nginx.conf` if the chart does not render a runtime config instead

Goal:

- Reflect the real split stack in Kubernetes.
- Tighten `ci/k8s-smoke.sh` so it proves per-workload resources rather than kind counts.
- Ensure migration/auth/proxy assumptions are explicit.

### Task D — Minimal deployment-doc truth alignment

Files likely touched:

- `docs/runbooks/k8s-deploy.md`
- possibly a small note in `README.md` only if the release-gate command becomes the primary local verifier for this slice

Goal:

- Stop deploy docs from lying after the chart/workflow change.
- Avoid rolling the broader S13 onboarding rewrite into this slice unless required.

## Don’t Hand-Roll

- Do **not** build a second browser harness. Reuse `admin-web/playwright.global-setup.ts`, the seeded helpers, and the existing canonical specs.
- Do **not** keep relying on `ci/k8s-smoke.sh` resource-count thresholds as if they prove M006 closure.
- Do **not** salvage `scripts/verify-e2e.sh` by layering admin logic on top of the old single-backend script; it is structurally pre-M006.
- Do **not** turn the Helm chart into a speculative generic “N services” framework. Per Karpathy “Simplicity First”, a minimal three-workload structure is enough.
- Do **not** expose `admin-api` publicly unless product explicitly needs it; the current web contract prefers `admin-web` as the public surface with internal proxying.
- Do **not** silently change the Windows compose behavior. Keep the full `docker compose up -d --build` Playwright pattern unless there is proof it must change.

## Key constraints / gotchas

- `backend/*/pom.xml`
  - hardcode `DOCKER_HOST=tcp://localhost:2375` in surefire; this is a real CI portability trap.
- `admin-web/nginx.conf`
  - hardcodes `admin-api:8081`; K8s release names will break this unless explicitly handled.
- `backend/admin-api/src/main/resources/application.yml`
  - admin auth secret/bootstrap envs exist only as defaults today; chart values do not surface them.
- `backend/app-api/src/main/resources/application.yml`
  - consumer JWT envs likewise exist but are not surfaced in the chart.
- `backend/admin-api/src/main/resources/application.yml` and `backend/app-api/src/main/resources/application.yml`
  - only expose `health,info`; there is no Prometheus/metrics wiring yet. Any roadmap text about notification adapter metrics visible is **not** currently backed by code in this slice’s area.
- `ci/k8s-smoke.sh`
  - would still pass a single-workload chart after M006 unless strengthened.
- `admin-web/playwright.global-setup.ts`
  - already proves the full compose stack but will be slow on cold caches because `backend/Dockerfile` runs `mvn ... dependency:go-offline`; set CI timeouts accordingly and keep the spec pack minimal.

## Sources

- Playwright official CI guidance via Context7 (`/microsoft/playwright`)
  - recommends GitHub Actions steps with `actions/setup-node`, `npm ci`, `npx playwright install --with-deps`, test execution, and artifact upload.
- Testcontainers Java docs via Context7 (`/websites/java_testcontainers`)
  - show that TCP `DOCKER_HOST` is an environment-specific CI pattern rather than a universal default, reinforcing that the current hardcoded `localhost:2375` assumption must be handled explicitly in GitHub Actions.

## Verification

Current truth sources worth reusing:

- `docker compose config --services`
- `./backend/mvnw -f backend/pom.xml -B test`
- `npm --prefix admin-web run build`
- `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts users-management.spec.ts knowledge-ops.spec.ts`
- `helm lint deploy/helm/babytalk`
- `helm template babytalk deploy/helm/babytalk -f deploy/helm/babytalk/values-production.yaml`

Planner should strengthen operational verification to include:

- explicit proof that `db-migration` completed before app services
- compose health/assertion for `postgres`, `minio`, `app-api`, `admin-api`, `admin-web`
- templated Helm output assertions for `app-api`, `admin-api`, `admin-web`
- CI artifact upload for `admin-web/playwright-report/` on failure/non-cancelled runs

## Planner handoff

This slice is best treated as a **release-closure** slice that packages existing M006 runtime truth into one repeatable gate. The riskiest parts are not the product features — those already exist — but the mismatches between:

- split local runtime vs single-workload Helm,
- Windows-biased Testcontainers config vs Linux CI,
- truthful compose/browser proof vs stale legacy scripts/docs.

Plan around those seams, keep the browser pack minimal, and make the chart/CI reflect the system that already exists instead of building new feature code.
