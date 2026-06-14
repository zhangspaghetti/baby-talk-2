---
phase: "14"
plan: "03"
---

# T03: 为 admin-api 落地独立 JWT 登录/刷新/登出合同，并 seed 首个 super_admin。

**为 admin-api 落地独立 JWT 登录/刷新/登出合同，并 seed 首个 super_admin。**

## What Happened

我在 `common` 中补了 `JwtTokenService`，在 `admin-api` 中引入独立的 Spring Security resource-server filter chain、JWT encoder/decoder、BCrypt password encoder，以及稳定的 401/403 JSON 错误面。新的 admin 合同为 `POST /api/admin/auth/login`、`POST /api/admin/auth/refresh`、`POST /api/admin/auth/logout` 和 `GET /api/admin/me`；其中 `/actuator/health` 保持匿名可访问，`/api/admin/me` 在无 token、旧 token、被登出 token 下都会稳定返回 401，不再复用 mobile 侧的 `X-Session-Id`、`accounts` 或 `account_sessions` 表。\n\n在 schema 层，我新增了 `V15__create_admin_auth_tables.sql`，建立 `admin_principals`、`admin_roles`、`admin_principal_roles`、`admin_refresh_tokens` 四张独立表，把 admin principal、角色和 refresh 会话与 consumer identity 完全隔离。首个 `super_admin` 不是写死在 controller 里，而是由 admin-api 启动时的 bootstrap runner 根据配置幂等 seed；日志只记录 `invalid_credentials` / `expired` / `rotated` / `revoked` 这类可追踪失败原因，不回显 password、JWT 或 refresh token 原文。\n\n实现上我采用了“access token 绑定当前 `refresh_token_id`”的会话模型：access JWT 带 `rtid` claim，受保护请求会回查 `admin_refresh_tokens` 当前行是否仍为 `active`。这样 refresh 轮换和 logout revoke 后，旧 access token 会立即失效，不需要额外 access-token blacklist。为保证任务合同里的 reactor 验证命令可以直接工作，我还把 `admin-api` 测试改为从 `db-migration` test classpath 读取 `classpath:db/migration`，并在 `common` / `db-migration` 的 surefire 配置中显式设了 `failIfNoSpecifiedTests=false`，避免 `-pl admin-api -am -Dtest=AdminAuthWebTest` 先被上游无匹配测试模块拦住。

## Verification

我运行了任务合同命令 `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest`，通过 `MockMvc + Testcontainers PostgreSQL + Flyway V3-V15` 验证了 4 条关键链路：`super_admin` seed 后可成功登录；`/actuator/health` 可匿名访问；`/api/admin/me` 在无 token 时返回 401；坏凭据返回稳定 `invalid_admin_credentials`；refresh 会轮换 refresh row 并让旧 access/refresh 立即失效；expired / revoked refresh 与 logout 后的 bearer 再访问均返回稳定 401。测试内还显式断言了 `accounts` / `account_sessions` 仍为 0，证明 admin auth 没有复用 consumer session 边界。\n\n我另外运行了 `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest`，确认 `db-migration` 仍可独立完成 V3-V15 全量迁移，Flyway history 里已包含 V15，且 `admin_principals` / `admin_refresh_tokens` 表真实存在。这同时继续守住了 slice 里的 migration/log/exit-code 侧 proof。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest` | 0 | ✅ pass | 21807ms |
| 2 | `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` | 0 | ✅ pass | 16898ms |

## Deviations

为了让任务合同里的精确验证命令在多模块 reactor 下可重复执行，我没有继续依赖不稳定的 `filesystem:` Flyway 路径，而是给 `admin-api` 增加了 `db-migration` 的 test-scope 依赖，并把 `common` / `db-migration` 的 surefire 配置改成 `failIfNoSpecifiedTests=false`。这属于局部验证适配，没有改变任务目标或 admin auth 边界。

## Known Issues

当前 `application.yml` 中的 bootstrap `super_admin` 用户名/密码是本地 demo 默认值，生产/compose 侧仍需要在后续切片里改成明确的部署时环境变量或 secret 管理。另一个有意留白是：本任务只 seed 了 `super_admin` 角色与独立 auth 基线，细粒度 permissions / RBAC matrix 仍留给后续 slice。

## Files Created/Modified

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/security/JwtTokenService.java`
- `backend/common/pom.xml`
- `backend/admin-api/pom.xml`
- `backend/admin-api/src/main/resources/application.yml`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminSecurityConfig.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthService.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminAuthWebTest.java`
- `backend/db-migration/src/main/resources/db/migration/V15__create_admin_auth_tables.sql`
- `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`
- `backend/db-migration/pom.xml`
