#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
event_template="$repo_root/.act/pull_request.json"
event_file=''
act_log=''

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

main() {
  cd "$repo_root"
  command -v act >/dev/null 2>&1 || fail 'act is required'
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

  act -l pull_request -W .github/workflows/local-act-pr.yml -e "$event_file" "$@" | tee "$act_log"
  grep -Fq 'local-pr-full-ci' "$act_log" || fail 'fixture does not select local-pr-full-ci'
  : >"$act_log"
  act pull_request -W .github/workflows/local-act-pr.yml -e "$event_file" -j local-pr-full-ci "$@" \
    | tee "$act_log"
  if grep -Eqi 'skipp(ing|ed).*job|job.*skipp(ing|ed)' "$act_log"; then
    fail 'local-pr-full-ci was skipped'
  fi
  grep -Eq 'Job succeeded|✅ Success' "$act_log" || fail 'local-pr-full-ci did not report success'
  printf 'act PR pre-merge job succeeded: head=%s origin_develop=%s merge_base=%s\n' \
    "$head_sha" "$origin_develop_sha" "$merge_base_sha"
}

main "$@"
