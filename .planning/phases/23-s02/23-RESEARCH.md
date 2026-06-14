# S02 Research: Split infra and app release boundaries

**Date:** 2026-04-26  
**Slice:** M007/S02 — Split infra and app release boundaries  
**Requirements Owned:** R054 (primary — Helm-first split deployment, independent infra/app releases)

---

## Summary

S01 already delivered the structural split (babytalk-infra chart + babytalk-app chart, db-migration pre-install Job with correct hook annotations, ci/k8s-smoke.sh 52 assertions, Dart verifier). S02's job is **not** to rebuild the split — it's to **document and prove the independent lifecycle semantics** with a runbook rewrite, a schema compatibility matrix, and verifier extensions that lock those semantics in CI.

This is targeted research — well-understood Helm concepts, known codebase. No unfamiliar technology.

---

## What S01 Already Delivered (do not redo)

| Artifact | Location | Status |
|---|---|---|
| babytalk-infra chart (Postgres/Redis/MinIO, vendored Bitnami) | `deploy/helm/babytalk-infra/` | ✅ complete |
| babytalk-app chart (db-migration Job + gateway stub + services) | `deploy/helm/babytalk-app/` | ✅ complete |
| db-migration Helm pre-install Job | `deployment.yaml` annotations | ✅ locked |
| k8s-smoke.sh 52 assertions (split-stack truth) | `ci/k8s-smoke.sh` | ✅ 52/52 pass |
| Dart verifier (6 stages) | `tool/verify_m007_s01_helm_baseline.dart` | ✅ complete |
| values-kind.yaml Redis hostname | `babytalk-infra-redis-master` | ✅ in place |

---

## db-migration Hook Semantics (locked in S01, document in S02)

The Job in `deploy/helm/babytalk-app/templates/deployment.yaml` already has:

```yaml
annotations:
  "helm.sh/hook": pre-install,pre-upgrade
  "helm.sh/hook-weight": "-10"
  "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
```

Semantics to document:

- **pre-install,pre-upgrade** — Job runs before any Deployment pods start; Helm blocks promotion of the release until the Job completes.
- **hook-weight: -10** — runs before any other hooks in the release.
- **before-hook-creation** — deletes any previous Job object before creating a new one; prevents `AlreadyExists` error on re-upgrade.
- **hook-succeeded** — deletes the completed Job pod so it doesn't litter the namespace.
- **backoffLimit: 1** — only one retry; fail-fast on schema errors.
- **activeDeadlineSeconds: 300 (kind) / 600 (prod)** — hard timeout.
- **restartPolicy: Never** — no automatic restart inside the pod.

**Rollback constraint (critical):** Flyway migrations are **forward-only**. `helm rollback babytalk-app` restores Kubernetes workloads to a previous revision, but the database schema stays at its current migration level. App services must tolerate running against schema version N when the codebase is at version N-1. This must be stated explicitly in the compatibility matrix.

---

## Gap Analysis: What S02 Must Build

### Gap 1: Runbook is M006-vintage

`docs/runbooks/k8s-deploy.md` (301 lines) still references:

- `deploy/helm/babytalk` (old single chart, deleted in S01)
- `helm upgrade --install babytalk deploy/helm/babytalk` commands
- Single-release rollback (`helm rollback babytalk`)
- Missing: infra release install/upgrade path, dual-release validation sequence, db-migration hook failure diagnosis, S02 compatibility matrix reference

**Action:** Full rewrite. Target 250+ lines covering both releases.

### Gap 2: No schema compatibility matrix

There is no file documenting which Flyway migration version is required by which app-api/admin-api release, or the rollback semantics. The open question from M007-CONTEXT.md ("Exact `db-migration` pre-flight contract in dual-release — to be locked at S02") must be answered here.

**Current state:** 15 migrations, V3–V17. No compatibility document exists.

**Action:** Create `docs/schema-compatibility-matrix.md` defining the compatibility policy.

### Gap 3: ci/k8s-smoke.sh has no S02-specific assertions

The existing 52 assertions cover S01 split-stack truth. They do NOT assert:

- Schema compatibility matrix doc exists
- Runbook references both `babytalk-infra` and `babytalk-app`
- Infra chart contains **no** db-migration Job (proving isolation)
- db-migration `hook-delete-policy` is `before-hook-creation,hook-succeeded`

**Action:** Add Step 10 (4–6 new assertions, total ~56–58).

### Gap 4: No S02 Dart verifier

`tool/verify_m007_s01_helm_baseline.dart` is live-cluster oriented. S02 needs an offline dry-run verifier focused on release boundary proof (no live cluster required).

**Action:** Create `tool/verify_m007_s02_release_boundaries.dart` — offline, `helm template`-based, asserting the S02 contract.

---

## Implementation Landscape

### T01 — Runbook rewrite (`docs/runbooks/k8s-deploy.md`)

Full rewrite (~250 lines). Key sections:

```

1. 当前部署真相（dual-release topology）
   - babytalk-infra: Postgres + Redis + MinIO (stateful, upgrade conservatively)
   - babytalk-app: db-migration Job (pre-hook) + gateway + app-api + admin-api + admin-web

2. 安装顺序（order matters, infra first）
   helm upgrade --install babytalk-infra deploy/helm/babytalk-infra \
     -f deploy/helm/babytalk-infra/values-kind.yaml -n babytalk --create-namespace
   helm upgrade --install babytalk-app deploy/helm/babytalk-app \
     -f deploy/helm/babytalk-app/values-kind.yaml -n babytalk

3. 独立升级路径
   - infra-only: helm upgrade babytalk-infra ... (no app disruption)
   - app-only: helm upgrade babytalk-app ... (db-migration runs as pre-hook)

4. db-migration hook 语义与失败处理
   - pre-install,pre-upgrade + hook-weight -10
   - 失败诊断: kubectl get jobs -n babytalk, kubectl logs job/...
   - 回滚约束: schema 不可逆，helm rollback 只恢复 app workloads

5. Schema 兼容矩阵引用 → docs/schema-compatibility-matrix.md

6. 回滚指南
   - infra rollback: helm rollback babytalk-infra <rev> (conservative — involves stateful data)
   - app rollback: helm rollback babytalk-app <rev> (safe if schema is N-compatible with app N-1)

7. 预检与验证
   bash ci/k8s-smoke.sh
   dart run tool/verify_m007_s02_release_boundaries.dart

8. 故障定位
   - preflight / cluster / infra / app / gateway / smoke vocabulary

```

### T02 — Schema compatibility matrix (`docs/schema-compatibility-matrix.md`)

New file (~80 lines). Defines:

- **Policy**: app-api/admin-api N-1 must run against schema N (two-version window).  
- **Current schema version**: V17 (15 migrations, V3–V17).
- **Table**: migration filename → first compatible app-api/admin-api release.
- **Rollback constraint section**: "Flyway migrations are forward-only. helm rollback babytalk-app restores workloads but does NOT undo schema changes. Do not rollback babytalk-app if the schema change removed a column required by the previous workload version."
- **Pre-upgrade checklist**: before bumping db-migration image tag, verify schema N is backward-compatible with app N-1.

Migration table (sourced from `backend/db-migration/src/main/resources/db/migration/`):

| Migration | Description | Introduced in release |
|---|---|---|
| V3 | accounts and sync tables | app-api 1.0.0 |
| V4 | mentor tables | app-api 1.0.0 |
| V5 | release distribution | app-api 1.0.0 |
| V6 | share landing | app-api 1.0.0 |
| V7 | caregiver invite | app-api 1.1.0 |
| V8 | caregiver audit alignment | app-api 1.1.0 |
| V9 | household shared context | app-api 1.1.0 |
| V10 | pgvector + minio infra | app-api 1.2.0 |
| V11 | ingestion tables | app-api 1.2.0 |
| V12 | keyword search vector store | app-api 1.2.0 |
| V13 | chat memory | app-api 1.2.0 |
| V14 | knowledge graph tables | app-api 1.2.0 |
| V15 | admin auth tables | admin-api 1.0.0 |
| V16 | account JWT tables | app-api 1.2.0 |
| V17 | admin RBAC permissions | admin-api 1.0.0 |

### T03 — Smoke assertions (Step 10) + Dart verifier

**k8s-smoke.sh Step 10** (~30 lines, 4–6 new assertions):

```bash
echo "--- Step 10: S02 release boundary truth ---"

# 1. Schema compatibility matrix doc exists

# 2. Runbook references babytalk-infra (dual-release)

# 3. Runbook references babytalk-app

# 4. Infra chart renders NO db-migration Job (infra is schema-free)

# 5. App chart db-migration hook delete policy is before-hook-creation,hook-succeeded

```

**Dart verifier** `tool/verify_m007_s02_release_boundaries.dart` (~200 lines, offline mode only):

- Stage 1: preflight (helm + dart available)
- Stage 2: infra boundary — `helm template babytalk-infra deploy/helm/babytalk-infra` → assert no Job/db-migration present
- Stage 3: app boundary — `helm template babytalk-app deploy/helm/babytalk-app` → assert db-migration Job with pre-install,pre-upgrade hook and correct delete policy
- Stage 4: doc existence — assert both `docs/runbooks/k8s-deploy.md` (dual-release sections) and `docs/schema-compatibility-matrix.md` exist
- Telemetry: `tmp/m007-s02-boundary-metrics.jsonl`

---

## Sequencing / Dependencies

```
T01 (runbook rewrite, ~2h)   → independent, no code deps
T02 (schema matrix, ~1h)     → independent, needs db/migration file list (already read)
T03 (smoke + verifier, ~1.5h) → depends on T01+T02 doc paths, but verifier can be written first with file-existence assertions
```

T01 and T02 can be done in parallel by the executor. T03 depends on T01/T02 doc paths being final.

---

## Verification Commands (end-state)

```bash

# 1. Smoke script (adds ~6 assertions in Step 10, total ~58 passing)

bash ci/k8s-smoke.sh

# 2. S02 offline dry-run verifier (no cluster needed)

dart run tool/verify_m007_s02_release_boundaries.dart

# 3. Confirm runbook mentions dual releases

grep -q 'babytalk-infra' docs/runbooks/k8s-deploy.md
grep -q 'babytalk-app'   docs/runbooks/k8s-deploy.md

# 4. Confirm schema matrix exists

[ -f docs/schema-compatibility-matrix.md ]

# 5. Confirm infra chart has no db-migration Job

helm template babytalk-infra deploy/helm/babytalk-infra \
  | grep -c 'kind: Job' | grep -q '^0$'

# 6. Confirm app chart db-migration hook semantics

helm template babytalk-app deploy/helm/babytalk-app \
  | grep 'hook-delete-policy' \
  | grep -q 'before-hook-creation,hook-succeeded'
```

---

## Known Constraints and Gotchas

1. **Redis `BABY_TALK_REDIS_HOST` is optional in configmap** — only injected when the key is present in `.Values.config`. The production values-production.yaml does not set it. If any service needs Redis in production, `values-production.yaml` must be extended. S02 should document this in the runbook; the gap itself is in scope if it blocks production topology correctness.

2. **Helm rollback + forward-only schema** — the runbook must explicitly warn that `helm rollback babytalk-app` is safe only when the previous app version is compatible with the current schema version. This constraint must appear in both the runbook and the schema matrix.

3. **No real images available** — db-migration, app-api, admin-api, admin-web images are referenced as `babytalk/db-migration:1.0.0` etc. (not built/pushed). All S02 verifications are dry-run/template only. The Dart verifier must NOT attempt a live helm install.

4. **Karpathy rule: surgical changes** — the runbook rewrite is complete (the existing file is M006 wrong-truth, not just outdated), but deployment.yaml and other chart files should NOT be touched unless a specific gap is found. They are already correct.

5. **Infra chart has no templates/ directory** — only dependency charts via Bitnami tarballs. `helm template babytalk-infra` renders the sub-charts. This means the "no db-migration Job in infra" assertion needs to grep the rendered output, not check for a Job template file.

---

## Skills Discovered

No new skills installed — this is standard Helm + Dart territory already established in S01.
