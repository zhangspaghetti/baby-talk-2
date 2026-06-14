---
phase: "14"
plan: "04"
---

# T04: 交付 compose-backed admin-web 最小登录壳，并用 Playwright 证明 401 守卫、坏凭据错误态与 super_admin 首次登录闭环。

**交付 compose-backed admin-web 最小登录壳，并用 Playwright 证明 401 守卫、坏凭据错误态与 super_admin 首次登录闭环。**

## What Happened

我新建了 `admin-web` React + Vite + Ant Design 最小工程，补了 `index.html`、`src/main.tsx`、`src/App.tsx` 与 `src/lib/authClient.ts`，把 S01 的浏览器 proof 压缩在一个极薄的登录壳里：未登录访问 `/protected` 会被守卫重定向到 `/login`，并展示可见的 `admin_authentication_required` 提示；登录失败会把后端返回的 message/code 渲染成可见 Alert；登录成功后进入 protected stub，并通过真实 `GET /api/admin/me` 再校验一次 bearer token，而不是只信任本地 storage。退出登录则调用 `/api/admin/auth/logout` 做 best-effort revoke 并清空本地会话。

为避免在 S01 提前引入 admin-api CORS 复杂度，我让 admin-web 全部走相对路径 `/api/admin`：本地开发时由 `vite.config.ts` 代理到 `http://127.0.0.1:8081`，compose/runtime 时由 `nginx.conf` 反代到 `admin-api:8081`。同时新增了 `admin-web/Dockerfile` 并在 `docker-compose.yml` 中加入 `admin-web` 服务（`3000:80`，依赖 `admin-api` health），这样 `http://localhost:3000` 不再碰旧单体入口，而是直连新的 admin split runtime。

浏览器 proof 方面，我没有停留在 Vite dev proxy，而是给 `playwright.config.ts` 加了 compose-backed `globalSetup/globalTeardown`：测试前自动 `docker compose up -d --build postgres db-migration admin-api admin-web`，测试后回收相关容器。`admin-login.spec.ts` 现在覆盖 3 条真实路径：未登录访问 protected route 被拦到 login；错误凭据返回 401 且页面显示稳定错误态；使用 bootstrap 的 `super_admin / SuperAdmin123!` 可以登录并看到 protected stub。中途我修复了两个非功能性测试问题：一是 Vite 在 `npm --prefix` 下会把 repo 根误当 cwd，因此显式把 `root` 固定到 `admin-web` 目录；二是 AntD 按钮可访问名实际是“登 录”，所以给提交按钮补了稳定的 `data-testid`，避免 Playwright 因文案空格排版误判失败。

## Verification

我运行了 `npm --prefix admin-web run build`，确认最小 admin-web 能产出静态 bundle，并可被 Docker/nginx 镜像消费。随后运行 `npm --prefix admin-web run test:e2e -- admin-login.spec.ts`，Playwright 在 compose 拉起的真实 `admin-web + admin-api + db-migration + postgres` 上通过 3 个场景：`/protected` 未登录重定向、坏凭据显示可见错误态、`super_admin` 首次登录进入 protected stub。为补齐 slice 最终任务所需的后端 contract/migration 证明，我又 fresh-run 了 `bash backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest` 与 `bash backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest`；前者再次证明 admin 401 / bad credentials / refresh / logout contract 稳定，后者再次证明 V15 admin auth tables 仍由 db-migration 独占并可干净迁移到最新版本。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run build` | 0 | ✅ pass | 5880ms |
| 2 | `npm --prefix admin-web run test:e2e -- admin-login.spec.ts` | 0 | ✅ pass | 42400ms |
| 3 | `bash backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest` | 0 | ✅ pass | 18243ms |
| 4 | `bash backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` | 0 | ✅ pass | 11092ms |

## Deviations

相对 task plan，我额外加入了 `index.html`、`package-lock.json`、`playwright.global-setup.ts` 和 `playwright.global-teardown.ts`。这不是扩 scope，而是为了让计划里的单条验证命令 `npm --prefix admin-web run test:e2e -- admin-login.spec.ts` 真正自举出 compose runtime，而不是依赖外部先手工起服务。

## Known Issues

`vite build` 仍会提示单一 JS chunk 约 647kB（minified）的大包告警，因为 S01 只交付极薄登录壳，暂未做 route-level code splitting；这不阻塞首个 admin login proof，但后续 admin-web slices 增长页面后应再处理。另一个已知成本是：Playwright 的 compose-backed 首次冷启动会花数分钟构建 `admin-web/admin-api/db-migration` 镜像，热缓存复跑则约 40 秒。

## Files Created/Modified

- `admin-web/package.json`
- `admin-web/package-lock.json`
- `admin-web/index.html`
- `admin-web/vite.config.ts`
- `admin-web/playwright.config.ts`
- `admin-web/playwright.global-setup.ts`
- `admin-web/playwright.global-teardown.ts`
- `admin-web/src/main.tsx`
- `admin-web/src/App.tsx`
- `admin-web/src/lib/authClient.ts`
- `admin-web/tests/admin-login.spec.ts`
- `admin-web/Dockerfile`
- `admin-web/nginx.conf`
- `docker-compose.yml`
- `.gsd/milestones/M006/slices/S01/tasks/T03-VERIFY.json`
