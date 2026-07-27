#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
temporary_root=''

fail() {
  printf 'mobile-format-test: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n "$temporary_root" ]]; then
    rm -rf -- "$temporary_root"
  fi
  exit "$status"
}

make_fixture() {
  local name="$1"
  local fixture="$temporary_root/$name"
  mkdir -p "$fixture/ci" "$fixture/mobile/lib" "$fixture/mobile/test" \
    "$fixture/mobile/integration_test" "$fixture/bin"
  cp "$repo_root/ci/mobile-format-changed.sh" "$fixture/ci/"
  printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
    'for argument in "$@"; do' \
    '  if [[ -d "$argument" ]]; then' \
    "    find \"\$argument\" -type f -name '*.dart' -exec sed -i 's/unformatted/formatted/g' {} +" \
    '  fi' \
    'done' >"$fixture/bin/dart"
  chmod +x "$fixture/bin/dart"
  (
    cd "$fixture"
    git init -q
    git config user.email 'format-gate@example.test'
    git config user.name 'format gate test'
  )
  printf '%s' "$fixture"
}

expect_failure() {
  local fixture="$1"
  local base_ref="$2"
  if (
    cd "$fixture"
    PATH="$fixture/bin:$PATH" MOBILE_FORMAT_BASE_REF="$base_ref" \
      bash ci/mobile-format-changed.sh >/dev/null 2>&1
  ); then
    fail "expected formatter gate failure in $fixture"
  fi
}

test_baseline_must_equal_actual_debt() {
  local fixture
  fixture="$(make_fixture exact)"
  printf '%s\n' 'void main() {}' >"$fixture/mobile/lib/foo.dart"
  printf '%s\n' 'mobile/lib/foo.dart' >"$fixture/ci/mobile-format-baseline.txt"
  (
    cd "$fixture"
    git add .
    git commit -qm 'fixture baseline contains repaired file'
  )

  expect_failure "$fixture" HEAD
}

test_baseline_cannot_expand_after_base() {
  local fixture
  fixture="$(make_fixture monotonic)"
  : >"$fixture/ci/mobile-format-baseline.txt"
  (
    cd "$fixture"
    git add .
    git commit -qm 'fixture base baseline'
  )
  printf '%s\n' 'void main() { /* unformatted */ }' >"$fixture/mobile/lib/foo.dart"
  printf '%s\n' 'mobile/lib/foo.dart' >"$fixture/ci/mobile-format-baseline.txt"
  (
    cd "$fixture"
    git add .
    git commit -qm 'fixture expands baseline'
  )

  expect_failure "$fixture" HEAD~1
}

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/babytalk-mobile-format-test.XXXXXX")"
trap cleanup EXIT

test_baseline_must_equal_actual_debt
test_baseline_cannot_expand_after_base
printf '%s\n' 'mobile-format-test: pass'
