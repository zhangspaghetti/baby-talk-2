---
phase: "02"
plan: "04"
---

# T04: feat: 创建批量导入脚本(batch-ingest.sh/.cmd)和 S02 端到端验证脚本(verify-s02.sh)

**feat: 创建批量导入脚本(batch-ingest.sh/.cmd)和 S02 端到端验证脚本(verify-s02.sh)**

## What Happened

创建了三个脚本文件完成 S02 slice 的最后一项任务：

1. **scripts/batch-ingest.sh** — Linux/Mac 批量导入脚本：遍历指定目录中的文件，从文件名推断 bookTitle（去扩展名、替换下划线/连字符为空格），通过 curl POST multipart 上传到 /api/v1/ingestion/upload，轮询 job 状态直到 COMPLETED/FAILED，每个文件间 sleep 1s 做 rate limiting，最后输出成功/失败/总数汇总。支持两个参数：文献目录路径和 API base URL（默认 http://localhost:8080）。

2. **scripts/batch-ingest.cmd** — Windows CMD 版本，功能与 bash 版一致。使用 setlocal enabledelayedexpansion 处理变量延迟展开，findstr 解析 JSON 响应，timeout 做延迟。

3. **scripts/verify-s02.sh** — S02 端到端验证脚本：docker compose up → 等待 backend healthy → 创建测试文件并上传 → 轮询 job 状态 → psql 检查 vector_store 表有记录 → 检查 ingestion_jobs 表状态 → docker compose down -v 清理。支持 SKIP_DOCKER=1 环境变量跳过 docker 启停（手动验证用）。

前一次验证失败的原因是 slice 级验证在错误的工作目录下运行 `test -f`，所有 T03 产出的文件实际都存在于正确路径。

## Verification

T04 验证命令全部通过：

- `test -f scripts/batch-ingest.sh` → 通过
- `test -f scripts/batch-ingest.cmd` → 通过
- `test -f scripts/verify-s02.sh` → 通过
- `bash -n scripts/batch-ingest.sh` → 语法正确
- `bash -n scripts/verify-s02.sh` → 语法正确

Slice 级文件检查全部通过：

- IngestionController.java 存在
- PalaceSearchService.java 存在
- IngestionControllerTest.java 存在
- PalaceSearchServiceTest.java 存在
- IngestionServiceIntegrationTest.java 存在

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `test -f scripts/batch-ingest.sh && test -f scripts/batch-ingest.cmd && test -f scripts/verify-s02.sh && bash -n scripts/batch-ingest.sh && bash -n scripts/verify-s02.sh` | 0 | ✅ pass | 150ms |
| 2 | `test -f backend/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionController.java` | 0 | ✅ pass | 20ms |
| 3 | `test -f backend/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceSearchService.java` | 0 | ✅ pass | 20ms |
| 4 | `test -f backend/src/test/java/com/zhangspaghetti/babytalk/ingestion/IngestionControllerTest.java` | 0 | ✅ pass | 20ms |
| 5 | `test -f backend/src/test/java/com/zhangspaghetti/babytalk/palace/PalaceSearchServiceTest.java` | 0 | ✅ pass | 20ms |
| 6 | `test -f backend/src/test/java/com/zhangspaghetti/babytalk/ingestion/IngestionServiceIntegrationTest.java` | 0 | ✅ pass | 20ms |

## Deviations

None.

## Known Issues

Windows CMD 版 batch-ingest.cmd 的 JSON 解析较脆弱（依赖 findstr 正则匹配），如果 API 响应格式变化可能需要调整。

## Files Created/Modified

- `scripts/batch-ingest.sh`
- `scripts/batch-ingest.cmd`
- `scripts/verify-s02.sh`
