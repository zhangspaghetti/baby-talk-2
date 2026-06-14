---
phase: "22"
plan: "01"
---

# T01: Added the kind baseline and vendored babytalk-infra Helm chart for Postgres, Redis, and MinIO.

**Added the kind baseline and vendored babytalk-infra Helm chart for Postgres, Redis, and MinIO.**

## What Happened

Created `deploy/kind/kind-config.yaml` for the local Helm baseline with ingress port mappings on a single kind control-plane node and documented the required `--name babytalk-local` / `kubectl create namespace babytalk` bootstrap steps next to the config. Added a new dependency-only `deploy/helm/babytalk-infra` chart pinned to Bitnami `postgresql`, `redis`, and `minio`, with the PostgreSQL dependency aliased to `postgres` so downstream charts can target the expected in-cluster service names. Added baseline values that mirror the old compose defaults (babytalk DB/user/password, Redis without auth, MinIO credentials and bucket) plus kind-specific low-resource overrides, then vendored the dependency tarballs and lockfile so local and CI lint/template checks do not require live network resolution.

## Verification

Ran `helm dependency update deploy/helm/babytalk-infra` to generate `Chart.lock` and vendor the Bitnami tarballs. Ran `helm lint deploy/helm/babytalk-infra`, which passed with the expected informational warning that this dependency-only chart has no local `templates/` directory. Rendered `helm template babytalk-infra deploy/helm/babytalk-infra -f deploy/helm/babytalk-infra/values-kind.yaml` and parsed the output to confirm the chart emits the expected infra resource kinds and service names, including `babytalk-infra-postgres`, `babytalk-infra-redis-master`, and `babytalk-infra-minio`. Also inspected the slice-level telemetry artifact path; `tmp/m007-s01-helm-metrics.jsonl` is still absent, which is expected at T01 because the wrapper commands that append those records are scoped to later tasks.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `helm dependency update deploy/helm/babytalk-infra` | 0 | ✅ pass | 23178ms |
| 2 | `helm lint deploy/helm/babytalk-infra` | 0 | ✅ pass | 205ms |
| 3 | `python - <<'PY' # render babytalk-infra and parse unique kinds + Service names from helm template output\n...\nPY` | 0 | ✅ pass | 298ms |
| 4 | `python - <<'PY' # inspect tmp/m007-s01-helm-metrics.jsonl existence\n...\nPY` | 0 | ❌ fail | 1ms |

## Deviations

Used a single `control-plane` kind node instead of a `worker` node because kind cannot bootstrap a worker-only single-node cluster. The config comments document the planned cluster name and namespace bootstrap steps that are applied by the wrapper commands rather than encoded directly in the kind config schema.

## Known Issues

`tmp/m007-s01-helm-metrics.jsonl` is not produced yet because the `dev-up` / smoke wrappers that append slice telemetry are outside T01 scope and remain for later tasks in S01.

## Files Created/Modified

- `deploy/kind/kind-config.yaml`
- `deploy/helm/babytalk-infra/Chart.yaml`
- `deploy/helm/babytalk-infra/values.yaml`
- `deploy/helm/babytalk-infra/values-kind.yaml`
- `deploy/helm/babytalk-infra/.helmignore`
- `deploy/helm/babytalk-infra/Chart.lock`
- `deploy/helm/babytalk-infra/charts/postgresql-18.6.2.tgz`
- `deploy/helm/babytalk-infra/charts/redis-25.4.1.tgz`
- `deploy/helm/babytalk-infra/charts/minio-17.0.21.tgz`
