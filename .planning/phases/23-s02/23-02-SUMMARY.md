---
phase: "23"
plan: "02"
---

# T02: Added the V3–V17 schema compatibility matrix documenting the M007 N/N-1 Flyway contract and forward-only rollback boundary.

**Added the V3–V17 schema compatibility matrix documenting the M007 N/N-1 Flyway contract and forward-only rollback boundary.**

## What Happened

I created `docs/schema-compatibility-matrix.md` as the authoritative schema compatibility reference for the M007 dual-release topology. The new document records the N/N-1 compatibility policy for `app-api` and `admin-api`, states that the current schema is V17 with 15 migrations spanning V3–V17, and includes a full migration matrix mapped to the first workload version that requires each migration. I also documented the forward-only rollback constraint for Flyway in the `babytalk-app` release, including the operational warning that `helm rollback babytalk-app` restores Kubernetes workloads but does not revert the database schema. Finally, I added the pre-upgrade checklist that requires backward-compatible schema changes before bumping the `db-migration` image tag. This task stayed documentation-only and did not modify chart files or application source code.

## Verification

I re-read `docs/schema-compatibility-matrix.md` after writing it and verified that it contains `V17`, the `forward-only` rollback rule, and at least 60 lines; the final file is 122 lines. I also confirmed that the existing runbook still references `docs/schema-compatibility-matrix.md`, so the new document matches the T01 linkage contract. The slice-level smoke Step 10 and Dart verifier telemetry checks were not run here because those deliverables belong to T03; for T02, the document-level verification passed and the downstream slice-level verification remains pending by plan.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `python - <<'PY'
from pathlib import Path
p = Path('docs/schema-compatibility-matrix.md')
text = p.read_text(encoding='utf-8')
assert p.exists()
assert 'V17' in text
assert 'forward' in text
assert len(text.splitlines()) >= 60
print(len(text.splitlines()))
PY` | 0 | ✅ pass | 1ms |
| 2 | `python - <<'PY'
from pathlib import Path
runbook = Path('docs/runbooks/k8s-deploy.md').read_text(encoding='utf-8')
assert Path('docs/schema-compatibility-matrix.md').exists()
assert 'schema-compatibility-matrix.md' in runbook or 'schema-compatibility-matrix' in runbook
PY` | 0 | ✅ pass | 1ms |

## Deviations

The planned verification command used POSIX `[` tests, but this Windows shell reports `'[' is not recognized as an internal or external command`. I therefore executed equivalent Python-based checks for file existence, required text, and line count instead of using the original shell snippet verbatim.

## Known Issues

None.

## Files Created/Modified

- `docs/schema-compatibility-matrix.md`
