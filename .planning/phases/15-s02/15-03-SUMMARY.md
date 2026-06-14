---
phase: "15"
plan: "03"
---

# T03: 为 mobile account 引入 token-aware snapshot 持久化与单次 refresh/replay 的 AuthenticatedApiClient

**为 mobile account 引入 token-aware snapshot 持久化与单次 refresh/replay 的 AuthenticatedApiClient**

## What Happened

我先把 `AccountSession` 扩展为 legacy-compatible 的 JWT 会话模型：继续保留 `sessionId` / `accountId` / `maskedPhoneNumber` 供现有 session-centric 语义桥接，同时把 `accessToken`、`refreshToken`、`tokenType` 和两个 expiry 持久化到同一 snapshot；旧 `account_state.json` 缺 token 字段时仍可读取，不会在读档阶段直接 silent sign-out。

随后把 `AccountApiService` 的 consumer auth 契约切到 token-first：`verify` / `refresh` 解析后端新的 `{accessToken, refreshToken, tokenType, ...ExpiresAt}` 返回，受保护的 `accept/revoke/delete/bootstrap/sync` 统一改发 `Authorization: Bearer ...`。在这层之上新增 `AuthenticatedApiClient` 作为唯一 refresh seam，负责同一批 401 请求只发一次 in-flight refresh、refresh 成功后只 replay 一次原请求、并在 refresh 返回新 token 后立刻通过仓储回调落盘 rotated tokens；refresh timeout/network/malformed/revoked/rotated 等终态全部 fail-closed。

最后我把 `AccountRepository` 接到这个共享 seam：sign-in 先写入 token-aware snapshot，再用共享 client 完成 consent/bootstrap/sync；revoke/delete/bootstrap/sync 都不再手工塞 `X-Session-Id`。为了满足可观测性要求，我额外保留了 signed-out 状态下的 auth failure `lastSyncPhase`，不再在 merge 阶段一律折叠成 `signed_out`，这样 refresh 失败后的 `auth-expired` phase 与可见错误可以继续被 UI 和后续 agent 直接检查。测试层面，我更新了 `account_repository_test.dart` 以证明 token schema 落盘、legacy tokenless snapshot 兼容读取、terminal refresh failure clear-session；并新增 `jwt_session_refresh_test.dart`，明确覆盖并发 401 single-refresh replay、refresh timeout fail-closed、replay 401 loop prevention、legacy no-token fail-closed。

## Verification

已完成以下验证：

- `cd mobile && flutter test test/features/account/jwt_session_refresh_test.dart` 通过，覆盖 `AuthenticatedApiClient` 的并发 single-refresh replay、refresh timeout fail-closed、replay 401 不二次 refresh、legacy 缺 token 直接 fail-closed。
- `cd mobile && flutter test test/features/account/account_repository_test.dart test/features/account/jwt_session_refresh_test.dart` 通过，证明 sign-in 后 token schema 会落盘、legacy snapshot 仍可读取、terminal refresh failure 会清 session 并暴露 `auth-expired` phase。
- `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest` 在 bash 下通过，说明 T03 没有回归 app-api 的 consumer bearer contract。
- `cmd.exe /c "backend\\mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest"` 也通过，确认这次 auto-gate 报错来自 Windows `cmd.exe` 不识别 `./backend/mvnw` 的 shell 兼容性，而不是 app-api 测试失败。

作为中间任务，本次未重跑 slice-close 的 `db-migration` Flyway/Smoke proof；该验收仍留给 T05。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd mobile && flutter test test/features/account/jwt_session_refresh_test.dart` | 0 | ✅ pass | 16600ms |
| 2 | `cd mobile && flutter test test/features/account/account_repository_test.dart test/features/account/jwt_session_refresh_test.dart` | 0 | ✅ pass | 11700ms |
| 3 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest` | 0 | ✅ pass | 35500ms |
| 4 | `cmd.exe /c "backend\\mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest"` | 0 | ✅ pass | 12600ms |

## Deviations

按本地事实修正了两类执行细节：1）Flutter 测试必须从 `mobile/` 包根执行，而不是在 worktree 根目录直接 `flutter test mobile/...`；2）为验证 auto-gate 里的 Maven 假失败，我额外补跑了 `cmd.exe` 兼容形式的 `backend\\mvnw.cmd ...`。功能 scope 未扩张。

## Known Issues

代码路径上未发现新的功能性遗留问题。仍需注意：如果自动化通过 `cmd.exe` 执行 Maven wrapper，不能使用计划文案里的 `./backend/mvnw ...` 写法；slice-close 的 `db-migration` Flyway/Smoke proof 仍待 T05 完成。

## Files Created/Modified

- `mobile/lib/features/account/domain/models/account_session.dart`
- `mobile/lib/features/account/data/services/account_api_service.dart`
- `mobile/lib/features/account/data/services/authenticated_api_client.dart`
- `mobile/lib/features/account/data/repositories/account_repository.dart`
- `mobile/test/features/account/account_repository_test.dart`
- `mobile/test/features/account/jwt_session_refresh_test.dart`
