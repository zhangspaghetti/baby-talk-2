#!/usr/bin/env bash
# ci/k8s-smoke.sh — BabyTalk Helm split-stack dry-run verification
# 兼容 Git Bash (Windows) 和 Linux/macOS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_CHART_DIR="$PROJECT_ROOT/deploy/helm/babytalk-app"
APP_PROD_VALUES="$APP_CHART_DIR/values-production.yaml"
APP_RELEASE_NAME="babytalk-app"
INFRA_CHART_DIR="$PROJECT_ROOT/deploy/helm/babytalk-infra"
INFRA_KIND_VALUES="$INFRA_CHART_DIR/values-kind.yaml"
INFRA_RELEASE_NAME="babytalk-infra"
RUNBOOK="$PROJECT_ROOT/docs/runbooks/k8s-deploy.md"
SCHEMA_MATRIX="$PROJECT_ROOT/docs/schema-compatibility-matrix.md"
TELEMETRY_PATH="$PROJECT_ROOT/tmp/m007-s01-helm-metrics.jsonl"
START_TS="$(date +%s)"

# ── 颜色输出 ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
SKIP=0
RESULTS=()
FIRST_FAILURE_STAGE="none"
LIKELY_CAUSE="none"
NEXT_ACTION="none"

log_pass() {
  echo -e "  ${GREEN}✅ PASS${NC}: $1"
  RESULTS+=("✅ $1")
  PASS=$((PASS + 1))
}

log_fail() {
  echo -e "  ${RED}❌ FAIL${NC}: $1"
  RESULTS+=("❌ $1")
  FAIL=$((FAIL + 1))
}

log_skip() {
  echo -e "  ${YELLOW}⏭️  SKIP${NC}: $1"
  RESULTS+=("⏭️  $1")
  SKIP=$((SKIP + 1))
}

record_first_failure() {
  local stage="$1"
  local cause="$2"
  local next_action="$3"

  if [[ "$FIRST_FAILURE_STAGE" == "none" ]]; then
    FIRST_FAILURE_STAGE="$stage"
    LIKELY_CAUSE="$cause"
    NEXT_ACTION="$next_action"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if grep -Fq -- "$needle" <<<"$haystack"; then
    log_pass "$label"
  else
    log_fail "$label — missing [$needle]"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if grep -Fq -- "$needle" <<<"$haystack"; then
    log_fail "$label — unexpected [$needle]"
  else
    log_pass "$label"
  fi
}

render_resource_keys() {
  local manifest="$1"
  awk '
    BEGIN { kind = ""; in_metadata = 0 }
    /^kind:[[:space:]]*/ { kind = $2; in_metadata = 0; next }
    /^metadata:[[:space:]]*$/ { in_metadata = 1; next }
    in_metadata && /^  name:[[:space:]]*/ {
      name = $2
      gsub(/"/, "", name)
      print kind "/" name
      in_metadata = 0
      next
    }
    /^---/ { kind = ""; in_metadata = 0 }
  ' <<<"$manifest"
}

assert_resource_present() {
  local resource_keys="$1"
  local expected_key="$2"
  local label="$3"

  if grep -Fxq -- "$expected_key" <<<"$resource_keys"; then
    log_pass "$label"
  else
    log_fail "$label — missing resource [$expected_key]"
  fi
}

assert_resource_absent() {
  local resource_keys="$1"
  local unexpected_key="$2"
  local label="$3"

  if grep -Fxq -- "$unexpected_key" <<<"$resource_keys"; then
    log_fail "$label — unexpected resource [$unexpected_key]"
  else
    log_pass "$label"
  fi
}

step_begin() {
  STEP_FAIL_BASE="$FAIL"
}

step_failed() {
  [[ "$FAIL" -gt "$STEP_FAIL_BASE" ]]
}

emit_telemetry() {
  local exit_code="$1"
  local success="false"
  if [[ "$exit_code" -eq 0 ]]; then
    success="true"
  fi

  export TELEMETRY_PATH
  export TELEMETRY_MODE="smoke"
  export TELEMETRY_SHELL="bash"
  export TELEMETRY_SUCCESS="$success"
  export TELEMETRY_TTHW_SECONDS="$(( $(date +%s) - START_TS ))"
  export TELEMETRY_FIRST_FAILURE_STAGE="$FIRST_FAILURE_STAGE"
  export TELEMETRY_LIKELY_CAUSE="$LIKELY_CAUSE"
  export TELEMETRY_NEXT_ACTION="$NEXT_ACTION"
  export TELEMETRY_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  python - <<'PY'
import json
import os
from collections import Counter
from pathlib import Path

path = Path(os.environ['TELEMETRY_PATH'])
path.parent.mkdir(parents=True, exist_ok=True)

entry = {
    'mode': os.environ['TELEMETRY_MODE'],
    'shell': os.environ['TELEMETRY_SHELL'],
    'success': os.environ['TELEMETRY_SUCCESS'] == 'true',
    'tthw_seconds': int(os.environ['TELEMETRY_TTHW_SECONDS']),
    'first_failure_stage': os.environ['TELEMETRY_FIRST_FAILURE_STAGE'],
    'likely_cause': os.environ['TELEMETRY_LIKELY_CAUSE'],
    'next_action': os.environ['TELEMETRY_NEXT_ACTION'],
    'timestamp': os.environ['TELEMETRY_TIMESTAMP'],
}

history = []
if path.exists():
    for raw in path.read_text(encoding='utf-8').splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            history.append(json.loads(raw))
        except json.JSONDecodeError:
            continue

history.append(entry)
history = history[-50:]
path.write_text(
    ''.join(json.dumps(item, ensure_ascii=False, separators=(',', ':')) + '\n' for item in history),
    encoding='utf-8',
)

recent = history[-10:]
pass_rate = 0.0
if recent:
    pass_rate = sum(1 for item in recent if item.get('success')) / len(recent)

hotspot_candidates = [
    item.get('first_failure_stage')
    for item in recent
    if not item.get('success') and item.get('first_failure_stage') not in (None, '', 'none')
]
hotspot = Counter(hotspot_candidates).most_common(1)[0][0] if hotspot_candidates else 'none'

print(f'telemetry_path={path.as_posix()}')
print(f'smoke_recent_pass_rate={pass_rate:.2f}')
print(f'first_failure_hotspot={hotspot}')
PY

  echo "first_failure_stage=$FIRST_FAILURE_STAGE"
  echo "likely_cause=$LIKELY_CAUSE"
  echo "next_action=$NEXT_ACTION"
}

finalize_and_exit() {
  local exit_code="$1"

  echo ""
  echo "=============================================="
  echo " Summary"
  echo "=============================================="
  for r in "${RESULTS[@]}"; do
    echo "  $r"
  done
  echo ""
  echo -e "  ${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}  ${YELLOW}SKIP: $SKIP${NC}"
  echo ""

  emit_telemetry "$exit_code"
  echo ""

  if [[ "$exit_code" -eq 0 ]]; then
    echo -e "${GREEN}=== K8s Smoke Test PASSED ===${NC}"
  else
    echo -e "${RED}=== K8s Smoke Test FAILED ===${NC}"
  fi

  exit "$exit_code"
}

# ── 检测 helm ─────────────────────────────────────────────────
detect_helm() {
  if command -v helm &>/dev/null; then
    HELM_CMD="helm"
    return 0
  fi

  local WINGET_HELM="C:/Users/zhang/AppData/Local/Microsoft/WinGet/Packages/Helm.Helm_Microsoft.Winget.Source_8wekyb3d8bbwe/windows-amd64/helm.exe"
  if [[ -f "$WINGET_HELM" ]]; then
    HELM_CMD="$WINGET_HELM"
    return 0
  fi

  record_first_failure \
    "preflight" \
    "helm not found in PATH or WinGet location" \
    "Install Helm or expose helm.exe in PATH, then rerun bash ci/k8s-smoke.sh"
  echo -e "${RED}ERROR: helm not found in PATH or WinGet location${NC}"
  echo "Install helm: https://helm.sh/docs/intro/install/"
  return 1
}

# ── 检测 kubectl ──────────────────────────────────────────────
detect_kubectl() {
  if command -v kubectl &>/dev/null; then
    KUBECTL_CMD="kubectl"
    return 0
  fi
  KUBECTL_CMD=""
  return 1
}

echo "=============================================="
echo " BabyTalk Helm Smoke Test (dry-run)"
echo "=============================================="
echo ""

if ! detect_helm; then
  finalize_and_exit 1
fi
echo "Helm: $HELM_CMD ($($HELM_CMD version --short 2>/dev/null || echo 'unknown'))"

if detect_kubectl; then
  echo "kubectl: $KUBECTL_CMD ($($KUBECTL_CMD version --client -o yaml 2>/dev/null | grep gitVersion | head -1 | sed 's/.*: //' || echo 'unknown'))"
else
  echo "kubectl: not found (dry-run validation will be skipped)"
fi
echo ""

# ── Step 1: helm lint infra chart ─────────────────────────────
echo "--- Step 1: helm lint (infra chart) ---"
step_begin
if "$HELM_CMD" lint "$INFRA_CHART_DIR" 2>&1; then
  log_pass "helm lint (infra chart)"
else
  log_fail "helm lint (infra chart)"
fi
if step_failed; then
  record_first_failure \
    "infra" \
    "babytalk-infra chart failed lint" \
    "Fix deploy/helm/babytalk-infra and rerun helm lint deploy/helm/babytalk-infra"
fi
echo ""

# ── Step 2: helm lint app chart (default values) ─────────────
echo "--- Step 2: helm lint (app chart, default values) ---"
step_begin
if "$HELM_CMD" lint "$APP_CHART_DIR" 2>&1; then
  log_pass "helm lint (app chart, default values)"
else
  log_fail "helm lint (app chart, default values)"
fi
if step_failed; then
  record_first_failure \
    "app" \
    "babytalk-app chart failed lint with default values" \
    "Fix deploy/helm/babytalk-app templates/values and rerun helm lint deploy/helm/babytalk-app"
fi
echo ""

# ── Step 3: helm lint app chart (production values) ──────────
echo "--- Step 3: helm lint (app chart, production values) ---"
step_begin
if [[ -f "$APP_PROD_VALUES" ]]; then
  if "$HELM_CMD" lint "$APP_CHART_DIR" -f "$APP_PROD_VALUES" 2>&1; then
    log_pass "helm lint (app chart, production values)"
  else
    log_fail "helm lint (app chart, production values)"
  fi
else
  log_skip "helm lint (app chart, production values) — values-production.yaml not found"
fi
if step_failed; then
  record_first_failure \
    "app" \
    "babytalk-app production overrides no longer render" \
    "Fix deploy/helm/babytalk-app/values-production.yaml and rerun helm lint deploy/helm/babytalk-app -f deploy/helm/babytalk-app/values-production.yaml"
fi
echo ""

# ── Step 4: helm template infra service truth ────────────────
echo "--- Step 4: helm template infra service truth (kind values) ---"
TEMPLATE_INFRA=""
RESOURCE_KEYS_INFRA=""
step_begin
if TEMPLATE_INFRA=$("$HELM_CMD" template "$INFRA_RELEASE_NAME" "$INFRA_CHART_DIR" -f "$INFRA_KIND_VALUES" 2>&1); then
  RESOURCE_KEYS_INFRA="$(render_resource_keys "$TEMPLATE_INFRA")"
  assert_resource_present "$RESOURCE_KEYS_INFRA" "Service/${INFRA_RELEASE_NAME}-postgres" "infra render includes Service/${INFRA_RELEASE_NAME}-postgres"
  assert_resource_present "$RESOURCE_KEYS_INFRA" "Service/${INFRA_RELEASE_NAME}-redis-master" "infra render includes Service/${INFRA_RELEASE_NAME}-redis-master"
  assert_resource_present "$RESOURCE_KEYS_INFRA" "Service/${INFRA_RELEASE_NAME}-minio" "infra render includes Service/${INFRA_RELEASE_NAME}-minio"
else
  log_fail "helm template infra — render failed"
fi
if step_failed; then
  record_first_failure \
    "infra" \
    "babytalk-infra no longer renders the expected service names" \
    "Fix deploy/helm/babytalk-infra and rerun helm template babytalk-infra deploy/helm/babytalk-infra -f deploy/helm/babytalk-infra/values-kind.yaml"
fi
echo ""

# ── Step 5: helm template app split-stack truth (default) ────
echo "--- Step 5: helm template app split-stack truth (default values) ---"
TEMPLATE_DEFAULT=""
RESOURCE_KEYS_DEFAULT=""
step_begin
if TEMPLATE_DEFAULT=$("$HELM_CMD" template "$APP_RELEASE_NAME" "$APP_CHART_DIR" 2>&1); then
  RESOURCE_KEYS_DEFAULT="$(render_resource_keys "$TEMPLATE_DEFAULT")"

  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Service/${APP_RELEASE_NAME}-app-api" "default render includes Service/${APP_RELEASE_NAME}-app-api"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Service/${APP_RELEASE_NAME}-admin-api" "default render includes Service/${APP_RELEASE_NAME}-admin-api"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Service/${APP_RELEASE_NAME}-admin-web" "default render includes Service/${APP_RELEASE_NAME}-admin-web"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Deployment/${APP_RELEASE_NAME}-app-api" "default render includes Deployment/${APP_RELEASE_NAME}-app-api"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Deployment/${APP_RELEASE_NAME}-admin-api" "default render includes Deployment/${APP_RELEASE_NAME}-admin-api"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Deployment/${APP_RELEASE_NAME}-admin-web" "default render includes Deployment/${APP_RELEASE_NAME}-admin-web"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Job/${APP_RELEASE_NAME}-db-migration" "default render includes Job/${APP_RELEASE_NAME}-db-migration"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Pod/${APP_RELEASE_NAME}-split-stack-smoke" "default render includes Pod/${APP_RELEASE_NAME}-split-stack-smoke"
  assert_resource_absent "$RESOURCE_KEYS_DEFAULT" "Deployment/${APP_RELEASE_NAME}" "default render rejects legacy single Deployment/${APP_RELEASE_NAME}"
  assert_resource_absent "$RESOURCE_KEYS_DEFAULT" "Service/${APP_RELEASE_NAME}" "default render rejects legacy single Service/${APP_RELEASE_NAME}"
  assert_resource_absent "$RESOURCE_KEYS_DEFAULT" "Ingress/${APP_RELEASE_NAME}-app-api" "default render keeps app-api ingress disabled"
  assert_resource_absent "$RESOURCE_KEYS_DEFAULT" "Ingress/${APP_RELEASE_NAME}-admin-web" "default render keeps admin-web ingress disabled"
  assert_contains "$TEMPLATE_DEFAULT" '"helm.sh/hook": pre-install,pre-upgrade' "default render keeps db-migration pre-install/pre-upgrade hook"
else
  log_fail "helm template app default — render failed"
fi
if step_failed; then
  record_first_failure \
    "app" \
    "babytalk-app default render lost split-stack resources or kept legacy naming" \
    "Fix deploy/helm/babytalk-app templates and rerun helm template babytalk-app deploy/helm/babytalk-app"
fi

echo "--- Step 5b: gateway resource assertions (default values) ---"
step_begin
if [[ -n "$RESOURCE_KEYS_DEFAULT" ]]; then
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Deployment/${APP_RELEASE_NAME}-gateway" "default render includes Deployment/${APP_RELEASE_NAME}-gateway"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Service/${APP_RELEASE_NAME}-gateway" "default render includes Service/${APP_RELEASE_NAME}-gateway"
  assert_contains "$TEMPLATE_DEFAULT" "name: ${APP_RELEASE_NAME}-gateway" "default render exposes gateway resource names"
  assert_not_contains "$TEMPLATE_DEFAULT" "nginx:alpine" "gateway deployment no longer references nginx:alpine image"
  assert_contains "$TEMPLATE_DEFAULT" "BABY_TALK_APP_API_URI" "default render injects BABY_TALK_APP_API_URI into gateway"
  assert_not_contains "$TEMPLATE_DEFAULT" "Ingress/${APP_RELEASE_NAME}-gateway" "default render keeps gateway ingress disabled"
else
  log_fail "gateway resource assertions skipped — app default render failed"
fi
if step_failed; then
  record_first_failure \
    "gateway" \
    "gateway stub resources are missing from babytalk-app default render" \
    "Fix deploy/helm/babytalk-app gateway templates and rerun helm template babytalk-app deploy/helm/babytalk-app"
fi
echo ""

# ── Step 6: helm template app split-stack truth (production) ─
echo "--- Step 6: helm template app split-stack truth (production values) ---"
TEMPLATE_PROD=""
RESOURCE_KEYS_PROD=""
step_begin
if [[ -f "$APP_PROD_VALUES" ]]; then
  if TEMPLATE_PROD=$("$HELM_CMD" template "$APP_RELEASE_NAME" "$APP_CHART_DIR" -f "$APP_PROD_VALUES" 2>&1); then
    RESOURCE_KEYS_PROD="$(render_resource_keys "$TEMPLATE_PROD")"

    assert_resource_present "$RESOURCE_KEYS_PROD" "Service/${APP_RELEASE_NAME}-app-api" "production render includes Service/${APP_RELEASE_NAME}-app-api"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Service/${APP_RELEASE_NAME}-admin-api" "production render includes Service/${APP_RELEASE_NAME}-admin-api"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Service/${APP_RELEASE_NAME}-admin-web" "production render includes Service/${APP_RELEASE_NAME}-admin-web"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Service/${APP_RELEASE_NAME}-gateway" "production render includes Service/${APP_RELEASE_NAME}-gateway"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Deployment/${APP_RELEASE_NAME}-app-api" "production render includes Deployment/${APP_RELEASE_NAME}-app-api"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Deployment/${APP_RELEASE_NAME}-admin-api" "production render includes Deployment/${APP_RELEASE_NAME}-admin-api"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Deployment/${APP_RELEASE_NAME}-admin-web" "production render includes Deployment/${APP_RELEASE_NAME}-admin-web"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Deployment/${APP_RELEASE_NAME}-gateway" "production render includes Deployment/${APP_RELEASE_NAME}-gateway"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Job/${APP_RELEASE_NAME}-db-migration" "production render includes Job/${APP_RELEASE_NAME}-db-migration"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Ingress/${APP_RELEASE_NAME}-gateway" "production render includes Ingress/${APP_RELEASE_NAME}-gateway (consumer entry point)"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Ingress/${APP_RELEASE_NAME}-admin-web" "production render includes Ingress/${APP_RELEASE_NAME}-admin-web"
    assert_resource_absent "$RESOURCE_KEYS_PROD" "Ingress/${APP_RELEASE_NAME}-app-api" "production render keeps app-api internal (consumer routes via gateway)"
    assert_resource_absent "$RESOURCE_KEYS_PROD" "Ingress/${APP_RELEASE_NAME}-admin-api" "production render keeps admin-api internal (no ingress)"
    assert_resource_absent "$RESOURCE_KEYS_PROD" "Deployment/${APP_RELEASE_NAME}" "production render rejects legacy single Deployment/${APP_RELEASE_NAME}"
    assert_resource_absent "$RESOURCE_KEYS_PROD" "Service/${APP_RELEASE_NAME}" "production render rejects legacy single Service/${APP_RELEASE_NAME}"
    assert_contains "$TEMPLATE_PROD" '"helm.sh/hook": pre-install,pre-upgrade' "production render keeps db-migration pre-install/pre-upgrade hook"
  else
    log_fail "helm template production — render failed"
  fi
else
  log_skip "helm template production — values-production.yaml not found"
fi
if step_failed; then
  record_first_failure \
    "app" \
    "babytalk-app production render no longer matches the split-stack release boundary" \
    "Fix deploy/helm/babytalk-app/values-production.yaml and templates, then rerun helm template babytalk-app deploy/helm/babytalk-app -f deploy/helm/babytalk-app/values-production.yaml"
fi
echo ""

# ── Step 7: kubectl dry-run ──────────────────────────────────
echo "--- Step 7: kubectl dry-run validation ---"
KUBECTL_REACHABLE=false
if [[ -n "${KUBECTL_CMD:-}" ]]; then
  if "$KUBECTL_CMD" cluster-info --request-timeout=5s &>/dev/null; then
    KUBECTL_REACHABLE=true
  fi
fi

step_begin
if [[ "$KUBECTL_REACHABLE" == "true" ]] && [[ -n "$TEMPLATE_DEFAULT" ]]; then
  if echo "$TEMPLATE_DEFAULT" | "$KUBECTL_CMD" apply --dry-run=client -f - &>/dev/null; then
    log_pass "kubectl dry-run (app default values)"
  else
    log_fail "kubectl dry-run (app default values)"
  fi
else
  log_skip "kubectl dry-run (app default) — no reachable cluster or app default render failed"
fi
if step_failed; then
  record_first_failure \
    "cluster" \
    "kubectl client-side dry-run rejected the rendered babytalk-app manifest" \
    "Inspect kubectl validation output with a reachable cluster and rerun bash ci/k8s-smoke.sh"
fi

step_begin
if [[ "$KUBECTL_REACHABLE" == "true" ]] && [[ -n "$TEMPLATE_PROD" ]]; then
  if echo "$TEMPLATE_PROD" | "$KUBECTL_CMD" apply --dry-run=client -f - &>/dev/null; then
    log_pass "kubectl dry-run (app production values)"
  else
    log_fail "kubectl dry-run (app production values)"
  fi
elif [[ "$KUBECTL_REACHABLE" != "true" ]]; then
  log_skip "kubectl dry-run (app production) — no reachable cluster"
else
  log_skip "kubectl dry-run (app production) — production render failed or values-production.yaml not found"
fi
if step_failed; then
  record_first_failure \
    "cluster" \
    "kubectl client-side dry-run rejected the production babytalk-app manifest" \
    "Inspect kubectl validation output with a reachable cluster and rerun bash ci/k8s-smoke.sh"
fi
echo ""

# ── Step 8: Helm test pod + release notes truth ──────────────
echo "--- Step 8: Helm test pod + release notes truth ---"
TEST_CONNECTION_RENDER=""
step_begin
if TEST_CONNECTION_RENDER=$("$HELM_CMD" template "$APP_RELEASE_NAME" "$APP_CHART_DIR" --show-only templates/tests/test-connection.yaml 2>&1); then
  TEST_RESOURCE_KEYS="$(render_resource_keys "$TEST_CONNECTION_RENDER")"
  assert_resource_present "$TEST_RESOURCE_KEYS" "Pod/${APP_RELEASE_NAME}-split-stack-smoke" "helm test render includes Pod/${APP_RELEASE_NAME}-split-stack-smoke"
  assert_contains "$TEST_CONNECTION_RENDER" '"helm.sh/hook": test' "helm test pod keeps helm.sh/hook=test"
  assert_contains "$TEST_CONNECTION_RENDER" "http://${APP_RELEASE_NAME}-gateway:8090/actuator/health" "helm test pod probes gateway actuator health truth"
  assert_contains "$TEST_CONNECTION_RENDER" "http://${APP_RELEASE_NAME}-app-api:8080/actuator/health" "helm test pod probes app-api service truth"
  assert_contains "$TEST_CONNECTION_RENDER" "http://${APP_RELEASE_NAME}-admin-api:8081/actuator/health" "helm test pod probes admin-api service truth"
  assert_contains "$TEST_CONNECTION_RENDER" "http://${APP_RELEASE_NAME}-admin-web:80/" "helm test pod probes admin-web service truth"
else
  log_fail "helm test pod render — templates/tests/test-connection.yaml failed to render"
fi
if step_failed; then
  record_first_failure \
    "gateway" \
    "helm test hook no longer proves the gateway-first smoke path" \
    "Fix deploy/helm/babytalk-app/templates/tests/test-connection.yaml and rerun helm template babytalk-app deploy/helm/babytalk-app --show-only templates/tests/test-connection.yaml"
fi

RELEASE_NOTES_OUTPUT=""
step_begin
if [[ -f "$APP_PROD_VALUES" ]]; then
  if RELEASE_NOTES_OUTPUT=$("$HELM_CMD" install "$APP_RELEASE_NAME" "$APP_CHART_DIR" -f "$APP_PROD_VALUES" --dry-run --debug 2>&1); then
    assert_contains "$RELEASE_NOTES_OUTPUT" "https://api.babytalk.example.com" "release notes expose consumer API via gateway"
    assert_contains "$RELEASE_NOTES_OUTPUT" "https://admin.babytalk.example.com" "release notes expose admin-web public surface"
    assert_contains "$RELEASE_NOTES_OUTPUT" "svc/${APP_RELEASE_NAME}-gateway:8090" "release notes expose gateway Spring Cloud Gateway service truth"
    assert_contains "$RELEASE_NOTES_OUTPUT" "Spring Cloud Gateway" "release notes reference Spring Cloud Gateway (not nginx stub)"
    assert_contains "$RELEASE_NOTES_OUTPUT" "svc/${APP_RELEASE_NAME}-admin-api:8081" "release notes mark admin-api as internal service truth"
    assert_contains "$RELEASE_NOTES_OUTPUT" "svc/${APP_RELEASE_NAME}-app-api:8080" "release notes mark app-api as internal service (consumer routes via gateway)"
    assert_contains "$RELEASE_NOTES_OUTPUT" "pre-install / pre-upgrade hook job ${APP_RELEASE_NAME}-db-migration" "release notes point to db-migration hook job"
  else
    log_fail "helm install --dry-run --debug (production values) failed to render NOTES"
  fi
else
  log_skip "release notes truth — values-production.yaml not found"
fi
if step_failed; then
  record_first_failure \
    "gateway" \
    "release notes no longer describe the gateway stub or internal service boundary" \
    "Fix deploy/helm/babytalk-app/templates/NOTES.txt and rerun helm install babytalk-app deploy/helm/babytalk-app -f deploy/helm/babytalk-app/values-production.yaml --dry-run --debug"
fi
echo ""

# ── Step 9: Runbook exists ───────────────────────────────────
echo "--- Step 9: Runbook check ---"
step_begin
if [[ -f "$RUNBOOK" ]]; then
  RUNBOOK_LINES=$(wc -l < "$RUNBOOK")
  if [[ "$RUNBOOK_LINES" -ge 50 ]]; then
    log_pass "Runbook exists ($RUNBOOK_LINES lines)"
  else
    log_fail "Runbook too short ($RUNBOOK_LINES lines, expected >= 50)"
  fi
else
  log_fail "Runbook not found at docs/runbooks/k8s-deploy.md"
fi
if step_failed; then
  record_first_failure \
    "smoke" \
    "k8s runbook is missing or too short to support the Helm smoke handoff" \
    "Restore docs/runbooks/k8s-deploy.md and rerun bash ci/k8s-smoke.sh"
fi
echo ""

# ── Step 10: Dual-release doc + chart boundary check ────────
echo "--- Step 10: Dual-release doc + chart boundary check ---"
TEMPLATE_INFRA_DEFAULT=""
TEMPLATE_APP_DEFAULT=""
step_begin
if [[ -f "$SCHEMA_MATRIX" ]]; then
  log_pass "schema compatibility matrix exists"
else
  log_fail "schema compatibility matrix not found at docs/schema-compatibility-matrix.md"
fi

if grep -q 'babytalk-infra' "$RUNBOOK"; then
  log_pass "runbook references babytalk-infra"
else
  log_fail "runbook missing babytalk-infra reference"
fi

if grep -q 'babytalk-app' "$RUNBOOK"; then
  log_pass "runbook references babytalk-app"
else
  log_fail "runbook missing babytalk-app reference"
fi

if TEMPLATE_INFRA_DEFAULT=$("$HELM_CMD" template "$INFRA_RELEASE_NAME" "$INFRA_CHART_DIR" 2>&1); then
  INFRA_JOB_COUNT="$(grep -c 'kind: Job' <<<"$TEMPLATE_INFRA_DEFAULT" || true)"
  if [[ "$INFRA_JOB_COUNT" -eq 0 ]]; then
    log_pass "infra chart renders no Job resources"
  else
    log_fail "infra chart must not contain a db-migration Job; found $INFRA_JOB_COUNT Job resources"
  fi
else
  log_fail "infra chart default render failed while checking Job boundary"
fi

if TEMPLATE_APP_DEFAULT=$("$HELM_CMD" template "$APP_RELEASE_NAME" "$APP_CHART_DIR" 2>&1); then
  if grep 'hook-delete-policy' <<<"$TEMPLATE_APP_DEFAULT" | grep -q 'before-hook-creation,hook-succeeded'; then
    log_pass "app chart keeps db-migration hook-delete-policy"
  else
    log_fail "app chart lost db-migration hook-delete-policy boundary"
  fi
else
  log_fail "app chart default render failed while checking db-migration hook-delete-policy"
fi
if step_failed; then
  record_first_failure \
    "smoke" \
    "dual-release docs or Helm boundary checks drifted from the M007 contract" \
    "Fix docs/schema-compatibility-matrix.md, docs/runbooks/k8s-deploy.md, or the babytalk-infra/babytalk-app chart boundary, then rerun bash ci/k8s-smoke.sh"
fi
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  finalize_and_exit 1
else
  finalize_and_exit 0
fi
