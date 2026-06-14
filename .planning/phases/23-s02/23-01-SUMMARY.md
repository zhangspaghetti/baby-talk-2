---
phase: "23"
plan: "01"
---

# T01: Rewrote the Kubernetes deploy runbook around the M007 dual-release topology for babytalk-infra and babytalk-app.

**Rewrote the Kubernetes deploy runbook around the M007 dual-release topology for babytalk-infra and babytalk-app.**

## What Happened

I replaced the legacy M006 single-chart runbook in `docs/runbooks/k8s-deploy.md` with an M007 dual-release operator guide. The new document now describes the real split between `babytalk-infra` and `babytalk-app`, the required install order, independent infra-only vs app-only upgrade paths, the `db-migration` hook semantics (`pre-install,pre-upgrade`, `hook-weight: -10`, `before-hook-creation,hook-succeeded`), `backoffLimit: 1`, rollback constraints, schema compatibility matrix references, and a shared troubleshooting vocabulary (`preflight / cluster / infra / app / gateway / smoke`). I verified the surrounding chart files before writing so the runbook reflects the current repository truth, including the gateway stub and the forward-only schema rule. No chart, values, or deployment templates were changed; this task remained documentation-only as planned.

## Verification

Ran the task-level verification command against `docs/runbooks/k8s-deploy.md`. It passed, confirming the rewritten runbook references `babytalk-infra`, `babytalk-app`, `schema-compatibility-matrix`, and `helm rollback`, and that the file exceeds the required minimum length. Slice-level smoke and Dart boundary verifier checks are intentionally not yet applicable at T01 because those deliverables are introduced in T03.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `grep -q 'babytalk-infra' docs/runbooks/k8s-deploy.md && grep -q 'babytalk-app' docs/runbooks/k8s-deploy.md && grep -q 'schema-compatibility-matrix' docs/runbooks/k8s-deploy.md && grep -q 'helm rollback' docs/runbooks/k8s-deploy.md && lines=$(wc -l < docs/runbooks/k8s-deploy.md) && [ "$lines" -ge 250 ]` | 0 | ✅ pass | 313ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `docs/runbooks/k8s-deploy.md`
