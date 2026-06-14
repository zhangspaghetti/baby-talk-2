---
phase: "03"
plan: "03"
---

# T03: 实现四层 MemPalace Prompt 构建器、search-mode 三模式切换配置、SpringAiMentorProvider 及 MentorProviderConfiguration 重构

**实现四层 MemPalace Prompt 构建器、search-mode 三模式切换配置、SpringAiMentorProvider 及 MentorProviderConfiguration 重构**

## What Happened

实现了 T03 的全部工作：

1. **MentorProperties 扩展**：新增 `searchMode` 字段（String，默认 null）和 `effectiveSearchMode()` 便捷方法（null/blank 默认 "none"），保持 record 向后兼容。

2. **application.yml 配置**：在 `app.mentor` 下新增 `search-mode: ${BABY_TALK_MENTOR_SEARCH_MODE:none}`，默认 none 确保向后兼容。

3. **MemPalacePromptBuilder 四层 Prompt 构建器**：
   - L0: 小禾老师核心人格 + 知识来源引用指令（新增"如果使用了知识宫殿中的知识，请在回复末尾用括号标注来源书名"）
   - L1: 基于 contextSummary 预检索 top-N 知识条目，附加到 system prompt（rag/agentic 模式）
   - L2: Tool calling 工具使用指引文本（仅 agentic 模式），列出 4 个可用 tool
   - L3: 运行时由 Spring AI 框架处理
   - 异常降级：L1 预检索失败时 WARN 日志并降级为纯 L0

4. **SpringAiMentorProvider 重构**：
   - 新增四参数构造函数（ChatClient, MentorProperties, PalaceToolProvider, PalaceSearchService）
   - 保留双参数向后兼容构造函数
   - respond() 方法根据 searchMode 动态决定是否注册 tools
   - agentic 模式下通过 `.tools(palaceToolProvider)` 注册 tool calling
   - SYSTEM_PROMPT 常量指向 MemPalacePromptBuilder.L0_SYSTEM_PROMPT

5. **MentorProviderConfiguration 重构**：
   - 使用 `ObjectProvider<PalaceToolProvider>` 和 `ObjectProvider<PalaceSearchService>` 可选注入
   - ChatClient 改用 `ChatClient.builder(chatModel).build()` 模式
   - 将 PalaceToolProvider + PalaceSearchService 传给 SpringAiMentorProvider

6. **MemPalacePromptBuilderTest**（18 个测试）：覆盖 none/rag/agentic 三模式、L1 空结果/异常降级/null palaceSearch、辅助方法边界条件。

7. **SpringAiMentorProviderTest 更新**：用 @Nested 类重组为 SearchModeNone/SearchModeRag/SearchModeAgentic/BackwardCompatibility 四组，适配新构造函数和 searchMode 参数。

8. **MentorProviderConfigurationTest 修复**：适配 MentorProperties 新增 searchMode 参数和 mentorProvider 方法签名变更。

## Verification

编译通过 + 全部测试通过：

- `mvn compile test-compile -q` → exit 0
- `mvn test -Dtest="MemPalacePromptBuilderTest,SpringAiMentorProviderTest" -q` → exit 0
- `mvn test -Dtest="PalaceToolProviderTest" -q` → exit 0（T02 测试未被破坏）

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd backend && mvn compile test-compile -q` | 0 | ✅ pass | 12000ms |
| 2 | `cd backend && mvn test -pl . -Dtest="MemPalacePromptBuilderTest,SpringAiMentorProviderTest" -q` | 0 | ✅ pass | 15000ms |
| 3 | `cd backend && mvn test -pl . -Dtest="PalaceToolProviderTest" -q` | 0 | ✅ pass | 12000ms |

## Deviations

MentorProviderConfigurationTest 需要额外修复以适配新的 MentorProperties 签名和 mentorProvider 方法签名（ObjectProvider 参数），这在任务计划中未明确列出但属于必要的级联修改。

## Known Issues

None.

## Files Created/Modified

- `backend/src/main/java/com/zhangspaghetti/babytalk/config/MentorProperties.java`
- `backend/src/main/resources/application.yml`
- `backend/src/main/java/com/zhangspaghetti/babytalk/palace/MemPalacePromptBuilder.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProvider.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/MentorProviderConfiguration.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/palace/MemPalacePromptBuilderTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProviderTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/service/MentorProviderConfigurationTest.java`
