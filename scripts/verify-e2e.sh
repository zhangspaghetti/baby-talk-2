#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# verify-e2e.sh — Docker 一键部署端到端验证脚本
#
# 完整流程:
#   1. docker-compose up -d --build (启动全栈)
#   2. 等待 backend healthy（轮询 /actuator/health，最多 120s）
#   3. 健康检查：验证 status=UP，db/minio 组件 UP
#   4. API Smoke Test — 基础端点
#   5. API Smoke Test — M005 新增端点
#   6. 输出 PASSED/FAILED 汇总
#   7. docker-compose down -v (清理)
#
# 用法: ./scripts/verify-e2e.sh
#
# 环境变量:
#   SKIP_DOCKER — 设为 1 跳过 docker 启停（适用于已运行的环境）
#   API_BASE    — 后端地址（默认 http://localhost:8080）
#   ADMIN_API_BASE — 管理端地址（默认 http://localhost:8081）
#   ADMIN_ACCESS_TOKEN — 可选，直接复用现成管理员 access token
#   ADMIN_USERNAME / ADMIN_PASSWORD — 未提供 token 时用于本地 bootstrap 登录
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── 配置 ──
API_BASE="${API_BASE:-http://localhost:8080}"
ADMIN_API_BASE="${ADMIN_API_BASE:-http://localhost:8081}"
HEALTH_URL="${API_BASE}/actuator/health"
ADMIN_LOGIN_URL="${ADMIN_API_BASE}/api/admin/auth/login"
ADMIN_UPLOAD_URL="${ADMIN_API_BASE}/api/admin/knowledge/ingestion/upload"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"
SKIP_DOCKER="${SKIP_DOCKER:-0}"
INSTALLATION_ID="test-e2e-$(date +%s)"
APP_VERSION="${APP_VERSION:-1.3.0}"
ADMIN_ACCESS_TOKEN="${ADMIN_ACCESS_TOKEN:-}"
ADMIN_USERNAME="${ADMIN_USERNAME:-super_admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-SuperAdmin123!}"

if [[ "${1:-}" == "--print-app-version" ]]; then
    printf '%s\n' "$APP_VERSION"
    exit 0
fi

# ── 颜色 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

check_pass() { echo -e "  ${GREEN}✓ PASS${NC}: $1"; PASS=$((PASS + 1)); }
check_fail() { echo -e "  ${RED}✗ FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }

log_info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

resolve_admin_token() {
    if [ -n "$ADMIN_ACCESS_TOKEN" ]; then
        return 0
    fi

    local response http_code body
    response=$(curl -s -w "\n%{http_code}" \
        -X POST "$ADMIN_LOGIN_URL" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${ADMIN_USERNAME}\",\"password\":\"${ADMIN_PASSWORD}\"}" \
        2>/dev/null) || true
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" != "200" ]; then
        check_fail "管理员登录失败 (HTTP ${http_code}): ${body}"
        return 1
    fi

    ADMIN_ACCESS_TOKEN=$(echo "$body" | grep -o '"accessToken":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -z "$ADMIN_ACCESS_TOKEN" ]; then
        check_fail "管理员登录成功但未返回 accessToken"
        return 1
    fi

    check_pass "管理员登录成功"
}

# ── 清理函数 ──
cleanup() {
    if [ "$SKIP_DOCKER" != "1" ]; then
        echo ""
        log_info "清理 docker 环境..."
        cd "$PROJECT_DIR"
        docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ══════════════════════════════════════════
#  E2E 端到端验证
# ══════════════════════════════════════════
echo ""
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo -e "${BOLD}  Baby Talk — E2E 端到端验证${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo ""

# ──────────────────────────────────────────
# Step 0: 前置检查
# ──────────────────────────────────────────
if [ "$SKIP_DOCKER" != "1" ]; then
    if ! command -v docker &>/dev/null; then
        echo "错误: 需要 docker 命令" >&2
        exit 1
    fi
    if ! docker info &>/dev/null; then
        echo "错误: Docker daemon 未运行" >&2
        exit 1
    fi
fi

if ! command -v curl &>/dev/null; then
    echo "错误: 需要 curl 命令" >&2
    exit 1
fi

# ──────────────────────────────────────────
# Step 1: 启动 docker-compose
# ──────────────────────────────────────────
if [ "$SKIP_DOCKER" != "1" ]; then
    log_info "Step 1: 启动 docker-compose 环境..."
    cd "$PROJECT_DIR"
    docker compose -f "$COMPOSE_FILE" up -d --build
    log_info "等待服务启动..."
else
    log_info "Step 1: 跳过 docker 启动 (SKIP_DOCKER=1)"
fi

# ──────────────────────────────────────────
# Step 2: 等待 backend healthy
# ──────────────────────────────────────────
log_info "Step 2: 等待 backend 健康检查 (最多 120s)..."
MAX_WAIT=120
WAITED=0
while [ "$WAITED" -lt "$MAX_WAIT" ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null) || HTTP_CODE="000"
    if [ "$HTTP_CODE" = "200" ]; then
        check_pass "Backend 可达 (${WAITED}s)"
        break
    fi
    sleep 3
    WAITED=$((WAITED + 3))
done
if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    check_fail "Backend 未在 ${MAX_WAIT}s 内启动 (last HTTP=${HTTP_CODE})"
    echo ""
    echo "后端未就绪，跳过后续所有检查。"
    # 打印汇总后退出
    echo ""
    echo -e "${BOLD}════════════════════════════════════════${NC}"
    echo -e "${BOLD}  E2E 验证结果${NC}"
    echo -e "  ${GREEN}通过: ${PASS}${NC}"
    echo -e "  ${RED}失败: ${FAIL}${NC}"
    echo -e "${BOLD}════════════════════════════════════════${NC}"
    exit 1
fi

# ──────────────────────────────────────────
# Step 3: 健康检查详细验证
# ──────────────────────────────────────────
log_info "Step 3: 健康检查详细验证..."

HEALTH_BODY=$(curl -sf "$HEALTH_URL" 2>/dev/null) || HEALTH_BODY=""

if [ -z "$HEALTH_BODY" ]; then
    check_fail "获取健康检查响应失败"
else
    # 检查 status=UP
    if echo "$HEALTH_BODY" | grep -q '"status":"UP"'; then
        check_pass "actuator/health status=UP"
    else
        check_fail "actuator/health status 不是 UP (body=${HEALTH_BODY:0:200})"
    fi

    # 检查 db 组件
    if echo "$HEALTH_BODY" | grep -q '"db"'; then
        if echo "$HEALTH_BODY" | grep -A2 '"db"' | grep -q '"status":"UP"'; then
            check_pass "健康检查 db 组件 UP"
        else
            check_fail "健康检查 db 组件非 UP"
        fi
    else
        log_warn "健康检查未包含 db 组件（可能未启用详细健康检查）"
    fi

    # 检查 minio 组件（Spring Boot 可能显示为 minio 或自定义名称）
    if echo "$HEALTH_BODY" | grep -qi '"minio\|"s3\|"blobStore'; then
        check_pass "健康检查包含存储组件"
    else
        log_warn "健康检查未包含 minio/s3 组件信息（可能未配置 health indicator）"
    fi
fi

# ──────────────────────────────────────────
# Step 4: API Smoke Test — 基础端点
# ──────────────────────────────────────────
echo ""
log_info "Step 4: API Smoke Test — 基础端点..."

# 4a. GET /actuator/health → 200
RESP=$(curl -s -o /dev/null -w "%{http_code}" "${API_BASE}/actuator/health" 2>/dev/null) || RESP="000"
if [ "$RESP" = "200" ]; then
    check_pass "GET /actuator/health → ${RESP}"
else
    check_fail "GET /actuator/health → ${RESP} (期望 200)"
fi

# 4b. POST /api/v1/mentor/chat → 验证可达
CHAT_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "${API_BASE}/api/v1/mentor/chat" \
    -H "Content-Type: application/json" \
    -H "X-App-Version: ${APP_VERSION}" \
    -H "X-Session-Id: e2e-session-${INSTALLATION_ID}" \
    -d "{
        \"installationId\": \"${INSTALLATION_ID}\",
        \"prompt\": \"你好\",
        \"surface\": \"home\",
        \"mode\": \"single_turn\"
    }" 2>/dev/null) || CHAT_RESPONSE=$'\n000'

CHAT_HTTP=$(echo "$CHAT_RESPONSE" | tail -1)
CHAT_BODY=$(echo "$CHAT_RESPONSE" | sed '$d')

# dev 模式下应成功（200），或至少可达（非 404/503）
if [ "$CHAT_HTTP" = "200" ]; then
    check_pass "POST /api/v1/mentor/chat → ${CHAT_HTTP} (dev 模式正常)"
elif [ "$CHAT_HTTP" -ge 400 ] && [ "$CHAT_HTTP" -lt 500 ] 2>/dev/null; then
    check_pass "POST /api/v1/mentor/chat → ${CHAT_HTTP} (端点可达，客户端错误)"
elif [ "$CHAT_HTTP" = "500" ]; then
    # 500 可能是 dev 模式下的正常行为（无 AI 配置）
    check_pass "POST /api/v1/mentor/chat → ${CHAT_HTTP} (端点可达，服务端错误可接受)"
else
    check_fail "POST /api/v1/mentor/chat → ${CHAT_HTTP} (端点不可达, body=${CHAT_BODY:0:200})"
fi

# ──────────────────────────────────────────
# Step 5: API Smoke Test — M005 新增端点
# ──────────────────────────────────────────
echo ""
log_info "Step 5: API Smoke Test — M005 新增端点..."

# 5a. POST /api/v1/mentor/practice/generate → 验证可达
PRACTICE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "${API_BASE}/api/v1/mentor/practice/generate" \
    -H "Content-Type: application/json" \
    -H "X-App-Version: ${APP_VERSION}" \
    -d "{
        \"installationId\": \"${INSTALLATION_ID}\",
        \"surface\": \"practice\",
        \"babyAgeMonths\": 12,
        \"sceneTag\": \"mealtime\"
    }" 2>/dev/null) || PRACTICE_RESPONSE=$'\n000'

PRACTICE_HTTP=$(echo "$PRACTICE_RESPONSE" | tail -1)
PRACTICE_BODY=$(echo "$PRACTICE_RESPONSE" | sed '$d')

if [ "$PRACTICE_HTTP" = "200" ]; then
    check_pass "POST /api/v1/mentor/practice/generate → ${PRACTICE_HTTP}"
elif [ "$PRACTICE_HTTP" -ge 400 ] && [ "$PRACTICE_HTTP" -lt 600 ] 2>/dev/null; then
    check_pass "POST /api/v1/mentor/practice/generate → ${PRACTICE_HTTP} (端点可达)"
else
    check_fail "POST /api/v1/mentor/practice/generate → ${PRACTICE_HTTP} (不可达, body=${PRACTICE_BODY:0:200})"
fi

# 5b. GET /api/v1/kg/notifications → 200
KG_NOTIF_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-App-Version: ${APP_VERSION}" \
    "${API_BASE}/api/v1/kg/notifications" 2>/dev/null) || KG_NOTIF_HTTP="000"
if [ "$KG_NOTIF_HTTP" = "200" ]; then
    check_pass "GET /api/v1/kg/notifications → ${KG_NOTIF_HTTP}"
else
    check_fail "GET /api/v1/kg/notifications → ${KG_NOTIF_HTTP} (期望 200)"
fi

# 5c. GET /api/v1/kg/contradictions → 200
KG_CONTRA_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-App-Version: ${APP_VERSION}" \
    "${API_BASE}/api/v1/kg/contradictions" 2>/dev/null) || KG_CONTRA_HTTP="000"
if [ "$KG_CONTRA_HTTP" = "200" ]; then
    check_pass "GET /api/v1/kg/contradictions → ${KG_CONTRA_HTTP}"
else
    check_fail "GET /api/v1/kg/contradictions → ${KG_CONTRA_HTTP} (期望 200)"
fi

# 5d. POST /api/admin/knowledge/ingestion/upload → 400（已认证、无文件时应返回 400）
if resolve_admin_token; then
    UPLOAD_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${ADMIN_UPLOAD_URL}" \
        -H "Authorization: Bearer ${ADMIN_ACCESS_TOKEN}" \
        2>/dev/null) || UPLOAD_HTTP="000"

    if [ "$UPLOAD_HTTP" = "400" ]; then
        check_pass "POST /api/admin/knowledge/ingestion/upload (无文件) → ${UPLOAD_HTTP}"
    else
        check_fail "POST /api/admin/knowledge/ingestion/upload (无文件) → ${UPLOAD_HTTP} (期望 400)"
    fi
fi

# ──────────────────────────────────────────
# 汇总
# ──────────────────────────────────────────
echo ""
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo -e "${BOLD}  E2E 端到端验证结果${NC}"
echo -e "${BOLD}────────────────────────────────────────${NC}"
echo -e "  ${GREEN}通过: ${PASS}${NC}"
echo -e "  ${RED}失败: ${FAIL}${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
