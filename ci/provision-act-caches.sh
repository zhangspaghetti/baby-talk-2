#!/usr/bin/env bash
set -euo pipefail

cache_layout_version='v1'

fail() {
  printf 'provision-act-caches: %s\n' "$*" >&2
  exit 1
}

default_cache_root() {
  local cache_root
  if command -v cygpath >/dev/null 2>&1 && [[ -n "${LOCALAPPDATA:-}" ]]; then
    cache_root="$(cygpath -u "$LOCALAPPDATA")/BabyTalk/act/cache-${cache_layout_version}"
  else
    cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/babytalk/act/cache-${cache_layout_version}"
  fi
  printf '%s\n' "$cache_root"
}

validate_cache() {
  local cache_root="$1"
  local metadata="$cache_root/.babytalk-act-cache.json"
  local cache_directory

  [[ -f "$metadata" ]] || return 1
  python3 - "$metadata" "$cache_layout_version" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if metadata != {"layout_version": sys.argv[2]}:
    raise SystemExit(1)
PY
  for cache_directory in m2 pub-cache playwright pnpm-store pnpm-home corepack; do
    [[ -d "$cache_root/$cache_directory" ]] || return 1
  done
}

main() {
  local cache_root cache_directory
  cache_root="${ACT_LOCAL_CACHE_ROOT:-$(default_cache_root)}"

  if validate_cache "$cache_root"; then
    printf 'act host caches are ready: %s\n' "$cache_root"
    return
  fi
  [[ ! -e "$cache_root" ]] || fail "invalid existing cache root: $cache_root; remove that exact cache root and retry"

  umask 077
  mkdir -p "$cache_root"
  for cache_directory in m2 pub-cache playwright pnpm-store pnpm-home corepack; do
    mkdir -p "$cache_root/$cache_directory"
  done
  python3 - "$cache_root/.babytalk-act-cache.json" "$cache_layout_version" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(
    json.dumps({"layout_version": sys.argv[2]}, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  printf 'provisioned act host caches: %s\n' "$cache_root"
}

main "$@"
