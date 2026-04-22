# Baby Talk 2

Baby Talk 2 是一款面向中国父母的亲子英语启蒙 Flutter App，帮助 0-3 岁宝宝的父母在换尿布、洗澡、喂奶、睡前等日常场景中，自然地用英语和宝宝互动。

内置 **MemPalace 知识宫殿**：基于 Agentic Search 的育儿专家系统，支持权威文献导入、语义搜索、知识图谱矛盾检测，以及动态练习生成。

**目标用户：** 25-40 岁、一二线城市、CET-4/6 英语水平的父母。

## 项目结构

```
baby-talk-2/
├── backend/        # Spring Boot 3 后端，PostgreSQL(pgvector) + MinIO
├── mobile/         # Flutter 移动端 (Android + iOS)
├── scripts/        # 运维与批量导入脚本
├── tool/           # Dart 验证与检查脚本
├── deploy/         # Helm chart (K8s 部署)
├── docs/           # 运维手册 (runbooks)
└── DESIGN.md       # 设计系统文档
```

| 目录 | 说明 |
|------|------|
| `backend/` | Spring Boot 3 后端服务，PostgreSQL(pgvector) 向量数据库 + MinIO 对象存储，提供 REST API |
| `mobile/` | Flutter 跨平台移动客户端，包含音频短语播放、离线内容、Isar 本地存储 |
| `scripts/` | 运维脚本：`batch-ingest.sh`（批量文献导入）、`verify-e2e.sh`（端到端验证） |
| `tool/` | Dart CLI 验证脚本，用于 smoke test、集成检查和事实审查 |
| `deploy/` | Kubernetes Helm chart，含开发/生产 values 配置 |
| `docs/` | 运维手册和操作文档 |

## 环境要求

| 工具 | 版本要求 | 说明 |
|------|----------|------|
| JDK | 17+ | 后端编译和运行 |
| Maven | 3.8+ | 后端构建（`mvn`，不含 wrapper） |
| Flutter SDK | 3.x（Dart SDK ≥ 3.11.4） | 移动端构建 |
| Dart SDK | ≥ 3.11.4 | 验证脚本运行 |
| Docker | ≥ 24.0 | 本地开发一键部署 |
| Docker Compose | ≥ 2.20 | 编排 PostgreSQL + MinIO + 后端 |

## 后端本地运行

```bash
cd backend

# 使用系统安装的 Maven：
mvn spring-boot:run
```

> **注意：** 项目不包含 Maven Wrapper（`mvnw`），请使用系统安装的 `mvn` 命令。

服务启动后默认监听 `http://localhost:8080`。

默认连接本地 PostgreSQL（`localhost:15432/babytalk`），需要先启动数据库：

```bash
# 方式一（推荐）：使用 Docker Compose 启动完整开发栈
docker compose up -d

# 方式二：仅启动数据库和 MinIO，后端本地运行
docker compose up -d postgres minio
cd backend && mvn spring-boot:run
```

### 环境变量

后端通过环境变量覆盖默认配置。本地开发推荐使用 Docker Compose（已内置默认值），手动运行时可参考以下变量：

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| **数据库** | | |
| `BABY_TALK_DB_URL` | `jdbc:postgresql://localhost:15432/babytalk` | PostgreSQL JDBC URL |
| `BABY_TALK_DB_USERNAME` | `babytalk` | 数据库用户名 |
| `BABY_TALK_DB_PASSWORD` | `babytalk` | 数据库密码 |
| **对象存储** | | |
| `BABY_TALK_MINIO_ENDPOINT` | `http://localhost:9000` | MinIO 端点 |
| `BABY_TALK_MINIO_ACCESS_KEY` | `babytalk` | MinIO Access Key |
| `BABY_TALK_MINIO_SECRET_KEY` | `babytalk123` | MinIO Secret Key |
| **服务模式** | | |
| `BABY_TALK_SMS_PROVIDER_MODE` | `dev` | 短信服务模式（`dev` 使用固定验证码 246810） |
| `BABY_TALK_MENTOR_PROVIDER_MODE` | `dev` | AI 导师模式（`dev` 使用模拟响应） |
| **搜索与嵌入** | | |
| `BABY_TALK_MENTOR_SEARCH_MODE` | `none` | 搜索模式：`agentic` / `rag` / `none` |
| `BABY_TALK_EMBEDDING_BASE_URL` | `https://models.inference.ai.azure.com` | Embedding API 端点 |
| `BABY_TALK_EMBEDDING_API_KEY` | _(空)_ | Embedding API 密钥 |
| `BABY_TALK_EMBEDDING_MODEL` | `text-embedding-3-small` | Embedding 模型名称 |
| `BABY_TALK_EMBEDDING_DIMENSIONS` | `1536` | 向量维度 |
| **AI 服务** | | |
| `BABY_TALK_AI_BASE_URL` | `https://models.inference.ai.azure.com` | AI Chat API 端点 |
| `BABY_TALK_AI_API_KEY` | _(空)_ | AI Chat API 密钥 |
| `BABY_TALK_AI_MODEL` | `gpt-4o-mini` | AI 模型名称 |
| **会话与练习** | | |
| `BABY_TALK_MENTOR_SESSION_TIMEOUT` | `PT30M` | 多轮会话超时时间（ISO 8601 Duration） |
| `BABY_TALK_MENTOR_PRACTICE_RESPONSE_MAX_LENGTH` | `2000` | 练习回复最大长度 |
| **知识图谱审查** | | |
| `BABY_TALK_KG_REVIEW_ENABLED` | `true`（生产）/ `false`（Docker 本地） | KG 矛盾审查开关 |
| `BABY_TALK_KG_REVIEW_INTERVAL` | `PT5M` | 审查轮询间隔 |
| `BABY_TALK_KG_REVIEW_BATCH_SIZE` | `10` | 每次审查批量大小 |

完整环境变量列表参见 [`.env.example`](.env.example)。

## 移动端本地运行

```bash
cd mobile

# 获取依赖
flutter pub get

# 运行（自动检测已连接的设备或模拟器）
flutter run
```

如需指定平台：

```bash
flutter run -d chrome     # Web（开发调试）
flutter run -d android    # Android 设备/模拟器
flutter run -d ios        # iOS 设备/模拟器（需 macOS）
```

## Docker 本地开发

使用 Docker Compose 一键拉起完整本地开发栈（PostgreSQL + MinIO + 后端服务）：

```bash
# 复制环境变量模板（首次）
cp .env.example .env
# 按需编辑 .env，填入 AI API 密钥等

# 启动本地栈（首次会自动构建镜像）
docker compose up -d --build

# 查看服务状态和健康检查
docker compose ps

# 查看服务日志
docker compose logs -f backend

# 停止并清理
docker compose down -v
```

### 服务架构

| 服务 | 镜像 | 端口 | 说明 |
|------|------|------|------|
| `postgres` | `pgvector/pgvector:pg16` | `15432:5432` | PostgreSQL 16 + pgvector 扩展 |
| `minio` | `minio/minio:latest` | `9000` / `9001` | 对象存储（API 9000 / Console 9001） |
| `backend` | 本地构建 | `8080:8080` | Spring Boot 后端 |

服务启动后，healthcheck 会每 30 秒探测 `/actuator/health` 端点，确认服务健康状态。
容器就绪后可通过 `http://localhost:8080` 访问后端 API。

### Android 模拟器连接

Android 模拟器中访问宿主机服务时，需使用 `10.0.2.2` 替代 `127.0.0.1`（`localhost`）：

```
# 模拟器中访问后端 API
http://10.0.2.2:8080/api/v1/...
```

## 知识宫殿（MemPalace）

MemPalace 是内置的知识管理与智能搜索系统，为 AI 育儿导师提供权威知识库支持。

### 核心功能

- **文献导入**：支持上传育儿类书籍/文档，自动切片、Embedding 向量化、存储到 pgvector
- **Agentic Search**：AI Agent 自动规划搜索策略，综合语义检索 + 知识图谱回答用户问题
- **知识图谱**：从导入文献中自动抽取实体和关系，构建育儿知识图谱
- **矛盾检测**：定期扫描知识图谱中的矛盾信息，经 Agent 审查后标记或修正

### 搜索模式（search-mode）

通过 `BABY_TALK_MENTOR_SEARCH_MODE` 环境变量控制：

| 模式 | 说明 |
|------|------|
| `agentic` | 完整 Agentic Search — Agent 规划搜索策略，综合 pgvector 语义检索 + 知识图谱查询 |
| `rag` | 简单 RAG — 直接向量相似度检索，不经过 Agent 规划 |
| `none` | 关闭知识库搜索，仅使用模型自身知识回答（默认） |

### 批量文献导入

使用 `scripts/batch-ingest.sh` 批量导入文献：

```bash
# 基本用法（默认连接 localhost:8080）
./scripts/batch-ingest.sh /path/to/docs/

# 指定 API 地址
./scripts/batch-ingest.sh /path/to/docs/ http://your-server:8080
```

脚本会遍历目录中所有文件，对每个文件：
1. 从文件名推断书名（去扩展名，替换下划线/连字符为空格）
2. 调用 `POST /api/v1/ingestion/upload` 上传
3. 轮询 job 状态直到 COMPLETED / FAILED
4. 输出汇总报告（成功/失败/总数）

单本书手动上传：

```bash
curl -X POST http://localhost:8080/api/v1/ingestion/upload \
  -F "file=@/path/to/book.pdf" \
  -F "bookTitle=我的育儿书"
```

## 动态练习生成

MemPalace 支持基于知识库内容动态生成亲子英语练习场景：

```bash
# 生成练习
curl -X POST http://localhost:8080/api/v1/mentor/practice/generate \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: test-device" \
  -d '{
    "childAgeMonths": 18,
    "scenario": "bath_time",
    "difficulty": "beginner"
  }'
```

练习回复最大长度由 `BABY_TALK_MENTOR_PRACTICE_RESPONSE_MAX_LENGTH` 控制（默认 2000 字符）。

## 运行测试

### 后端测试

```bash
cd backend
mvn test
```

### 移动端全量测试

```bash
cd mobile
flutter test
```

### Smoke 测试

快速验证 App 启动和核心路由：

```bash
cd mobile
flutter test test/smoke/
```

## 验证脚本

项目提供 `tool/verify_s06.dart` 验证脚本，用于检查集成状态：

```bash
# 检查模式 — 验证文件结构和脚本存在性
dart run tool/verify_s06.dart --inspect

# 集成模式 — 运行完整集成测试链
dart run tool/verify_s06.dart --integration

# 默认（两者都运行）
dart run tool/verify_s06.dart
```

其他可用的检查脚本：

```bash
dart run tool/inspect_interaction_events.dart   # 检查交互事件
dart run tool/inspect_mentor_facts.dart          # 检查导师事实数据
```

## 持续集成 (CI)

项目使用 **GitHub Actions** 在 push 和 PR 时自动运行质量门检查。

### 自动触发

- **push** 到 `main` 或 `milestone/*` 分支时自动运行
- **Pull Request** 目标为 `main` 时自动运行

CI workflow 包含两个并行 job：
- **backend-test**：JDK 17 + Maven 缓存，运行 `mvn verify`
- **mobile-analyze**：Flutter stable，运行 `flutter analyze` + `flutter test`

### 本地运行 CI 脚本

双轨 CI 脚本可在任意 bash 环境独立运行，无需 GitHub Actions：

```bash
# 运行后端测试
bash ci/backend-test.sh

# 运行移动端分析和测试
bash ci/mobile-analyze.sh
```

## Kubernetes 部署

项目提供完整的 Helm chart 用于 K8s 集群部署，位于 `deploy/helm/babytalk/`。

### 快速开始

```bash
# Lint 检查
helm lint deploy/helm/babytalk/

# 模拟渲染（不实际部署）
helm template babytalk deploy/helm/babytalk/

# 使用生产配置安装
helm install babytalk deploy/helm/babytalk/ \
  --namespace babytalk --create-namespace \
  -f deploy/helm/babytalk/values-production.yaml \
  --set secret.BABY_TALK_DB_URL="<db-url>" \
  --set secret.BABY_TALK_DB_PASSWORD="<db-password>" \
  --set secret.BABY_TALK_AI_API_KEY="<api-key>" \
  --set secret.BABY_TALK_EMBEDDING_API_KEY="<embedding-key>"
```

### Dry-Run 验证

运行 smoke test 脚本验证 Helm chart 和 K8s manifests 的正确性（无需集群）：

```bash
bash ci/k8s-smoke.sh
```

### 详细操作手册

从零到运行的完整操作步骤（命名空间创建、Secret 注入、部署、验证、回滚、监控、排查）参见：

📖 [K8s 部署操作手册](docs/runbooks/k8s-deploy.md)

📖 [M005 MemPalace 运维手册](docs/runbooks/m005-mempalace-ops.md)

## 设计系统

项目的视觉设计方向、字体选择、配色方案和组件规范详见 [DESIGN.md](DESIGN.md)。

核心设计原则：
- **暖纸亲和（Warm Paper Kindness）** — 温暖、克制、亲切
- **用户是父母，不是小孩** — 亲子指导派定位
- **Fraunces 衬线体** 用于英文短语展示，**DM Sans** 用于 UI 文本

## 开发须知

- 后端使用 **PostgreSQL 16 + pgvector** 作为主数据库，Flyway 管理数据库迁移，首次启动自动执行
- **MinIO** 用于文献文件存储（文献导入管道）
- 短信和 AI 导师服务在 `dev` 模式下使用模拟数据，无需外部服务依赖
- 本地开发推荐使用 `docker compose up -d` 一键启动所有依赖服务
- 环境变量模板见 [`.env.example`](.env.example)，复制后按需修改
