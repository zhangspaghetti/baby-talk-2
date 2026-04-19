# Baby Talk 2

Baby Talk 2 是一款面向中国父母的亲子英语启蒙 Flutter App，帮助 0-3 岁宝宝的父母在换尿布、洗澡、喂奶、睡前等日常场景中，自然地用英语和宝宝互动。

**目标用户：** 25-40 岁、一二线城市、CET-4/6 英语水平的父母。

## 项目结构

```
baby-talk-2/
├── backend/        # Spring Boot 后端 (Java 17, H2/PostgreSQL)
├── mobile/         # Flutter 移动端 (Android + iOS)
├── tool/           # Dart 验证与检查脚本
├── docs/           # 运维手册 (runbooks)
└── DESIGN.md       # 设计系统文档
```

| 目录 | 说明 |
|------|------|
| `backend/` | Spring Boot 3 后端服务，提供 REST API，默认使用 H2 文件数据库（支持切换 PostgreSQL） |
| `mobile/` | Flutter 跨平台移动客户端，包含音频短语播放、离线内容、Isar 本地存储 |
| `tool/` | Dart CLI 验证脚本，用于 smoke test、集成检查和事实审查 |
| `docs/` | 运维手册和操作文档 |

## 环境要求

| 工具 | 版本要求 |
|------|----------|
| JDK | 17+ |
| Maven | 3.8+（用于后端构建） |
| Flutter SDK | 3.x（Dart SDK ≥ 3.11.4） |
| Dart SDK | ≥ 3.11.4 |

## 后端本地运行

```bash
cd backend

# 默认使用 H2 文件数据库，无需额外配置
# 使用 Maven Wrapper（推荐，如仓库内含 mvnw）：
./mvnw spring-boot:run

# 或使用系统安装的 Maven：
mvn spring-boot:run
```

服务启动后默认监听 `http://localhost:8080`。

### 环境变量

后端通过环境变量覆盖默认配置，所有变量均有合理默认值，本地开发无需手动设置：

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `BABY_TALK_DB_URL` | `jdbc:h2:file:./.data/babytalk;...` | 数据库 JDBC URL |
| `BABY_TALK_DB_USERNAME` | `sa` | 数据库用户名 |
| `BABY_TALK_DB_PASSWORD` | _(空)_ | 数据库密码 |
| `BABY_TALK_SMS_PROVIDER_MODE` | `dev` | 短信服务模式（`dev` 使用固定验证码 246810） |
| `BABY_TALK_MENTOR_PROVIDER_MODE` | `dev` | AI 导师模式（`dev` 使用模拟响应） |

切换到 PostgreSQL：

```bash
BABY_TALK_DB_URL=jdbc:postgresql://localhost:5432/babytalk \
BABY_TALK_DB_USERNAME=postgres \
BABY_TALK_DB_PASSWORD=your_password \
mvn spring-boot:run
```

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

## 运行测试

### 后端测试

```bash
cd backend
./mvnw test
# 或使用系统 Maven：
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

## Docker 本地开发

使用 Docker Compose 一键拉起完整本地开发栈（后端服务 + H2 数据库）：

```bash
# 启动本地栈（首次会自动构建镜像）
docker compose up -d --build

# 查看服务状态和健康检查
docker compose ps

# 查看服务日志
docker compose logs -f backend

# 停止并清理
docker compose down -v
```

服务启动后，healthcheck 会每 30 秒探测 `/actuator/health` 端点，确认服务健康状态。
容器就绪后可通过 `http://localhost:8080` 访问后端 API。

## 持续集成 (CI)

项目使用 **GitHub Actions** 在 push 和 PR 时自动运行质量门检查。

### 自动触发

- **push** 到 `main` 或 `milestone/*` 分支时自动运行
- **Pull Request** 目标为 `main` 时自动运行

CI workflow 包含两个并行 job：
- **backend-test**：JDK 17 + Maven 缓存，运行 `./mvnw verify`
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
  --set secret.BABY_TALK_AI_API_KEY="<api-key>"
```

### Dry-Run 验证

运行 smoke test 脚本验证 Helm chart 和 K8s manifests 的正确性（无需集群）：

```bash
bash ci/k8s-smoke.sh
```

### 详细操作手册

从零到运行的完整操作步骤（命名空间创建、Secret 注入、部署、验证、回滚、监控、排查）参见：

📖 [K8s 部署操作手册](docs/runbooks/k8s-deploy.md)

## 设计系统

项目的视觉设计方向、字体选择、配色方案和组件规范详见 [DESIGN.md](DESIGN.md)。

核心设计原则：
- **暖纸亲和（Warm Paper Kindness）** — 温暖、克制、亲切
- **用户是父母，不是小孩** — 亲子指导派定位
- **Fraunces 衬线体** 用于英文短语展示，**DM Sans** 用于 UI 文本

## 开发须知

- 后端数据库文件存储在 `backend/.data/`，已被 `.gitignore` 排除
- 短信和 AI 导师服务在 `dev` 模式下使用模拟数据，无需外部服务依赖
- Flyway 管理数据库迁移，首次启动自动执行
