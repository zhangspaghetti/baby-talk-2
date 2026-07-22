# Local CI

Target branch: `Develop`

`bash ci/full-ci.sh` is the only complete local repository CI entrypoint. It
executes the repository gates directly and fails closed. Run it from a clean
checkout after fetching the current target:

```bash
git fetch origin Develop
bash ci/full-ci.sh
```

The fixed gate order covers the Spring AI verifier fixtures, live verifier, and
resolved dependency graph; the six-module backend reactor; Maven Checkstyle;
the Helm smoke; admin-web typecheck, lint, format, unit coverage, P0 E2E, and build;
mobile analyze, full test suite, and R4 release gates; release/docs/schema/M006
gates; then diff and final-cleanliness checks. A gate that fails stops the run;
an environment-specific skip is not a pass.

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
default branch. Testcontainers resolves Docker-published ports through
`TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal`, while Ryuk remains enabled.
`PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT=180000` tolerates slow local browser
downloads without skipping Playwright installation. Do not add production
secrets, tokens, database passwords, JWT keys, Kubernetes secrets, or real user
data to act invocations or event files.

The CI workflow pins Helm `v4.1.4`, matching the audited local toolchain. Do not
replace this with the setup action's floating latest resolution.

## Package download sources

The repository pins public China mirrors only for package ecosystems whose
artifacts remain version-locked and integrity-checked by their native tools.
`ci/download-sources.sh` is sourced by local full CI and mobile gates; workflow
environment values make the same source selection when those definitions are
simulated through act.

| Layer | CI download | Source |
| --- | --- | --- |
| pnpm/npm and first Corepack pnpm resolution | `pnpm install --frozen-lockfile`, `corepack enable` | `.npmrc`, `NPM_CONFIG_REGISTRY`, and `COREPACK_NPM_REGISTRY` use `https://mirrors.cloud.tencent.com/npm/`. `pnpm-lock.yaml` keeps package integrity and no registry-specific tarball URL. |
| Playwright | `playwright install chromium` | `PLAYWRIGHT_DOWNLOAD_HOST=https://npmmirror.com/mirrors/playwright`. Chromium and Chromium headless shell are separate required artifacts; full CI installs once, while isolated act jobs may each need their own cache. |
| Maven | Maven Wrapper and dependency/plugin resolution | Wrapper distribution remains on Aliyun. `ci/maven.sh` and `backend/.mvn/settings.xml` mirror only Maven Central through `https://maven.aliyun.com/repository/central`; they do not redirect arbitrary repositories. |
| Flutter/Dart Pub | `flutter pub get` and Flutter SDK assets | `PUB_HOSTED_URL=https://pub.flutter-io.cn` and `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`. Pub locks retain archive hashes. |
| Android Gradle | Android build workflows | Gradle Wrapper already uses Tencent's Gradle mirror; Android repositories keep Aliyun first, then official fallbacks for artifacts unavailable from a mirror. |
| Helm smoke | `bash ci/k8s-smoke.sh` | No chart download: Redis chart is vendored and smoke does not run `helm dependency update`. |

Docker images, the act runner image, GitHub Actions source, and setup-action SDK downloads are not redirected to public mirrors.
They stay on their pinned upstream/digest source or Docker Desktop configuration;
replace them only with a trusted, digest-preserving internal mirror. Do not use a
generic proxy URL in repository configuration, and do not commit proxy credentials.

The tracked event fixture is a draft PR #13 template for `Develop`. It omits
both `pull_request.base.sha` and `pull_request.head.sha`; the wrapper resolves
fresh `origin/Develop`, checked-out HEAD, and merge-base SHAs before every run.
SHA-bound runtime evidence records all three values.

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

## Run the pre-merge PR simulation

`.act/pull_request.json` is a credential-free template, not a reusable event:
it deliberately contains no fixed base or head SHA. Run the wrapper instead of
calling `act` with that template directly:

```powershell
bash ci/run-act-pr.sh
```

The wrapper rejects a dirty worktree before fetching `origin/Develop`, resolves
the checked-out HEAD and actual merge-base, writes a private temporary event,
lists `local-pr-full-ci`, then executes it with act's bind mount. The job
requires the bound `.git` directory and verifies its `HEAD` equals the event's
recorded full SHA before it calls `bash ci/full-ci.sh`, the authoritative
complete local repository CI entrypoint. The wrapper captures stdout and
stderr, and fails if the selected job is skipped or does not report success; a
listed job alone is not evidence.

On Windows, the bind job applies `core.autocrlf=true` only to its Git commands,
matching the checked-out file representation without changing `.git/config`.
The repository ignores local `.gstack/` state explicitly, so both host and
container enforce the same clean-worktree contract. The local-only workflow
installs the same JDK 21, Node 22, Helm 4.1.4, and stable Flutter runtimes that
the applicable repository workflows require before calling the shared script.

`.github/workflows/ci.yml` and `admin-web.yml` are `Develop -> Release_QA`
post-merge workflows. They are not PR #13 pre-merge simulation and must not be
used as its act evidence. The dedicated
`.act/workflows/local-act-pr.yml` is local-only (not discoverable by GitHub
Actions), models `pull_request -> Develop`, and reuses the same full-CI script.

The pinned pnpm 11 runtime requires Node 22. All workflows that invoke pnpm
select Node 22 explicitly.

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
bash ci/run-act-pr.sh `
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
