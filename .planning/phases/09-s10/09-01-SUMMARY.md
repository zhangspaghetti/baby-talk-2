---
phase: "09"
plan: "01"
---

# T01: 交付 incident-first mentor audit 读模型、受 RBAC 保护的 admin API、合同测试与 runbook

**交付 incident-first mentor audit 读模型、受 RBAC 保护的 admin API、合同测试与 runbook**

## What Happened

本任务把 S10 的 backend 边界锁定为按 `correlation_id` 工作的 incident-first 审计读模型，而不是伪造完整 transcript。`backend/common` 新增 `AdminMentorAuditReadRepository`，用 plain JDBC 从 `mentor_audit_logs` / `mentor_turns` 聚合 flagged queue、detail snapshot、audit timeline 与 current live rate-limit count；queue 对外暴露稳定的 operator-facing `flagCode`，同时保留 raw `failureCode` 供排查。`admin-api` 新增 `AdminMentorAuditService`、`AdminMentorAuditController` 与 `AdminMentorAuditProperties`：`GET /api/admin/mentor/audits` 支持 `installationId` / `flag` / `limit` 过滤并保持只读，`GET /api/admin/mentor/audits/{correlationId}` 明确返回 `scope=incident_evidence`、`deliveryState`（`delivered` / `missing_turn`）、request evidence、timeline 与 live rate-limit snapshot，而不暗示多轮会话已被持久化。为保持 live snapshot truthful，admin-api 复用了 `BABY_TALK_MENTOR_RATE_LIMIT_*` 配置来源，但没有把 app-api runtime class 拉进编译依赖。随后新增 `AdminMentorAuditWebTest`，用 Postgres seed 覆盖 queue/detail 200、empty queue、non-auditor 403、disabled admin 401、unknown correlation 404、malformed filters 400、以及 rate-limited incident 的 missing-turn + live snapshot；并补 `backend/admin-api/src/test/resources/application-test.yml` 把 Hikari pool 压低，避免 admin-api 集成测试把 Postgres client 用爆。最后补了 `docs/runbooks/m006-s10-mentor-audit.md`，把 flag taxonomy、`historicalRateLimited` vs `liveRateLimit` 的差异、correlation-based triage path，以及 future transcript bridge 的 defer 边界写死。

## Verification

已运行 T01 规定的两条 backend 验证，并额外跑了 slice-level 的 build / pending checks：1) `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminMentorAuditWebTest` 通过，证明 incident-first queue/detail contract、RBAC 401/403/404、empty queue、missing-turn 与 live snapshot。2) `./backend/mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=MentorWebTest,MentorRateLimitConcurrencyTest,MentorTransactionBoundaryTest` 通过，证明本任务没有回归既有 mentor runtime。3) `npm --prefix admin-web run build` 通过，说明当前前端改动面之外的 admin-web 仍可构建。4) slice-level `npm --prefix admin-web run test:e2e -- mentor-audit.spec.ts` 当前失败，因为 T02 负责的 Playwright spec 还不存在；命令最终在 Playwright 已报 `No tests found` 后又卡在 compose cleanup，超时退出。5) `dart run tool/verify_m006_s10_mentor_audit.dart` 当前失败，因为 root-safe verify tool 文件尚未创建，这同样属于 T02 的后续闭环。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminMentorAuditWebTest` | 0 | ✅ pass | 30200ms |
| 2 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=MentorWebTest,MentorRateLimitConcurrencyTest,MentorTransactionBoundaryTest` | 0 | ✅ pass | 33900ms |
| 3 | `npm --prefix admin-web run build` | 0 | ✅ pass | 7000ms |
| 4 | `npm --prefix admin-web run test:e2e -- mentor-audit.spec.ts` | 124 | ❌ fail | 300000ms |
| 5 | `dart run tool/verify_m006_s10_mentor_audit.dart` | 255 | ❌ fail | 1895ms |

## Deviations

相对原计划，额外新增了 `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditProperties.java` 与 `backend/admin-api/src/main/resources/application.yml` 的 `app.admin.mentor-audit` 配置块，用于在不依赖 app-api runtime classes 的前提下计算 truthful 的 live rate-limit snapshot。另按 load-profile 风险预先补了 `backend/admin-api/src/test/resources/application-test.yml`，主动压低 Hikari pool，而不是等到 `too many clients already` 再修。

## Known Issues

完整 slice 级闭环仍依赖 T02：`admin-web/tests/mentor-audit.spec.ts` 与 `tool/verify_m006_s10_mentor_audit.dart` 目前都不存在，因此对应验证项尚未收口。`npm --prefix admin-web run build` 虽然通过，但前端真实 mentor audit 页面、URL context return 与 browser proof 仍待下一任务落地。

## Files Created/Modified

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditReadRepository.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditProperties.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditController.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
- `backend/admin-api/src/main/resources/application.yml`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminMentorAuditWebTest.java`
- `backend/admin-api/src/test/resources/application-test.yml`
- `docs/runbooks/m006-s10-mentor-audit.md`
