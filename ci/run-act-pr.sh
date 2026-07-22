#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
event_template="$repo_root/.act/pull_request.json"
event_file=''
act_log=''
act_flutter_sdk=''
act_flutter_mount=''

fail() {
  printf 'run-act-pr: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  local status=$?
  trap - EXIT
  [[ -z "$event_file" ]] || rm -f -- "$event_file"
  [[ -z "$act_log" ]] || rm -f -- "$act_log"
  exit "$status"
}

default_act_flutter_sdk() {
  if command -v cygpath >/dev/null 2>&1 && [[ -n "${LOCALAPPDATA:-}" ]]; then
    printf '%s/BabyTalk/act/flutter/flutter-3.41.6-linux/flutter\n' \
      "$(cygpath -u "$LOCALAPPDATA")"
  else
    printf '%s/babytalk/act/flutter/flutter-3.41.6-linux/flutter\n' \
      "${XDG_CACHE_HOME:-$HOME/.cache}"
  fi
}

resolve_act_flutter_mount() {
  local metadata
  act_flutter_sdk="${ACT_FLUTTER_LINUX_SDK:-$(default_act_flutter_sdk)}"
  metadata="$act_flutter_sdk/.babytalk-act-flutter.json"
  [[ -x "$act_flutter_sdk/bin/flutter" ]] \
    || fail "Linux Flutter SDK is missing; run bash ci/provision-act-flutter-sdk.sh first"
  python3 - "$metadata" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if metadata.get("platform") != "linux-x64" or metadata.get("version") != "3.41.6":
    raise SystemExit("invalid local act Flutter SDK metadata")
PY
  if command -v cygpath >/dev/null 2>&1; then
    act_flutter_mount="$(cygpath -w "$act_flutter_sdk")"
  else
    act_flutter_mount="$act_flutter_sdk"
  fi
}

main() {
  cd "$repo_root"
  command -v act >/dev/null 2>&1 || fail 'act is required'
  resolve_act_flutter_mount
  [[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] \
    || fail 'worktree must be clean so act validates the recorded HEAD exactly'
  git fetch --no-tags origin Develop

  local head_sha origin_develop_sha merge_base_sha head_ref
  head_sha="$(git rev-parse --verify 'HEAD^{commit}')"
  origin_develop_sha="$(git rev-parse --verify 'refs/remotes/origin/Develop^{commit}')"
  merge_base_sha="$(git merge-base "$head_sha" "$origin_develop_sha")"
  head_ref="$(git branch --show-current)"
  [[ -n "$head_ref" ]] || head_ref="local/${head_sha:0:12}"

  event_file="$(mktemp "${TMPDIR:-/tmp}/babytalk-act-pr-event.XXXXXX.json")"
  act_log="$(mktemp "${TMPDIR:-/tmp}/babytalk-act-pr-log.XXXXXX")"
  trap cleanup EXIT

  python3 - "$event_template" "$event_file" "$head_sha" "$origin_develop_sha" "$merge_base_sha" "$head_ref" <<'PY'
import json
import sys
from pathlib import Path

template = Path(sys.argv[1])
output = Path(sys.argv[2])
head_sha, origin_develop_sha, merge_base_sha, head_ref = sys.argv[3:]
event = json.loads(template.read_text(encoding="utf-8"))
event["pull_request"]["base"]["sha"] = origin_develop_sha
event["pull_request"]["head"]["ref"] = head_ref
event["pull_request"]["head"]["sha"] = head_sha
event["local_act"] = {"head_sha": head_sha, "origin_develop_sha": origin_develop_sha, "merge_base_sha": merge_base_sha}
output.write_text(json.dumps(event, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

  local act_args=(
    -b
    -W .act/workflows/local-act-pr.yml
    -e "$event_file"
    --container-options "--mount type=bind,source=$act_flutter_mount,target=/opt/babytalk/flutter-source,readonly"
  )
  MSYS_NO_PATHCONV=1 act "${act_args[@]}" -l pull_request "$@" 2>&1 | tee "$act_log"
  grep -Fq 'local-pr-full-ci' "$act_log" || fail 'fixture does not select local-pr-full-ci'
  : >"$act_log"
  MSYS_NO_PATHCONV=1 act "${act_args[@]}" pull_request -j local-pr-full-ci "$@" \
    2>&1 | tee "$act_log"
  if grep -Eqi 'skipp(ing|ed).*job|job.*skipp(ing|ed)' "$act_log"; then
    fail 'local-pr-full-ci was skipped'
  fi
  grep -Eq 'Job succeeded|✅ Success' "$act_log" || fail 'local-pr-full-ci did not report success'
  printf 'act PR pre-merge job succeeded: head=%s origin_develop=%s merge_base=%s\n' \
    "$head_sha" "$origin_develop_sha" "$merge_base_sha"
}

main "$@"
