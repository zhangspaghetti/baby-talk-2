#!/usr/bin/env bash
set -euo pipefail

flutter_version='3.41.6'
flutter_storage_base_url="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"

fail() {
  printf 'provision-act-flutter-sdk: %s\n' "$*" >&2
  exit 1
}

default_sdk_dir() {
  local cache_root
  if command -v cygpath >/dev/null 2>&1 && [[ -n "${LOCALAPPDATA:-}" ]]; then
    cache_root="$(cygpath -u "$LOCALAPPDATA")/BabyTalk/act/flutter"
  else
    cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/babytalk/act/flutter"
  fi
  printf '%s/flutter-%s-linux/flutter\n' "$cache_root" "$flutter_version"
}

validate_sdk() {
  local sdk_dir="$1"
  local metadata="$sdk_dir/.babytalk-act-flutter.json"
  [[ -x "$sdk_dir/bin/flutter" ]] || return 1
  [[ -f "$metadata" ]] || return 1
  python3 - "$metadata" "$flutter_version" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if metadata != {
    "platform": "linux-x64",
    "version": sys.argv[2],
    "archive_sha256": metadata.get("archive_sha256"),
}:
    raise SystemExit(1)
if not isinstance(metadata["archive_sha256"], str) or len(metadata["archive_sha256"]) != 64:
    raise SystemExit(1)
PY
}

main() {
  local sdk_dir metadata_parent work_dir releases archive archive_path archive_sha256
  sdk_dir="${ACT_FLUTTER_LINUX_SDK:-$(default_sdk_dir)}"

  if validate_sdk "$sdk_dir"; then
    printf 'act Flutter Linux SDK is ready: %s\n' "$sdk_dir"
    return
  fi
  [[ ! -e "$sdk_dir" ]] || fail "invalid existing SDK cache: $sdk_dir; remove that exact cache directory and retry"

  metadata_parent="$(dirname "$sdk_dir")"
  mkdir -p "$metadata_parent"
  work_dir="$(mktemp -d "$metadata_parent/.flutter-download.XXXXXX")"
  trap 'rm -rf -- "$work_dir"' EXIT
  releases="$work_dir/releases_linux.json"
  archive="$work_dir/flutter_linux_${flutter_version}_stable.tar.xz"

  curl --fail --location --retry 5 --connect-timeout 15 \
    "$flutter_storage_base_url/flutter_infra_release/releases/releases_linux.json" \
    -o "$releases"
  readarray -t release_fields < <(python3 - "$releases" "$flutter_version" <<'PY'
import json
import sys
from pathlib import Path

releases = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["releases"]
match = next((entry for entry in releases if entry.get("version") == sys.argv[2]), None)
if match is None:
    raise SystemExit(f"Flutter {sys.argv[2]} is absent from releases_linux.json")
print(match["archive"])
print(match["hash"])
PY
)
  [[ "${#release_fields[@]}" -eq 2 ]] || fail 'could not resolve the pinned Flutter archive'
  archive_path="${release_fields[0]}"
  archive_sha256="${release_fields[1]}"

  curl --fail --location --retry 5 --connect-timeout 15 \
    "$flutter_storage_base_url/flutter_infra_release/releases/$archive_path" \
    -o "$archive"
  printf '%s  %s\n' "$archive_sha256" "$archive" | sha256sum --check --status \
    || fail 'Flutter archive checksum mismatch'
  tar -xJf "$archive" -C "$work_dir"
  [[ -x "$work_dir/flutter/bin/flutter" ]] || fail 'downloaded archive did not contain a Linux Flutter SDK'

  python3 - "$work_dir/flutter/.babytalk-act-flutter.json" "$flutter_version" "$archive_sha256" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(json.dumps({
    "platform": "linux-x64",
    "version": sys.argv[2],
    "archive_sha256": sys.argv[3],
}, sort_keys=True) + "\n", encoding="utf-8")
PY
  mv "$work_dir/flutter" "$sdk_dir"
  trap - EXIT
  rm -rf -- "$work_dir"
  printf 'provisioned act Flutter Linux SDK: %s\n' "$sdk_dir"
}

main "$@"
