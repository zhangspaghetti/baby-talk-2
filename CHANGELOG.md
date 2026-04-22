# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Version format: MAJOR.MINOR.PATCH.MICRO

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
