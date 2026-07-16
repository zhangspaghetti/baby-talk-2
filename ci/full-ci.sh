#!/usr/bin/env bash
set -euo pipefail

repo_root=''
ci_runtime_dir=''
empty_kubeconfig=''
dependency_tree=''
relay_container_id=''

fail() {
  printf 'full-ci: %s\n' "$*" >&2
  exit 1
}

stage() {
  printf 'gate=%s command=%s\n' "$1" "$2"
}

sanitize_environment() {
  local env_name

  # Repository prefixes can bind arbitrary endpoints, profiles, provider modes, or secrets.
  for env_name in ${!BABY_TALK_@}; do
    unset "$env_name"
  done

  # Spring environment binding is intentionally closed; fixtures/system properties reopen it.
  for env_name in ${!SPRING_@}; do
    unset "$env_name"
  done

  # Maven wrapper credentials are prefix-based and must not reach Maven children.
  for env_name in ${!MVNW_@}; do
    unset "$env_name"
  done

  # Generic service and tool prefixes can bypass repository-specific property names.
  for env_name in ${!DB_@} ${!MINIO_@} ${!JWT_@} ${!KUBE_@} \
    ${!KUBERNETES_@} ${!HELM_@} ${!TESTCONTAINERS_@}; do
    unset "$env_name"
  done

  # Exact injection and credential channels outside repository-owned prefixes.
  unset \
    SSY_API_KEY \
    OPENAI_API_KEY \
    ANTHROPIC_API_KEY \
    AZURE_OPENAI_API_KEY \
    GOOGLE_API_KEY \
    MISTRAL_AI_API_KEY \
    OPENAI_BASE_URL \
    ANTHROPIC_BASE_URL \
    AZURE_OPENAI_ENDPOINT \
    SPRING_APPLICATION_JSON \
    DATABASE_URL \
    JDBC_DATABASE_URL \
    JDBC_URL \
    REDIS_URL \
    REDIS_HOST \
    REDIS_PORT \
    REDIS_PASSWORD \
    PGPASSWORD \
    PGPASSFILE \
    PGSERVICE \
    PGSERVICEFILE \
    PGHOST \
    PGHOSTADDR \
    PGPORT \
    PGDATABASE \
    PGUSER \
    PGOPTIONS \
    JAVA_TOOL_OPTIONS \
    _JAVA_OPTIONS \
    JDK_JAVA_OPTIONS \
    MAVEN_OPTS \
    MAVEN_ARGS \
    MAVEN_USER_HOME \
    MAVEN_EXT_CLASS_PATH \
    M2_HOME \
    CLASSPATH \
    KUBECONFIG \
    KUBE_TOKEN \
    KUBERNETES_SERVICE_HOST \
    KUBERNETES_SERVICE_PORT \
    HELM_REGISTRY_CONFIG \
    HELM_REPOSITORY_CONFIG \
    ADMIN_ACCESS_TOKEN \
    ADMIN_PASSWORD \
    GITHUB_TOKEN \
    GH_TOKEN \
    NPM_TOKEN \
    CODECOV_TOKEN \
    AWS_ACCESS_KEY_ID \
    AWS_SECRET_ACCESS_KEY \
    AWS_SESSION_TOKEN \
    AWS_PROFILE \
    AWS_SHARED_CREDENTIALS_FILE \
    GOOGLE_APPLICATION_CREDENTIALS \
    AZURE_CLIENT_SECRET \
    DOCKER_AUTH_CONFIG \
    DOCKER_HOST \
    DOCKER_CONTEXT \
    DOCKER_TLS_VERIFY \
    DOCKER_CERT_PATH \
    REGISTRY_AUTH_FILE \
    TESTCONTAINERS_RYUK_DISABLED

  # Testcontainers must see an explicit safe value, even when host config disables Ryuk.
  export TESTCONTAINERS_RYUK_DISABLED=false
}

cleanup() {
  local status=$?
  local cleanup_failed=0
  trap - EXIT

  if [[ -n "$relay_container_id" ]]; then
    if ! docker rm -f "$relay_container_id" >/dev/null 2>&1; then
      cleanup_failed=1
    fi
  fi
  if [[ -n "$dependency_tree" ]] && \
    ! rm -f -- "$dependency_tree" >/dev/null 2>&1; then
    cleanup_failed=1
  fi
  if [[ -n "$empty_kubeconfig" ]] && \
    ! rm -f -- "$empty_kubeconfig" >/dev/null 2>&1; then
    cleanup_failed=1
  fi
  if [[ -n "$ci_runtime_dir" ]] && \
    ! rmdir -- "$ci_runtime_dir" >/dev/null 2>&1; then
    cleanup_failed=1
  fi

  if [[ "$cleanup_failed" -ne 0 ]]; then
    printf 'full-ci: failed to clean owned runtime resources\n' >&2
    if [[ "$status" -eq 0 ]]; then
      status=1
    fi
  fi
  exit "$status"
}

initialize_ci_environment() {
  sanitize_environment

  ci_runtime_dir="$(mktemp -d "${TMPDIR:-/tmp}/babytalk-full-ci.XXXXXX")"
  empty_kubeconfig="${ci_runtime_dir}/kubeconfig"
  dependency_tree="${ci_runtime_dir}/spring-ai-dependency-tree.txt"
  trap cleanup EXIT

  printf '%s\n' \
    'apiVersion: v1' \
    'kind: Config' \
    'clusters: []' \
    'contexts: []' \
    'current-context: ""' \
    'users: []' >"$empty_kubeconfig"

  if command -v cygpath >/dev/null 2>&1; then
    export KUBECONFIG="$(cygpath -w "$empty_kubeconfig")"
  else
    export KUBECONFIG="$empty_kubeconfig"
  fi
}

main() {
  initialize_ci_environment
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "$repo_root"

  initial_status="$(git status --porcelain=v1 --untracked-files=all)"
  [[ -z "$initial_status" ]] || fail 'worktree must be clean before local full CI starts'

  stage 'fetch-target' 'git fetch --no-tags origin Develop'
  git fetch --no-tags origin Develop
  HEAD_SHA="$(git rev-parse --verify 'HEAD^{commit}')"
  ORIGIN_DEVELOP_SHA="$(git rev-parse --verify 'refs/remotes/origin/Develop^{commit}')"
  MERGE_BASE_SHA="$(git merge-base "$HEAD_SHA" "$ORIGIN_DEVELOP_SHA")"
  [[ -n "$MERGE_BASE_SHA" ]] || fail 'HEAD and origin/Develop have no merge base'

  stage 'docker-preflight' 'docker info (Linux containers and tcp://localhost:2375)'
  command -v docker >/dev/null 2>&1 || fail 'docker is required'
  docker_os="$(docker info --format '{{.OSType}}')"
  [[ "$docker_os" == 'linux' ]] || fail "Docker must use Linux containers; found ${docker_os}"

  if ! docker --host tcp://localhost:2375 info >/dev/null 2>&1; then
    relay_name="babytalk-full-ci-relay-${$}-${RANDOM}"
    relay_container_id="$(
      docker run -d --name "$relay_name" -p 2375:2375 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        alpine/socat@sha256:d85531a29ef5ba99dfb4717485c239307e2902d522a1bc010992a2728c92cfad \
        TCP-LISTEN:2375,fork,reuseaddr UNIX-CONNECT:/var/run/docker.sock
    )"

    relay_ready=0
    for _ in {1..20}; do
      if docker --host tcp://localhost:2375 info >/dev/null 2>&1; then
        relay_ready=1
        break
      fi
      sleep 1
    done
    [[ "$relay_ready" == '1' ]] || fail 'owned Docker relay did not become ready within 20 seconds'
  fi

  stage 'spring-ai-fixture' 'python3 test/tool/verify_spring_ai_2_backend_platform_test.py'
  python3 test/tool/verify_spring_ai_2_backend_platform_test.py

  stage 'spring-ai-live' 'python3 tool/verify_spring_ai_2_backend_platform.py'
  python3 tool/verify_spring_ai_2_backend_platform.py

  stage 'spring-ai-dependency-tree' 'backend/mvnw dependency:tree (Spring AI only)'
  backend/mvnw -f backend/pom.xml -B -Dstyle.color=never \
    dependency:tree '-Dincludes=org.springframework.ai:*' | tee "$dependency_tree"

  stage 'spring-ai-resolved' 'python3 tool/verify_spring_ai_2_backend_platform.py --dependency-tree <owned-temp>'
  python3 tool/verify_spring_ai_2_backend_platform.py --dependency-tree "$dependency_tree"

  stage 'backend-reactor' 'bash ci/backend-test.sh'
  bash ci/backend-test.sh

  stage 'growth-mapper-postgres' 'backend/mvnw -pl app-api -am -Dtest=GrowthServiceMapperIntegrationTest test'
  backend/mvnw -f backend/pom.xml -B -pl app-api -am \
    -Dtest=GrowthServiceMapperIntegrationTest \
    '-Dsurefire.failIfNoSpecifiedTests=false' test

  stage 'backend-checkstyle' 'backend/mvnw checkstyle:check'
  backend/mvnw -f backend/pom.xml -B checkstyle:check

  stage 'helm-smoke' 'bash ci/k8s-smoke.sh'
  bash ci/k8s-smoke.sh

  stage 'mobile-analyze' 'bash ci/mobile-analyze.sh'
  bash ci/mobile-analyze.sh

  stage 'mobile-r4' 'bash ci/mobile-r4-release-gates.sh'
  bash ci/mobile-r4-release-gates.sh

  stage 'release-fixtures' 'flutter test M006/S01/schema fixtures'
  flutter test \
    test/tool/verify_m006_s14_release_closure_test.dart \
    test/tool/verify_m007_schema_compatibility_test.dart \
    test/tool/verify_m007_s01_helm_baseline_test.dart

  stage 'm007-s02' 'dart run tool/verify_m007_s02_release_boundaries.dart'
  dart run tool/verify_m007_s02_release_boundaries.dart

  stage 'm007-s06' 'dart run tool/verify_m007_s06_docs_coherence.dart'
  dart run tool/verify_m007_s06_docs_coherence.dart

  stage 'diff-check' 'git diff --check <merge-base>..<HEAD>'
  git diff --check "${MERGE_BASE_SHA}..${HEAD_SHA}"

  stage 'final-cleanliness' 'git status --porcelain=v1 --untracked-files=all'
  final_status="$(git status --porcelain=v1 --untracked-files=all)"
  [[ -z "$final_status" ]] || fail 'worktree changed while local full CI was running'

  printf '%s\n' \
    'target_branch=Develop' \
    "commit=${HEAD_SHA}" \
    "origin_develop=${ORIGIN_DEVELOP_SHA}" \
    "merge_base=${MERGE_BASE_SHA}" \
    'full local CI passed'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
