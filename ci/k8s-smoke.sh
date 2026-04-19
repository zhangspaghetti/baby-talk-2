#!/usr/bin/env bash
# ci/k8s-smoke.sh — BabyTalk K8s 交付产物 dry-run 验证
# 兼容 Git Bash (Windows) 和 Linux/macOS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHART_DIR="$PROJECT_ROOT/deploy/helm/babytalk"
PROD_VALUES="$CHART_DIR/values-production.yaml"

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

# ── 检测 helm ─────────────────────────────────────────────────
detect_helm() {
  # 优先检查 PATH
  if command -v helm &>/dev/null; then
    HELM_CMD="helm"
    return 0
  fi
  # Windows WinGet 安装路径
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

# ── Step 3: helm template (default) ──────────────────────────
echo "--- Step 3: helm template (default values) ---"
TEMPLATE_DEFAULT=$("$HELM_CMD" template babytalk "$CHART_DIR" 2>&1) || true
KIND_COUNT_DEFAULT=$(echo "$TEMPLATE_DEFAULT" | grep -c "^kind:" || true)
if [[ "$KIND_COUNT_DEFAULT" -ge 5 ]]; then
  log_pass "helm template default — rendered $KIND_COUNT_DEFAULT resource kinds"
else
  log_fail "helm template default — rendered $KIND_COUNT_DEFAULT resource kinds (expected >= 5)"
fi
echo ""

# ── Step 4: helm template (production) ───────────────────────
echo "--- Step 4: helm template (production values) ---"
if [[ -f "$PROD_VALUES" ]]; then
  TEMPLATE_PROD=$("$HELM_CMD" template babytalk "$CHART_DIR" -f "$PROD_VALUES" 2>&1) || true
  KIND_COUNT_PROD=$(echo "$TEMPLATE_PROD" | grep -c "^kind:" || true)
  if [[ "$KIND_COUNT_PROD" -ge 6 ]]; then
    log_pass "helm template production — rendered $KIND_COUNT_PROD resource kinds (includes Ingress)"
  else
    log_fail "helm template production — rendered $KIND_COUNT_PROD resource kinds (expected >= 6)"
  fi
else
  log_skip "helm template production — values-production.yaml not found"
fi
echo ""

# ── Step 5: kubectl dry-run (default) ────────────────────────
echo "--- Step 5: kubectl dry-run validation ---"
KUBECTL_REACHABLE=false
if [[ -n "${KUBECTL_CMD:-}" ]]; then
  # 检测 kubectl 能否连接集群（快速超时），无可用集群则跳过
  if "$KUBECTL_CMD" cluster-info --request-timeout=5s &>/dev/null; then
    KUBECTL_REACHABLE=true
  fi
fi

if [[ "$KUBECTL_REACHABLE" == "true" ]]; then
  if echo "$TEMPLATE_DEFAULT" | "$KUBECTL_CMD" apply --dry-run=client -f - &>/dev/null; then
    log_pass "kubectl dry-run (default values)"
  else
    log_fail "kubectl dry-run (default values)"
  fi
else
  log_skip "kubectl dry-run (default) — no reachable cluster"
fi
echo ""

# ── Step 6: kubectl dry-run (production) ─────────────────────
echo "--- Step 6: kubectl dry-run validation (production) ---"
if [[ "$KUBECTL_REACHABLE" == "true" ]] && [[ -f "$PROD_VALUES" ]]; then
  if echo "$TEMPLATE_PROD" | "$KUBECTL_CMD" apply --dry-run=client -f - &>/dev/null; then
    log_pass "kubectl dry-run (production values)"
  else
    log_fail "kubectl dry-run (production values)"
  fi
elif [[ "$KUBECTL_REACHABLE" != "true" ]]; then
  log_skip "kubectl dry-run (production) — no reachable cluster"
else
  log_skip "kubectl dry-run (production) — values-production.yaml not found"
fi
echo ""

# ── Step 7: Helm test template exists ────────────────────────
echo "--- Step 7: Helm test template check ---"
if [[ -f "$CHART_DIR/templates/tests/test-connection.yaml" ]]; then
  log_pass "Helm test template exists"
else
  log_fail "Helm test template missing"
fi
echo ""

# ── Step 8: Runbook exists ───────────────────────────────────
echo "--- Step 8: Runbook check ---"
RUNBOOK="$PROJECT_ROOT/docs/runbooks/k8s-deploy.md"
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
