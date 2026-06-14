# S07 Research: 部署更新 + 文档 + 端到端验证

**Date:** 2026-04-20

## Summary

S07 是 M005 的收尾切片，工作范围明确且模式成熟：(1) docker-compose.yml 补齐 S02-S06 新增的环境变量（Embedding、KG、Search Mode、Session Timeout、Practice 等），(2) Helm chart values.yaml / values-production.yaml 同步 10 个缺失的 BABY_TALK_* 变量到 config/secret，(3) README.md 全面更新为 PostgreSQL + pgvector + MinIO 架构、MemPalace 知识宫殿功能描述、新增环境变量文档，(4) docs/runbooks/ 新增 M005 运维手册（ingestion、知识宫殿运维、KG 矛盾处理），(5) 端到端验证脚本 + docker-compose up 健康检查。

所有工作基于已有模式（S01 建立的 docker-compose 模式、现有 Helm chart 结构、现有 README 格式），无技术风险。关键约束：Helm chart 的 configmap.yaml 和 secret.yaml 模板使用 range 遍历 values，只需在 values.yaml 添加 key-value 即可自动生效。

## Recommendation

按自然分层拆分：T01 docker-compose 补全 + .env.example 创建 → T02 Helm chart 同步 → T03 文档全面更新（README + runbooks）→ T04 端到端验证脚本。T01 最先因为 docker-compose 是本地开发入口，T04 最后因为验证脚本依赖前面的文件变更。

## Implementation Landscape

### Key Files

- `docker-compose.yml` — 需补齐 10 个缺失环境变量（BABY_TALK_MENTOR_SESSION_TIMEOUT, BABY_TALK_MENTOR_PRACTICE_RESPONSE_MAX_LENGTH, BABY_TALK_KG_REVIEW_INTERVAL, BABY_TALK_KG_REVIEW_ENABLED, BABY_TALK_KG_REVIEW_BATCH_SIZE, BABY_TALK_AI_API_KEY, BABY_TALK_AI_BASE_URL, BABY_TALK_AI_MODEL）+ 切换 MENTOR_PROVIDER_MODE 为可配置
- `.env.example` — 新建：列出所有 docker-compose 引用的环境变量及默认值，方便开发者 `cp .env.example .env`
- `deploy/helm/babytalk/values.yaml` — config 段需添加 7 个非敏感变量（SEARCH_MODE, SESSION_TIMEOUT, PRACTICE_RESPONSE_MAX_LENGTH, KG_REVIEW_*, EMBEDDING_BASE_URL, EMBEDDING_MODEL, EMBEDDING_DIMENSIONS），secret 段需添加 1 个敏感变量（BABY_TALK_EMBEDDING_API_KEY）
- `deploy/helm/babytalk/values-production.yaml` — 同步 values.yaml 新增变量的生产值覆盖
- `README.md` — 全面重写：项目描述更新为 MemPalace 知识宫殿、环境变量表补齐 M005 新增项、Docker 本地开发段落更新为 PostgreSQL+MinIO+backend 三服务、Agentic Search 功能介绍、批量导入脚本说明
- `docs/runbooks/m005-mempalace-ops.md` — 新建：知识宫殿运维手册（文献导入、Embedding 配置、KG 矛盾审查流程、search-mode 切换、会话超时调整）
- `docs/runbooks/k8s-deploy.md` — 更新：补充 M005 新增 Secret 和 ConfigMap 变量说明
- `scripts/verify-e2e.sh` — 新建：端到端验证脚本（docker-compose up → health check → API smoke test → docker-compose down）

### docker-compose.yml 变量缺口分析

当前 docker-compose.yml backend environment 段缺少以下变量（已在 application.yml 有对应 ${ENV_VAR:default} 占位符）：

| 变量 | 类型 | 建议值（docker-compose 本地） |
|------|------|-----|
| BABY_TALK_AI_BASE_URL | pass-through | `${BABY_TALK_AI_BASE_URL:-https://models.inference.ai.azure.com}` |
| BABY_TALK_AI_API_KEY | pass-through | `${BABY_TALK_AI_API_KEY:-}` |
| BABY_TALK_AI_MODEL | pass-through | `${BABY_TALK_AI_MODEL:-gpt-4o-mini}` |
| BABY_TALK_MENTOR_SESSION_TIMEOUT | 直接值 | `PT30M`（默认即可） |
| BABY_TALK_MENTOR_PRACTICE_RESPONSE_MAX_LENGTH | 直接值 | `2000` |
| BABY_TALK_KG_REVIEW_ENABLED | 直接值 | `false`（本地开发默认关闭 KG 审查） |
| BABY_TALK_KG_REVIEW_INTERVAL | 直接值 | `PT5M` |
| BABY_TALK_KG_REVIEW_BATCH_SIZE | 直接值 | `10` |

### Helm chart 变量缺口分析

values.yaml config 段缺少 7 个非敏感变量：

```yaml

# M005 新增 — MemPalace

BABY_TALK_MENTOR_SEARCH_MODE: "agentic"
BABY_TALK_MENTOR_SESSION_TIMEOUT: "PT30M"
BABY_TALK_MENTOR_PRACTICE_RESPONSE_MAX_LENGTH: "2000"
BABY_TALK_EMBEDDING_BASE_URL: "https://models.inference.ai.azure.com"
BABY_TALK_EMBEDDING_MODEL: "text-embedding-3-small"
BABY_TALK_EMBEDDING_DIMENSIONS: "1536"
BABY_TALK_KG_REVIEW_INTERVAL: "PT5M"
BABY_TALK_KG_REVIEW_ENABLED: "true"
BABY_TALK_KG_REVIEW_BATCH_SIZE: "10"
```

values.yaml secret 段缺少 1 个敏感变量：

```yaml
BABY_TALK_EMBEDDING_API_KEY: ""
```

### Build Order

1. **T01: docker-compose 补全 + .env.example** — 补齐环境变量，创建 .env.example，确保 `docker-compose config` 无报错
2. **T02: Helm chart 同步** — values.yaml + values-production.yaml 添加 M005 变量，`helm lint` / `helm template` 验证
3. **T03: 文档更新** — README.md 全面更新 + docs/runbooks/m005-mempalace-ops.md 新建 + k8s-deploy.md 更新
4. **T04: 端到端验证脚本** — scripts/verify-e2e.sh 端到端验证脚本（docker-compose up → 健康检查 → API smoke → 清理）

### Verification Approach

- T01: `docker-compose config` 退出码 0，所有新增变量均出现在输出中
- T02: `helm lint deploy/helm/babytalk/` 通过 + `helm template babytalk deploy/helm/babytalk/` 输出包含新增变量
- T03: README.md 包含 PostgreSQL/MinIO/MemPalace 关键词，runbook 文件存在且非空
- T04: `bash -n scripts/verify-e2e.sh` 语法检查通过

## Constraints

- Helm chart configmap.yaml 和 secret.yaml 使用 `range $key, $value := .Values.config/secret` 自动遍历，只需在 values.yaml 添加 kv 即可生效——不需要修改模板文件
- docker-compose.yml 中 backend 的 `build.context: ./backend` 表示 Dockerfile 在 `backend/` 目录
- ci/backend-test.sh 使用 `./mvnw verify`，但 S01 已将 Dockerfile 改为 `mvn`（不再使用 mvnw）——ci 脚本仍引用 ./mvnw，CI 环境需要 mvnw 存在或改为 mvn
- `.gitignore` 已配置 `.env` 和 `.env.*` 排除但 `!.env.example` 允许提交
- 移动端 API base URL 默认 `http://127.0.0.1:8080`，安卓模拟器需使用 `http://10.0.2.2:8080`，通过 `--dart-define=BABY_TALK_API_BASE_URL=http://10.0.2.2:8080` 配置

## Common Pitfalls

- **Helm values.yaml 中值必须是字符串** — 数字、布尔值需用引号包裹（如 `"1536"`、`"true"`），否则 configmap.yaml 的 `{{ $value | quote }}` 可能处理不一致
- **ci/backend-test.sh 引用 ./mvnw** — S01 已删除 mvnw wrapper 文件改用镜像内置 mvn。CI 脚本需改为 `mvn verify -B`（或恢复 mvnw）。这是 S01 的遗留问题，S07 文档更新时应一并修复

## Requirements Advanced

None.

## Requirements Validated

None — 实际验证将在 T04 执行时完成。

## Requirements Invalidated or Re-scoped

None.
