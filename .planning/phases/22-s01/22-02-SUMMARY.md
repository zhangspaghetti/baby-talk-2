---
phase: "22"
plan: "02"
---

# T02: Carved `deploy/helm/babytalk-app`, added a stub `gateway` component, and turned `ci/k8s-smoke.sh` into dual-chart Helm smoke with telemetry.

**Carved `deploy/helm/babytalk-app`, added a stub `gateway` component, and turned `ci/k8s-smoke.sh` into dual-chart Helm smoke with telemetry.**

## What Happened

Copied the old `deploy/helm/babytalk` chart into `deploy/helm/babytalk-app`, renamed all helper templates to `babytalk-app.*`, and updated `Chart.yaml` plus the copied production values header so the new chart becomes the only application release boundary. Added a conditional `gateway` Deployment/Service on `nginx:alpine` with readiness/liveness probes, Helm test coverage, and NOTES output that explicitly calls out the temporary stub to be replaced in S03. Added `values-kind.yaml` and `values-kind-secrets.example.yaml` so local installs can point at `babytalk-infra-postgres`, `babytalk-infra-minio`, and `babytalk-infra-redis-master` with low-resource overrides, and taught the config map to surface `BABY_TALK_REDIS_HOST` when that kind override is supplied. Reworked `ci/k8s-smoke.sh` to lint/render both `deploy/helm/babytalk-infra` and `deploy/helm/babytalk-app`, assert the new `babytalk-app-*` resource names including gateway, and append redaction-safe bounded smoke telemetry to `tmp/m007-s01-helm-metrics.jsonl`. After those checks passed, removed the old `deploy/helm/babytalk` directory to eliminate dual chart truth.

## Verification

Ran `bash ci/k8s-smoke.sh` after deleting the old chart and it passed all Helm lint/render/test/NOTES assertions for both charts, skipping only kubectl client dry-runs because no reachable cluster was available in this environment. Rendered `helm template babytalk-app deploy/helm/babytalk-app` and confirmed the gateway stub resources render as `babytalk-app-gateway`, and rendered the chart with `-f deploy/helm/babytalk-app/values-kind.yaml` to confirm `BABY_TALK_REDIS_HOST` plus decoded `BABY_TALK_DB_URL` and `BABY_TALK_MINIO_ENDPOINT` point at the `babytalk-infra-*` services. Verified the latest `tmp/m007-s01-helm-metrics.jsonl` entry contains the required telemetry keys and confirmed `deploy/helm/babytalk` no longer exists.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `bash ci/k8s-smoke.sh` | 0 | ✅ pass | 10781ms |
| 2 | `bash -lc "helm template babytalk-app deploy/helm/babytalk-app | grep -E 'babytalk-app-gateway' | head -5"` | 0 | ✅ pass | 1475ms |
| 3 | `helm template babytalk-app deploy/helm/babytalk-app -f deploy/helm/babytalk-app/values-kind.yaml | decode Secret infra endpoints` | 0 | ✅ pass | 209ms |
| 4 | `bash -lc "helm template babytalk-app deploy/helm/babytalk-app -f deploy/helm/babytalk-app/values-kind.yaml | grep -E 'babytalk-infra-(postgres|minio|redis-master)|BABY_TALK_REDIS_HOST' | head -10"` | 0 | ✅ pass | 973ms |
| 5 | `python -c "import json,pathlib; p=pathlib.Path('tmp/m007-s01-helm-metrics.jsonl'); lines=[json.loads(line) for line in p.read_text(encoding='utf-8').splitlines() if line.strip()]; last=lines[-1]; required=['mode','shell','success','tthw_seconds','first_failure_stage','likely_cause','next_action','timestamp']; missing=[key for key in required if key not in last]; assert not missing, missing; print(json.dumps({key:last[key] for key in required}, ensure_ascii=False))"` | 0 | ✅ pass | 247ms |
| 6 | `bash -lc "test ! -d deploy/helm/babytalk"` | 0 | ✅ pass | 613ms |

## Deviations

Extended `ci/k8s-smoke.sh` beyond the explicit task-plan bullets to template-check `deploy/helm/babytalk-infra` service names and to emit bounded `tmp/m007-s01-helm-metrics.jsonl` telemetry, because the slice verification contract requires smoke-level dual-chart truth and an inspection-friendly recent-history artifact. No other deviations.

## Known Issues

Docs still contain stale references to the deleted `deploy/helm/babytalk` path (notably `docs/runbooks/k8s-deploy.md` and older M005 runbooks). A later documentation task should retarget those commands to `deploy/helm/babytalk-app` / `deploy/helm/babytalk-infra`.

## Files Created/Modified

- `deploy/helm/babytalk-app/Chart.yaml`
- `deploy/helm/babytalk-app/values.yaml`
- `deploy/helm/babytalk-app/values-kind.yaml`
- `deploy/helm/babytalk-app/values-kind-secrets.example.yaml`
- `deploy/helm/babytalk-app/values-production.yaml`
- `deploy/helm/babytalk-app/templates/_helpers.tpl`
- `deploy/helm/babytalk-app/templates/configmap.yaml`
- `deploy/helm/babytalk-app/templates/deployment.yaml`
- `deploy/helm/babytalk-app/templates/service.yaml`
- `deploy/helm/babytalk-app/templates/tests/test-connection.yaml`
- `deploy/helm/babytalk-app/templates/NOTES.txt`
- `ci/k8s-smoke.sh`
- `.gitignore`
