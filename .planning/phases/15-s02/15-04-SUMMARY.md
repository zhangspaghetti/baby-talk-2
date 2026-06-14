---
phase: "15"
plan: "04"
---

# T04: Rewired household and mentor mobile consumers onto a shared bearer auth seam and updated app wiring/tests.

**Rewired household and mentor mobile consumers onto a shared bearer auth seam and updated app wiring/tests.**

## What Happened

我把 mobile 默认网络 wiring 收口成一条共享 consumer auth seam：`app.dart` 现在只创建一个 shared `http.Client`，并用它构造 `AccountApiService`、`AuthenticatedApiClient`、`HouseholdApiService` 与 `MentorApiService`。`AccountRepository` 新增可复用的 `persistRefreshedSession` 公开回调，供 household/mentor 在 Bearer 调用发生 refresh/replay 时复用同一 token 持久化路径，而不是各自维护独立 auth client。

在业务层，`HouseholdApiService` / `MentorApiService` 都从显式 `sessionId` transport 改成 Bearer：household 受保护方法改为消费 `AccountSession + persistRefreshedSession`，mentor 保留匿名聊天路径，但 signed-in chat 会走共享 `AuthenticatedApiClient`。`HouseholdRepository` 的 auth gate 现在要求 token-ready session，缺少 JWT 时会 fail closed 并保留既有 visible phase；`MentorViewModel` 则把 signed-in chat 改为传递 session/persist callback，并继续保持 offline/timeout/401 banner 语义。

测试方面，我把 household/mentor harness 更新为 JWT-ready snapshots，新增了 household 缺 token 不发 protected 请求、mentor signed-in `authenticated=true` 路径、以及 signed-in 401 banner 回归校验。同时因为 `AccountRepository` 公开了新接口，补齐了相关 test fake 的 `persistRefreshedSession` 实现，避免接口漂移导致的非业务性测试失败。

## Verification

在 `mobile/` 子工程上下文内完成了计划要求的 household/mentor 单测与组合验证，并额外重跑了此前 gate 失败的 account refresh/account repository 组合验证。所有 Flutter tests 均通过；新增的 household 负例证明缺 JWT 时不会发送 protected 请求，mentor 回归证明匿名聊天仍走 anonymous path、signed-in 聊天会标记 `authenticated=true` 且 401 仍暴露旧 banner 语义。最后用静态 inspection 命令确认 `app.dart` 只保留一个 shared `http.Client`，且 household/mentor service 中不再出现 `X-Session-Id`，Bearers 都通过 `Authorization` 头发送。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd mobile && flutter test test/features/household/household_repository_test.dart` | 0 | ✅ pass | 6200ms |
| 2 | `cd mobile && flutter test test/features/mentor/mentor_view_model_test.dart` | 0 | ✅ pass | 6400ms |
| 3 | `cd mobile && flutter test test/features/household/household_repository_test.dart test/features/mentor/mentor_view_model_test.dart` | 0 | ✅ pass | 23300ms |
| 4 | `cd mobile && flutter test test/features/account/jwt_session_refresh_test.dart test/features/account/account_repository_test.dart` | 0 | ✅ pass | 7300ms |
| 5 | `python - <<'PY' ... shared auth wiring inspection ... PY` | 0 | ✅ pass | 0ms |

## Deviations

验证命令需要在 `mobile/` 子工程上下文中执行（`cd mobile && flutter test test/...`），因为从 worktree 根直接运行 `flutter test mobile/...` 时，Flutter 会把根目录当作 project root，导致 `package:mobile` 无法解析。实现范围本身未偏离任务计划。

## Known Issues

None.

## Files Created/Modified

- `mobile/lib/app/app.dart`
- `mobile/lib/features/account/data/repositories/account_repository.dart`
- `mobile/lib/features/household/data/services/household_api_service.dart`
- `mobile/lib/features/household/data/repositories/household_repository.dart`
- `mobile/lib/features/mentor/data/services/mentor_api_service.dart`
- `mobile/lib/features/mentor/presentation/mentor_view_model.dart`
- `mobile/test/features/household/household_repository_test.dart`
- `mobile/test/features/mentor/mentor_view_model_test.dart`
