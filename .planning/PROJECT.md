# Project

## What This Is

Baby Talk 2 是一个面向中国父母的 Flutter 原生移动应用，围绕换尿布、洗澡、喂奶、睡前等日常场景，帮助父母在真实育儿时刻自然地对 0-3 岁宝宝说英语。它不是课程产品，不是词卡库，也不是面向孩子自己的卡通课堂；它是一个实时双语育儿伴侣。

## Core Value

如果 scope 被迫缩小，最不能丢的是：父母在真实场景里打开 app 后，马上拿到一句自然、可播放、可跟说的英语短语，并在说出口之后获得继续开口的反馈，而不是被带去"学习英语"。

## Current State

**M010《Baby Talk vNext Family Micro-ritual 架构重启》已推进至 Phase 41 planning。Phase 39《vNext 产品承诺与 Family English Micro-ritual 单元收敛》已完成（2026-06-15）：产品承诺、旧语义 supersession、Context Seed / Joinability 边界、semantic firewall、独立 `mobile_v2` 非 UI 边界均已锁定。Phase 40《Activation Governor 与 Garden Memory 节奏治理合同》已完成并验证通过（2026-06-16）：Activation Governor 权威、Garden Memory parent-confirmation、Explore/Activate 边界已由独立 verifier、proof、validation、verification artifacts 锁定。**

### M010 Phase 40 已交付

- ✅ **40-01** — `tool/verify_activation_governor_contract.dart` 与 root verifier tests 完成；Activation Governor 作为唯一 activation pacing authority，Pack/Graph、Runtime、Garden 绕过均 fail-closed。
- ✅ **40-02** — surface activation intent、weak-signal、parent-confirmed Garden Memory、pressure language、mobile wrapper parity 覆盖完成；Explore remains open while Activate intent is gated。
- ✅ **40-03** — `40-ACTIVATION-GOVERNOR-CONTRACT-PROOF.md`、`40-VALIDATION.md`、SPEC proof links、`40-VERIFICATION.md` 完成；D-31/D-32/D-33 compact decision/state matrix 保留为 verifier/planning contract，不锁 schema/API/UI/runtime payload。

### M010 Phase 39 已交付

- ✅ **39-01** — Source-grounded supersession proof 与 SPEC linkage 完成；R058/R059/R060 对应的 Family English Micro-ritual 产品承诺、非目标、旧 Phrase/Activity/completion/streak/GardenGrowth 语义处置已记录。
- ✅ **39-02** — `tool/verify_mobile_v2_semantic_firewall.dart` 与 root/mobile 测试完成；`mobile_v2/lib` 禁止旧 mobile practice/onboarding/garden import，禁止 old-product runtime terms，且禁止 runtime 导入 quarantine/reference 路径。
- ✅ **39-03** — 独立 `mobile_v2/` Flutter package boundary 建立；`mobile_v2/lib` 只保留 vNext semantic anchors；reference assets 与 legacy reference 均明确隔离，Phase 39 validation/review/verification 通过。

**M009《Historical completeness re-review and UX maturity closure》已完成（2026-04-28）。所有 8 个切片 S01–S08 ✅，里程碑验证通过并已关闭。**

### M009 已交付

- ✅ **S01** — M001-M004 completeness autoplan document locked as canonical record: M001=archive-broken/product-substantially-complete, M002-M004=implementation-complete
- ✅ **S02** — Home screen hierarchy tightened: HomeTodaySceneCard dominant (warmShadowMd Container), secondary blocks compressed; R001/R034 tests green (8/8)
- ✅ **S03** — Discover screen simplified: shorter hero, reduced activity-card chrome (sceneTag/spaceTitle chips removed, hero note removed, progress footer removed), R008 chip intact; 6/6 tests green
- ✅ **S04** — Garden screen zoned (Zone A: hero→continue CTA; Zone B: error→patches; Zone C: household context): continuation visually earlier, household context secondary; R034 tests green (5/5)
- ✅ **S05** — Mobile ownership extraction complete: 12 large private display widgets extracted into dedicated per-feature widget files (6 Home, 3 Discover, 3 Garden); flutter analyze clean, smoke 58/58, all 5 targeted feature tests green; zero behavior changes, no new state containers
- ✅ **S06** — Admin shell chrome compression: AdminLayout.tsx progressive disclosure of metadata (role/permissions/token collapsed via antd Collapse with destroyInactivePanel=false), work content leads; TypeScript typecheck clean
- ✅ **S07** — KnowledgeOps workbench decomposition: 2171-line KnowledgeOpsPage.tsx → 249-line URL-truth orchestrator + IngestionSurface + PalaceRagSurface + KgSurface + knowledgeOpsUtils.ts; URL truth preserved; TypeScript typecheck clean
- ✅ **S08** — Proof refresh and archival follow-through: all S02–S07 verification commands run, 6 PASS rows + 1 DEFERRED (knowledge-ops E2E, compose-free worktree) recorded; `## S08 Validation Evidence` appended to `docs/reviews/m009-autoplan-2026-04-26.md`

**M008《Graph-aware knowledge palace RAG for agentic mentor search, temporal retrieval, and MemPalace design closure》已完成（2026-04-27）。S01 ✅、S02 ✅、S03 ✅；全部 3 个切片已完成，里程碑验证通过。**

### M008 已交付

- ✅ **S01** — childAgeMonths 线索化至 ChatCommand → PalaceHybridRetrievalService；age-aware 软评分 + temporal rule 确定性分支（infant_0_12 / toddler_13_24 / preschool_25_48）；QueryTrace 持久化至 palace_query_traces；unit test 证明同一 query 在 childAgeMonths=6 和 childAgeMonths=24 下 top-3 排序可测量差异
- ✅ **S02** — 异步 PalaceProjectionSyncService（非阻断热路径）：ingestion 完成后 palace_projection_version 递增、palace_rooms 反映 MemPalaceTaxonomy rooms、bridge-proposal 生成进入 bridge-review 队列；V19 Flyway migration；Testcontainers 集成测试覆盖投影版本 bump 与 bridge proposal 落库
- ✅ **S03** — Palace RAG Ops admin surface 完成：Bridge Review 队列（approve/reject，rag:write 门控），Trace Samples 视图，Projection 状态卡；AdminPalaceRagService + 6 个 REST endpoints；KnowledgeOpsPage.tsx palace-rag 视图含 reload-safe URL 深度链接；`AdminKnowledgeOpsWebTest` 11 测试全通过

**M007《Helm-first split deployment, gateway front door, persistence stack migration, and collaborative onboarding docs》已完成（2026-04-27）。S01–S06 全部 ✅。**

### M007 已交付

- ✅ **S01** — kind + Helm preflight/up/verify 路径建立；README 只指向 Helm-first；compose 已从仓库中移除；babytalk-infra 和 babytalk-app chart skeleton 可渲染可安装；本地 values/secrets bootstrap 路径就绪；52 断言烟测通过
- ✅ **S02** — 双 release 边界合同锁定：docs/runbooks/k8s-deploy.md 重写（532 行）；docs/schema-compatibility-matrix.md 新建（122 行）；ci/k8s-smoke.sh 扩展到 57 断言；tool/verify_m007_s02_release_boundaries.dart 新建
- ✅ **S03** — Spring Cloud Gateway 模块建立（WebFlux-only，port 8090）；AdminJwtGlobalFilter 6 个命名错误码；admin-web nginx/vite/Helm ConfigMap 全部指向 gateway:8090；ci/k8s-smoke.sh 58 断言
- ✅ **S04** — Consumer/public 路径全部经 gateway；app-api/admin-api 直连入口已关闭；ci/k8s-smoke.sh 62 PASS
- ✅ **S05** — Repo-wide runtime 持久层迁移：20 个 owned repository 迁至 MyBatisPlus adapter（36 XML mapper files）；Druid 慢查询配置；ci/k8s-smoke.sh 63 PASS
- ✅ **S06** — 前门文档与 proof 工具协作重写完成

### 里程碑历史

- **M001**（开口验证闭环）✅ 完成
- **M002**（连续使用与留存强化）✅ 完成
- **M003**（扩张与分发能力）✅ 完成
- **M004**（Review 问题收口与仓库整治）✅ 完成（2026-04-19）
- **M005**（MemPalace 育儿知识宫殿）✅ 完成（2026-04-20）
- **M006**（Admin 管理后台与后端多模块重构）✅ 完成（2026-04-25）
- **M007**（Helm-first split deployment + gateway + persistence migration + docs）✅ 完成（2026-04-27）
- **M008**（Graph-aware knowledge palace RAG + temporal retrieval + MemPalace design closure）✅ 完成（2026-04-27）
- **M009**（Historical completeness re-review and UX maturity closure）✅ 完成（2026-04-28）

## Architecture / Key Patterns

- **客户端**：Flutter Native（Android + iOS），竖屏优先
- **vNext mobile boundary（M010/P39 后）**：`mobile_v2/` 是独立 Flutter package，不依赖旧 `mobile/`；`mobile_v2/lib` 只允许 boundary-level semantic anchors，不承载 UI/runtime/domain truth；`tool/verify_mobile_v2_semantic_firewall.dart` 阻止旧 practice/onboarding/garden import、old-product runtime terms，以及 runtime 对 quarantine/reference 路径的导入。
- **服务端**：Spring Boot 3.4.4，**Maven 五模块 reactor**（`common` / `app-api` / `admin-api` / `db-migration` / `gateway`）
- **认证**：
  - mobile 侧已升级为 **JWT 双令牌**（access / refresh），但 controller/service 之间仍通过 `sid` claim 回桥到既有 session-centric seam
  - admin 侧使用独立 JWT + DB-backed RBAC snapshot；consumer/admin token model 保持分离
  - `admin-api` 授权 truth source 是当前数据库里的 roles/permissions，不信任 JWT 签发时的 `roles` claim
  - `admin-web` browser auth truth 收口到 `babytalk.admin.session` + `/api/admin/me` + shared refresh interceptor
  - **gateway AdminJwtGlobalFilter**：order -100；bypass 三条公开路径；6 命名错误码；结构化 WARN 日志
- **持久层（M007/S05 后）**：
  - MyBatisPlus 3.5.9 + Druid 1.2.23：所有 owned repository 均通过 `@Mapper` + XML SQL 访问数据库
  - Spring AI JdbcTemplate carve-outs：`EmbeddingConfiguration.java`（PgVectorStore）、`ChatMemoryConfiguration.java`（JdbcChatMemoryRepository）— 不可迁移
  - **Palace admin (M008)**：`AdminPalaceRagService` + `PalaceProjectionSyncService` 均用 JdbcTemplate（palace 表无 MyBatis mapper）
  - Druid slow-query logging（>2000ms）在 app-api 和 admin-api 均已配置
- **Palace RAG 检索架构（M008 后）**：
  - `PalaceHybridRetrievalService`：age-aware 检索所有者（vector + keyword + KG hints），3 temporal 分支，QueryTrace 持久化
  - palace tables：palace_rooms、palace_bridge_edges、palace_projection_version、palace_query_traces（V18–V19）
  - 严格隔离：palace_rooms/palace_bridge_edges（检索 DAG）≠ kg_entities/kg_relationships（语义 KG）
  - `PalaceProjectionSyncService` (admin-api)：异步投影同步，ingestion 完成触发版本 bump + bridge proposal 扫描
  - `AdminPalaceRagService` (admin-api)：palace RAG admin 读/写服务（JdbcTemplate-only）
  - `/api/admin/knowledge/palace/**`：6 个 REST endpoints（projection, bridge-edges list/detail/approve/reject, traces）
  - KnowledgeOpsPage.tsx：palace-rag 第三视图，3 个子视图（bridge-review / trace-samples / projection）
  - root `scripts/tsc-proxy.cjs`：worktree-root `npx tsc` 代理，委托 admin-web TypeScript 检查两个 tsconfig targets
- **Mobile widget ownership（M009/S05 后）**：
  - `features/shell/presentation/widgets/`：Discover 和 Garden 的独立显示 widget 文件（discover_view_toggle、discover_activity_card、discover_space_section、garden_hero_card、garden_continue_card、garden_patch_card）
  - `features/practice/presentation/widgets/`：Home 的独立显示 widget 文件（home_personalized_hero、home_today_scene_card、home_week_stats_card、home_garden_mini_entry、home_growth_summary_card、home_recent_result_card）加现有的 phrase_card、reaction_chip_row、activation_frame
  - 所有提取的 widget 均为纯 StatelessWidget，无状态容器，无新 truth store，行为不变
- **Admin UX（M009/S06–S07 后）**：
  - `AdminLayout.tsx`：session metadata 的 progressive disclosure（role/permissions/token detail 折叠至 antd Collapse 二级面板，destroyInactivePanel=false 保持 testid DOM 合同，work content 首位）
  - `KnowledgeOpsPage.tsx`：249 行 URL-truth orchestrator（useSearchParams 单一所有者，别名 useRouterSearchParams），surfaces（IngestionSurface/PalaceRagSurface/KgSurface）接收 query+onPatchQuery props
  - `knowledgeOpsUtils.ts`：所有工作台 surface 共享的纯函数工具模块
- **Home/Discover/Garden 视觉层级（M009/S02–S04 后）**：
  - Home：`HomeTodaySceneCard`（warmShadowMd Container）首位，账号状态、共享上下文、banner 变体在第一决策区之后
  - Discover：更短的 hero，活动卡片密度降低（sceneTag/spaceTitle chips 已移除，进度 footer 已移除），R008 recoverable-issue chip 保留
  - Garden：Zone A（hero → continue CTA）→ Zone B（error → patches）→ Zone C（household context → share → overlays）
- **部署拓扑（M007 目标，S04 后全面落地）**：
  - `babytalk-infra` Helm release：Postgres + Redis + MinIO（stateful，独立生命周期）
  - `babytalk-app` Helm release：db-migration Job（pre-install/pre-upgrade hook） + gateway + app-api + admin-api + admin-web
  - Spring Cloud Gateway (port 8090) 是唯一对外 backend 入口（dev 和 prod）；app-api/admin-api 为 internal-only services
  - compose 已从仓库中移除；所有路径经 kind + helm
- **Helm dual-release hook contract**：`pre-install,pre-upgrade` + `hook-weight: -10` + `before-hook-creation,hook-succeeded` + `backoffLimit: 1`
- **Schema 兼容策略**：N/N-1 兼容窗口；Flyway 只前进；`helm rollback babytalk-app` 只恢复工作负载不回滚 schema；schema 变更必须只追加列，不能 drop/rename
- **数据库**：PostgreSQL（含 pgvector）；Flyway 迁移由独立 `db-migration` 模块在服务前执行；current schema V19，17 migrations V3–V19
- **对象存储**：MinIO（S3 兼容）
- **向量存储**：pgvector，`vector_store` 表（embedding `vector(1536)`，HNSW 余弦索引）
- **本地存储**：Isar，离线事件、进度缓存、Mentor facts
- **Admin Web**：React + Vite + Ant Design + ProLayout；已有 live shell、Users / Knowledge Ops（含 Palace RAG Ops）/ Mentor / Distribution / Overview 五个工作面；dev proxy 指向 gateway:8090
- **KnowledgeOpsPage as-const pattern**：每个新视图在 KNOWLEDGE_OPS_VIEWS 追加条目 + normalizeXxxSubview helper + QueryState 字段 + accessibleViews push + canShowXxxSurface 变量 + ~10 处 guard sites
- **Root TypeScript 验证**：`scripts/tsc-proxy.cjs` 委托 admin-web TypeScript 检查两个 tsconfig targets；worktree root 执行 `node scripts/tsc-proxy.cjs --noEmit`
- **Offline verifier pattern**：`tool/verify_m007_s0N_*.dart` 通过 `helm template` 断言离线合同，不需要 live cluster；JSONL 遥测写入 `tmp/`
- **CI smoke pattern**：`bash ci/k8s-smoke.sh` 现有 63 断言（Step 1–11），fail-fast 并输出 first_failure_stage / hotspot
- **S08 validation evidence pattern**：run verification suite → write intermediate `s08-evidence-draft.md` → append single `## S08 Validation Evidence` section to milestone autoplan; E2E tests blocked by missing infrastructure recorded as DEFERRED (not FAIL) with explicit rationale

## Capability Contract

See `.gsd/REQUIREMENTS.md` for the explicit capability contract, requirement status, and coverage mapping.

Notable current status:

- `R055`（Gateway single front door）— **validated**（S03 admin + S04 consumer/public paths fully switched）
- `R056`（Repo-wide runtime persistence migration）— **validated**（M007/S05 complete: zero owned JdbcTemplate, Druid slow-query, 4-batch parity green）
- `R057`（Collaborative onboarding docs）— **validated**（M007/S06 complete）
- `R058`–`R060`（Family English Micro-ritual product promise, product unit, Context Seed / Joinability boundary）— **satisfied by M010/P39**（proof, SPEC linkage, semantic firewall, `mobile_v2` boundary, and verification report complete）
- `R063`–`R065`（Activation Governor authority, Garden Memory parent-confirmation, Explore/Activate pacing boundary）— **satisfied by M010/P40**（independent verifier, surface/mobile tests, proof artifact, validation gate, and verification report complete）
- M008 palace RAG enhancements (age-aware retrieval, QueryTrace, bridge review, projection visibility) — shipped and verified; no dedicated R0XX requirement; advances R005 and R011
- M009 UX maturity (Home/Discover/Garden hierarchy + mobile extraction + admin shell + KnowledgeOps) — all 8 slices complete; milestone closed 2026-04-28; validation evidence in `docs/reviews/m009-autoplan-2026-04-26.md`; E2E knowledge-ops.spec.ts deferred pending live stack

## Outstanding Follow-ups (Post-M009 / M010)

- Run `npm --prefix admin-web run test:e2e -- tests/knowledge-ops.spec.ts` against a live stack to retire the DEFERRED E2E row (validates URL truth, testid contracts, readonly alert)
- Run `npm --prefix admin-web run test:e2e -- tests/admin-login.spec.ts` against a live server to confirm AdminLayout.tsx testid DOM contracts hold after Collapse-based progressive disclosure

## Milestone Sequence

- [x] M001: 开口验证闭环 — 完整本地优先练习闭环，含个性化 onboarding 与 Mentor 援助
- [x] M002: 连续使用与留存强化 — 多活动 Discover、跨 activity 回访聚合、context-aware 下一步
- [x] M003: 扩张与分发能力 — 正式分发入口、成长分享回流、多照护者协作
- [x] M004: Review 问题收口与仓库整治 — UX 基线、Spring AI 真实 provider、仓库卫生、K8s 部署
- [x] M005: MemPalace 育儿知识宫殿 — pgvector/MinIO 基础设施、Agentic Search、多轮对话、KG、动态练习
- [x] M006: Admin 管理后台与后端多模块重构 — split backend、JWT/RBAC、admin web 五大工作面、Overview control plane、repo-root demo/smoke front door、CI/Helm release closure 全部完成
- [x] M007: Helm-first split deployment + gateway + persistence migration + docs — S01–S06 全部 ✅ 完成（2026-04-27）
- [x] M008: Graph-aware knowledge palace RAG + temporal retrieval + MemPalace design closure — S01–S03 全部 ✅ 完成（2026-04-27）
- [x] M009: Historical completeness re-review and UX maturity closure — S01–S08 全部 ✅ 完成（2026-04-28）
- [ ] M010: Baby Talk vNext Family Micro-ritual 架构重启 — Phase 39 ✅ 完成（2026-06-15）；Phase 40 ✅ 完成（2026-06-16）；Phase 41 未开始
