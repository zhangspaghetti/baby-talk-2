# S04 — 多轮对话记忆 + 会话管理 — Research

**Date:** 2026-04-20

## Requirements Advanced

- R042 — 本 slice 直接交付 R042 全部内容：10 轮滑动窗口、30 分钟超时、PostgreSQL 持久化

## Requirements Validated

None yet — 由本 slice 实现后验证。

## Requirements Invalidated or Re-scoped

None.

## Summary

S04 需要在 S03 已建立的 agentic search + prompt 分层架构基础上叠加 Spring AI 的 ChatMemory 机制，实现多轮对话记忆和会话管理。核心改动集中在四个层面：

1. **依赖 + DDL**：添加 `spring-ai-starter-model-chat-memory-repository-jdbc` Maven 依赖，通过 Flyway V13 迁移创建 `SPRING_AI_CHAT_MEMORY` 表（Spring AI 官方 PostgreSQL schema）。
2. **ChatMemory 配置**：手动创建 `JdbcChatMemoryRepository`（PostgreSQL dialect）和 `MessageWindowChatMemory`（maxMessages=10）bean。不使用 Spring AI 自动配置（已在 application.yml 中排除 `ChatMemoryAutoConfiguration`）。
3. **ChatClient 重构**：将 `MessageChatMemoryAdvisor` 集成到 `SpringAiMentorProvider` 和 `MentorProviderConfiguration` 中。关键设计决策：conversationId 通过 `.advisors(a -> a.param(ChatMemory.CONVERSATION_ID, conversationId))` 在每次请求时动态传入，与 S03 的 `.tools()` 动态注入模式兼容。
4. **API 层面**：`ChatRequest`/`ChatCommand`/`ProviderRequest` 添加 `conversationId` 字段。`allowed-modes` 从 `[single_turn]` 扩展支持 `multi_turn`。30 分钟会话超时通过应用层逻辑（按 conversationId 查询最后消息时间戳）实现。

这是一个 **targeted research** 场景——Spring AI ChatMemory 是已知技术，API 模式在文档中有清晰示例，关键是在现有代码的三层编排架构（Controller → MentorService → SpringAiMentorProvider）中正确穿透 conversationId 并处理好与 agentic search tools() 的共存。

## Recommendation

**自底向上构建**：先建 DDL + 配置 bean → 重构 SpringAiMentorProvider 集成 advisor → 扩展 API 层传透 conversationId + 超时逻辑 → 集成测试验证端到端链路。

关键技术选择：

- 使用 `MessageChatMemoryAdvisor` + `.advisors()` 运行时参数注入 conversationId，而非 `.defaultAdvisors()` 构建时绑定。这样 conversationId 可以按请求变化。
- ChatClient 构建时注册 `MessageChatMemoryAdvisor` 为 defaultAdvisor（无 conversationId），每次 `.prompt()` 调用通过 `.advisors(a -> a.param(...))` 覆盖。
- 30 分钟超时不依赖 Spring AI 内置机制（没有），而是在 MentorService 层查询 `SPRING_AI_CHAT_MEMORY` 表最后一条消息的 timestamp，超过 30 分钟则生成新 conversationId 返回给客户端。
- 手动 bean 配置（不走自动配置），因为 `ChatMemoryAutoConfiguration` 已被排除，且我们需要精确控制 PostgreSQL dialect。

## Implementation Landscape

### Key Files

- `backend/pom.xml` — 需添加 `spring-ai-starter-model-chat-memory-repository-jdbc` 依赖
- `backend/src/main/resources/db/migration/V13__create_chat_memory_table.sql` — 新建：Flyway 迁移创建 SPRING_AI_CHAT_MEMORY 表
- `backend/src/main/resources/application.yml` — 修改：添加 `spring.ai.chat.memory.repository.jdbc.initialize-schema: never`（交给 Flyway），`allowed-modes` 添加 `multi_turn`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/ChatMemoryConfiguration.java` — 新建：手动配置 JdbcChatMemoryRepository + MessageWindowChatMemory + MessageChatMemoryAdvisor bean
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/MentorProviderConfiguration.java` — 重构：ChatClient 构建时注册 MessageChatMemoryAdvisor 为 defaultAdvisor
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProvider.java` — 重构：respond() 中通过 .advisors() 传入 conversationId
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/MentorProvider.java` — 修改：ProviderRequest record 添加 conversationId 字段
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java` — 修改：ChatCommand record 添加 conversationId，30 分钟超时逻辑，生成/验证 conversationId
- `backend/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java` — 修改：ChatRequest 添加 conversationId 字段
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/ConversationSessionService.java` — 新建：会话管理服务（30 分钟超时检测、conversationId 生成/验证）
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/DevMentorProvider.java` — 修改：DevMentorProvider 忽略 conversationId（dev 模式无 memory）
- `backend/src/test/java/com/zhangspaghetti/babytalk/config/ChatMemoryConfigurationTest.java` — 新建：验证 bean 正确创建
- `backend/src/test/java/com/zhangspaghetti/babytalk/service/ChatMemoryIntegrationTest.java` — 新建：多轮对话 + 窗口滑动 + 超时的端到端测试

### Build Order

1. **T01: Flyway V13 + Maven 依赖 + ChatMemory bean 配置** — 基础设施层。添加 JDBC chat memory 依赖，创建 V13 迁移脚本（`SPRING_AI_CHAT_MEMORY` 表），配置 `ChatMemoryConfiguration`（JdbcChatMemoryRepository + MessageWindowChatMemory + MessageChatMemoryAdvisor bean）。设置 `spring.ai.chat.memory.repository.jdbc.initialize-schema: never`。验证：`mvn compile` 通过，Flyway 迁移成功。这解除了所有下游任务的阻塞。

2. **T02: SpringAiMentorProvider + MentorProviderConfiguration 重构** — 核心集成层。MentorProviderConfiguration 将 MessageChatMemoryAdvisor 注册为 ChatClient defaultAdvisor。SpringAiMentorProvider.respond() 在 `.prompt()` 链中添加 `.advisors(a -> a.param(ChatMemory.CONVERSATION_ID, conversationId))`。与 S03 的 `.tools()` 共存——两者在 ChatClient fluent API 中是独立的 builder 方法，不冲突。ProviderRequest 添加 conversationId 字段。验证：单元测试验证 advisor 参数传入。

3. **T03: API 层扩展 + 会话管理（30 分钟超时）** — 应用编排层。扩展 ChatRequest/ChatCommand 添加 conversationId。创建 ConversationSessionService：查询 SPRING_AI_CHAT_MEMORY 表最后消息 timestamp，超过 30 分钟则视为过期。MentorService 在阶段 1 中调用 ConversationSessionService 验证/生成 conversationId。ChatResponse 返回 conversationId 供客户端后续请求使用。`allowed-modes` 添加 `multi_turn`。验证：单元测试 + 集成测试。

4. **T04: 端到端集成测试 + 全量编译验证** — 验证层。ChatMemoryIntegrationTest（@SpringBootTest + Testcontainers）：多轮对话中模型引用前几轮内容（通过 mock ChatClient 验证消息列表包含历史）、第 11 轮后最早对话被丢弃（验证 MessageWindowChatMemory maxMessages=10）、30 分钟超时后新对话不含旧上下文（验证 ConversationSessionService 超时逻辑）。全量 `mvn test` 所有测试通过。

### Verification Approach

1. `mvn compile test-compile -q` → exit 0（无编译错误）
2. Flyway V13 迁移在 Testcontainers PostgreSQL 上成功执行
3. `mvn test` → 全量测试通过（包括新增的 ChatMemory 相关测试和所有现有 87 个测试）
4. 多轮对话集成测试：
   - 同一 conversationId 下连续 3 次调用，验证 advisor 携带 conversationId
   - 11 次调用后验证 SPRING_AI_CHAT_MEMORY 表中该 conversation 仅保留最近 10 条
   - 模拟 30 分钟超时（通过修改 timestamp）后验证新请求生成新 conversationId
5. 向后兼容：searchMode=none + 无 conversationId 的请求行为不变（单轮模式）

## Don't Hand-Roll

| Problem | Existing Solution | Why Use It |
|---------|------------------|------------|
| 对话消息持久化到 PostgreSQL | `spring-ai-starter-model-chat-memory-repository-jdbc` + `JdbcChatMemoryRepository` | Spring AI 官方 JDBC 持久化实现，PostgresChatMemoryRepositoryDialect 处理 SQL 方言差异 |
| 滑动窗口消息管理 | `MessageWindowChatMemory(maxMessages=10)` | Spring AI 内置实现，自动在 add() 时按窗口大小裁剪旧消息 |
| 对话历史注入 LLM prompt | `MessageChatMemoryAdvisor` | Spring AI advisor 模式，自动在 prompt 调用前读取历史消息并注入，调用后保存新消息 |

## Constraints

- `ChatMemoryAutoConfiguration` 已在 application.yml 中排除——必须手动配置所有 ChatMemory bean
- `ProviderRequest` 是 record 类型——添加 conversationId 字段需要修改所有构造位置（MentorService.chat() 阶段 2 的 new ProviderRequest()）
- `MentorProperties` 是 record 类型（@ConfigurationProperties）——添加新 properties（如超时时长）需要同步更新所有 test 中的 `makeProperties()` 辅助方法
- `ChatClient` 目前在 `MentorProviderConfiguration.buildSpringAiProvider()` 内部创建——需要将 MessageChatMemoryAdvisor 通过参数传入或在内部创建
- DevMentorProvider 不使用 ChatClient——conversationId 传入后需要静默忽略

## Common Pitfalls

- **advisors() 与 tools() 共存顺序** — Spring AI ChatClient fluent API 中 `.advisors()` 和 `.tools()` 是独立的 builder 方法，可以链式调用。但 advisor 在 tools 之前执行（before chain），如果 advisor 修改了 prompt（注入历史消息），tool calling 能看到完整上下文。这是正确的行为，不需要特殊处理。
- **defaultAdvisors vs per-request advisors** — `MessageChatMemoryAdvisor` 应注册为 `defaultAdvisor`（因为每次调用都需要），conversationId 通过 `.advisors(a -> a.param(...))` 在运行时覆盖。如果不注册为 defaultAdvisor 而是每次 per-request 创建，会导致重复创建开销。
- **Flyway 与 Spring AI auto-init 冲突** — 必须设置 `spring.ai.chat.memory.repository.jdbc.initialize-schema: never`，否则 Spring AI 和 Flyway 都会尝试创建同一张表，在非首次启动时可能导致 schema 版本混乱。
- **conversationId 为 null 的向后兼容** — 当客户端未传 conversationId（单轮模式），MentorService 应自动生成一个临时 UUID 作为 conversationId，确保 MessageChatMemoryAdvisor 有合法的 conversation key。单轮请求的历史消息在后续请求中不会被访问（因为 ID 是临时的）。
- **record 字段添加破坏编译** — ProviderRequest / ChatCommand / ChatRequest 是 record，添加字段后所有构造调用都会编译失败。需要同步更新 MentorService、MentorController、以及所有测试文件中的构造调用。

## Open Risks

- Spring AI 1.1.4 的 `MessageChatMemoryAdvisor` 与 `.tools()` 的交互尚未在生产环境验证——如果 advisor 注入的历史消息格式（USER/ASSISTANT message list）与 tool calling 的消息格式（TOOL message）产生冲突，可能需要调整 advisor 的注册方式。T04 集成测试需要重点覆盖这个场景。
- 30 分钟超时需要直接查询 `SPRING_AI_CHAT_MEMORY` 表，这意味着 `ConversationSessionService` 需要 JdbcTemplate 直接读表而非通过 ChatMemoryRepository API（该 API 只暴露 get/save/delete）。如果 Spring AI 未来版本修改表结构，需要同步更新查询。

## Skills Discovered

| Technology | Skill | Status |
|------------|-------|--------|
| Spring Boot | spring-boot-engineer | installed |
| Spring AI | spring-ai | installed |

## Sources

- Spring AI ChatMemory 官方文档：JdbcChatMemoryRepository + MessageWindowChatMemory + MessageChatMemoryAdvisor 配置模式 (source: [Chat Memory :: Spring AI Reference](https://docs.spring.io/spring-ai/reference/api/chat-memory.html))
- Spring AI PostgreSQL schema DDL：`SPRING_AI_CHAT_MEMORY` 表结构（conversation_id, content, type, timestamp）(source: [schema-postgresql.sql](https://github.com/spring-projects/spring-ai/blob/main/memory/repository/spring-ai-model-chat-memory-repository-jdbc/src/main/resources/org/springframework/ai/chat/memory/repository/jdbc/schema-postgresql.sql))
- Spring AI 1.1.4 升级说明：`CHAT_MEMORY_CONVERSATION_ID_KEY` 已重命名为 `ChatMemory.CONVERSATION_ID` (source: [Upgrade Notes](https://docs.spring.io/spring-ai/reference/upgrade-notes.html))
