#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
parser_file="$(mktemp "${TMPDIR:-/tmp}/babytalk-k8s-resource-parser.XXXXXX")"
trap 'rm -f -- "$parser_file"' EXIT

awk '
  /^render_resource_keys\(\)/ { capture = 1 }
  capture { print }
  capture && /^}/ { exit }
' "$repo_root/ci/k8s-smoke.sh" >"$parser_file"

# shellcheck source=/dev/null
source "$parser_file"

manifest=$'\033[0m---\r\n\033[0mkind: Service\r\napiVersion: v1\r\nmetadata:\r\n  name: babytalk-app-gateway\r\nspec:\r\n  ports: []\r\n'
actual="$(render_resource_keys "$manifest")"

[[ "$actual" == 'Service/babytalk-app-gateway' ]] || {
  printf 'expected normalized resource key; got: %q\n' "$actual" >&2
  exit 1
}
