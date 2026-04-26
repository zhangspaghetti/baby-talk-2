#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# batch-ingest.sh — 批量导入文献到 MemPalace ingestion 管道
#
# 用法: ADMIN_ACCESS_TOKEN=... ./scripts/batch-ingest.sh <文献目录> [ADMIN_API_BASE_URL]
#
# 遍历目录中的所有文件，对每个文件：
#   1. 从文件名推断 bookTitle（去掉扩展名，替换下划线/连字符为空格）
#   2. curl POST /api/admin/knowledge/ingestion/upload（multipart: file + bookTitle）
#   3. 记录 jobId
#   4. 轮询 job 状态直到 COMPLETED / FAILED
#   5. sleep 1s（rate limiting）
# 最后输出汇总：成功 / 失败 / 总数
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── 参数 ──
DOCS_DIR="${1:?用法: ADMIN_ACCESS_TOKEN=... $0 <文献目录> [ADMIN_API_BASE_URL]}"
API_BASE="${2:-http://localhost:8081}"
UPLOAD_URL="${API_BASE}/api/admin/knowledge/ingestion/upload"
JOBS_URL="${API_BASE}/api/admin/knowledge/ingestion/jobs"
ADMIN_ACCESS_TOKEN="${ADMIN_ACCESS_TOKEN:-}"

if [ -z "$ADMIN_ACCESS_TOKEN" ]; then
    echo "错误: 需要 ADMIN_ACCESS_TOKEN 环境变量。请先调用 /api/admin/auth/login 获取管理员 access token。" >&2
    exit 1
fi

# ── 计数器 ──
TOTAL=0
SUCCESS=0
FAILED=0
SKIPPED=0

# ── 轮询配置 ──
POLL_INTERVAL=3       # 秒
POLL_MAX_ATTEMPTS=120  # 最多轮询次数（~6 分钟）

# ── 颜色输出 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_fail()  { echo -e "${RED}[FAIL]${NC}  $*"; }

# ── 从文件名提取 bookTitle ──
extract_book_title() {
    local filename
    filename="$(basename "$1")"
    # 去掉扩展名
    filename="${filename%.*}"
    # 替换下划线和连字符为空格
    filename="${filename//_/ }"
    filename="${filename//-/ }"
    echo "$filename"
}

# ── 轮询 job 状态直到终态 ──
poll_job_status() {
    local job_id="$1"
    local attempt=0
    local status=""

    while [ "$attempt" -lt "$POLL_MAX_ATTEMPTS" ]; do
        local response
        response=$(curl -s -w "\n%{http_code}" \
            -H "Authorization: Bearer ${ADMIN_ACCESS_TOKEN}" \
            "${JOBS_URL}/${job_id}" 2>/dev/null) || true
        local http_code
        http_code=$(echo "$response" | tail -1)
        local body
        body=$(echo "$response" | sed '$d')

        if [ "$http_code" != "200" ]; then
            log_warn "轮询 job ${job_id} 返回 HTTP ${http_code}，等待重试..."
            sleep "$POLL_INTERVAL"
            attempt=$((attempt + 1))
            continue
        fi

        # 解析 status 字段（兼容无 jq 环境）
        status=$(echo "$body" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)

        case "$status" in
            COMPLETED)
                local chunks
                chunks=$(echo "$body" | grep -o '"totalChunks":[0-9]*' | head -1 | cut -d':' -f2)
                log_ok "job ${job_id} 完成，生成 ${chunks:-?} 个 chunks"
                return 0
                ;;
            FAILED)
                local err_msg
                err_msg=$(echo "$body" | grep -o '"errorMessage":"[^"]*"' | head -1 | cut -d'"' -f4)
                log_fail "job ${job_id} 失败: ${err_msg:-未知错误}"
                return 1
                ;;
            PENDING|PROCESSING)
                # 仍在处理中
                ;;
            *)
                log_warn "job ${job_id} 未知状态: ${status}"
                ;;
        esac

        sleep "$POLL_INTERVAL"
        attempt=$((attempt + 1))
    done

    log_fail "job ${job_id} 轮询超时（${POLL_MAX_ATTEMPTS} 次尝试）"
    return 1
}

# ── 主流程 ──
if [ ! -d "$DOCS_DIR" ]; then
    echo "错误: 目录不存在: $DOCS_DIR" >&2
    exit 1
fi

log_info "批量导入开始"
log_info "文献目录: $DOCS_DIR"
log_info "Admin API: $UPLOAD_URL"
echo "────────────────────────────────────────"

for filepath in "$DOCS_DIR"/*; do
    # 跳过目录
    [ -f "$filepath" ] || continue

    TOTAL=$((TOTAL + 1))
    filename="$(basename "$filepath")"
    book_title="$(extract_book_title "$filepath")"

    log_info "[${TOTAL}] 上传: ${filename} (bookTitle: ${book_title})"

    # 上传文件
    upload_response=$(curl -s -w "\n%{http_code}" \
        -X POST "$UPLOAD_URL" \
        -H "Authorization: Bearer ${ADMIN_ACCESS_TOKEN}" \
        -F "file=@${filepath}" \
        -F "bookTitle=${book_title}" \
        2>/dev/null) || true

    http_code=$(echo "$upload_response" | tail -1)
    body=$(echo "$upload_response" | sed '$d')

    if [ "$http_code" != "202" ]; then
        log_fail "上传失败 (HTTP ${http_code}): ${filename}"
        log_fail "响应: ${body}"
        FAILED=$((FAILED + 1))
        sleep 1
        continue
    fi

    # 提取 jobId
    job_id=$(echo "$body" | grep -o '"jobId":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -z "$job_id" ]; then
        log_fail "无法解析 jobId: ${filename}"
        FAILED=$((FAILED + 1))
        sleep 1
        continue
    fi

    log_info "  jobId: ${job_id}"

    # 轮询直到完成
    if poll_job_status "$job_id"; then
        SUCCESS=$((SUCCESS + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    # Rate limiting
    sleep 1
done

# ── 汇总 ──
echo ""
echo "════════════════════════════════════════"
echo "  批量导入完成"
echo "────────────────────────────────────────"
echo -e "  总数:   ${TOTAL}"
echo -e "  ${GREEN}成功:   ${SUCCESS}${NC}"
echo -e "  ${RED}失败:   ${FAILED}${NC}"
if [ "$TOTAL" -gt 0 ]; then
    RATE=$((SUCCESS * 100 / TOTAL))
    echo -e "  成功率: ${RATE}%"
fi
echo "════════════════════════════════════════"

# 非零退出码如果有失败
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
