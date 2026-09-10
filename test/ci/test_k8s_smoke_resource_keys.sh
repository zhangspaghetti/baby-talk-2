#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
parser_file="$(mktemp "${TMPDIR:-/tmp}/babytalk-k8s-resource-parser.XXXXXX")"
owner_key_checker_file="$(mktemp "${TMPDIR:-/tmp}/babytalk-k8s-owner-key-checker.XXXXXX")"
trap 'rm -f -- "$parser_file" "$owner_key_checker_file"' EXIT

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

awk '
  /^assert_placeholder_not_in_non_secret_documents\(\)/ { capture = 1 }
  capture { print }
  capture && /^}/ { exit }
' "$repo_root/ci/k8s-smoke.sh" >"$owner_key_checker_file"

# shellcheck source=/dev/null
source "$owner_key_checker_file"

CHECK_RESULT=""
log_pass() { CHECK_RESULT="pass:$1"; }
log_fail() { CHECK_RESULT="fail:$1"; }

placeholder='ci-public-agentic-owner-key-placeholder-0123456789'
encoded_placeholder="$(printf '%s' "$placeholder" | base64 | tr -d '\r\n')"
secret_only_manifest=$'apiVersion: v1\nkind: Secret\nmetadata:\n  name: owner-key\ndata:\n  owner: ci-public-agentic-owner-key-placeholder-0123456789\n---\napiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: runtime\ndata:\n  mode: agentic\n'
assert_placeholder_not_in_non_secret_documents "$secret_only_manifest" "$placeholder" 'Secret-only placeholder stays isolated'
[[ "$CHECK_RESULT" == 'pass:Secret-only placeholder stays isolated' ]] || {
  printf 'expected Secret-only placeholder check to pass; got: %q\n' "$CHECK_RESULT" >&2
  exit 1
}

encoded_secret_manifest="apiVersion: v1
kind: Secret
metadata:
  name: owner-key
data:
  owner: ${encoded_placeholder}"
CHECK_RESULT=""
assert_placeholder_not_in_non_secret_documents "$encoded_secret_manifest" "$placeholder" 'Secret-only base64 placeholder stays isolated'
[[ "$CHECK_RESULT" == 'pass:Secret-only base64 placeholder stays isolated' ]] || {
  printf 'expected Secret-only base64 placeholder check to pass; got: %q\n' "$CHECK_RESULT" >&2
  exit 1
}

leaked_manifest=$'apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: runtime\ndata:\n  owner: ci-public-agentic-owner-key-placeholder-0123456789\n'
assert_placeholder_not_in_non_secret_documents "$leaked_manifest" "$placeholder" 'ConfigMap placeholder leak is rejected'
[[ "$CHECK_RESULT" == 'fail:ConfigMap placeholder leak is rejected — placeholder leaked outside Secret document' ]] || {
  printf 'expected ConfigMap placeholder leak to fail; got: %q\n' "$CHECK_RESULT" >&2
  exit 1
}

for base64_leak_manifest in \
  "apiVersion: v1
kind: ConfigMap
metadata:
  name: runtime
data:
  owner: ${encoded_placeholder}" \
  "apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-api
  annotations:
    owner: ${encoded_placeholder}" \
  "apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-api
spec:
  template:
    spec:
      containers:
        - name: app-api
          env:
            - name: OWNER
              value: ${encoded_placeholder}"; do
  CHECK_RESULT=""
  assert_placeholder_not_in_non_secret_documents "$base64_leak_manifest" "$placeholder" 'Base64 placeholder leak is rejected'
  [[ "$CHECK_RESULT" == 'fail:Base64 placeholder leak is rejected — placeholder leaked outside Secret document' ]] || {
    printf 'expected base64 placeholder leak to fail; got: %q\n' "$CHECK_RESULT" >&2
    exit 1
  }
done

grep -Fq -- 'lint "$APP_CHART_DIR" -f "$APP_PROD_VALUES" --set-string "$AGENTIC_OWNER_KEY_HELM_SET"' "$repo_root/ci/k8s-smoke.sh" || {
  printf 'expected production Helm lint to use the public owner-key placeholder\n' >&2
  exit 1
}
