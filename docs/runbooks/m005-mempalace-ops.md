# M005 MemPalace 运维手册

本手册覆盖 MemPalace 知识宫殿（M005）相关的运维操作，包括文献导入、Embedding 配置、知识图谱审查、搜索模式管理等。

## 目录

1. [文献导入操作](#文献导入操作)
2. [Embedding 配置](#embedding-配置)
3. [Knowledge Graph 矛盾审查](#knowledge-graph-矛盾审查)
4. [Search Mode 切换](#search-mode-切换)
5. [会话超时调整](#会话超时调整)
6. [动态练习生成](#动态练习生成)
7. [常见问题排查](#常见问题排查)

---

## 文献导入操作

### 批量导入（batch-ingest.sh）

`scripts/batch-ingest.sh` 脚本可一次性导入整个目录的文献文件。脚本现在调用受保护的 admin-api ingestion 路由，因此需要先准备管理员 access token：

```bash
export ADMIN_ACCESS_TOKEN=$(curl -s http://localhost:8081/api/admin/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"super_admin","password":"SuperAdmin123!"}' \
  | jq -r '.accessToken')
```

```bash
# 基本用法（默认连接 localhost:8081）
./scripts/batch-ingest.sh /path/to/docs/

# 指定 admin-api 地址（生产环境）
./scripts/batch-ingest.sh /path/to/docs/ https://admin-api.babytalk.example.com
```

**脚本流程：**

1. 遍历目录中的所有文件
2. 从文件名推断 `bookTitle`（去掉扩展名，替换 `_`/`-` 为空格）
3. 调用 `POST /api/admin/knowledge/ingestion/upload`（multipart: `file` + `bookTitle`）
4. 记录 `jobId` 并轮询状态（每 3 秒，最多 120 次 ≈ 6 分钟）
5. 每个文件之间 sleep 1s（内置限流）
6. 最终输出汇总：成功 / 失败 / 总数

脚本依赖 `ADMIN_ACCESS_TOKEN` 环境变量；如果 token 过期，请重新执行上面的登录命令。

**轮询超时配置（脚本内变量）：**

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `POLL_INTERVAL` | `3` | 轮询间隔（秒） |
| `POLL_MAX_ATTEMPTS` | `120` | 最大轮询次数 |

### 单本书手动上传

```bash
curl -X POST http://localhost:8081/api/admin/knowledge/ingestion/upload \
  -H "Authorization: Bearer ${ADMIN_ACCESS_TOKEN}" \
  -F "file=@/path/to/book.pdf" \
  -F "bookTitle=我的育儿书"
```

成功返回 HTTP 202 + `jobId`，后续可通过 Job API 查询进度：

```bash
# 查询 job 状态
curl http://localhost:8081/api/admin/knowledge/ingestion/jobs/{jobId} \
  -H "Authorization: Bearer ${ADMIN_ACCESS_TOKEN}"
```

Job 状态码：`PENDING` → `PROCESSING` → `COMPLETED` / `FAILED`

### 失败重试

若单个文件导入失败：

1. 检查 job 错误信息：`curl /api/admin/knowledge/ingestion/jobs/{jobId}` → `errorMessage` 字段
2. 常见失败原因：
   - 文件过大 → 检查 Spring 文件上传大小限制
   - Embedding API 限流 → 等待一段时间后重试
   - MinIO 连接失败 → 检查 MinIO 健康状态
3. 对 FAILED job 可直接调用 retry 接口：

```bash
curl -X POST http://localhost:8081/api/admin/knowledge/ingestion/jobs/{jobId}/retry \
  -H "Authorization: Bearer ${ADMIN_ACCESS_TOKEN}"
```

### K8s 环境导入

在 K8s 集群中执行批量导入：

```bash
# Port-forward 到 admin-api Service
kubectl port-forward -n babytalk svc/babytalk-admin-api 8081:8081 &

# 获取管理员 token
export ADMIN_ACCESS_TOKEN=$(curl -s http://localhost:8081/api/admin/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"super_admin","password":"<bootstrap-password>"}' \
  | jq -r '.accessToken')

# 在本地运行导入脚本
./scripts/batch-ingest.sh /path/to/docs/ http://localhost:8081
```

---

## Embedding 配置

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `BABY_TALK_EMBEDDING_BASE_URL` | `https://models.inference.ai.azure.com` | Embedding API 端点 |
| `BABY_TALK_EMBEDDING_API_KEY` | _(空)_ | Embedding API 密钥（**敏感，生产环境必须通过 Secret 注入**） |
| `BABY_TALK_EMBEDDING_MODEL` | `text-embedding-3-small` | Embedding 模型名称 |
| `BABY_TALK_EMBEDDING_DIMENSIONS` | `1536` | 向量维度 |

### 第三方 Proxy 配置

如果使用第三方 Embedding 代理（如自建 OpenAI 兼容代理），只需修改 `BABY_TALK_EMBEDDING_BASE_URL`：

```bash
# Docker Compose（.env 文件）
BABY_TALK_EMBEDDING_BASE_URL=https://your-proxy.example.com/v1

# Helm（values 覆盖）
helm upgrade babytalk deploy/helm/babytalk/ \
  --set config.BABY_TALK_EMBEDDING_BASE_URL="https://your-proxy.example.com/v1" \
  --set secret.BABY_TALK_EMBEDDING_API_KEY="<your-key>"
```

### 更换模型

更换 Embedding 模型时需同步修改维度：

```bash
# 示例：切换到 text-embedding-3-large（3072维）
BABY_TALK_EMBEDDING_MODEL=text-embedding-3-large
BABY_TALK_EMBEDDING_DIMENSIONS=3072
```

> **⚠️ 注意：** 更换模型后，已有文献的向量不会自动重新计算。需重新运行批量导入以生成新模型的向量。

---

## Knowledge Graph 矛盾审查

### 工作原理

知识图谱审查是一个定时任务，定期扫描新导入的知识实体，检测是否存在与已有知识矛盾的信息。

**流程：** 自动检测 → AI Agent 审查 → 管理员通知 → 人工确认/解决

### 配置变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `BABY_TALK_KG_REVIEW_ENABLED` | `true`（生产）/ `false`（本地开发） | 是否启用定时审查 |
| `BABY_TALK_KG_REVIEW_INTERVAL` | `PT5M`（开发）/ `PT30M`（生产） | 审查轮询间隔 |
| `BABY_TALK_KG_REVIEW_BATCH_SIZE` | `10` | 每次审查的最大实体数 |

### 审查流程

1. **自动检测：** 定时任务按 `KG_REVIEW_INTERVAL` 间隔运行，每次取 `KG_REVIEW_BATCH_SIZE` 个待审查实体
2. **Agent 审查：** AI Agent 分析实体间是否存在矛盾（如"6 个月可以吃蜂蜜" vs "1 岁前不可食用蜂蜜"）
3. **审查结果：** 矛盾实体被标记为 `FLAGGED`，无矛盾则标记为 `REVIEWED`
4. **解决矛盾：** 管理员通过 Resolve API 处理被标记的矛盾

### 手动触发与管理

```bash
# 查看审查状态（通过 Actuator 健康检查）
curl http://localhost:8080/actuator/health | jq '.components'
```

### 调整审查频率

```bash
# Docker Compose — 修改 .env 后重启
BABY_TALK_KG_REVIEW_INTERVAL=PT30M
docker compose restart backend

# Helm — 升级 release
helm upgrade babytalk deploy/helm/babytalk/ \
  --set config.BABY_TALK_KG_REVIEW_INTERVAL="PT30M"
```

### 关闭审查

在调试或数据修复期间，可临时关闭审查：

```bash
# Docker Compose
BABY_TALK_KG_REVIEW_ENABLED=false
docker compose restart backend

# Helm
helm upgrade babytalk deploy/helm/babytalk/ \
  --set config.BABY_TALK_KG_REVIEW_ENABLED="false"
```

---

## Search Mode 切换

### 三种模式

| 模式 | 变量值 | 行为 |
|------|--------|------|
| **Agentic** | `agentic` | AI Agent 规划搜索策略，综合 pgvector 语义检索 + 知识图谱 |
| **RAG** | `rag` | 简单 RAG — 直接向量相似度检索，不经过 Agent 规划 |
| **None** | `none` | 关闭知识库搜索，仅用模型自身知识回答 |

### 切换方法

```bash
# Docker Compose — 修改 .env
BABY_TALK_MENTOR_SEARCH_MODE=agentic
docker compose restart backend

# Helm — 更新 ConfigMap
helm upgrade babytalk deploy/helm/babytalk/ \
  --set config.BABY_TALK_MENTOR_SEARCH_MODE="agentic"
```

### 选择建议

- **首次部署 / 无文献：** 使用 `none`，避免空知识库查询
- **已导入文献 / 无需复杂推理：** 使用 `rag`，响应更快
- **已导入文献 / 需要跨来源综合回答：** 使用 `agentic`，质量最高但延迟略高

---

## 会话超时调整

多轮对话会话的超时时间由 `BABY_TALK_MENTOR_SESSION_TIMEOUT` 控制：

```bash
# 默认 30 分钟（ISO 8601 Duration 格式）
BABY_TALK_MENTOR_SESSION_TIMEOUT=PT30M

# 示例：调整为 1 小时
BABY_TALK_MENTOR_SESSION_TIMEOUT=PT1H

# 示例：调整为 15 分钟
BABY_TALK_MENTOR_SESSION_TIMEOUT=PT15M
```

超时后，会话自动关闭，用户下次提问会开启新会话。

### ISO 8601 Duration 速查

| 格式 | 含义 |
|------|------|
| `PT5M` | 5 分钟 |
| `PT30M` | 30 分钟 |
| `PT1H` | 1 小时 |
| `PT1H30M` | 1 小时 30 分钟 |

---

## 动态练习生成

### API 接口

```
POST /api/v1/mentor/practice/generate
```

练习回复最大长度由 `BABY_TALK_MENTOR_PRACTICE_RESPONSE_MAX_LENGTH` 控制（默认 2000 字符）。

### 测试练习生成

```bash
curl -X POST http://localhost:8080/api/v1/mentor/practice/generate \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: test-device" \
  -d '{
    "childAgeMonths": 18,
    "scenario": "bath_time",
    "difficulty": "beginner"
  }'
```

---

## 常见问题排查

### Embedding API 连接失败

**症状：** 文献导入时 job 状态变为 FAILED，错误信息包含 "connection refused" 或 "timeout"

**排查步骤：**

```bash
# 1. 检查 Embedding API 连通性
curl -v ${BABY_TALK_EMBEDDING_BASE_URL}/models

# 2. 检查 API 密钥是否正确注入
# Docker Compose
docker compose exec backend env | grep EMBEDDING

# K8s
kubectl exec -n babytalk <pod-name> -- env | grep EMBEDDING

# 3. 检查后端日志
docker compose logs backend | grep -i embedding
# 或
kubectl logs -n babytalk -l app.kubernetes.io/name=babytalk | grep -i embedding
```

### MinIO 存储问题

**症状：** 文件上传返回 500，日志报 MinIO 连接错误

```bash
# 检查 MinIO 健康状态
curl http://localhost:9000/minio/health/live

# 检查 MinIO Console（浏览器）
# http://localhost:9001  用户名: babytalk  密码: babytalk123

# K8s 环境检查
kubectl exec -n babytalk <pod-name> -- env | grep MINIO
```

### 知识图谱审查不运行

**症状：** 导入文献后矛盾未被检测

```bash
# 1. 确认审查已启用
docker compose exec backend env | grep KG_REVIEW
# KG_REVIEW_ENABLED 应为 true

# 2. 检查审查间隔是否过长
# 默认开发环境 PT5M，生产 PT30M

# 3. 确认 AI API 密钥已配置
# 审查依赖 AI Agent，需要有效的 AI API 密钥
docker compose exec backend env | grep AI_API_KEY
```

### 搜索模式切换后无效果

**症状：** 修改 `SEARCH_MODE` 后 Mentor 行为未变化

```bash
# 1. 确认环境变量已生效
docker compose exec backend env | grep SEARCH_MODE

# 2. 确认后端已重启
docker compose restart backend

# 3. 使用 agentic/rag 模式时，确认已导入文献
# 无文献时搜索结果为空，行为与 none 模式相同

# 4. 确认 Embedding API 密钥已配置
# agentic/rag 模式依赖 Embedding 向量化
```

### 会话突然断开

**症状：** 用户反馈多轮对话中途断开

```bash
# 检查 SESSION_TIMEOUT 配置
docker compose exec backend env | grep SESSION_TIMEOUT
# 默认 PT30M，如果用户对话间隔超过此值则会话过期

# 考虑增大超时时间
BABY_TALK_MENTOR_SESSION_TIMEOUT=PT1H
```

---

## 附录：M005 新增环境变量速查表

| 变量 | 分类 | 敏感 | Docker Compose 默认 | 生产建议 |
|------|------|------|---------------------|----------|
| `BABY_TALK_MENTOR_SEARCH_MODE` | Config | 否 | `none` | `agentic` |
| `BABY_TALK_EMBEDDING_BASE_URL` | Config | 否 | Azure 端点 | 按需配置 |
| `BABY_TALK_EMBEDDING_API_KEY` | Secret | **是** | 空 | **必须配置** |
| `BABY_TALK_EMBEDDING_MODEL` | Config | 否 | `text-embedding-3-small` | 按需选择 |
| `BABY_TALK_EMBEDDING_DIMENSIONS` | Config | 否 | `1536` | 与模型匹配 |
| `BABY_TALK_MENTOR_SESSION_TIMEOUT` | Config | 否 | `PT30M` | `PT30M` |
| `BABY_TALK_MENTOR_PRACTICE_RESPONSE_MAX_LENGTH` | Config | 否 | `2000` | `2000` |
| `BABY_TALK_KG_REVIEW_ENABLED` | Config | 否 | `false` | `true` |
| `BABY_TALK_KG_REVIEW_INTERVAL` | Config | 否 | `PT5M` | `PT30M` |
| `BABY_TALK_KG_REVIEW_BATCH_SIZE` | Config | 否 | `10` | `10` |
