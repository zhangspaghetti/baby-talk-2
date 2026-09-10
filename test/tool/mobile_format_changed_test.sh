#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
temporary_root=''
trusted_temp_base='/tmp'
canonical_repo_root=''
canonical_temp_base=''

git_local_env_vars="$(git -C "$repo_root" rev-parse --local-env-vars)"
while IFS= read -r git_local_env_var; do
  if [[ -n "$git_local_env_var" ]]; then
    unset "$git_local_env_var"
  fi
done <<<"$git_local_env_vars"

parent_head_before="$(git -C "$repo_root" rev-parse HEAD)"
parent_config_before="$(git -C "$repo_root" config --local --list | sha256sum | awk '{print $1}')"
parent_index_path="$(git -C "$repo_root" rev-parse --git-path index)"
parent_status_before="$(git -C "$repo_root" status --porcelain=v1 --untracked-files=all)"
parent_index_before="$(git -C "$repo_root" hash-object -- "$parent_index_path")"

fail() {
  printf 'mobile-format-test: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n "$temporary_root" ]]; then
    verify_temporary_root_is_safe
    rm -rf -- "$temporary_root"
  fi
  assert_parent_repository_unchanged
  exit "$status"
}

verify_temporary_root_is_safe() {
  local canonical_temporary_root
  [[ -n "$temporary_root" ]] || return 0
  [[ -d "$temporary_root" ]] \
    || fail "temporary root is missing: $temporary_root"
  canonical_temporary_root="$(cd "$temporary_root" && pwd -P)" \
    || fail "cannot canonicalize temporary root: $temporary_root"
  case "$canonical_temp_base/" in
    "$canonical_repo_root/"*)
      fail "trusted temporary base overlaps repository: $canonical_temp_base"
      ;;
  esac
  case "$canonical_temporary_root/" in
    "$canonical_repo_root/"*)
      fail "temporary root overlaps repository: $canonical_temporary_root"
      ;;
  esac
  case "$canonical_temporary_root/" in
    "$canonical_temp_base/"*) ;;
    *)
      fail "temporary root escaped trusted base: $canonical_temporary_root"
      ;;
  esac
}

make_fixture() {
  local name="$1"
  local fixture="$temporary_root/$name"
  mkdir -p "$fixture/ci" "$fixture/mobile/lib" "$fixture/mobile/test" \
    "$fixture/mobile/integration_test" "$fixture/bin"
  cp "$repo_root/ci/mobile-format-changed.sh" "$fixture/ci/"
  printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
    'check_changed_files=false' \
    'file_args=()' \
    'for argument in "$@"; do' \
    '  if [[ "$argument" == "--set-exit-if-changed" ]]; then' \
    '    check_changed_files=true' \
    '  fi' \
    '  if [[ -f "$argument" ]]; then' \
    '    file_args+=("$argument")' \
    '  fi' \
    'done' \
    'file_count=${#file_args[@]}' \
    'if [[ "$check_changed_files" == "true" && -n "${DART_MAX_FILE_ARGS:-}" && "$file_count" -gt "$DART_MAX_FILE_ARGS" ]]; then' \
    "  printf '%s\\n' 'dart-format-stub: command line too long' >&2" \
    '  exit 64' \
    'fi' \
    'if [[ "$check_changed_files" == "true" ]]; then' \
    '  if ((file_count > 0)) && grep -Fxl "void main() { /* unformatted */ }" -- "${file_args[@]}" >/dev/null; then' \
    "      printf '%s\\n' 'dart-format-stub: unformatted changed Dart file' >&2" \
    '      exit 1' \
    '  fi' \
    '  exit 0' \
    'fi' \
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
    git config core.autocrlf false
  )
  assert_parent_repository_unchanged
  printf '%s' "$fixture"
}

commit_fixture() {
  local fixture="$1"
  local message="$2"
  (
    cd "$fixture"
    git add .
    git commit -qm "$message"
    git rev-parse --verify HEAD >/dev/null
  )
  assert_parent_repository_unchanged
}

expect_failure() {
  local fixture="$1"
  local base_ref="$2"
  local output_file="$3"
  local expected_message="${4:-}"
  if (
    cd "$fixture"
    PATH="$fixture/bin:$PATH" MOBILE_FORMAT_BASE_REF="$base_ref" \
      bash ci/mobile-format-changed.sh
  ); then
    fail "expected formatter gate failure in $fixture"
  fi >"$output_file" 2>&1
  if [[ -n "$expected_message" ]]; then
    grep -Fq "$expected_message" "$output_file" \
      || fail "formatter gate failure did not mention: $expected_message"
  fi
  assert_parent_repository_unchanged
}

assert_parent_repository_unchanged() {
  local parent_head_after
  local parent_config_after
  local parent_index_after
  local parent_status_after
  parent_head_after="$(git -C "$repo_root" rev-parse HEAD)"
  parent_config_after="$(git -C "$repo_root" config --local --list | sha256sum | awk '{print $1}')"
  parent_index_after="$(git -C "$repo_root" hash-object -- "$parent_index_path")"
  parent_status_after="$(git -C "$repo_root" status --porcelain=v1 --untracked-files=all)"
  [[ "$parent_head_after" == "$parent_head_before" ]] \
    || fail "parent HEAD changed: before=$parent_head_before after=$parent_head_after"
  [[ "$parent_config_after" == "$parent_config_before" ]] \
    || fail 'parent Git config changed during fixture setup'
  [[ "$parent_index_after" == "$parent_index_before" ]] \
    || fail 'parent Git index changed during fixture setup'
  [[ "$parent_status_after" == "$parent_status_before" ]] \
    || fail 'parent worktree status changed during fixture setup'
}

test_fixture_git_operations_preserve_parent_repository() {
  local fixture
  fixture="$(make_fixture inherited_git_env)"
  : >"$fixture/ci/mobile-format-baseline.txt"
  commit_fixture "$fixture" 'fixture setup under inherited Git environment'
}

test_baseline_must_equal_actual_debt() {
  local fixture
  fixture="$(make_fixture exact)"
  printf '%s\n' 'void main() {}' >"$fixture/mobile/lib/foo.dart"
  printf '%s\n' 'mobile/lib/foo.dart' >"$fixture/ci/mobile-format-baseline.txt"
  commit_fixture "$fixture" 'fixture baseline contains repaired file'

  expect_failure "$fixture" HEAD "$temporary_root/exact.out"
}

test_baseline_cannot_expand_after_base() {
  local fixture
  fixture="$(make_fixture monotonic)"
  printf '%s\n' 'void main() { /* unformatted */ }' >"$fixture/mobile/lib/foo.dart"
  printf '%s\n' 'void main() { /* unformatted */ }' >"$fixture/mobile/lib/bar.dart"
  printf '%s\n' 'mobile/lib/foo.dart' >"$fixture/ci/mobile-format-baseline.txt"
  commit_fixture "$fixture" 'fixture base baseline contains one debt file'
  printf '%s\n' 'void main() { /* unformatted */ }' >"$fixture/mobile/lib/foo.dart"
  printf '%s\n' 'mobile/lib/foo.dart' 'mobile/lib/bar.dart' \
    >"$fixture/ci/mobile-format-baseline.txt"
  commit_fixture "$fixture" 'fixture expands baseline'

  local output_file="$temporary_root/monotonic.out"
  expect_failure "$fixture" HEAD~1 "$output_file" \
    'mobile-format: formatter baseline may only shrink:'
  if grep -Fq 'dart-format-stub: unformatted changed Dart file' "$output_file"; then
    fail 'monotonic baseline fixture failed from changed-Dart formatting instead of baseline expansion'
  fi
}

write_many_changed_dart_files() {
  local fixture="$1"
  local count="$2"
  local unformatted_index="${3:-0}"
  local index
  local file
  local source='void main() {}'
  mkdir -p "$fixture/mobile/lib/format_batch"
  for ((index = 1; index <= count; index += 1)); do
    printf -v file \
      'mobile/lib/format_batch/format_batch_with_a_long_path_component_for_command_length_%04d_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.dart' \
      "$index"
    if [[ "$index" == "$unformatted_index" ]]; then
      source='void main() { /* unformatted */ }'
    else
      source='void main() {}'
    fi
    printf '%s\n' "$source" >"$fixture/$file"
  done
  (
    cd "$fixture"
    git add mobile/lib
    git commit -qm 'fixture adds many changed Dart files'
    git rev-parse --verify HEAD >/dev/null
  )
  assert_parent_repository_unchanged
}

run_large_changed_file_gate() {
  local fixture="$1"
  local base_ref="$2"
  local output_file="$3"
  (
    cd "$fixture"
    PATH="$fixture/bin:$PATH" MOBILE_FORMAT_BASE_REF="$base_ref" \
      DART_MAX_FILE_ARGS=50 bash ci/mobile-format-changed.sh
  ) >"$output_file" 2>&1
}

test_many_changed_dart_files_are_checked_in_bounded_batches() {
  local fixture
  local output_file
  fixture="$(make_fixture bounded_batches)"
  : >"$fixture/ci/mobile-format-baseline.txt"
  (
    cd "$fixture"
    git add .
    git commit -qm 'fixture base with empty baseline'
    git rev-parse --verify HEAD >/dev/null
  )
  assert_parent_repository_unchanged
  write_many_changed_dart_files "$fixture" 320
  output_file="$temporary_root/bounded-batches.out"

  if ! run_large_changed_file_gate "$fixture" HEAD~1 "$output_file"; then
    fail 'many changed Dart files should not exceed formatter command length'
  fi
  if grep -Fq 'dart-format-stub: command line too long' "$output_file"; then
    fail 'formatter expanded many changed Dart files into one command'
  fi
}

test_many_changed_dart_files_still_reject_unformatted_source() {
  local fixture
  local output_file
  fixture="$(make_fixture bounded_unformatted)"
  : >"$fixture/ci/mobile-format-baseline.txt"
  (
    cd "$fixture"
    git add .
    git commit -qm 'fixture base with empty baseline'
    git rev-parse --verify HEAD >/dev/null
  )
  assert_parent_repository_unchanged
  write_many_changed_dart_files "$fixture" 320 320
  output_file="$temporary_root/bounded-unformatted.out"

  if run_large_changed_file_gate "$fixture" HEAD~1 "$output_file"; then
    fail 'unformatted changed Dart source should fail formatter gate'
  fi
  grep -Fq 'dart-format-stub: unformatted changed Dart file' "$output_file" \
    || fail 'formatter gate did not check the unformatted changed Dart file'
  if grep -Fq 'dart-format-stub: command line too long' "$output_file"; then
    fail 'unformatted fixture failed from command length instead of formatting'
  fi
}

canonical_repo_root="$(cd "$repo_root" && pwd -P)"
canonical_temp_base="$(cd "$trusted_temp_base" && pwd -P)"
temporary_root="$(mktemp -d "$canonical_temp_base/babytalk-mobile-format-test.XXXXXX")"
verify_temporary_root_is_safe
trap cleanup EXIT

test_fixture_git_operations_preserve_parent_repository
test_baseline_must_equal_actual_debt
test_baseline_cannot_expand_after_base
test_many_changed_dart_files_are_checked_in_bounded_batches
test_many_changed_dart_files_still_reject_unformatted_source
assert_parent_repository_unchanged
printf '%s\n' 'mobile-format-test: pass'
