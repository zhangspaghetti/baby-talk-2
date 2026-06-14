# S02 Research — Spring Security + JWT 双令牌 + db-migration 模块

## Requirement Targets

- **R049** — S01 已交付 admin JWT/login/refresh/logout 半边；S02 的核心是补齐 **mobile/app-api** 这一半：SMS verify 返回双令牌、Flutter 改走 Bearer、受保护 app-api 调用链可用。
- **R050** — `db-migration` 已经是 runtime/compose/CI 的唯一 Flyway owner；S02 还缺一块 **CLI closure**：`backend/db-migration` 自己可跑 `mvn flyway:migrate`，而不是只能靠 Boot runner 或上层脚本。
- **R053 (supporting)** — S01 已有 admin auth 的 MockMvc/browser 基线；S02 需要为 consumer JWT 再补一条同等级 proof（app-api contract + Flutter refresh test），给后续 S03/S04 留可复用 harness。

## Summary

这不是从零开始的 JWT 切片。**admin half 已在 S01 落地**：`admin-api` 已经证明了 `Spring Security resource server + JWT access/refresh + refresh row rotation + post-bearer session guard` 这套模式在本仓库可跑。S02 真正的工作量在四块：

1. **app-api 侧 consumer JWT contract**：`/api/v1/auth/verify` 不再只回 `sessionId`，而要回双令牌；新增 refresh/logout；保留现有 consent/sync/mentor/household 语义。
2. **app-api 认证接入方式**：当前所有受保护路径都直接吃 `X-Session-Id`，而 app-api 还没有 SecurityFilterChain。这里要补 Spring Security，但不能误伤 `/download`、`/share/**`、`/invite/**` 这些公开路由。
3. **Flutter token persistence + refresh retry**：mobile 目前没有共享 auth client；`AccountApiService` / `HouseholdApiService` / `MentorApiService` 各自 new `http.Client`、各自塞 `X-Session-Id`。如果直接硬切，refresh 逻辑会散到三处。
4. **db-migration Maven plugin**：模块有 Flyway runtime，但还没有 `flyway-maven-plugin` 配置；`mvn flyway:migrate` 这条验收路径现在并不存在。

**Recommendation:** 按 `karpathy-guidelines` 的 *Simplicity First* 和 *Surgical Changes* 来做，优先复用 admin-api 已验证的模式，在 app-api 增加一条**兼容性 seam**，而不是一口气重写所有 controller/service 签名与 Flutter 网络层。

## Skills Discovered

- **Activated:** `karpathy-guidelines`
  - *Think Before Coding*：先盘清 public vs protected 路由边界，不能先上 blanket auth 再回头救火。
  - *Simplicity First*：不要在 S02 发明“统一 admin+mobile 超抽象认证框架”；consumer auth 只做 consumer 需要的 claims/table。
  - *Surgical Changes*：优先保住现有 `AuthConsentSyncService` / `CaregiverInviteService` / `MentorService` 的 session-centric 业务签名。
  - *Goal-Driven Execution*：先补 contract proof（JWT lifecycle web test / Flutter refresh test），再扩散改动。
- **Installed during research:** `flyway-migrations` (`ashchupliak/dream-team@flyway-migrations`)
- **Already available and directly relevant:** `spring-boot-engineer`, `flutter-managing-state`, `verify-before-complete`

## Recommendation

### 1) Reuse the admin JWT pattern, but do **not** reuse admin tables/principal model

`backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/` 已经把这条链路跑通了：

- `AdminSecurityConfig.java`：`SecurityFilterChain` + `oauth2ResourceServer().jwt()` + custom entrypoint/accessDenied + `AdminSessionGuardFilter`
- `AdminAuthService.java`：login / refresh / logout / refresh rotation / revoke
- `JwtTokenService.java`：统一 JWT encode/decode
- `V15__create_admin_auth_tables.sql`：refresh row + rotation/revoke schema

S02 应该**镜像这套模式**到 consumer/app-api，但表和 claims 继续独立：

- 新表建议：`account_refresh_tokens`（或同义命名），绑定现有 `account_sessions.session_id`
- access token 继续绑定 `rtid`，像 admin 一样依赖 refresh row active 状态让旧 bearer 立即失效
- 不把 consumer account/session 混进 admin principal/role 表

### 2) app-api 先走“Bearer canonical + session compatibility seam”，不要在 S02 重写全部业务签名

当前 app-api 仍然是**header/session 驱动**：

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncController.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/CaregiverInviteController.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java`

这些 controller 全都直接收 `@RequestHeader("X-Session-Id")`，对应 service/repository 也是 `sessionId` 贯穿到底：

- `AuthConsentSyncService.java` / `AuthConsentSyncRepository.java`
- `CaregiverInviteService.java`
- `MentorService.java`

**最小风险方案**：

- 在 `app-api` 加 `spring-boot-starter-oauth2-resource-server`
- 新增 consumer security config（建议放 `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/`）
- 让 Bearer 成为**新 canonical path**
- 但在 S02 内保留一个 compatibility seam：认证通过后，把 JWT 里的 session identity 映射回现有 session-centric downstream（例如 request attribute / wrapper 注入 / 统一 resolver），这样 controller/service 不必在一个切片内全部改成 `AuthenticationPrincipal`

这样做的好处：

- Java 侧只需要收口在 security/auth 层与 `verify/refresh/logout` 合同层
- 现有业务事务语义（consent、sync、mentor、household）可基本不动
- 现有回归测试可以分批迁移，而不是一次性改烂 5 个 web test 文件

### 3) Flutter 侧不要把 refresh 逻辑散落到三个 service；加一个小而明确的 authenticated client seam

当前 mobile 没有共享 HTTP auth layer：

- `mobile/lib/features/account/data/services/account_api_service.dart`
- `mobile/lib/features/household/data/services/household_api_service.dart`
- `mobile/lib/features/mentor/data/services/mentor_api_service.dart`

这三个 service 都：

- 自己 new `http.Client`
- 自己发请求
- 自己塞 `X-Session-Id`
- **没有共享拦截器 / BaseClient / refresh coordinator**

同时，auth state 还只存 `sessionId`：

- `mobile/lib/features/account/domain/models/account_session.dart`
- `mobile/lib/features/account/data/local/account_local_store.dart`
- `mobile/lib/features/account/data/repositories/account_repository.dart`

而下游消费方直接依赖 `snapshot.session.sessionId`：

- `mobile/lib/features/household/data/repositories/household_repository.dart`
- `mobile/lib/features/mentor/presentation/mentor_view_model.dart`

**推荐 seam：**

- 在 account feature 下新增一个很小的 `AuthenticatedApiClient` / `BearerRefreshingClient`（名字可由 planner 定）
- 它负责：
  - 从本地 snapshot/token store 读 access token
  - 加 `Authorization: Bearer ...`
  - 遇到 401 时只做 **一次** refresh
  - 持久化 rotated token 后只 replay **一次** 原请求
  - refresh 失败则清 session，暴露可见错误
- `HouseholdApiService` / `MentorApiService` 改依赖这个小 client，而不是各自复制 refresh 流程

这比在每个 repository/viewmodel 里手写“401 -> refresh -> retry”要稳得多，也更符合 *Simplicity First*。

### 4) `db-migration` 只补 Maven plugin，不要回头把 Flyway owner 再分散

`backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java` 已经能作为 Boot runner 执行 Flyway 并输出 `currentVersion` / `appliedCount`。但是：

- `backend/db-migration/pom.xml` **没有** `flyway-maven-plugin`
- 所以验收语句里的 `mvn flyway:migrate` 现在还跑不通

S02 这里应补的是：

- 仅在 `backend/db-migration/pom.xml` 加 plugin 配置
- URL/user/password 从 env 或 Maven property 读入
- `locations` 指向 `classpath:db/migration`
- 不要把 plugin 再加回 `app-api` / `admin-api`

## Implementation Landscape

### A. app-api 当前没有 Spring Security，且 protected/public 边界不是按 `/api/**` 简单切分

**当前现状**

- `backend/app-api/pom.xml` 还没有 `spring-boot-starter-oauth2-resource-server`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/WebConfig.java` 只注册了 `ApiVersionInterceptor` 和 `SecurityHeadersFilter`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/ApiExceptionHandler.java` 已定义统一错误包体（`timestamp/status/code/message/details`）

**必须继续 public / permitAll 的路由**

- `POST /api/v1/auth/challenges`
- `POST /api/v1/auth/verify`
- `GET /download`
- `GET /upgrade`
- `GET /download/redirect`
- `GET /upgrade/redirect`
- `GET /share/{token}` / `/share/{token}/open-app` / `/share/{token}/download`
- `GET /invite/{token}` / `/invite/{token}/open-app` / `/invite/{token}/download`
- `GET /actuator/health` / `/actuator/info`

**当前是 session-bound、应成为 Bearer protected 的路由**

- `POST /api/v1/consent/accept`
- `POST /api/v1/consent/revoke`
- `DELETE /api/v1/account`
- `POST /api/v1/sync/events`
- `GET /api/v1/bootstrap`
- `POST /api/v1/caregiver-invites`
- `POST /api/v1/caregiver-invites/accept`
- `POST /api/v1/caregiver-invites/{token}/revoke`
- `GET /api/v1/household/shared-context`
- `POST /api/v1/mentor/chat`

**Explicit scope call**

- `POST /api/v1/share-links` 当前没有 `X-Session-Id`，也不在本 slice success criteria 内。S02 不要顺手把它卷进认证重构，除非实现中确认它确实必须跟 mobile session 绑定。

### B. `AuthConsentSyncService` 仍是 consumer auth 的真入口，最适合补 token issuance/refresh contract

关键文件：

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncController.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncRepository.java`
- `backend/db-migration/src/main/resources/db/migration/V3__create_accounts_and_sync_tables.sql`

当前 `verifyChallenge()`：

- 验证 SMS challenge
- 创建/复用 `accounts`
- 新建 `account_sessions.session_id`
- 返回 `SessionResponse(accountId, sessionId, maskedPhoneNumber, createdAt, consentStatus)`

这意味着 S02 最自然的扩展点就是：

- `verify` 在创建 session 后**顺手发 token**
- 新增 `refresh` / `logout`
- `account_sessions` 继续作为业务 session 真相来源
- 新 refresh table 只负责 rotation/revoke/expiry，不替代现有 session domain

### C. `JwtTokenService` 已可复用，但当前 API 是 admin-shaped，不要硬拧成大一统万能抽象

文件：`backend/common/src/main/java/com/zhangspaghetti/babytalk/security/JwtTokenService.java`

当前 access token issuance 方法需要：

- `principalId`
- `username`
- `refreshTokenId`
- `roleCodes`

这很适合 admin，但对 consumer/app 不自然。S02 更稳的做法是二选一：

1. 给 `JwtTokenService` 增加一组**consumer-specific issuance overloads**（例如 session subject + installation/account claims）
2. 或在 `common/security` 下增加一个 sibling service，专门给 consumer auth 发 token

**不建议**为了“通用性”把 `JwtTokenService` 一次性改造成高度可配置 claims builder；那会把简单 slice 变成抽象工程。

### D. mobile local snapshot/schema 需要升级路径，不能假定老 snapshot 不存在

关键文件：

- `mobile/lib/features/account/domain/models/account_session.dart`
- `mobile/lib/features/account/data/local/account_local_store.dart`
- `mobile/lib/features/account/data/repositories/account_repository.dart`

当前 `AccountSession` 只持有：

- `accountId`
- `sessionId`
- `maskedPhoneNumber`
- `createdAt`

而 `AccountLocalSnapshot.fromJsonMap()` 对 `session.sessionId` 是 hard-required。也就是说：

- 如果 S02 直接把 snapshot schema 改成 token-only
- 又不做 backward read compatibility
- 升级后的 app 读到旧本地状态时就会 `FormatException` / 降级 signed out

这和“透明迁移”目标冲突。Planner 应明确保留一个**one-way read compatibility path**：

- 要么 snapshot 同时兼容 legacy `sessionId`
- 要么读取老格式后立即写回新格式
- 不要把“让用户重登一次就行”当默认策略，除非 slice owner 明确接受

### E. mobile refresh retry 的 blast radius不只 account feature

直接受影响的 runtime 文件：

- `mobile/lib/features/account/data/services/account_api_service.dart`
- `mobile/lib/features/household/data/services/household_api_service.dart`
- `mobile/lib/features/mentor/data/services/mentor_api_service.dart`
- `mobile/lib/features/household/data/repositories/household_repository.dart`
- `mobile/lib/features/mentor/presentation/mentor_view_model.dart`
- `mobile/lib/app/app.dart`

研究时确认到：

- `AccountApiService` 有 23 处 `sessionId` 相关引用，直接发 `X-Session-Id`
- `HouseholdApiService` / `MentorApiService` 也都是 header 注入
- `app.dart` 里 Account/Household service 都是各自 new `http.Client()`；`MentorViewModel` 默认也自己 new `MentorApiService()`

这意味着如果不引入一个共享 authenticated client，S02 至少会在 **account + household + mentor** 三个面上重复 refresh/retry/clear-session 逻辑。

### F. db-migration numbering has already moved; roadmap SQL version labels are stale

实际 migration 文件现在到：

- `V15__create_admin_auth_tables.sql`

所以：

- S02 新建 consumer JWT table 时，**下一号是 V16**
- 路线图里写的 `S03 -> V16__create_rbac_tables.sql` 已经过期
- planner 必须在任务分解时把 S03 的 RBAC migration 号顺延到 **V17+**，否则后续会撞号

这是本 research 中最明确的 forward-intelligence 之一。

## Don’t Hand-Roll

- **不要手写 JWT 解析过滤器。** Spring Security 6.5 已经提供 `oauth2ResourceServer().jwt()`；admin-api 也已经在本仓库证明可用。S02 应复用这条路径，再叠一个 session/refresh-row guard filter。
- **不要在 Flutter 三个 service 里各写一套 refresh retry。** 新增一个薄的 authenticated client seam，比在 repository/viewmodel 分散复制安全得多。
- **不要把 admin 与 consumer 合成一套 principal/role/session 体系。** 当前 milestone 已明确隔离两条身份边界；S02 只补 consumer JWT，不逆转这个决定。
- **不要把 `db-migration` CLI 验收变成“再起一次 Boot app 也算 migrate”。** 验收文案写的是 `mvn flyway:migrate`，就该补 plugin，不要偷换成已有 runner。

## Natural Seams / Suggested Task Boundaries

### Seam 1 — app-api consumer auth contract + schema

Files most likely touched:

- `backend/db-migration/src/main/resources/db/migration/V16__*.sql`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncController.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/security/JwtTokenService.java` (or sibling consumer token service)
- `backend/app-api/src/main/resources/application.yml`

Deliver first because it defines the external contract the Flutter side must consume.

### Seam 2 — app-api SecurityFilterChain + compatibility seam

Files most likely touched:

- `backend/app-api/pom.xml`
- new security config under `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/`
- maybe small request/session resolver helpers
- targeted controller wiring only if compatibility seam is not enough

Deliver second because it proves Bearer requests actually work before touching Flutter refresh choreography.

### Seam 3 — Flutter token persistence + shared authenticated client

Files most likely touched:

- `mobile/lib/features/account/domain/models/account_session.dart`
- `mobile/lib/features/account/data/local/account_local_store.dart`
- `mobile/lib/features/account/data/services/account_api_service.dart`
- new authenticated client/token coordinator file under `mobile/lib/features/account/data/services/`
- `mobile/lib/features/account/data/repositories/account_repository.dart`
- `mobile/lib/features/household/data/services/household_api_service.dart`
- `mobile/lib/features/mentor/data/services/mentor_api_service.dart`
- `mobile/lib/app/app.dart`
- `mobile/lib/features/mentor/presentation/mentor_view_model.dart` (constructor wiring only if needed)

Deliver third; once backend contract is stable, this is mostly local state/client plumbing.

### Seam 4 — db-migration CLI closure

Files most likely touched:

- `backend/db-migration/pom.xml`
- optionally `README`/script follow-ups later, but not required for S02 proof itself

This is operational closure, not the riskiest codepath, so it can land after auth proofs exist.

## Verification Plan

### Highest-value proofs to add first

1. **app-api JWT lifecycle contract**
   - New test file: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/JwtTokenLifecycleWebTest.java`
   - Must prove:
     - SMS verify returns `accessToken` + `refreshToken`
     - refresh rotates token
     - rotated/expired/revoked refresh returns stable 401 codes
     - old access token dies immediately after refresh/logout

2. **existing app-api protected endpoints still work under Bearer**
   - Re-run/update:
     - `AuthConsentSyncWebTest.java`
     - `MentorWebTest.java`
     - `CaregiverInviteApiWebTest.java`
     - `CaregiverInviteLandingWebTest.java`
     - `CaregiverPracticeAttributionWebTest.java`
   - Current `X-Session-Id` test blast radius found during research:
     - `AuthConsentSyncWebTest.java` — 10 refs
     - `CaregiverInviteApiWebTest.java` — 15 refs
     - `CaregiverInviteLandingWebTest.java` — 5 refs
     - `CaregiverPracticeAttributionWebTest.java` — 6 refs
     - `MentorWebTest.java` — 4 refs

3. **Flutter refresh-and-replay proof**
   - New test file: `mobile/test/features/account/jwt_session_refresh_test.dart`
   - Must prove:
     - expired access token -> refresh once -> original request replayed once
     - refresh expired -> local session cleared + visible error
     - no infinite retry loop

4. **db-migration CLI proof**
   - Command shape after plugin wiring:
     - `./backend/mvnw -f backend/db-migration/pom.xml flyway:migrate`
     - with DB env / properties injected from current local Postgres
   - Must prove module can migrate independently of Boot runner

### Fresh command set the executor should be able to run

- `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=JwtTokenLifecycleWebTest`
- `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverPracticeAttributionWebTest`
- `flutter test mobile/test/features/account/jwt_session_refresh_test.dart`
- `flutter test mobile/test/features/account/account_repository_test.dart mobile/test/features/household/household_repository_test.dart mobile/test/features/mentor/mentor_repository_test.dart`
- `./backend/mvnw -f backend/db-migration/pom.xml flyway:migrate`
- `./ci/backend-test.sh`

## Risks / Gotchas

- **Public-route trap:** app-api has public HTML/download/share/invite routes; a blanket `anyRequest().authenticated()` over `/api/**` or worse over all routes will break live pages.
- **Snapshot migration trap:** old `account_state.json` does not know about tokens. If backward read compatibility is skipped, “transparent migration” becomes forced sign-out.
- **No shared mobile auth client:** without one, refresh logic will fork across account/household/mentor and drift fast.
- **Migration number trap:** `V15` is already spent. Any plan that still reserves `V16` for RBAC is stale.
- **Test infra gotcha already known from memory:** keep using the existing Testcontainers/Hikari guardrails (`api.version=1.44`, small Hikari pool) rather than spawning new heavyweight contexts.
- **Stale helper:** `mobile/integration_test/support/in_memory_demo_backend.dart` still emulates `X-Session-Id`; if integration tests matter later, it must either learn Bearer or stay explicitly out of S02 verification scope.

## Forward Intelligence

- **Most valuable reuse is structural, not literal.** Reuse admin-api’s *pattern* (resource server + refresh-row guard), but do not force consumer auth into admin principal/role classes.
- **Session-centric business logic is an asset.** `AuthConsentSyncService`, `CaregiverInviteService`, and `MentorService` already encode the right session/consent semantics. Prefer mapping JWT -> existing session context over rewriting all downstream APIs.
- **`POST /api/v1/share-links` is a scope boundary.** It currently stands outside the session-header world. Don’t drag it into S02 unless a failing proof requires it.
- **Mobile logout UI is not the same as backend logout contract.** `AccountViewModel.clearSession()` is currently local-only. S02 can add backend logout/refresh semantics without expanding account UI scope.
- **The db-migration acceptance path is operational, not architectural.** The architecture move already happened in S01; S02 only needs to close the missing Maven plugin seam.

## Sources

- Spring Security 6.5 reference — JWT resource server / custom `SecurityFilterChain` / bearer processing
- Flyway Maven plugin docs — module-local `flyway-migrate` configuration (`url`, `user`, `password`, `locations`)

---

**Bottom line for planner:** build the backend token contract first, then the app-api security compatibility seam, then a single shared Flutter authenticated client/token-store seam, and only then close the Flyway Maven CLI. The risky part is not JWT syntax; it is avoiding unnecessary blast radius across public routes, snapshot compatibility, and three separate mobile services.
