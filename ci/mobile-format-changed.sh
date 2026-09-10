#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_ref="${MOBILE_FORMAT_BASE_REF:-f8fa0ec}"
baseline_file="$repo_root/ci/mobile-format-baseline.txt"
temporary_dir=''

fail() {
  printf 'mobile-format: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n "$temporary_dir" ]]; then
    rm -rf -- "$temporary_dir"
  fi
  exit "$status"
}

main() {
  cd "$repo_root"
  git rev-parse --verify "${base_ref}^{commit}" >/dev/null \
    || fail "base ref is unavailable: $base_ref"
  [[ -f "$baseline_file" ]] || fail 'formatter baseline is missing'

  mapfile -t changed_dart_files < <(
    git diff --name-only --diff-filter=ACMR "${base_ref}...HEAD" -- '*.dart' |
      awk '/^mobile\//'
  )
  if ((${#changed_dart_files[@]} > 0)); then
    local -a mobile_relative_paths=()
    local file
    for file in "${changed_dart_files[@]}"; do
      if [[ -f "$repo_root/$file" ]]; then
        mobile_relative_paths+=("${file#mobile/}")
      fi
    done
    if ((${#mobile_relative_paths[@]} > 0)); then
      (
        cd mobile
        printf '%s\0' "${mobile_relative_paths[@]}" |
          xargs -0 -n 50 dart format --output=none --set-exit-if-changed
      ) || fail 'Dart files changed since the M1 base are not format-clean'
    fi
  fi

  temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/babytalk-mobile-format.XXXXXX")"
  trap cleanup EXIT
  local -a tracked_dart_files=()
  while IFS= read -r -d '' file; do
    tracked_dart_files+=("$file")
    mkdir -p "${temporary_dir}/$(dirname "$file")"
    cp -- "$file" "${temporary_dir}/$file"
  done < <(find mobile/lib mobile/test mobile/integration_test -type f -name '*.dart' -print0)

  dart format \
    "$temporary_dir/mobile/lib" \
    "$temporary_dir/mobile/test" \
    "$temporary_dir/mobile/integration_test" >/dev/null

  local actual_file="$temporary_dir/unformatted.txt"
  : >"$actual_file"
  for file in "${tracked_dart_files[@]}"; do
    if ! cmp -s -- "$file" "${temporary_dir}/$file"; then
      printf '%s\n' "$file" >>"$actual_file"
    fi
  done
  sort -u -o "$actual_file" "$actual_file"

  local expected_file="$temporary_dir/baseline.txt"
  sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$baseline_file" |
    sort -u >"$expected_file"

  local mismatch_file="$temporary_dir/baseline-mismatch.txt"
  comm -3 "$expected_file" "$actual_file" >"$mismatch_file"
  if [[ -s "$mismatch_file" ]]; then
    printf '%s\n' 'mobile-format: checked-in baseline must exactly match current formatter debt:' >&2
    cat "$mismatch_file" >&2
    exit 1
  fi

  local base_baseline_file="$temporary_dir/base-baseline.txt"
  if git cat-file -e "${base_ref}:ci/mobile-format-baseline.txt" 2>/dev/null; then
    git show "${base_ref}:ci/mobile-format-baseline.txt" |
      sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' |
      sort -u >"$base_baseline_file"
    local additions_file="$temporary_dir/baseline-additions.txt"
    comm -13 "$base_baseline_file" "$expected_file" >"$additions_file"
    if [[ -s "$additions_file" ]]; then
      printf '%s\n' 'mobile-format: formatter baseline may only shrink:' >&2
      cat "$additions_file" >&2
      exit 1
    fi
  fi

  printf 'mobile-format: changed Dart files are clean; historical baseline=%s current=%s\n' \
    "$(wc -l <"$expected_file" | tr -d ' ')" \
    "$(wc -l <"$actual_file" | tr -d ' ')"
}

main "$@"
