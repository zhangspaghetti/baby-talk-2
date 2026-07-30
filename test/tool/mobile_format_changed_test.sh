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
  )
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
  )
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
  )
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

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/babytalk-mobile-format-test.XXXXXX")"
trap cleanup EXIT

test_baseline_must_equal_actual_debt
test_baseline_cannot_expand_after_base
test_many_changed_dart_files_are_checked_in_bounded_batches
test_many_changed_dart_files_still_reject_unformatted_source
printf '%s\n' 'mobile-format-test: pass'
