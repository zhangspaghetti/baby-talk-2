#!/usr/bin/env bash
# ci/k8s-smoke.sh — BabyTalk K8s 交付产物 dry-run 验证
# 兼容 Git Bash (Windows) 和 Linux/macOS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHART_DIR="$PROJECT_ROOT/deploy/helm/babytalk"
PROD_VALUES="$CHART_DIR/values-production.yaml"
RUNBOOK="$PROJECT_ROOT/docs/runbooks/k8s-deploy.md"
RELEASE_NAME="babytalk"

# ── 颜色输出 ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
SKIP=0
RESULTS=()

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

  echo -e "${RED}ERROR: helm not found in PATH or WinGet location${NC}"
  echo "Install helm: https://helm.sh/docs/intro/install/"
  exit 1
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
echo " BabyTalk K8s Smoke Test (dry-run)"
echo "=============================================="
echo ""

detect_helm
echo "Helm: $HELM_CMD ($($HELM_CMD version --short 2>/dev/null || echo 'unknown'))"

if detect_kubectl; then
  echo "kubectl: $KUBECTL_CMD ($($KUBECTL_CMD version --client -o yaml 2>/dev/null | grep gitVersion | head -1 | sed 's/.*: //' || echo 'unknown'))"
else
  echo "kubectl: not found (dry-run validation will be skipped)"
fi
echo ""

# ── Step 1: helm lint ─────────────────────────────────────────
echo "--- Step 1: helm lint ---"
if "$HELM_CMD" lint "$CHART_DIR" 2>&1; then
  log_pass "helm lint (default values)"
else
  log_fail "helm lint (default values)"
fi
echo ""

# ── Step 2: helm lint with production values ──────────────────
echo "--- Step 2: helm lint (production values) ---"
if [[ -f "$PROD_VALUES" ]]; then
  if "$HELM_CMD" lint "$CHART_DIR" -f "$PROD_VALUES" 2>&1; then
    log_pass "helm lint (production values)"
  else
    log_fail "helm lint (production values)"
  fi
else
  log_skip "helm lint (production values) — values-production.yaml not found"
fi
echo ""

# ── Step 3: helm template named split-stack truth (default) ──
echo "--- Step 3: helm template named split-stack truth (default values) ---"
TEMPLATE_DEFAULT=""
RESOURCE_KEYS_DEFAULT=""
if TEMPLATE_DEFAULT=$("$HELM_CMD" template "$RELEASE_NAME" "$CHART_DIR" 2>&1); then
  RESOURCE_KEYS_DEFAULT="$(render_resource_keys "$TEMPLATE_DEFAULT")"

  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Service/${RELEASE_NAME}-app-api" "default render includes Service/${RELEASE_NAME}-app-api"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Service/${RELEASE_NAME}-admin-api" "default render includes Service/${RELEASE_NAME}-admin-api"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Service/${RELEASE_NAME}-admin-web" "default render includes Service/${RELEASE_NAME}-admin-web"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Deployment/${RELEASE_NAME}-app-api" "default render includes Deployment/${RELEASE_NAME}-app-api"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Deployment/${RELEASE_NAME}-admin-api" "default render includes Deployment/${RELEASE_NAME}-admin-api"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Deployment/${RELEASE_NAME}-admin-web" "default render includes Deployment/${RELEASE_NAME}-admin-web"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Job/${RELEASE_NAME}-db-migration" "default render includes Job/${RELEASE_NAME}-db-migration"
  assert_resource_present "$RESOURCE_KEYS_DEFAULT" "Pod/${RELEASE_NAME}-split-stack-smoke" "default render includes Pod/${RELEASE_NAME}-split-stack-smoke"
  assert_resource_absent "$RESOURCE_KEYS_DEFAULT" "Deployment/${RELEASE_NAME}" "default render rejects legacy single Deployment/${RELEASE_NAME}"
  assert_resource_absent "$RESOURCE_KEYS_DEFAULT" "Service/${RELEASE_NAME}" "default render rejects legacy single Service/${RELEASE_NAME}"
  assert_resource_absent "$RESOURCE_KEYS_DEFAULT" "Ingress/${RELEASE_NAME}-app-api" "default render keeps app-api ingress disabled"
  assert_resource_absent "$RESOURCE_KEYS_DEFAULT" "Ingress/${RELEASE_NAME}-admin-web" "default render keeps admin-web ingress disabled"
  assert_contains "$TEMPLATE_DEFAULT" '"helm.sh/hook": pre-install,pre-upgrade' "default render keeps db-migration pre-install/pre-upgrade hook"
else
  log_fail "helm template default — render failed"
fi
echo ""

# ── Step 4: helm template named split-stack truth (production) ─
echo "--- Step 4: helm template named split-stack truth (production values) ---"
TEMPLATE_PROD=""
RESOURCE_KEYS_PROD=""
if [[ -f "$PROD_VALUES" ]]; then
  if TEMPLATE_PROD=$("$HELM_CMD" template "$RELEASE_NAME" "$CHART_DIR" -f "$PROD_VALUES" 2>&1); then
    RESOURCE_KEYS_PROD="$(render_resource_keys "$TEMPLATE_PROD")"

    assert_resource_present "$RESOURCE_KEYS_PROD" "Service/${RELEASE_NAME}-app-api" "production render includes Service/${RELEASE_NAME}-app-api"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Service/${RELEASE_NAME}-admin-api" "production render includes Service/${RELEASE_NAME}-admin-api"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Service/${RELEASE_NAME}-admin-web" "production render includes Service/${RELEASE_NAME}-admin-web"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Deployment/${RELEASE_NAME}-app-api" "production render includes Deployment/${RELEASE_NAME}-app-api"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Deployment/${RELEASE_NAME}-admin-api" "production render includes Deployment/${RELEASE_NAME}-admin-api"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Deployment/${RELEASE_NAME}-admin-web" "production render includes Deployment/${RELEASE_NAME}-admin-web"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Job/${RELEASE_NAME}-db-migration" "production render includes Job/${RELEASE_NAME}-db-migration"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Ingress/${RELEASE_NAME}-app-api" "production render includes Ingress/${RELEASE_NAME}-app-api"
    assert_resource_present "$RESOURCE_KEYS_PROD" "Ingress/${RELEASE_NAME}-admin-web" "production render includes Ingress/${RELEASE_NAME}-admin-web"
    assert_resource_absent "$RESOURCE_KEYS_PROD" "Ingress/${RELEASE_NAME}-admin-api" "production render keeps admin-api internal (no ingress)"
    assert_resource_absent "$RESOURCE_KEYS_PROD" "Deployment/${RELEASE_NAME}" "production render rejects legacy single Deployment/${RELEASE_NAME}"
    assert_resource_absent "$RESOURCE_KEYS_PROD" "Service/${RELEASE_NAME}" "production render rejects legacy single Service/${RELEASE_NAME}"
    assert_contains "$TEMPLATE_PROD" '"helm.sh/hook": pre-install,pre-upgrade' "production render keeps db-migration pre-install/pre-upgrade hook"
  else
    log_fail "helm template production — render failed"
  fi
else
  log_skip "helm template production — values-production.yaml not found"
fi
echo ""

# ── Step 5: kubectl dry-run ──────────────────────────────────
echo "--- Step 5: kubectl dry-run validation ---"
KUBECTL_REACHABLE=false
if [[ -n "${KUBECTL_CMD:-}" ]]; then
  if "$KUBECTL_CMD" cluster-info --request-timeout=5s &>/dev/null; then
    KUBECTL_REACHABLE=true
  fi
fi

if [[ "$KUBECTL_REACHABLE" == "true" ]] && [[ -n "$TEMPLATE_DEFAULT" ]]; then
  if echo "$TEMPLATE_DEFAULT" | "$KUBECTL_CMD" apply --dry-run=client -f - &>/dev/null; then
    log_pass "kubectl dry-run (default values)"
  else
    log_fail "kubectl dry-run (default values)"
  fi
else
  log_skip "kubectl dry-run (default) — no reachable cluster or default render failed"
fi

if [[ "$KUBECTL_REACHABLE" == "true" ]] && [[ -n "$TEMPLATE_PROD" ]]; then
  if echo "$TEMPLATE_PROD" | "$KUBECTL_CMD" apply --dry-run=client -f - &>/dev/null; then
    log_pass "kubectl dry-run (production values)"
  else
    log_fail "kubectl dry-run (production values)"
  fi
elif [[ "$KUBECTL_REACHABLE" != "true" ]]; then
  log_skip "kubectl dry-run (production) — no reachable cluster"
else
  log_skip "kubectl dry-run (production) — production render failed or values-production.yaml not found"
fi
echo ""

# ── Step 6: Helm test pod + release notes truth ──────────────
echo "--- Step 6: Helm test pod + release notes truth ---"
TEST_CONNECTION_RENDER=""
if TEST_CONNECTION_RENDER=$("$HELM_CMD" template "$RELEASE_NAME" "$CHART_DIR" --show-only templates/tests/test-connection.yaml 2>&1); then
  TEST_RESOURCE_KEYS="$(render_resource_keys "$TEST_CONNECTION_RENDER")"
  assert_resource_present "$TEST_RESOURCE_KEYS" "Pod/${RELEASE_NAME}-split-stack-smoke" "helm test render includes Pod/${RELEASE_NAME}-split-stack-smoke"
  assert_contains "$TEST_CONNECTION_RENDER" '"helm.sh/hook": test' "helm test pod keeps helm.sh/hook=test"
  assert_contains "$TEST_CONNECTION_RENDER" "http://${RELEASE_NAME}-app-api:8080/actuator/health" "helm test pod probes app-api service truth"
  assert_contains "$TEST_CONNECTION_RENDER" "http://${RELEASE_NAME}-admin-api:8081/actuator/health" "helm test pod probes admin-api service truth"
  assert_contains "$TEST_CONNECTION_RENDER" "http://${RELEASE_NAME}-admin-web:80/" "helm test pod probes admin-web service truth"
else
  log_fail "helm test pod render — templates/tests/test-connection.yaml failed to render"
fi

RELEASE_NOTES_OUTPUT=""
if [[ -f "$PROD_VALUES" ]]; then
  if RELEASE_NOTES_OUTPUT=$("$HELM_CMD" install "$RELEASE_NAME" "$CHART_DIR" -f "$PROD_VALUES" --dry-run --debug 2>&1); then
    assert_contains "$RELEASE_NOTES_OUTPUT" "https://api.babytalk.example.com" "release notes expose app-api public surface"
    assert_contains "$RELEASE_NOTES_OUTPUT" "https://admin.babytalk.example.com" "release notes expose admin-web public surface"
    assert_contains "$RELEASE_NOTES_OUTPUT" "svc/${RELEASE_NAME}-admin-api:8081" "release notes mark admin-api as internal service truth"
    assert_contains "$RELEASE_NOTES_OUTPUT" "pre-install / pre-upgrade hook job ${RELEASE_NAME}-db-migration" "release notes point to db-migration hook job"
  else
    log_fail "helm install --dry-run --debug (production values) failed to render NOTES"
  fi
else
  log_skip "release notes truth — values-production.yaml not found"
fi
echo ""

# ── Step 7: Runbook exists ───────────────────────────────────
echo "--- Step 7: Runbook check ---"
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
echo ""

# ── 汇总 ─────────────────────────────────────────────────────
echo "=============================================="
echo " Summary"
echo "=============================================="
for r in "${RESULTS[@]}"; do
  echo "  $r"
done
echo ""
echo -e "  ${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}  ${YELLOW}SKIP: $SKIP${NC}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}=== K8s Smoke Test FAILED ===${NC}"
  exit 1
else
  echo -e "${GREEN}=== K8s Smoke Test PASSED ===${NC}"
  exit 0
fi
