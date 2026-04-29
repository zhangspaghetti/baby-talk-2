# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Version format: MAJOR.MINOR.PATCH.MICRO

## [1.2.0.3] - 2026-04-29

### Performance
- **admin-web bundle split (ProTable → antd Table):** `UsersPage` 从 782 KB 降至 19 KB (-98%)；主入口 bundle 从 1,130 KB 降至 91 KB (-92%)。将 `@ant-design/pro-components` 拆分为独立 `vendor-pro-components` 缓存块 (88 KB)，base antd 独立 `vendor-antd` (1,282 KB，首次加载后常驻浏览器缓存)。ProTable 替换为标准 antd Table，所有功能与 UI 保持不变，QA 全页面验证通过。
- **AdminLayout PageContainer 移除:** `AdminLayout.tsx` 移除 `PageContainer`（原来每次 admin 页面加载时同步拉取 pro-components），改用 antd 原生 `Breadcrumb` + `Typography.Title/Text`；`@ant-design/pro-components` 降为仅 `ProLayout` sidebar 所需，vendor-pro-components chunk 不再随每次路由渲染加载。

### Fixed
- **MyBatis `double` primitive NPE regression (MyBatis 迁移引入):** `PalaceRagMapper.BridgeEdgeRow.confidence` 从 `double` 改为 `Double`（boxed），`PalaceRagMapper.xml` 对应 `javaType` 改为 `java.lang.Double`；修复 confidence 列值为 NULL 时 MyBatis 原始类型抛 `ResultMapException` 的问题（JdbcTemplate 旧行为：NULL → 0.0，MyBatis primitive → 异常）。
- **proposeBridges null guard:** `PalaceProjectionSyncService.proposeBridges` 在调用 `UUID.fromString()` 前增加 null 判断，防止 `findRoomIdByWingAndRoom` 返回 null 时以 "error=null" 日志吞掉异常；现在抛出 `IllegalStateException`（仍被 non-fatal try-catch 捕获，但日志信息有意义）。

### Changed
- **admin-api palace services: JdbcTemplate → MyBatis-Plus:** `AdminPalaceRagService` 和 `PalaceProjectionSyncService` 从手写 `JdbcTemplate` SQL 迁移至 MyBatis-Plus mapper（`PalaceRagMapper`、`PalaceProjectionMapper`），统一项目 ORM 技术栈。同步修复 k8s smoke test 中错误的 JdbcTemplate 审计豁免项。
- **`@Transactional` on `onIngestionCompleted`:** 关闭 `countCurrentProjectionVersion` + `insert/updateProjectionVersion` 之间的 TOCTOU 竞态；并发 ingestion 事件不再可能导致 unique constraint 冲突。
- **`@Max(500)` on palace list endpoints:** `GET /palace/bridge-edges` 和 `GET /palace/traces` 的 `limit` 参数新增 `@Max(500)` 上限，防止经过认证的管理员通过超大 limit 值耗尽内存。
- **helm scripts: 移除 `--force-conflicts`:** `scripts/restore-k8s-proxy.cmd` 两处 helm upgrade 命令移除 `--force-conflicts` 标志，防止静默赢得 field-manager 竞争、掩盖真实冲突。
- **test coverage:** 新增 `PalaceProjectionSyncService` 单元测试 7 个，覆盖 `resolveAgeRange`、`resolveSourceBook`、projection version insert/update 分支及 bridge proposal 异常非致命处理。新增 `AdminPalaceRagService` 单元测试 14 个，覆盖 projection status 查询、bridge edge CRUD 及状态规范化、trace sample 映射全链路（含 null 安全性）。

### Chore
- **mobile/.gitignore:** 新增 `test_results.json` 排除测试产物文件被纳入版本控制。

## [1.2.0.2] - 2026-04-29

### Added
- **pgvector 独立 Postgres 模板:** 替换 bitnami/postgresql 子 chart，改用 `pgvector/pgvector:pg17` 镜像独立部署；init 脚本自动创建 vector extension；readinessProbe 通过 `pg_isready` 保证 helm --wait 正确等待。
- **MinIO 独立模板 + 数据卷修复:** 新增 `deploy/helm/babytalk-infra/templates/minio.yaml`，MinIO 之前缺少 `/data` volumeMount（上传文件写入临时容器 FS 无持久化）；现已正确挂载 emptyDir/PVC。
- **可配置 PVC/emptyDir 持久化:** postgres 和 minio 均新增 `persistence.enabled`（默认 false = emptyDir）；置 true 创建命名 PVC，支持 storageClassName 和 size 配置，可无缝切换生产环境。
- **移动端 e2e 全链路测试:** 新增 `e2e_full_flow_test.dart` 入口与 `test_driver/integration_test.dart`；`run-full-e2e.sh/.cmd` 脚本一键执行。
- **e2e 测试报告 + 截图:** `docs/e2e-test-report-2026-04-29.md`、`docs/e2e-full-test-report-2026-04-29.md`，admin + mobile 截图 50 张。

### Fixed
- **MinIO 数据卷缺失 (P1):** MinIO 之前在无任何 volume 定义的情况下执行 `server /data`，所有上传仅存于临时容器 FS，Pod 重启即丢失；现已修复。
- **网关 CORS 缺失 PATCH 方法:** `gateway/application.yml` 补充 PATCH 到 allowedMethods，修复 admin-web PATCH 请求 403 问题。
- **backend/Dockerfile 缺失 gateway pom.xml:** COPY 步骤补全 `backend/gateway/pom.xml`，修复 Maven 层缓存 miss。
- **admin-web KnowledgeOpsPage:** 移除 `needsCanonicalQuery/viewWasNormalized` 标志，修复已规范化请求被意外二次重定向。
- **admin-web AdminAccountsPage:** 禁用状态按钮 UX 反馈改进，防止用户误操作无响应。
- **helm-app secret/serviceaccount:** 清理 hook 注解结构，保留 pre-install,pre-upgrade 语义不变。

### Changed
- **移动端集成测试稳定性:** s02/s03/s06 滚动修复、键盘关闭、超时延长；harness 更新。
- **移动端首页 UI:** home_screen + 各 widget 视觉和布局优化；中文 l10n 补全。
- **Helm infra:** 移除 bitnami/minio 子 chart，改用独立模板（同 postgres 模式）；values-kind.yaml 统一 emptyDir。
- **scripts:** dev-up/verify-helm-demo.sh/.cmd 添加 grep 噪音过滤。
- **admin-web playwright:** retries + screenshot-on-failure；URL regex 修复；kubectl exec K8s 模式支持；waitForResponse race 修复。
- **verify_m007_s01_helm_baseline.dart:** 替换 kind 检测为 Docker Desktop kubectl connectivity check；stdout.writeln build hook 修复。

## [1.2.0.1] - 2026-04-28

### Security
- **移除硬编码 JWT 密钥 fallback (P1):** `gateway/application.yml`、`admin-api/application.yml`、`app-api/application.yml` 三处 `${...:<hardcoded>}` fallback 已删除。三个环境变量（`BABY_TALK_ADMIN_JWT_SECRET`、`BABY_TALK_CONSUMER_JWT_SECRET`）现为必填，缺失时 Spring Boot fail-fast，不再允许使用默认密钥伪造令牌。
- **移动端 JWT Token 加密存储 (P1):** `AccountLocalStore` 从明文 JSON 文件（`account_state.json`）迁移至 `flutter_secure_storage`（iOS Keychain / Android Keystore）。Root 设备或未加密备份不再能直接读取 access/refresh token。
- **网关 CORS 配置 (P2):** Spring Cloud Gateway 新增 `globalcors` 配置块。Admin Web origin 通过 `BABY_TALK_ADMIN_WEB_ORIGIN` 控制（默认 `http://localhost:5173`），使用 `allowedOriginPatterns`（不允许 `*` + `allowCredentials` 组合）。

## [1.2.0.0] - 2026-04-22

### Added
- **知识宫殿 MemPalace (M006):** 结构化育儿知识图谱，支持 RAG 检索、KG 矛盾检测与 LLM 审查、关键词索引、向量存储与 pgvector 集成。
- **分发与成长分享 (S01–S02):** 发布分发链路（release distribution）、分享落地页（share landing）、短链 API 与受控分发策略。
- **照护者邀请与 household 协作 (S03–S04):** Caregiver invite/accept/revoke API，household 共享上下文 projection，照护者练习归因。
- **成功链路全链路验证 (S06):** 真机端到端集成测试，覆盖 onboarding → mentor blocked fallback 全链路。
- **Docker 容器化后端:** `docker-compose.yml` 含 Postgres + MinIO，`scripts/verify-e2e.sh` E2E smoke 验证（10 项全通过）。
- **Spring Boot 后端基础设施:** API 版本拦截器（`X-App-Version` / 426 升级门控）、安全响应头过滤器、MinIO bucket 初始化、Helm chart 部署配置。
- **Mentor 功能:** 多轮对话、rate-limit 并发安全（INSERT-then-COUNT）、practice generate、dev 模式 fallback。
- **账户与同步:** challenge/verify/consent/bootstrap/sync 完整链路，concurrent challenge 幂等性保证。
- **CI 脚本:** `ci/backend-test.sh`、`ci/mobile-analyze.sh`、`ci/k8s-smoke.sh`，`.github/workflows/ci.yml`。

### Changed
- **移动端导航:** Shell 从 5-tab 退回 4-tab（首页/发现/花园/成长）+ Drawer + 全局 Mentor FAB，`NavigationDestination` 添加稳定 widget key。
- **Mentor ViewModel:** 新增 `listFactHistory()` 方法，供集成测试在不重开 Isar 的情况下检查 mentor fact 历史。
- **集成测试 harness:** 改用直接 callback seam（`NavigationBar.onDestinationSelected`、`FloatingActionButton.onPressed`）替换 hit-test 依赖，提升真机稳定性；新增 `waitForGardenProjectionReady`、`scrollHomeToTop`、`inspectSyncQueue` 复用活跃仓库。
- **Docker compose:** 补充 `BABY_TALK_EMBEDDING_API_KEY` 非空占位值，修复本地启动时 `@NotBlank` 校验崩溃。
- **E2E smoke 脚本:** 所有 `/api/**` 请求补充 `X-App-Version` 头，修复 426 拦截器阻断问题。

### Fixed
- S06 集成测试：修复 garden/growth projection 就绪等待、home tab 切换、home summary 滚动、fallback 断言文本（`本地回应`）。
- 后端 `AuthConsentSyncServiceTest`：补充 expired challenge、wrong code、duplicate consent accept/revoke、invalid reaction type、missing client timestamp 等回归用例。
- 移动端 S01–S05 集成测试：适配 360×780 小屏设备，修复所有 pumpUntilFound / ensureVisible 顺序问题。
