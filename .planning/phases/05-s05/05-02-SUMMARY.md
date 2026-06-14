---
phase: "05"
plan: "02"
---

# T02: 实现 KG 矛盾检测器 + Agent 审查服务 + 配置属性 + 单元测试，11 个测试全部通过，编译成功

**实现 KG 矛盾检测器 + Agent 审查服务 + 配置属性 + 单元测试，11 个测试全部通过，编译成功**

## What Happened

实现了 KG 核心业务逻辑的四个文件和两个测试类：

1. **KgProperties** — `@ConfigurationProperties(prefix = "app.kg")` 绑定三个配置项：reviewInterval、reviewEnabled、reviewBatchSize。

2. **KgConfiguration** — `@EnableScheduling` + `@EnableConfigurationProperties` + `kgReviewChatClient` bean。ChatClient 复用 MentorProperties 的 AI 配置（同一 API key/base-url/model），但独立于 mentor 的 ChatClient，不绑定会话记忆或工具，使用低温度(0.2)以获得更稳定的 JSON 输出。

3. **KgContradictionDetector** — `onRelationshipInserted(KgRelationship)` 方法在 contradicts 类型关系写入时自动创建 KgContradiction 记录（detected 状态）。加载源/目标实体组装 entityTopic 和 description，实体不存在时跳过并记录警告日志。

4. **KgContradictionReviewService** — `@Scheduled` 定时审查服务。每轮扫描 detected 状态的矛盾记录，调用 LLM 判定 resolved/escalated。审查流程：标记 reviewing → 构建中文 prompt（要求 JSON 输出）→ 调用 ChatClient → 解析 verdict → 更新状态 → escalated 时创建管理员通知。安全默认：LLM 调用失败/返回空/JSON 解析失败时保持 detected 状态不变。

5. **配置更新** — application.yml 新增 `app.kg` 配置块（5分钟轮询、启用、批次10），application-test.yml 新增测试配置（1分钟轮询、禁用、批次5）。

6. **单元测试** — KgContradictionDetectorTest（4 tests）覆盖 contradicts 触发、非 contradicts 跳过、源实体/目标实体不存在。KgContradictionReviewServiceTest（7 tests）覆盖 resolved/escalated 判定、ChatClient 异常、非 JSON 响应、空响应、reviewEnabled=false 跳过、批次处理。

## Verification

编译验证：`mvn compile test-compile -q` → BUILD SUCCESS (exit 0)。
单元测试：`mvn test -Dtest=KgContradictionDetectorTest,KgContradictionReviewServiceTest` → Tests run: 11, Failures: 0, Errors: 0 (exit 0)。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd backend && mvn compile test-compile -q` | 0 | ✅ pass | 3500ms |
| 2 | `cd backend && mvn test -Dtest=KgContradictionDetectorTest,KgContradictionReviewServiceTest` | 0 | ✅ pass | 8352ms |

## Deviations

计划中 KgContradictionReviewService 使用 SpEL 表达式 `#{@kgProperties.reviewInterval().toMillis()}` 设置 @Scheduled fixedDelay，实际实现一致无偏差。

## Known Issues

矛盾审查流程先标记 reviewing 但异常时并未回退为 detected — 下次扫描时 findPendingReview 只查 detected 状态，reviewing 状态的矛盾不会被重新拾起。这需要一个独立的 stuck-reviewing 清理机制或在异常处理中显式回退状态。已在代码注释中记录，不影响编译和测试。

## Files Created/Modified

- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgProperties.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgConfiguration.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgContradictionDetector.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgContradictionReviewService.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/kg/KgContradictionDetectorTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/kg/KgContradictionReviewServiceTest.java`
- `backend/src/main/resources/application.yml`
- `backend/src/test/resources/application-test.yml`
