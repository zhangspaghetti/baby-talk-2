#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# verify-s02.sh — S02 端到端验证脚本
#
# 完整流程:
#   1. docker-compose up -d (启动 postgres + minio + backend)
#   2. 等待 backend healthy
#   3. curl 上传测试文件
#   4. 轮询 job 状态直到终态
#   5. psql 检查 vector_store 有记录
#   6. 检查 ingestion_jobs 表有正确状态
#   7. docker-compose down -v (清理)
#
# 用法: ./scripts/verify-s02.sh
#
# 环境变量:
#   BABY_TALK_EMBEDDING_API_KEY — embedding API key（必需）
#   BABY_TALK_EMBEDDING_BASE_URL — 默认 https://models.inference.ai.azure.com
#   BABY_TALK_EMBEDDING_MODEL — 默认 text-embedding-3-small
#   SKIP_DOCKER — 设为 1 跳过 docker 启停（用于手动验证）
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── 配置 ──
API_BASE="http://localhost:8080"
UPLOAD_URL="${API_BASE}/api/v1/ingestion/upload"
JOBS_URL="${API_BASE}/api/v1/ingestion/jobs"
HEALTH_URL="${API_BASE}/actuator/health"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"
SKIP_DOCKER="${SKIP_DOCKER:-0}"

# ── 颜色 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

check_pass() { echo -e "  ${GREEN}✓ PASS${NC}: $1"; PASS=$((PASS + 1)); }
check_fail() { echo -e "  ${RED}✗ FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }

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

log_info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# ──────────────────────────────────────────
# Step 0: 前置检查
# ──────────────────────────────────────────
echo "════════════════════════════════════════"
echo "  S02 端到端验证"
echo "════════════════════════════════════════"
echo ""

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
log_info "Step 2: 等待 backend 健康检查..."
MAX_WAIT=120
WAITED=0
while [ "$WAITED" -lt "$MAX_WAIT" ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null) || HTTP_CODE="000"
    if [ "$HTTP_CODE" = "200" ]; then
        check_pass "Backend 健康检查通过 (${WAITED}s)"
        break
    fi
    sleep 3
    WAITED=$((WAITED + 3))
done
if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    check_fail "Backend 未在 ${MAX_WAIT}s 内启动"
    echo "跳过后续检查。"
    exit 1
fi

# ──────────────────────────────────────────
# Step 3: 创建测试文件并上传
# ──────────────────────────────────────────
log_info "Step 3: 上传测试文件..."

# 创建临时测试文件
TEST_FILE=$(mktemp /tmp/test-document-XXXXXX.txt)
cat > "$TEST_FILE" <<'CONTENT'
Baby Talk: A Parent's Guide to Early Language Development

Chapter 1: The First Year of Communication

Babies begin communicating from birth. Through cries, coos, and gurgles, infants
express their needs and begin to understand the rhythm of language. Research shows
that responsive parenting—talking to babies, narrating daily activities, and
responding to their vocalizations—significantly boosts language development.

Key milestones in the first year:
- 0-3 months: Cooing and gurgling sounds
- 4-6 months: Babbling begins (ba-ba, da-da)
- 7-9 months: Varied babbling with intonation
- 10-12 months: First recognizable words

The importance of parentese (infant-directed speech) cannot be overstated.
Studies from the University of Washington demonstrate that babies exposed to
parentese develop larger vocabularies by age two.
CONTENT

BOOK_TITLE="Baby Talk"

UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "$UPLOAD_URL" \
    -F "file=@${TEST_FILE}" \
    -F "bookTitle=${BOOK_TITLE}" \
    2>/dev/null)
HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -1)
BODY=$(echo "$UPLOAD_RESPONSE" | sed '$d')

rm -f "$TEST_FILE"

if [ "$HTTP_CODE" = "202" ]; then
    check_pass "文件上传成功 (HTTP 202)"
else
    check_fail "文件上传失败 (HTTP ${HTTP_CODE}): ${BODY}"
    exit 1
fi

# 提取 jobId
JOB_ID=$(echo "$BODY" | grep -o '"jobId":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -n "$JOB_ID" ]; then
    check_pass "获取 jobId: ${JOB_ID}"
else
    check_fail "无法解析 jobId"
    exit 1
fi

# ──────────────────────────────────────────
# Step 4: 轮询 job 状态
# ──────────────────────────────────────────
log_info "Step 4: 轮询 job 状态..."
POLL_MAX=60
POLL_WAITED=0
FINAL_STATUS=""
while [ "$POLL_WAITED" -lt "$POLL_MAX" ]; do
    STATUS_RESPONSE=$(curl -s "${JOBS_URL}/${JOB_ID}" 2>/dev/null)
    FINAL_STATUS=$(echo "$STATUS_RESPONSE" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)

    case "$FINAL_STATUS" in
        COMPLETED)
            CHUNKS=$(echo "$STATUS_RESPONSE" | grep -o '"totalChunks":[0-9]*' | head -1 | cut -d':' -f2)
            check_pass "Job 完成 (${POLL_WAITED}s), ${CHUNKS:-?} chunks 生成"
            break
            ;;
        FAILED)
            ERR=$(echo "$STATUS_RESPONSE" | grep -o '"errorMessage":"[^"]*"' | head -1 | cut -d'"' -f4)
            check_fail "Job 失败: ${ERR:-未知错误}"
            break
            ;;
    esac
    sleep 3
    POLL_WAITED=$((POLL_WAITED + 3))
done
if [ "$POLL_WAITED" -ge "$POLL_MAX" ]; then
    check_fail "Job 轮询超时 (status=${FINAL_STATUS:-unknown})"
fi

# ──────────────────────────────────────────
# Step 5: 检查 vector_store 表有数据
# ──────────────────────────────────────────
log_info "Step 5: 检查 vector_store 表..."

PG_HOST="localhost"
PG_PORT="15432"
PG_USER="babytalk"
PG_DB="babytalk"
export PGPASSWORD="babytalk"

if command -v psql &>/dev/null; then
    VECTOR_COUNT=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" \
        -t -c "SELECT COUNT(*) FROM vector_store;" 2>/dev/null | tr -d ' ') || VECTOR_COUNT="error"

    if [ "$VECTOR_COUNT" != "error" ] && [ "$VECTOR_COUNT" -gt 0 ] 2>/dev/null; then
        check_pass "vector_store 有 ${VECTOR_COUNT} 条记录"
    else
        check_fail "vector_store 无记录 (count=${VECTOR_COUNT})"
    fi
else
    log_warn "psql 不可用，跳过 vector_store 直接检查"
    # 通过 docker exec 检查
    if [ "$SKIP_DOCKER" != "1" ]; then
        VECTOR_COUNT=$(docker exec babytalk-postgres \
            psql -U babytalk -d babytalk -t -c "SELECT COUNT(*) FROM vector_store;" 2>/dev/null | tr -d ' ') || VECTOR_COUNT="error"
        if [ "$VECTOR_COUNT" != "error" ] && [ "$VECTOR_COUNT" -gt 0 ] 2>/dev/null; then
            check_pass "vector_store 有 ${VECTOR_COUNT} 条记录 (via docker exec)"
        else
            check_fail "vector_store 无记录 (count=${VECTOR_COUNT})"
        fi
    else
        log_warn "跳过 vector_store 检查（无 psql 且 SKIP_DOCKER=1）"
    fi
fi

# ──────────────────────────────────────────
# Step 6: 检查 ingestion_jobs 表
# ──────────────────────────────────────────
log_info "Step 6: 检查 ingestion_jobs 表..."

run_pg_query() {
    local query="$1"
    if command -v psql &>/dev/null; then
        psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -t -c "$query" 2>/dev/null | tr -d ' '
    elif [ "$SKIP_DOCKER" != "1" ]; then
        docker exec babytalk-postgres psql -U babytalk -d babytalk -t -c "$query" 2>/dev/null | tr -d ' '
    else
        echo "unavailable"
    fi
}

JOB_STATUS=$(run_pg_query "SELECT status FROM ingestion_jobs WHERE id='${JOB_ID}';" 2>/dev/null) || JOB_STATUS="error"
if [ "$JOB_STATUS" = "COMPLETED" ]; then
    check_pass "ingestion_jobs 记录状态 COMPLETED"
elif [ "$JOB_STATUS" = "unavailable" ]; then
    log_warn "无法访问数据库，跳过 ingestion_jobs 检查"
else
    check_fail "ingestion_jobs 状态异常: ${JOB_STATUS}"
fi

unset PGPASSWORD

# ──────────────────────────────────────────
# 汇总
# ──────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "  S02 端到端验证结果"
echo "────────────────────────────────────────"
echo -e "  ${GREEN}通过: ${PASS}${NC}"
echo -e "  ${RED}失败: ${FAIL}${NC}"
echo "════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
