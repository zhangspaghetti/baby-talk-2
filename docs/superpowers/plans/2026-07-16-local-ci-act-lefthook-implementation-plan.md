# Local CI, act, and Lefthook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide one fail-fast repository CI command, simulate applicable GitHub workflows locally with act, enforce the command through Lefthook pre-push, and produce SHA-bound evidence for manual review into `Develop`.

**Architecture:** `ci/full-ci.sh` is the only complete local gate and delegates to existing backend, Helm, mobile, and release verifiers. act reuses tracked GitHub workflow definitions without ACT-only skips. Lefthook calls the same full gate. Exact-SHA reports are ignored local artifacts because committing a filename containing its own HEAD would change that HEAD; the same evidence is copied into draft PR #13 metadata.

**Tech Stack:** Bash, Python unittest, Git, Docker Desktop Linux containers, Testcontainers, nektos/act 0.2.89, Lefthook 2.1.10, Maven, Flutter/Dart, Helm.

## Global Constraints

- Merge target is exact-case `Develop`; all comparisons use freshly fetched `origin/Develop`.
- GitHub-hosted Actions remain disabled; no paid runner, server required check, automatic merge, or branch-protection claim.
- Never pass production AI keys, database passwords, JWT keys, Kubernetes secrets, or real user data to Maven, Docker, act, or logs.
- Keep Ryuk enabled and use cached `testcontainers/ryuk:0.14.0`; Testcontainers PostgreSQL fixtures use `pgvector/pgvector:pg17`.
- Host proxy is `127.0.0.1:7890`; act containers use `host.docker.internal:7890`; commit no proxy credentials.
- No product behavior, mobile UI, database business schema, release assertion, or test strength changes.
- `ci/full-ci.sh` uses `set -euo pipefail`, fails fast, starts and ends clean, and prints success metadata only after every required gate passes.
- act incompatibilities are recorded as `ACT_UNSUPPORTED_BUT_LOCAL_EQUIVALENT_VERIFIED`; workflow commands are never skipped through `if: env.ACT`.

---

### Task 1: Repository-level full CI entrypoint and target truth

**Files:**
- Create: `ci/full-ci.sh`
- Create: `test/ci/test_full_ci_contract.py`
- Modify: `AGENTS.md`
- Modify: `.gitignore`
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/mobile-pr-validation.yml`
- Modify: `.github/workflows/mobile-build.yml`
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `docs/runbooks/m006-s14-release-closure.md`
- Modify: `tool/verify_m006_s14_release_closure.dart`
- Modify: `test/tool/verify_m006_s14_release_closure_test.dart`
- Modify: `docs/superpowers/reports/2026-07-16-merge-base-ci-attribution.md`
- Modify: Testcontainers Java fixtures currently using `pgvector/pgvector:pg16`
- Modify: `mobile/lib/l10n/app_localizations.dart` generated documentation only if `flutter pub get` proves it stale

**Interfaces:**
- Consumes: existing `ci/backend-test.sh`, `ci/k8s-smoke.sh`, `ci/mobile-analyze.sh`, `ci/mobile-r4-release-gates.sh`, Spring AI verifier, M007 S01/S02/S06 and M006/schema fixtures.
- Produces: executable `bash ci/full-ci.sh`; stage markers and final SHA metadata consumed by Lefthook and report collection.

- [ ] **Step 1: Add failing contract tests**

Create Python unittest coverage asserting the script exists, is executable, contains strict mode, uses exact `Develop`, verifies clean state before and after, preserves required gate order, scrubs opt-in LLM keys, contains no required-gate `|| true`, and prints the five required final lines only after the last cleanliness check. Assert active workflow target branches use exact `Develop` and current CI authority copy names `ci/full-ci.sh`.

- [ ] **Step 2: Verify RED**

Run:

```bash
python3 -m unittest test.ci.test_full_ci_contract -v
```

Expected: failure because `ci/full-ci.sh` does not exist and current workflow/docs still name `main` or `.github/workflows/ci.yml` as repository authority.

- [ ] **Step 3: Implement minimal full gate**

`ci/full-ci.sh` must:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

It resolves repo root, rejects dirty input, resolves `HEAD`, `origin/Develop`, and merge-base, verifies Docker Linux mode, owns a scoped `alpine/socat` relay only when port 2375 is unavailable, never disables Ryuk, and scrubs `SSY_API_KEY` plus provider-key variables from backend children without printing values.

Run gates in fixed order:

```text
python3 test/tool/verify_spring_ai_2_backend_platform_test.py
python3 tool/verify_spring_ai_2_backend_platform.py
backend/mvnw dependency:tree + verifier --dependency-tree <mktemp>
bash ci/backend-test.sh
focused GrowthServiceMapperIntegrationTest PostgreSQL test
backend/mvnw checkstyle:check
bash ci/k8s-smoke.sh
bash ci/mobile-analyze.sh
bash ci/mobile-r4-release-gates.sh
flutter test M006/S01/schema fixtures
dart run tool/verify_m007_s02_release_boundaries.dart
dart run tool/verify_m007_s06_docs_coherence.dart
git diff --check <merge-base>..HEAD
final git status --short check
```

The mobile analyze script already contains full `flutter test`; do not duplicate it. Treat the R4 performance profile and two no-cluster Helm checks as explicit environmental/policy SKIPs in evidence.

- [ ] **Step 4: Correct active target and authority copy**

Use exact-case `Develop` in applicable workflow triggers. Mark the old merge-base report as historical and recompute current evidence from `origin/Develop`; do not rewrite its historical measurements as current. Make README, CONTRIBUTING, M006 runbook/tool/tests state:

```text
bash ci/full-ci.sh is the only complete local repository CI entrypoint.
.github/workflows/ci.yml is simulated locally with act.
GitHub-hosted Actions are intentionally disabled.
```

Keep Helm smoke explicitly scoped. Sync only generated localization comments already backed by unchanged ARB/runtime values, with zero UI behavior change.

- [ ] **Step 5: Move Testcontainers fixtures to pg17**

Mechanically replace test-only `pgvector/pgvector:pg16` image references with `pgvector/pgvector:pg17`. Do not edit migration SQL or production datasource behavior.

- [ ] **Step 6: Verify GREEN and commit**

Run Python contract tests, M006/schema fixtures, Spring AI fixture/live verifier, a focused PostgreSQL test, `bash -n ci/full-ci.sh`, and `git diff --check`. Commit exact task files as:

```text
chore: add local full CI entrypoint
```

---

### Task 2: act pull-request simulation

**Files:**
- Create: `.actrc`
- Create: `.act/pull_request.json`
- Create or modify: `test/ci/test_local_ci_configuration.py`
- Create: `docs/development/local-ci.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: PR #13 base/head metadata and workflow `Develop` triggers.
- Produces: reproducible `act -l` and `act pull_request` commands with pinned Linux runner image, host network, artifact server, no secrets.

- [ ] **Step 1: Add failing configuration tests**

Assert exact base/head refs, repository metadata, PR number 13, draft state, no secret-shaped keys, pinned runner digest, `--network=host`, artifact path, `Develop` default branch, and ignored `.act/artifacts/`.

- [ ] **Step 2: Verify RED**

```bash
python3 -m unittest test.ci.test_local_ci_configuration -v
```

- [ ] **Step 3: Implement config and docs**

Pin:

```text
ghcr.io/catthehacker/ubuntu:act-24.04@sha256:5d6a17640b25694988b9db5a4145537b9918e5430116b2cf90d84e837609b382
```

Configure Linux amd64, host network, artifact server, strict parsing, removal after run, and `Develop` default branch. Event JSON contains PR #13, base `Develop`, head `gsd/v0.1-milestone`, current base SHA where stable, repository metadata, and no credentials. Omit self-referential final head SHA if it cannot remain accurate after committing the fixture; runtime evidence records actual checkout HEAD.

Document host/container proxy forms and exact list/run commands. State act is local simulation, not remote CI or required checks.

- [ ] **Step 4: Verify and commit**

Run config tests, JSON parse, act strict workflow listing, and `git diff --check`. Commit:

```text
chore: add act pull request simulation
```

---

### Task 3: Lefthook pre-push enforcement

**Files:**
- Create: `lefthook.yml`
- Modify: `test/ci/test_local_ci_configuration.py`
- Modify: `docs/development/local-ci.md`

**Interfaces:**
- Consumes: `bash ci/full-ci.sh`.
- Produces: unconditional pre-push command and documented bypass limitations.

- [ ] **Step 1: Add failing tests**

Assert pre-push always executes exactly `bash ci/full-ci.sh`, with no file glob, skip, or path filter. Assert docs say `git push --no-verify` can bypass local hooks, bypass requires written PR disclosure, and no server-side required checks exist.

- [ ] **Step 2: Verify RED, implement, validate**

```yaml
pre-push:
  commands:
    full-local-ci:
      run: bash ci/full-ci.sh
      fail_text: "Full local CI failed; push blocked."
```

Run:

```powershell
lefthook validate
lefthook install
lefthook check-install
```

- [ ] **Step 3: Verify and commit**

Run config tests and `git diff --check`. Commit:

```text
chore: add lefthook pre-push gate
```

---

### Task 4: Exact-SHA local evidence, second environment, and PR handoff

**Files:**
- Modify: `docs/development/local-ci.md`
- Modify: `.gitignore`
- Generate ignored local artifact: `docs/superpowers/reports/local-ci-<full-head-sha>.md`
- Update remote metadata: draft PR #13 description and base branch only

**Interfaces:**
- Consumes: committed Tasks 1-3, exact HEAD, `origin/Develop`, act and Lefthook.
- Produces: local report plus PR-visible evidence for manual merge review.

- [ ] **Step 1: Commit all tracked documentation before evidence**

Commit plan/local-CI documentation before selecting candidate SHA:

```text
docs: document local CI evidence
```

- [ ] **Step 2: Fetch and record exact candidate**

```bash
git fetch origin Develop
git rev-parse HEAD
git rev-parse origin/Develop
git merge-base HEAD origin/Develop
git status --short
```

- [ ] **Step 3: Run primary environment gates**

Run `bash ci/full-ci.sh`, both-job `act -l`, full act CI workflow simulation, applicable mobile PR workflow simulation, `lefthook run pre-push`, final diff/clean checks. Do not pass production secrets. Capture commands, exit codes, test/pass/fail/skip counts, versions, timestamps, and specific ACT unsupported items.

- [ ] **Step 4: Run second clean worktree**

Create ignored `.worktrees/local-ci-<short-sha>` at detached exact full SHA. Confirm clean start, fresh `origin/Develop`, matching merge-base, and no leftover test/act containers. Run the same full CI and act commands. Do not reuse uncommitted files or production environment variables.

- [ ] **Step 5: Generate exact-SHA report without changing HEAD**

Write the ignored local report path after the exact candidate is fixed. Include required versions, start/end times, every command and exit code, counts, environmental SKIPs, primary/second environment results, and act boundaries. Copy the full evidence summary into PR #13 description so reviewers can audit it remotely. The report is not committed because doing so would change the SHA it names.

- [ ] **Step 6: Final handoff**

Confirm PR #13 base `Develop`, actual head branch, draft true; GitHub Actions still disabled; no required checks; worktree clean. Push without merge. Stop before manual review.
