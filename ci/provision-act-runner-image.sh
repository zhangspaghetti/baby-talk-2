#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner_image='babytalk/act-runner:ubuntu-24.04-playwright-1'
runner_base_image='ghcr.io/catthehacker/ubuntu:act-24.04@sha256:5d6a17640b25694988b9db5a4145537b9918e5430116b2cf90d84e837609b382'
dockerfile="$repo_root/ci/act-runner/Dockerfile"

fail() {
  printf 'provision-act-runner-image: %s\n' "$*" >&2
  exit 1
}

verify_image() {
  local expected_recipe_sha256="$1"
  local labels

  labels="$(docker image inspect --format '{{ index .Config.Labels "org.babytalk.act.base-image" }}|{{ index .Config.Labels "org.babytalk.act.recipe-sha256" }}|{{ index .Config.Labels "org.babytalk.act.playwright-system-deps" }}' "$runner_image" 2>/dev/null || true)"
  [[ "$labels" == "${runner_base_image}|${expected_recipe_sha256}|chromium-ubuntu24.04-x64" ]]
}

verify_runtime_dependencies() {
  docker run --rm --entrypoint bash "$runner_image" -lc '
    test "$BABYTALK_ACT_PLAYWRIGHT_SYSTEM_DEPS" = chromium-ubuntu24.04-x64
    for package in libasound2t64 libnss3 libxkbcommon0 xvfb fonts-noto-color-emoji; do
      dpkg-query --show --showformat="\${db:Status-Status}" "$package" | grep -Fxq "installed"
    done
  '
}

main() {
  local recipe_sha256
  command -v docker >/dev/null 2>&1 || fail 'docker is required'
  [[ -f "$dockerfile" ]] || fail "runner Dockerfile is missing: $dockerfile"
  recipe_sha256="$(sha256sum "$dockerfile" | awk '{print $1}')"

  if verify_image "$recipe_sha256"; then
    verify_runtime_dependencies
    printf 'act runner image is ready: %s\n' "$runner_image"
    return
  fi

  docker build \
    --file "$dockerfile" \
    --build-arg "ACT_RUNNER_BASE_IMAGE=$runner_base_image" \
    --build-arg "ACT_RUNNER_RECIPE_SHA256=$recipe_sha256" \
    --tag "$runner_image" \
    "$repo_root"
  verify_image "$recipe_sha256" || fail 'built runner image metadata does not match the pinned recipe'
  verify_runtime_dependencies || fail 'built runner image is missing Playwright system dependencies'
  printf 'provisioned act runner image: %s\n' "$runner_image"
}

main "$@"
