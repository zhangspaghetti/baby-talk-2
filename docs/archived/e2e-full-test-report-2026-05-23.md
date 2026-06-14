# BabyTalk 全栈 E2E 测试报告

**日期**: 周六 2026/05/23 19:10:26.48
**后端**: k8s (Docker Desktop) — namespace: babytalk
**前端测试**: Playwright (admin-web)
**移动端测试**: Flutter Integration Test (emulator: emulator-5554)

---

## 测试结果摘要

| 测试套件 | 状态 |
|---------|------|
| Admin Web (Playwright) | FAIL exit 1 |
| Mobile E2E (Flutter)   | PASS |

---

## 基础设施

```
App API:    http://127.0.0.1:8080  (kubectl port-forward -> babytalk app-api pod)
Admin API:  http://127.0.0.1:8081 (kubectl port-forward -> babytalk admin-api pod)
Admin Web:  http://127.0.0.1:3000 (Vite dev server 或 k8s pod)
Namespace:  babytalk
Dev SMS code: 246810
```

---

## 移动端测试截图 (Flutter)

以下截图由集成测试在 Android 模拟器 (emulator-5554) 上自动捕获。
截图按流程顺序排列：引导程序 -> 主屏幕 -> 练习 -> 标签页 -> 登录 -> Mentor。

### 000 onboarding welcome

<img src="screenshots/mobile/000_onboarding_welcome.png" alt="000 onboarding welcome" />

### 001 onboarding name entry

<img src="screenshots/mobile/001_onboarding_name_entry.png" alt="001 onboarding name entry" />

### 002 onboarding age selection

<img src="screenshots/mobile/002_onboarding_age_selection.png" alt="002 onboarding age selection" />

### 003 onboarding stage match

<img src="screenshots/mobile/003_onboarding_stage_match.png" alt="003 onboarding stage match" />

### 004 home shell ready

<img src="screenshots/mobile/004_home_shell_ready.png" alt="004 home shell ready" />

### 005 home starter seed

<img src="screenshots/mobile/005_home_starter_seed.png" alt="005 home starter seed" />

### 006 practice phrase 1

<img src="screenshots/mobile/006_practice_phrase_1.png" alt="006 practice phrase 1" />

### 007 practice phrase 2

<img src="screenshots/mobile/007_practice_phrase_2.png" alt="007 practice phrase 2" />

### 008 practice phrase 3

<img src="screenshots/mobile/008_practice_phrase_3.png" alt="008 practice phrase 3" />

### 009 home after practice

<img src="screenshots/mobile/009_home_after_practice.png" alt="009 home after practice" />

### 010 tab garden

<img src="screenshots/mobile/010_tab_garden.png" alt="010 tab garden" />

### 011 tab growth

<img src="screenshots/mobile/011_tab_growth.png" alt="011 tab growth" />

### 012 tab discover

<img src="screenshots/mobile/012_tab_discover.png" alt="012 tab discover" />

### 013 home before mentor

<img src="screenshots/mobile/013_home_before_mentor.png" alt="013 home before mentor" />

### 014 mentor panel overview

<img src="screenshots/mobile/014_mentor_panel_overview.png" alt="014 mentor panel overview" />

### 015 mentor chat input

<img src="screenshots/mobile/015_mentor_chat_input.png" alt="015 mentor chat input" />

### 016 mentor chat response

<img src="screenshots/mobile/016_mentor_chat_response.png" alt="016 mentor chat response" />

### 017 home before login

<img src="screenshots/mobile/017_home_before_login.png" alt="017 home before login" />

### 018 drawer open

<img src="screenshots/mobile/018_drawer_open.png" alt="018 drawer open" />

### 019 account entry screen

<img src="screenshots/mobile/019_account_entry_screen.png" alt="019 account entry screen" />

### 020 account signed in synced

<img src="screenshots/mobile/020_account_signed_in_synced.png" alt="020 account signed in synced" />

---

## Admin Web 测试截图 (Playwright)

完整的 HTML 报告（含所有页面截图）位于：
`admin-web/playwright-report/index.html`

### Admin Web 失败证据补齐（2026-05-23）

本次 Admin Web E2E 为 `FAIL exit 1`，失败用例总数为 `31`（来源：`admin-web/test-results/.last-run.json` 的 `failedTests` 字段）。

失败根因（统一）：
- 在失败目录 `error-context.md` 中，根因一致为 Playwright 浏览器可执行文件缺失（`Executable doesn't exist`）。

失败模块分布：

| 模块 | 失败数 |
|------|--------|
| auth-and-rbac.spec.ts | 7 |
| overview-control-plane.spec.ts | 5 |
| mentor-audit.spec.ts | 4 |
| users-management.spec.ts | 4 |
| admin-accounts.spec.ts | 3 |
| distribution-stats.spec.ts | 3 |
| knowledge-ops.spec.ts | 2 |
| admin-cookie-contract.spec.ts | 1 |
| admin-login.spec.ts | 1 |
| mentor-distribution-closure.spec.ts | 1 |

失败用例清单（31）：

1. admin-accounts.spec.ts >> admin accounts hidden route >> admins with users:read + admins:read can enter the hidden page but cannot write
2. admin-accounts.spec.ts >> admin accounts hidden route >> users-only admins do not see the entry and direct hidden-route visits land on explicit /403
3. admin-accounts.spec.ts >> admin accounts hidden route >> super admins can open the hidden page from Users and reuse existing create/disable contracts
4. admin-cookie-contract.spec.ts >> P0 cookie-backed admin session contract >> logs in without writing localStorage or sending bearer auth headers
5. admin-login.spec.ts >> legacy /protected login smoke >> keeps the compatibility alias redirecting unauthenticated visitors to /login
6. auth-and-rbac.spec.ts >> auth and rbac browser proof >> shows a visible error for bad credentials
7. auth-and-rbac.spec.ts >> auth and rbac browser proof >> lands super admins on overview and keeps all primary navigation visible
8. auth-and-rbac.spec.ts >> auth and rbac browser proof >> lands limited admins on their single module, hides unrelated nav, and makes forbidden deep links explicit
9. auth-and-rbac.spec.ts >> auth and rbac browser proof >> redirects unauthenticated visits to /login with visible return context
10. auth-and-rbac.spec.ts >> auth and rbac browser proof >> clears the stored session and returns to /login when the refresh token has been revoked
11. auth-and-rbac.spec.ts >> auth and rbac browser proof >> replays the original bootstrap request after exactly one refresh when the access token is stale
12. auth-and-rbac.spec.ts >> auth and rbac browser proof >> clears malformed stored session JSON before redirecting back to /login
13. distribution-stats.spec.ts >> distribution stats workspace >> shows truthful seeded stats, keeps filter query in URL, and redacts share tokens
14. distribution-stats.spec.ts >> distribution stats workspace >> lands distribution-only admins in stats workspace and hides mentor-only navigation
15. distribution-stats.spec.ts >> distribution stats workspace >> normalizes invalid URL filters to safe defaults while keeping query context recoverable
16. knowledge-ops.spec.ts >> knowledge ops workspace >> keeps sub-surface visibility scoped to the admin capability actually granted and forbids deep-link mutations
17. knowledge-ops.spec.ts >> knowledge ops workspace >> handles real ingestion upload/failure/retry and KG mark-read/resolve while keeping context inline
18. mentor-audit.spec.ts >> mentor audit workspace >> shows stable 403 UI when current backend permissions omit mentor:audit
19. mentor-audit.spec.ts >> mentor audit workspace >> shows explicit empty, missing-detail, and malformed-filter states
20. mentor-audit.spec.ts >> mentor audit workspace >> uses real mentor incidents, keeps queue context in URL, and shows incident-first detail states
21. mentor-audit.spec.ts >> mentor audit workspace >> clears stale local session and returns to login when /api/admin/me is 401
22. mentor-distribution-closure.spec.ts >> mentor + distribution closure proof >> keeps mentor incident evidence and distribution redaction truthful across shared shell navigation
23. overview-control-plane.spec.ts >> overview control plane proof >> renders the truthful overview control plane for super admins
24. overview-control-plane.spec.ts >> overview control plane proof >> lets single-domain overview readers deep-link into /overview while keeping hidden domains fail-closed
25. overview-control-plane.spec.ts >> overview control plane proof >> keeps the last good snapshot visible and surfaces contract failure on malformed summary refresh
26. overview-control-plane.spec.ts >> overview control plane proof >> falls back to polling after realtime loss, keeps the last good snapshot visible, and marks recovery
27. overview-control-plane.spec.ts >> overview control plane proof >> renders one stale domain among fresh domains from the overview summary contract
28. users-management.spec.ts >> users management workspace >> shows URL-backed list/detail state, requires a reason, and invalidates stale mobile tokens after disable
29. users-management.spec.ts >> users management workspace >> users-only admins keep /users/admins hidden, fail closed on deep links, and cannot disable users
30. users-management.spec.ts >> users management workspace >> keeps malformed URL context visible and surfaces detail/list failures inline
31. users-management.spec.ts >> users management workspace >> super admins can manage hidden admin accounts and surface backend validation inline

可用工件路径（已落库）：

- `admin-web/test-results/*/trace.zip`
- `admin-web/test-results/*/error-context.md`
- `admin-web/playwright-report/data/`
- `admin-web/playwright-report/trace/`

当前缺失证据（本仓库中未发现）：

- 每用例失败截图（png）
- 每用例失败视频（webm/mp4）
- 持久化 Playwright 原始 stdout/stderr 日志（当前脚本写入系统临时目录）
- HAR/网络抓包工件

### Admin Web 测试覆盖范围（按真实文件修正）

| 功能模块 | 测试文件 |
|---------|---------|
| 登录 | tests/admin-login.spec.ts |
| 认证与 RBAC | tests/auth-and-rbac.spec.ts |
| 控制台概览 | tests/overview-control-plane.spec.ts |
| 用户管理 | tests/users-management.spec.ts |
| 管理账号 | tests/admin-accounts.spec.ts |
| Cookie 合约 | tests/admin-cookie-contract.spec.ts |
| 知识库操作 | tests/knowledge-ops.spec.ts |
| Mentor 审核 | tests/mentor-audit.spec.ts |
| Mentor 分发闭环 | tests/mentor-distribution-closure.spec.ts |
| 分发统计 | tests/distribution-stats.spec.ts |

---

## 与 D11 治理契约对齐状态（2026-05-24 补充）

对照文档：
- `docs/reviews/management-decision-brief-2026-05-24.md`

### 1) 当前结论可用于 D11 吗
- 结论：**不可直接用于 D11 解冻决策**。
- 原因：缺少治理契约要求的最小工件全集（失败截图/视频、持久化 stdout/stderr、完整运行元信息映射）。

### 2) 契约对齐检查

| 契约项 | 状态 | 备注 |
|---|---|---|
| trace 工件（失败用例） | 已满足 | `admin-web/test-results/*/trace.zip` |
| 失败截图或视频 | 未满足 | 仓库内未发现逐用例失败截图/视频 |
| 原始 stdout/stderr 持久化 | 未满足 | 当前脚本写入系统临时目录 |
| 运行元信息（commit/分支/执行批次） | 部分满足 | 报告有时间与环境，缺统一批次标识映射 |

### 3) 归因分类（本次）
- 环境类：主因已确认（Playwright 浏览器可执行文件缺失）。
- 用例类：待环境修复后再判定。
- 功能类：待环境修复后再判定。

### 4) 后续动作（用于下一次全量回归）
1. 在测试前增加浏览器可执行自检步骤。
2. 落地失败截图/视频采集与持久化。
3. 持久化 stdout/stderr 并与 commit SHA 绑定。
4. 以同一契约再执行一次全量回归，作为 D11 输入。

