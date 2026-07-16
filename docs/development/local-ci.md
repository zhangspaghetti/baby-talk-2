# Local CI

Target branch: `Develop`

`bash ci/full-ci.sh` is the only complete local repository CI entrypoint. It
executes the repository gates directly and fails closed. Run it from a clean
checkout after fetching the current target:

```bash
git fetch origin Develop
bash ci/full-ci.sh
```

GitHub-hosted Actions: **INTENTIONALLY DISABLED**

Server-side required checks: **NOT CONFIGURED**

act is a local GitHub Actions simulation. It reuses tracked workflow commands,
but does not prove GitHub queueing, branch protection, required checks, or hosted-runner behavior.
Its result must be reported as local evidence, never as
a GitHub-hosted CI result.

## Lefthook pre-push gate

Lefthook is a local convenience gate. Install and validate the tracked hook:

```powershell
lefthook validate
lefthook install
lefthook check-install
```

Every normal push runs `bash ci/full-ci.sh` through the `pre-push` hook. There
are no path, file, or skip filters, and a quick check cannot replace this full
gate. Run the hook directly when collecting candidate evidence:

```powershell
lefthook run pre-push
```

`git push --no-verify` can bypass the pre-push hook.
Any pre-push bypass must be disclosed in writing in the PR.
Lefthook is not equivalent to server-side branch protection.
Manual merge review must inspect the SHA-bound local CI report.
GitHub-hosted Actions remain intentionally disabled, and server-side required
checks remain not configured as stated above.

## Prerequisites

- Docker Desktop using Linux containers
- nektos/act 0.2.89
- the toolchains required by `ci/full-ci.sh`

`.actrc` pins the `ubuntu-latest` substitute by multi-architecture index digest
and selects `linux/amd64`. It also uses host networking for the scoped Docker
relay, enables the local artifact server at `.act/artifacts`, parses workflows
strictly, removes job containers after each run, and uses `Develop` as the
default branch. Do not add production secrets, tokens, database passwords, JWT
keys, Kubernetes secrets, or real user data to act invocations or event files.

The tracked event fixture describes draft PR #13 from
`gsd/v0.1-milestone` into `Develop`. Its stable base SHA is the fetched
`origin/Develop` value at fixture creation. The tracked event fixture omits `pull_request.head.sha`
because committing that SHA inside its own fixture would
make it stale. SHA-bound runtime evidence records the exact checked-out HEAD SHA,
`origin/Develop` SHA, and merge-base SHA before each candidate run.

## Sanitize inherited credentials

act forwards parts of its host environment. In the same PowerShell session,
remove inherited production-capable variables before listing or running any
workflow. This block matches names only and does not print removed values:

```powershell
$unsafeEnvironmentNames = @(
  'GITHUB_TOKEN',
  'GH_TOKEN',
  'NPM_TOKEN',
  'CODECOV_TOKEN',
  'SSY_API_KEY',
  'OPENAI_API_KEY',
  'ANTHROPIC_API_KEY',
  'AZURE_OPENAI_API_KEY',
  'GOOGLE_API_KEY',
  'MISTRAL_AI_API_KEY',
  'DEEPSEEK_API_KEY',
  'OPENAI_BASE_URL',
  'ANTHROPIC_BASE_URL',
  'AZURE_OPENAI_ENDPOINT',
  'SPRING_APPLICATION_JSON',
  'DATABASE_URL',
  'JDBC_DATABASE_URL',
  'JDBC_URL',
  'REDIS_URL',
  'REDIS_HOST',
  'REDIS_PORT',
  'REDIS_PASSWORD',
  'PGPASSWORD',
  'PGPASSFILE',
  'PGSERVICE',
  'PGSERVICEFILE',
  'PGHOST',
  'PGHOSTADDR',
  'PGPORT',
  'PGDATABASE',
  'PGUSER',
  'PGOPTIONS',
  'JAVA_TOOL_OPTIONS',
  '_JAVA_OPTIONS',
  'JDK_JAVA_OPTIONS',
  'MAVEN_OPTS',
  'MAVEN_ARGS',
  'MAVEN_USER_HOME',
  'MAVEN_EXT_CLASS_PATH',
  'M2_HOME',
  'CLASSPATH',
  'KUBECONFIG',
  'KUBE_TOKEN',
  'KUBERNETES_SERVICE_HOST',
  'KUBERNETES_SERVICE_PORT',
  'HELM_REGISTRY_CONFIG',
  'HELM_REPOSITORY_CONFIG',
  'ADMIN_ACCESS_TOKEN',
  'ADMIN_PASSWORD',
  'AWS_ACCESS_KEY_ID',
  'AWS_SECRET_ACCESS_KEY',
  'AWS_SESSION_TOKEN',
  'AWS_PROFILE',
  'AWS_SHARED_CREDENTIALS_FILE',
  'GOOGLE_APPLICATION_CREDENTIALS',
  'AZURE_CLIENT_SECRET',
  'DOCKER_HOST',
  'DOCKER_CONTEXT',
  'DOCKER_TLS_VERIFY',
  'DOCKER_CERT_PATH',
  'DOCKER_AUTH_CONFIG',
  'REGISTRY_AUTH_FILE',
  'HTTP_PROXY',
  'HTTPS_PROXY',
  'ALL_PROXY',
  'NO_PROXY',
  'TESTCONTAINERS_RYUK_DISABLED'
)
$unsafeEnvironmentPrefixes = @(
  'BABY_TALK_',
  'SPRING_',
  'MVNW_',
  'DB_',
  'JWT_',
  'MINIO_',
  'KUBE_',
  'KUBERNETES_',
  'HELM_',
  'TESTCONTAINERS_'
)
$unsafeEnvironmentSuffixes = @(
  '_API_KEY',
  '_API_TOKEN',
  '_PASSWORD',
  '_SECRET',
  '_PRIVATE_KEY'
)

Get-ChildItem Env: | ForEach-Object {
  $entry = $_
  $hasUnsafePrefix = $unsafeEnvironmentPrefixes |
    Where-Object { $entry.Name.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }
  $hasUnsafeSuffix = $unsafeEnvironmentSuffixes |
    Where-Object { $entry.Name.EndsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }
  if (
    $unsafeEnvironmentNames -contains $entry.Name -or
    $hasUnsafePrefix -or
    $hasUnsafeSuffix
  ) {
    Remove-Item -LiteralPath "Env:$($entry.Name)" -ErrorAction SilentlyContinue
  }
}
$env:TESTCONTAINERS_RYUK_DISABLED = 'false'
```

Set only local fake test values required by an existing fixture. Never reuse a
production value. Environment-name comparison is case-insensitive, so existing
lowercase proxy names are removed too. Configure the credential-free proxy, if needed, only after
this cleanup. Then verify Docker resolves to the local Docker Desktop Linux
daemon before invoking act:

```powershell
docker context show
docker info --format 'OSType={{.OSType}} Name={{.Name}} ServerVersion={{.ServerVersion}}'
```

Expected `OSType=linux`. On Windows, act's startup diagnostic must name the
local `npipe:////./pipe/docker_engine` host. Stop if it resolves to a TCP or
remote daemon.

## List and run the PR workflow

List jobs without executing them:

```powershell
act -l pull_request `
  -W .github/workflows/ci.yml `
  -e .act/pull_request.json
```

Expected job IDs are `release-closure-gate` and `mobile-analyze`. Listing proves
only that act parsed and selected these jobs; it is not execution evidence.

Execute both jobs:

```powershell
act pull_request `
  -W .github/workflows/ci.yml `
  -e .act/pull_request.json
```

Determine every `pull_request` workflow whose path filters match the candidate
diff. List and run each applicable workflow with the same event fixture, then
record it separately. For mobile changes:

```powershell
act -l pull_request `
  -W .github/workflows/mobile-pr-validation.yml `
  -e .act/pull_request.json

act pull_request `
  -W .github/workflows/mobile-pr-validation.yml `
  -e .act/pull_request.json
```

For admin-web changes, including root pnpm metadata such as
`pnpm-workspace.yaml`:

```powershell
act -l pull_request `
  -W .github/workflows/admin-web.yml `
  -e .act/pull_request.json

act pull_request `
  -W .github/workflows/admin-web.yml `
  -e .act/pull_request.json
```

The pinned pnpm 11 runtime requires Node 22. All pull-request workflows that
invoke pnpm select Node 22 explicitly.

`.github/workflows/mobile-build.yml` is a push workflow. Its
`macos-latest` cannot run in Windows/Linux act containers and is not part of PR #13's
pull-request simulation. For any unsupported Actions feature, keep the workflow
unchanged, record the exact incompatibility, and run the real equivalent command
through `ci/full-ci.sh`. Use the evidence label
`ACT_UNSUPPORTED_BUT_LOCAL_EQUIVALENT_VERIFIED` only after that equivalent
command succeeds and is recorded. A Windows act run cannot establish an iOS
build result.

## Optional local proxy

The proxy is environment-specific and intentionally absent from `.actrc` and
the event fixture. The host act process reaches it through
`http://127.0.0.1:7890`; job and action containers reach the host through
`http://host.docker.internal:7890`. Do not commit proxy credentials.

```powershell
$env:HTTP_PROXY = 'http://127.0.0.1:7890'
$env:HTTPS_PROXY = 'http://127.0.0.1:7890'
act pull_request `
  -W .github/workflows/ci.yml `
  -e .act/pull_request.json `
  --env HTTP_PROXY=http://host.docker.internal:7890 `
  --env HTTPS_PROXY=http://host.docker.internal:7890 `
  --env NO_PROXY=localhost,127.0.0.1,::1,host.docker.internal
```

Docker image pulls use Docker Desktop's daemon proxy configuration. Cached
`testcontainers/ryuk:0.14.0` and `pgvector/pgvector:pg17` images do not justify
setting `TESTCONTAINERS_RYUK_DISABLED=true`; Ryuk remains enabled. `.actrc` explicitly passes `TESTCONTAINERS_RYUK_DISABLED=false`
to every runner job instead of relying on inherited host state.

## Evidence boundary

For every merge candidate, record command, exit code, test counts, explicit
environmental skips, start/end times, tool versions, exact SHAs, and final
working-tree state. act artifacts are local output under `.act/artifacts/` and
are ignored; inspect and remove them as appropriate before the cleanliness
check. Manual merge review into `Develop` requires the SHA-bound local report
plus the full gate output.

Write candidate evidence to
`docs/superpowers/reports/local-ci-<full-head-sha>.md`. This exact-SHA report
is intentionally ignored: committing the report would change the SHA it names
and make its own identity stale. The full SHA-bound evidence must be copied into the draft PR description
so remote reviewers can audit the local result. The
ignored report is supporting evidence only; it cannot replace command logs,
exact exit codes, or the clean-worktree checks recorded for both environments.
