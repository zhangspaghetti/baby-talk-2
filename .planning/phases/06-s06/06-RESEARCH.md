# S06 Research: 移动端改造 + 动态练习生成

## Requirements Advanced

- R043 — 本研究识别了实现动态练习生成需要的全部后端和前端改造路径

## Summary

S06 有两个独立但关联的工作面：**(A) 移动端 Mentor 多轮聊天 UI 改造** 和 **(B) 练习场景由 agentic search 动态生成，淘汰 seed_content.json**。

**A 面（多轮聊天 UI）** 影响范围已被 S03/S04 收敛：后端 `ChatResponse` record 已在 S04 中添加 `conversationId` 字段；`MentorApiService.sendChat()` 在 Dart 端已发送 `contextSummary`。需要做的是：(1) Dart 端 `MentorApiService` 增加 `conversationId` 收发；(2) `MentorViewModel` 从单轮模式升级为多轮会话模式（持有 `conversationId`，维护本地 `_messages` 列表）；(3) `MentorPanelSheet` 的 `_MentorChatTab` 从单条回复卡片升级为聊天气泡列表。后端不需要改 API 结构——`ChatResponse` 已返回 `conversationId`，客户端只需要在后续请求中带回去。**知识来源引用**目前依赖 LLM 在 responseText 中以文本形式引用（L0 prompt 已指示"引用具体来源书名"），前端可以用正则匹配 `《书名》` 格式做轻量级标注，不需要后端结构化返回 `knowledgeSources[]`。

**B 面（动态练习生成）** 是更大的架构变化。当前练习系统完全离线：`AssetPhraseService` 从 `seed_content.json`（app bundle asset）加载 spaces → activities → phrases；`PracticeRepository` 围绕本地 Isar 数据库做状态追踪。D075 决定淘汰预置内容，改为 agentic search 动态生成。这意味着练习场景的"内容来源"要从本地 JSON 切换为后端 API（通过 agentic search 基于宝宝月龄/进度/场景动态生成 activity+phrases）。但 **音频播放**（`audioAsset`）依赖本地 bundle 文件——动态内容无法预打包 mp3。因此合理的增量策略是：新增一个"动态练习" API 端点，前端增加一个新 practice mode，该模式不使用 audio playback 而是走 TTS 或纯文本模式，本地 `seed_content.json` 练习模式暂时保留作为 fallback（离线或 API 不可用时）。

## Recommendation

将 S06 分为两条平行线：

1. **后端：练习生成 API**——新增 `POST /api/v1/mentor/practice/generate` 端点，接收 `{ installationId, surface, babyAgeMonths, sceneTag?, conversationId? }`，内部复用 `SpringAiMentorProvider`（agentic 模式 + 定制 practice system prompt），返回 `{ activities: [{ title, summary, sceneTag, coachTip, phrases: [{ english, chinese, pronunciation, difficulty }] }], knowledgeSources: [{ book, chapter? }], conversationId }`。
2. **移动端 Mentor 多轮聊天 UI**——`MentorApiService` 添加 `conversationId` 字段 + 本地 messages 列表 + 气泡 UI + 知识来源标注。
3. **移动端 practice 动态模式**——新增 `DynamicPracticeApiService`，`PracticeSessionViewModel` 支持 dynamic 模式（phrases 从 API 而非 asset 加载），`PracticeSessionScreen` 在 dynamic 模式下隐藏 audio 播放按钮改用 TTS。

建议构建顺序：先后端 API（可独立于前端测试） → 多轮聊天 UI（变更面最小、风险可控）→ 动态练习前端集成（依赖后端 API）。

## Implementation Landscape

### Key Files

**后端（练习生成 API）**

- `backend/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java` — 新增 `POST /practice/generate` 端点
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java` — 新增 `generatePractice()` 编排方法（复用 phase1 验证逻辑 + 调用 provider）
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProvider.java` — 新增 `respondPractice()` 方法或复用 `respond()` + practice-specific system prompt
- `backend/src/main/java/com/zhangspaghetti/babytalk/palace/MemPalacePromptBuilder.java` — 新增 practice system prompt template（指导 LLM 为指定月龄/场景生成练习短语）
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/MentorProperties.java` — `allowedSurfaces` 增加 `"practice"` 值
- `backend/src/main/resources/application.yml` — `allowed-surfaces` 列表增加 `practice`

**移动端 Mentor 多轮聊天**

- `mobile/lib/features/mentor/data/services/mentor_api_service.dart` — `MentorChatResponse` 添加 `conversationId` 字段；`sendChat()` 请求体添加 `conversationId`
- `mobile/lib/features/mentor/presentation/mentor_view_model.dart` — 新增 `_conversationId` 状态 + `_messages` 列表（本地聊天历史）；`submitChat()` 在请求中传 `conversationId`，在响应后更新本地 messages
- `mobile/lib/features/mentor/presentation/widgets/mentor_panel_sheet.dart` — `_MentorChatTab` 从单条 `_ChatResponseCard` 改为 `ListView` 气泡列表 + 知识来源高亮（正则匹配 `《》` 包围文本）

**移动端动态练习**

- `mobile/lib/features/practice/data/services/dynamic_practice_api_service.dart` — 新增：调用 `POST /api/v1/mentor/practice/generate`
- `mobile/lib/features/practice/presentation/practice_session_view_model.dart` — 支持 dynamic 模式：`_loadDynamicPhrases()` 从 API 获取 phrases
- `mobile/lib/features/practice/data/repositories/practice_repository.dart` — `getActivitySnapshot()` 增加 dynamic 路径
- `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart` — dynamic 模式下隐藏 audio player 改为 TTS 按钮

### Build Order

1. **后端 practice/generate API + 测试** — 先证明后端能动态生成练习内容（MockMvc 测试）。这是最高风险点：LLM 输出格式不稳定，需要 JSON 输出解析和 fallback。
2. **Dart MentorApiService conversationId** — 低风险，纯字段添加。
3. **MentorViewModel 多轮聊天状态** — 中等复杂度，需要维护本地 messages 列表。
4. **MentorPanelSheet 聊天气泡 UI** — 纯 UI 工作，遵循 DESIGN.md 暖纸风格。
5. **动态练习前端集成** — 最后组装，依赖步骤 1 的 API。

### Verification Approach

- **后端**：MockMvc 测试 `POST /api/v1/mentor/practice/generate` 返回包含 activities+phrases 的 JSON；`mvn test -Dtest=PracticeGenerateWebTest`
- **多轮聊天**：Dart 单元测试 `MentorViewModel` 多轮状态流转（messages 累积、conversationId 持久）；Widget 测试气泡列表渲染
- **动态练习**：Dart 单元测试 `DynamicPracticeApiService` mock HTTP 响应 → phrases 解析
- **E2E**：`flutter test` 全量通过 + `mvn test` 全量通过

## Constraints

- **音频文件不可动态生成**：`seed_content.json` 中每个 phrase 关联 `audioAsset`（mp3），动态生成的 phrases 没有预打包音频。Dynamic 模式必须走 TTS（`FlutterTtsMentorAudioController` 已存在）或纯文本模式。
- **LLM 输出不保证 JSON 格式**：practice/generate API 需要 LLM 以结构化 JSON 返回 phrases。必须在 system prompt 中严格约束输出格式，并在后端做 JSON 解析 + fallback。
- **后端 `allowed-surfaces` 白名单**：`MentorProperties.allowedSurfaces` 硬编码在 application.yml，新增 `practice` surface 需更新配置。
- **现有测试隔离问题**：S04 summary 记录了 MentorWebTest FK 污染等遗留测试失败，S06 的新测试需避免受其影响（使用独立 @SpringBootTest 配置）。

## Common Pitfalls

- **Dart 端 MentorChatResponse 反序列化遗漏** — `conversationId` 是后端 S04 新增字段，Dart `_MentorChatResponse` factory 必须解析它。如果遗漏，多轮对话在前端会每次发 null conversationId，后端自动生成新 UUID，导致每次都是新会话。确保 `_readOptionalString(json, 'conversationId')` 被添加。
- **LLM practice 输出格式漂移** — LLM 不总是严格遵循 JSON schema。后端 `generatePractice()` 必须先尝试 JSON 解析，解析失败时用正则提取或返回 fallback 练习内容。
- **seed_content.json 不能直接删除** — 现有离线练习流程、本地 Isar 事件追踪、continuity snapshot 全部依赖 `AssetPhraseService` 的 seed_content 结构。"淘汰"应理解为 dynamic 模式为默认 + seed_content 降级为 offline fallback，而非文件删除。

## Open Risks

- LLM 生成的练习 phrases 质量不稳定——pronunciation 字段需要 IPA 格式，LLM 可能生成不规范内容。可能需要后端校验或前端容错。
- `seed_content.json` → dynamic 的过渡期间，practice continuity（`PracticeContinuitySnapshot`）和 garden growth 统计系统假设 activity/phrase ID 是稳定的（来自 JSON）。动态生成的 ID 是临时的，现有统计逻辑需要适配。

## Skills Discovered

| Technology | Skill | Status |
|------------|-------|--------|
| Flutter | flutter-managing-state | installed |
| Flutter | flutter-architecting-apps | installed |
| Spring AI | spring-ai | installed |
