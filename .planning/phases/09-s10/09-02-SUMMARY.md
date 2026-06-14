---
phase: "09"
plan: "02"
---

# T02: 交付基于后端 permissions 的 mentor audit workspace、URL-backed queue/detail，以及 root-safe proof pack

**交付基于后端 permissions 的 mentor audit workspace、URL-backed queue/detail，以及 root-safe proof pack**

## What Happened

本任务把 admin-web 从 login + protected stub 落成了可操作的 mentor audit 工作台，并保持 S10 的 incident-first 语义不漂移。`admin-web/src/lib/authClient.ts` 现在会持久化 backend `permissions`，对 login `/api/admin/me` `/api/admin/auth/logout` 的 payload 做运行时 shape 校验，并在 local session 里兼容旧 session 缺少 permissions 的场景，但不会再用本地 roles 猜测放行。`admin-web/src/App.tsx` 改成在受保护页面先刷新 `/api/admin/me` 作为 current truth：成功时回写最新 identity；401 时清掉 stale session 并回登录页；缺少 `mentor:audit` 时渲染稳定 403；同时把 generic `/api/admin/me` 401 归一化成 `admin_session_invalid` UX，避免代理层只返回裸 401 时页面显示成无意义的 request_failed。随后新增 `admin-web/src/lib/mentorAuditClient.ts` 与 `admin-web/src/pages/MentorAuditPage.tsx`，在 minimal shell 中渲染 queue/detail：过滤与选中状态以后端 contract 为准并落在 URL query params `installationId` `flag` `selected` 上，detail 显式标记“incident evidence only”，展示 redacted request summary、delivered response evidence（或 missing-turn empty state）、audit timeline 与 current live rate-limit card，同时把 empty/error/404/unknown flag 都做成可见状态而不是 blank screen。验证侧把 `admin-web/playwright.global-setup.ts` / `playwright.global-teardown.ts` 扩到真实 `postgres + minio + db-migration + app-api + admin-api + admin-web` 栈，并把 compose 启动改成全量 `docker compose up -d --build`，避免 Windows 下按服务列表启动时出现 `db-migration is missing dependency postgres`。新建 `admin-web/tests/mentor-audit.spec.ts` 后，Playwright 通过真实 `/api/v1/mentor/chat` 种出 success / blocked fallback / rate-limited incidents，并覆盖 happy path、403、stale session 401、missing detail / empty queue / malformed flag；没有退回手写 DB fixture。最后新增 `tool/verify_m006_s10_mentor_audit.dart`，把 focused backend contract、`admin-web` build、mentor Playwright spec 和 `inspect_mentor_facts` smoke 串成 root-safe proof pack。

## Verification

已完成并通过任务与 slice 相关的真实验证：1) `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminMentorAuditWebTest` 通过，确认 mentor audit queue/detail contract、RBAC 与 malformed/not-found 行为未回归。2) `npm --prefix admin-web run build` 通过，确认新的 auth/session、mentor audit client/page 与 Playwright harness 能编译。3) `npm --prefix admin-web run test:e2e -- mentor-audit.spec.ts` 通过，4 条 Playwright 用真实 `/api/v1/mentor/chat` 种数据并验证 URL context return、incident-first detail、403、stale-session 401、empty/not-found/malformed states。4) `dart run tool/inspect_mentor_facts.dart --help` 通过，确认 inspect helper 仍可作为后续人工/代理诊断入口。5) `dart run tool/verify_m006_s10_mentor_audit.dart` 通过，说明 root-safe proof pack 已能顺序复跑 backend contract、frontend build、mentor Playwright spec 与 inspect helper smoke。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminMentorAuditWebTest` | 0 | ✅ pass | 18300ms |
| 2 | `npm --prefix admin-web run build` | 0 | ✅ pass | 5840ms |
| 3 | `npm --prefix admin-web run test:e2e -- mentor-audit.spec.ts` | 0 | ✅ pass | 53900ms |
| 4 | `dart run tool/inspect_mentor_facts.dart --help` | 0 | ✅ pass | 500ms |
| 5 | `dart run tool/verify_m006_s10_mentor_audit.dart` | 0 | ✅ pass | 210000ms |

## Deviations

相对原计划，额外更新了 `admin-web/playwright.global-teardown.ts` 以清理新加入的 `app-api` / `minio` 容器，并把 compose harness 从“按服务列表 up”改成全量 `docker compose up -d --build`；这是为修复当前 Windows + Docker Desktop 环境下的依赖解析问题，而不是扩 scope。另对 `/api/admin/me` 的 generic 401 做了前端归一化 banner，以满足任务要求的 stable stale-session UX。

## Known Issues

`tool/verify_m006_s10_mentor_audit.dart` 的步骤日志里仍有一处命令标题打印成字面量占位符（`$ {step.renderedCommand}` 语义），不影响命令执行或退出码；当前 proof pack 行为正确，但日志可读性还可再 polish。

## Files Created/Modified

- `admin-web/src/lib/authClient.ts`
- `admin-web/src/App.tsx`
- `admin-web/src/lib/mentorAuditClient.ts`
- `admin-web/src/pages/MentorAuditPage.tsx`
- `admin-web/playwright.global-setup.ts`
- `admin-web/playwright.global-teardown.ts`
- `admin-web/tests/mentor-audit.spec.ts`
- `tool/verify_m006_s10_mentor_audit.dart`
