# S06: Front-door docs and proof tooling collaborative rewrite — Research

**Date:** 2026-04-27
**Scope:** R057 — README/CONTRIBUTING/runbooks/verifiers all describe the same Helm-first + gateway-first truth

## Summary

S06 is documentation alignment work. S01–S05 wrote the stable truths (Helm commands, gateway URL, migration paths, MyBatisPlus patterns) but left behind stale S01-era language in README, CONTRIBUTING, and the k8s-deploy.md runbook. The core issue is that S01 wrote `nginx:alpine stub; S03 会替换成 Spring Cloud Gateway` in multiple places — S03 and S04 have since landed, but the docs still describe the world as it was in S01. Additionally, S05 established MyBatisPlus as the canonical backend persistence pattern, but CONTRIBUTING.md has no mention of it.

S06 has three concrete deliverables:

1. **Stale reference cleanup** in README.md, CONTRIBUTING.md, and docs/runbooks/k8s-deploy.md — remove all references to the nginx:alpine stub, `S01 的 CI-equivalent`, `S03 会替换`, `app-api` with external ingress, and admin-api:8081 as the admin-web proxy target.
2. **MyBatisPlus persistence pattern section** in CONTRIBUTING.md — satisfy the S05 follow-up and R057's documentation completeness criterion for the backend persistence story.
3. **Docs coherence verifier + smoke gate** — `tool/verify_m007_s06_docs_coherence.dart` (offline Dart, JSONL telemetry) and a new `ci/k8s-smoke.sh` Step 12 with 4–5 assertions.

This is low-risk, targeted work. No backend code changes required.

## Recommendation

Execute in three tasks:

- **T01:** Patch README.md and CONTRIBUTING.md (stale reference cleanup + MyBatisPlus section)
- **T02:** Patch docs/runbooks/k8s-deploy.md (gateway-stub stale language)
- **T03:** Write `tool/verify_m007_s06_docs_coherence.dart` + add `ci/k8s-smoke.sh` Step 12

Follow the Karpathy surgical-change rule: touch only what is stale or missing. Do not reorganise sections that are already correct.

## Implementation Landscape

### Key Files

- `README.md` (235 lines) — 5 stale items (detailed below)
- `CONTRIBUTING.md` (114 lines) — 3 stale items + 1 missing section
- `docs/runbooks/k8s-deploy.md` (532 lines) — 5 stale "gateway stub" occurrences
- `ci/k8s-smoke.sh` — add Step 12 docs coherence assertions (last step, 4–5 checks)
- `tool/verify_m007_s06_docs_coherence.dart` — new offline Dart verifier following S02 pattern

### Stale Items in README.md

| Line | Stale Text | Replace With |
|------|------------|--------------|
| 107 | `当前是 nginx:alpine stub；S03 会替换成 Spring Cloud Gateway` | `Spring Cloud Gateway (babytalk/gateway:1.0.0)；admin 和 consumer 流量的唯一外部后端入口` |
| 44 (app-api row) | `public app surface` | `cluster-internal service；consumer 流量经 gateway 代理` |
| 110 (admin-api row) | `http://127.0.0.1:8081` | `仅 cluster-internal service；无公网 Ingress` |
| ~97 | `Final release closure（当前 S01 的 CI-equivalent）` | `Final release closure (CI smoke gate)` |
| ~161–164 | `admin-api 不在 127.0.0.1:8081` / `VITE_ADMIN_API_PROXY_TARGET=http://127.0.0.1:8081` | `gateway 不在 127.0.0.1:8090` / `VITE_ADMIN_API_PROXY_TARGET=http://127.0.0.1:8090` |

Confirmed via `admin-web/vite.config.ts` line 10: default is already `http://127.0.0.1:8090`.

### Stale Items in CONTRIBUTING.md

| Line | Stale Text | Replace With |
|------|------------|--------------|
| ~8 | `想跑当前 S01 的 CI-equivalent gate` | `想跑 CI-equivalent gate` |
| ~57 | `默认代理目标是本地 admin-api。如果 admin-api 不在…` | `默认代理目标是本地 gateway（8090）。如果 gateway 不在…` |
| ~62 | `VITE_ADMIN_API_PROXY_TARGET=http://127.0.0.1:8081` | `VITE_ADMIN_API_PROXY_TARGET=http://127.0.0.1:8090` |
| missing | (no MyBatisPlus section) | Add **Backend persistence pattern** subsection under Backend-only change |

The new MyBatisPlus section should be brief (5–8 lines):

- Repository facade pattern (JdbcTemplate removed; callers unchanged)
- Inject `@Mapper` interface; SQL in `src/main/resources/mapper/**/*.xml`
- Druid datasource with slow-query logging (slow-sql-millis: 2000)
- UuidTypeHandler in common for PostgreSQL UUID mapping
- Reference: `tool/verify_m007_s06_docs_coherence.dart` for pattern compliance check

### Stale Items in docs/runbooks/k8s-deploy.md

| Line | Stale Text | Replace With |
|------|------------|--------------|
| 7 | `gateway stub` | `gateway (Spring Cloud Gateway)` |
| 24 | `gateway stub` in table | `gateway (Spring Cloud Gateway)` |
| 42 | `目前是 stub，S03 才会替换为正式 gateway` | `Spring Cloud Gateway (babytalk/gateway:1.0.0)；admin 和 consumer 流量的唯一外部入口` |
| 43 | `app-api` row: `对外` + `Ingress` | `仅集群内；consumer 流量经 gateway 代理` — aligns with S04 production values |
| 53 | `gateway 当前是 stub，可作为 smoke / 边界验证对象，但不能把它当最终拓扑。` | `gateway 是 Spring Cloud Gateway；是 admin + consumer 流量的唯一外部入口。` |
| 503 | `gateway 当前仍是 stub` | `gateway 是 Spring Cloud Gateway；如果 smoke 中 gateway 检查失败，优先把它当 app 边界回归。` |
| 522 | `gateway 回归：smoke 不再能证明 gateway stub 仍在 app release 中。` | `gateway 回归：smoke 不再能证明 Spring Cloud Gateway 仍在 app release 中。` |

### New Tool: `tool/verify_m007_s06_docs_coherence.dart`

Follow the exact offline Dart verifier pattern from S02 (`tool/verify_m007_s02_release_boundaries.dart`):

- 4 stages: preflight (dart/helm versions), readme-truth, contributing-truth, runbook-truth
- Each stage runs `File.readAsStringSync()` / `helm template` checks and asserts expected/unexpected strings
- Writes JSONL telemetry to `tmp/m007-s06-docs-metrics.jsonl`
- Exit code 0 on all pass, non-zero on any failure

Assertions to include:

- README does NOT contain `nginx:alpine stub` or `S03 会替换`
- README contains `Spring Cloud Gateway` and `dev-up-helm-demo`
- CONTRIBUTING does NOT contain `admin-api:8081` or `S01 的 CI`
- CONTRIBUTING contains `MyBatisPlus` and `gateway（8090）` or `gateway:8090`
- `docs/runbooks/k8s-deploy.md` does NOT contain `gateway stub`
- `docs/schema-compatibility-matrix.md` exists

### New ci/k8s-smoke.sh Step 12

Add after the existing Step 11 (own-jdbctemplate-count):

```bash
step "12. Docs coherence gate"
assert_not_contains "README.md" "nginx:alpine stub"
assert_not_contains "README.md" "S03 会替换"
assert_not_contains "docs/runbooks/k8s-deploy.md" "gateway stub"
assert_not_contains "CONTRIBUTING.md" "admin-api:8081"
assert_contains "CONTRIBUTING.md" "MyBatisPlus"
```

Use the same `assert_contains` / `assert_not_contains` helper pattern already used in other steps.

### Build Order

1. **T01 first** — README + CONTRIBUTING patches are self-contained, highest visibility to new developers, and touch nothing in the build pipeline.
2. **T02 second** — k8s-deploy.md is operator-facing; patch after T01 to keep the same review focus.
3. **T03 last** — Dart verifier + smoke gate can only be written after T01+T02 are clean; this is also the final verification layer.

### Verification Approach

For each task, the verify criterion is:

- `bash ci/k8s-smoke.sh` passes (≥63 PASS after T01+T02; ≥68 PASS after T03 with Step 12)
- `dart run tool/verify_m007_s06_docs_coherence.dart` exits 0 after T03
- `dart analyze tool/verify_m007_s06_docs_coherence.dart` exits 0 after T03
- `grep -c 'nginx:alpine\|gateway stub\|S01 の CI\|S03 会替換' README.md CONTRIBUTING.md docs/runbooks/k8s-deploy.md` returns 0

## Constraints

- No backend code changes in S06. Touch only docs, scripts, and the new Dart verifier.
- Karpathy surgical-change rule: edit only the stale lines; do not reorganise sections, rewrite prose, or rename commands that already work.
- The `ci/k8s-smoke.sh` Step 12 must use `|| true` on any grep-based assertion that checks for absence (zero-count pattern) to survive `set -euo pipefail`. This is the pattern established in S02 T03 and S05 T06.
- `verify_m007_s06_docs_coherence.dart` must use `RegExp(pattern, multiLine: true)` for multiline patterns — NOT inline `(?m)` flag (Dart does not support inline flags). This is the S02 Dart gotcha.

## Common Pitfalls

- **Editing README tables without checking column alignment** — Markdown table rendering depends on pipe alignment; misalignment does not break GitHub rendering but makes raw reading harder. Match existing column spacing.
- **Missing `|| true` on zero-count greps** — `grep -c pattern file` returns exit code 1 when match count is 0, which kills the script under `set -euo pipefail`. Use `|| true` for absence assertions.
- **`assert_not_contains` with Chinese characters** — The smoke script runs in bash; non-ASCII pattern matching with `grep` works but must be in UTF-8. The worktree is UTF-8, so this is not a problem in practice.

## Sources

- S01-S05 summaries (preloaded) — stable command truth for docs
- `admin-web/vite.config.ts` line 10: confirms default proxy target is `127.0.0.1:8090`
- `ci/k8s-smoke.sh` current step structure: confirms Step 11 is the last step
- `tool/verify_m007_s02_release_boundaries.dart` — pattern to follow for S06 Dart verifier
