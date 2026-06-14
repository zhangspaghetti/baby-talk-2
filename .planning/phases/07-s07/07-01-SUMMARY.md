---
phase: "07"
plan: "01"
---

# T01: 补齐 docker-compose 8 个 M005 环境变量、创建 .env.example、修复 CI 脚本 ./mvnw → mvn

**补齐 docker-compose 8 个 M005 环境变量、创建 .env.example、修复 CI 脚本 ./mvnw → mvn**

## What Happened

完成三项独立修改：

1. **docker-compose.yml** — 在 backend environment 段末尾追加 8 个 M005 新增变量：AI 三件套（BASE_URL/API_KEY/MODEL）、MENTOR_SESSION_TIMEOUT、MENTOR_PRACTICE_RESPONSE_MAX_LENGTH、KG_REVIEW 三件套（ENABLED/INTERVAL/BATCH_SIZE）。所有变量名和默认值与 application.yml 的 ${} 占位符完全对齐。KG_REVIEW_ENABLED 本地开发默认 false（关闭 KG 审查定时任务），与 application.yml 的生产默认 true 有意不同。

2. **.env.example** — 新建文件，列出所有 docker-compose 引用的可配置环境变量（AI、Embedding、Mentor、KG Review），附中文注释说明用途和默认值。.gitignore 已有 `!.env.example` 规则允许提交。

3. **ci/backend-test.sh** — 将 `./mvnw verify -B` 修正为 `mvn verify -B`，与 S01 删除 mvnw wrapper 的决定保持一致。

## Verification

运行 4 项验证命令全部通过：docker-compose config 解析成功、3 个关键变量名 grep 匹配、.env.example 文件存在、CI 脚本包含 `mvn verify` 且不含 `./mvnw`。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `docker-compose config > /dev/null 2>&1` | 0 | ✅ pass | 1200ms |
| 2 | `grep -q BABY_TALK_AI_BASE_URL docker-compose.yml && grep -q BABY_TALK_KG_REVIEW_ENABLED docker-compose.yml && grep -q BABY_TALK_MENTOR_SESSION_TIMEOUT docker-compose.yml` | 0 | ✅ pass | 50ms |
| 3 | `test -f .env.example` | 0 | ✅ pass | 10ms |
| 4 | `grep -q 'mvn verify' ci/backend-test.sh && ! grep -q './mvnw' ci/backend-test.sh` | 0 | ✅ pass | 10ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `docker-compose.yml`
- `.env.example`
- `ci/backend-test.sh`
