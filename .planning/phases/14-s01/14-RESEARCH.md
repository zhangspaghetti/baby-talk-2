# S01 Research — Split runtimes + first admin login

_Planning basis: latest `M006-ROADMAP.md` + latest `M006-CONTEXT.md` re-read after the update notice on 2026-04-23._

## Requirements Alignment

- **Primary:** R048（三/四模块 Maven 重构）, R049（Spring Security + JWT 统一认证层）, R050（独立 db-migration 模块）
- **Supports:** R051（Admin RBAC）, R052（Admin Web 管理面）, R053（admin-api MockMvc + SSE/Playwright 覆盖）, R007（合规边界）, R008（失败可见性）
- **Planning assumption:** 保留 roadmap 的 slice ID `S01`，但用更新后的 `M006-CONTEXT.md` 作为任务排序权威。也就是说：此 slice 要证明“拆 runtime + 独立 admin auth + 最小浏览器登录闭环”，**不要**把完整 Ant Design Pro 工作台、完整 RBAC、mobile JWT 硬切一起塞进同一个任务批次。

## Summary

- 当前仓库仍是**单 backend 运行时**：
  - 根 `pom.xml` 只包含 `backend`
  - `backend/pom.xml` 仍是一个可执行 Spring Boot 模块
  - 唯一入口类是 `backend/src/main/java/com/zhangspaghetti/babytalk/BabyTalkBackendApplication.java`
  - `docker-compose.yml` / Helm / CI 全都只认识一个 `backend`
- 当前后端**没有 Spring Security / JWT**：
  - `backend/pom.xml` 中没有 `spring-boot-starter-security` / JWT 相关依赖
  - 代码里没有 `SecurityFilterChain`
  - mobile auth 仍基于 `X-Session-Id`
- 当前 mobile 端 auth 仍是**session/header 心智模型**：
  - `mobile/lib/features/account/data/services/account_api_service.dart` 发送 `X-Session-Id`
  - `mobile/lib/features/account/data/repositories/account_repository.dart` 围绕 challenge/verify/session/bootstrap 编排
  - `mobile/lib/features/account/data/local/account_local_store.dart` 本地存的是 `AccountSession`，不是 access/refresh token
- 当前仓库**没有 admin-web 脚手架**：
  - 没有 `admin-web/`
  - 没有 `package.json` / `tsconfig.json` / Vite 配置 / Playwright 配置
- 更新后的 CONTEXT 明确把目标收紧为：
  - `backend/` 下最终是 **`common` + `app-api` + `admin-api` + `db-migration`**
  - `common` 必须保持**很薄**，只放共享 security primitives / DTO / base config，不要把 domain repository/service 倒进去
  - admin identity 必须与 consumer identity 分离：独立 principal store、独立 session/refresh token、独立 break-glass 路径
  - admin-web 推荐是 **React + Vite + `@ant-design/pro-components`**，不是 Umi 隐式路由脚手架
- **最大陷阱**不是“模块不够多”，而是：当前 `config/`、`service/`、`web/`、`kg/`、`ingestion/` 互相缠得很紧，任何“先抽个大 common 再说”的做法都会违反 Eng lock 并放大 blast radius。

## What exists now

| Path | Current role | Planning consequence |
| --- | --- | --- |
| `pom.xml` | repo 根聚合器，当前只列 `backend` | 继续保持 repo-level 聚合即可，不承载 runtime 逻辑 |
| `backend/pom.xml` | 单体 Boot app + 所有依赖 + 所有测试 | 应改成 backend parent/aggregator，子模块继承它 |
| `backend/src/main/java/com/zhangspaghetti/babytalk/BabyTalkBackendApplication.java` | 唯一 Boot main | 必须拆成 `app-api` / `admin-api` 各自 main，不能保留单 god app |
| `backend/src/main/resources/db/migration/V3__...sql` 到 `V14__...sql` | Flyway SQL 仍跟 runtime 混在一起 | 迁到 `db-migration`，并禁止 app/admin runtime 再各自跑 Flyway |
| `backend/src/main/java/com/zhangspaghetti/babytalk/config/*` | 混合 cross-cutting 与 runtime wiring | 只把“被双 runtime 真共享”的配置/类型搬到 `common`，其余留在本 runtime |
| `backend/src/main/java/com/zhangspaghetti/babytalk/web/*`, `service/*`, `ingestion/*`, `kg/*`, `palace/*` | 现有 mobile/business HTTP + service 层 | 当前 backend 基本就是 `app-api` 的种子，不要一开始就整体搬进 `common` |
| `mobile/lib/features/account/...` | 基于 session 的登录/恢复/同步 | 后续 JWT slice 的真实改动面；S01 不应半切到 token 半保留 session |
| `docker-compose.yml` | 只有 `postgres` / `minio` / `backend` | 后续必须扩成显式 split runtime；里程碑目标最终是五容器 |
| `deploy/helm/babytalk/templates/deployment.yaml` | 只有一个 Deployment | admin-api / admin-web 在 Helm 里基本是 greenfield |
| `.github/workflows/ci.yml` | 只有 backend-test + mobile-analyze | 没有 db-migration step，没有 admin-web build/test，没有 E2E |
| `README.md` | 单 backend onboarding | 当前与代码有 drift：README 说没有 Maven wrapper，但 `backend/mvnw` 实际存在 |

## Current code shape

- 当前 Java 包规模（粗分）:
  - `config/` = 20 files
  - `service/` = 17 files
  - `web/` = 7 controllers/advice
  - `kg/` = 14 files
  - `ingestion/` = 4 files
  - `palace/` = 6 files
- 这说明：
  - `web/`、`ingestion/`、`kg/`、大部分 `service/` 都应视作 runtime/domain 代码，不是天然的 `common`
  - `common` 应从**接近空模块**起步，再按真实复用增长

## Recommendation

1. **先锁定 slice 解释。** 用更新后的 CONTEXT 做任务顺序权威，但保留 roadmap 的 slice ID `S01`。实操上可理解为：
   - S01 要证明 runtime split + dedicated admin auth bootstrap + 最小浏览器登录 proof
   - 不要在本 slice 试图交付完整 admin workbench、完整 RBAC、mobile JWT 硬切
2. **先改 build topology，再引入 security。**
   - 把 `backend/pom.xml` 变成 parent/aggregator
   - 建 `common` / `app-api` / `admin-api` / `db-migration`
   - 先让 `app-api` 在新模块结构下尽量“行为不变”地跑起来
3. **尽早把 `db-migration` 做成一等 deploy unit。**
   - 迁移 SQL 挪过去
   - app/admin runtime 关闭 Flyway
   - compose/CI 统一改成 migration-first
4. **把 admin auth 当成独立工作流。**
   - 新 admin tables / session / refresh token / seed super_admin
   - 不复用现有 `accounts` / `account_sessions` / `sms_challenges`
5. **浏览器 proof 保持最小化。**
   - 最新 CONTEXT 已把完整 admin shell 推迟到更后面的前端脚手架阶段
   - 如果 roadmap S01 仍要求“browser login shell”，建议仅交付极薄 login page + protected stub，而不是完整 ProLayout 工作台
6. **显式遵守 Karpathy Guidelines。**
   - **Think before coding**：先写清 roadmap/context 编号冲突，不要静默选择其一
   - **Simplicity first**：最小 `common`、最小 browser proof、不要先建抽象共享层
   - **Surgical changes**：先把当前 backend 平移为 `app-api`，再做新 boundary；不要一上来同时改 ORM / pool / security / admin UI

## Natural seams / likely task boundaries

### 1) Build & parent POM seam

Likely files:

- `backend/pom.xml`
- `backend/common/pom.xml`
- `backend/app-api/pom.xml`
- `backend/admin-api/pom.xml`
- `backend/db-migration/pom.xml`
- 可能还要动 repo-root `pom.xml`

Goal:

- backend parent 统一版本/插件
- `app-api` / `admin-api` 是可执行 Boot jar
- `common` 是普通 library jar（不要带 Boot repackage main）
- `db-migration` 是独立可运行单元

### 2) App-api carve-out seam

Likely files:

- 当前 `backend/src/main/java/...` 平移到 `backend/app-api/src/main/java/...`
- `backend/app-api/src/main/java/.../AppApiApplication.java`
- `backend/app-api/src/main/resources/application.yml`
- 现有测试重归属到 `backend/app-api/src/test/...`

Goal:

- 当前 mobile/public endpoints 在新模块结构下继续可跑
- `AuthConsentSyncWebTest` / `MentorWebTest` / `IngestionControllerTest` 等 regression proof 继续通过

### 3) Thin common seam

只建议放这些“真的被双 runtime 共用”的东西：

- API version contract/interceptor 基础类型
- shared error envelope / base config
- security primitives（token utilities、principal model、password/JWT helper）
- truly shared DTO / normalized event contract

**一开始不要搬：**

- repositories
- domain services
- controllers
- ingestion / KG 业务编排

### 4) db-migration seam

Likely files:

- 全部 `backend/src/main/resources/db/migration/V*.sql`
- 新 migration runner main/config
- compose/CI wiring for “migration first”

Goal:

- schema ownership 单点化
- app/admin runtime 都不再和 Flyway 锁竞争

### 5) Admin auth seam

New files expected:

- `backend/admin-api/src/main/java/.../AdminApiApplication.java`
- `backend/admin-api/src/main/java/.../auth/*`
- admin principal / role / refresh token / audit 的新 migration
- first `super_admin` seed 机制
- MockMvc tests for login/refresh/logout/bad credential

Goal:

- admin 身份边界从第一天起就与 mobile 身份分离

### 6) Minimal browser proof seam

Greenfield files expected:

- `admin-web/package.json`
- `admin-web/vite.config.ts`
- `admin-web/src/main.tsx`
- `admin-web/src/routes/Login` 或等价结构
- 极薄 auth client

Goal:

- 浏览器能打开本地 login page 并认证到 `admin-api`
- 不要求本 slice 就把完整 admin workbench 做出来

## Critical constraints and surprises

- **ROADMAP vs CONTEXT 的编号/范围不完全一致。**
  - ROADMAP S01 仍写着 browser shell
  - 更新后的 CONTEXT 又把内部执行顺序拆成 auth/ops decisions → 多模块 → JWT → RBAC → admin-web shell
  - planner 应保留 roadmap 的 milestone bookkeeping，但任务顺序按 CONTEXT 的细粒度来排
- **现有 docs 不是可靠 runtime map。**
  - `README.md` 说没有 Maven wrapper，但 `backend/mvnw` / `backend/mvnw.cmd` 实际存在
  - 老 runbook 仍保留旧 auth/storage 假设
  - 实施时应优先相信代码与最新 roadmap/context，而不是旧 README 文案
- **admin-web 完全不存在。**
  - 这不是“改一两个页面”，而是新 package、新 compose、新 CI、新 Helm 表面
- **Spring Security 是净新增。**
  - 当前后端所有 auth 仍是 controller/service 手动校验，不是 framework auth
  - 如果放行白名单不清楚，Security 一上就可能把现有 mobile/public endpoint 全挡死
- **mobile auth 目前是 session-centric。**
  - 本地模型、API client、错误文案都围绕 `sessionId`
  - JWT 迁移是真正的后续 slice 改动面，不是 S01 顺手改完的小事

## Planner decisions to make early

1. **Parent hierarchy**
   - 最稳妥的做法是让 `backend/pom.xml` 成为四个 backend 子模块的真实 parent/aggregator
   - repo-root `pom.xml` 继续只做仓库级聚合即可
2. **Flyway runner shape**
   - 可以是极小 Boot app，也可以是 plain Java entrypoint
   - 关键是 ownership 和 deploy order，不是框架花样
3. **Admin login proof scope**
   - 推荐假设：最小 login page + protected `/me`/stub，而不是完整 admin shell
4. **Admin auth storage**
   - 必须是新表族
   - refresh token persistence 与 break-glass 约束需要从 day one 被考虑到 schema/contract
5. **Port contract**
   - 当前脚本与 mobile 默认都绑定 `app-api = 8080`
   - 低摩擦 split 建议：`admin-api = 8081`，`admin-web = 3000`

## Don’t hand-roll

- **不要手写 JWT 解析/校验。** 用 Spring Security + 标准 JOSE 支持。
- **不要手写 parallel DTO 给 admin-web。** 最新锁定要求 Java contract types in `admin-api` 是 source of truth，TS client 后续从 OpenAPI 生成。
- **不要先造 fat `common`。** 先最小、再按复用证明增长。
- **不要让 Flyway 同时跑在 `db-migration` 和两个 runtime 里。** 迁移 owner 只能有一个。
- **不要把第一个 browser proof 做成完整后台壳。** 完整 Pro shell 属于后续 slice，这里只要最小认证闭环。

## Verification plan

最小但真正能退风险的 proof：

1. **Build proof**
   - backend parent 一条命令能 build/test 全部 backend 模块
   - `app-api` / `admin-api` 都能产出独立可执行 jar
2. **Regression proof**
   - 现有 app-api 测试在模块搬迁后继续通过
3. **Admin auth contract proof**
   - MockMvc 覆盖：
     - login success
     - bad credentials
     - refresh success
     - revoked/expired refresh
     - protected endpoint 在未登录时拒绝访问
4. **Runtime proof**
   - compose 能以 migration-first 顺序拉起 split runtime
   - `app-api` 与 `admin-api` health 独立
5. **Browser proof**
   - 本地浏览器能打开 admin login UI，并在登录后进入受保护 stub/shell

Suggested commands once this slice lands:

```bash
cd backend
./mvnw test

./mvnw -pl admin-api -Dtest=AdminAuthApiTest test

docker compose up -d postgres minio db-migration app-api admin-api admin-web
```

Expected smoke checks after startup:

- `http://localhost:8080/actuator/health` → `UP`
- `http://localhost:8081/actuator/health` → `UP`
- admin login page reachable on `http://localhost:3000`
- one protected admin endpoint returns success after login and rejects unauthenticated access

## Skills discovered

- **Already present and directly relevant**
  - `spring-boot-engineer`
  - `react-best-practices`
- **Installed during research**
  - `springboot-security` (`affaan-m/everything-claude-code@springboot-security`) — first Spring Security + JWT introduction
  - `java-maven` (`pluginagentmarketplace/custom-plugin-java@java-maven`) — multi-module Maven restructuring

## Forward intelligence

- 把本 slice 拆成**三个 sub-proofs**最安全：
  1. backend build split
  2. admin auth boundary
  3. minimal browser proof
  如果 planner 把三者揉成一个超厚 task，执行风险会很高。

- 最稳的迁移顺序是：
  - 先把当前 monolith 平移成 `app-api`
  - 再建近乎空的 `common`
  - 再抽 `db-migration`
  - 然后新建 `admin-api`
  - 最后补最小 browser proof
- 更新后的 CONTEXT 还引入了 `MyBatisPlus + Druid + Hutool` 决策，这会显著扩大 blast radius。**不要**把“模块拆分 + ORM/pool 切换 + Security + admin login UI”并成一个 task；要强拆。
- README / runbook drift 很大，后续 executor 很容易拿错命令。直到文档修复前，task plan 里应明确写出命令，并优先使用 `backend/mvnw`。

## Sources

### Code

- `pom.xml`
- `backend/pom.xml`
- `backend/src/main/java/com/zhangspaghetti/babytalk/BabyTalkBackendApplication.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/WebConfig.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/ApiVersionInterceptor.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncRepository.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncController.java`
- `backend/src/main/resources/application.yml`
- `backend/src/main/resources/db/migration/V3__create_accounts_and_sync_tables.sql`
- `backend/src/test/java/com/zhangspaghetti/babytalk/AbstractIntegrationTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncWebTest.java`
- `docker-compose.yml`
- `deploy/helm/babytalk/values.yaml`
- `deploy/helm/babytalk/templates/deployment.yaml`
- `.github/workflows/ci.yml`
- `mobile/lib/features/account/data/services/account_api_service.dart`
- `mobile/lib/features/account/data/repositories/account_repository.dart`
- `mobile/lib/features/account/data/local/account_local_store.dart`
- `README.md`

### Docs

- latest `.gsd/milestones/M006/M006-ROADMAP.md`
- latest `.gsd/milestones/M006/M006-CONTEXT.md`
- Spring Boot 3.4 Maven plugin docs (Context7)
- Spring Security 6.5 JWT + MockMvc testing docs (Context7)
