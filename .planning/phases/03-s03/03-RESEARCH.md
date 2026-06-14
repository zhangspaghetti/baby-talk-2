# S03 Research: Agentic Search 核心 + Prompt 分层

## 1. 现有架构摘要

### MentorProvider 分层

```
MentorController → MentorService (3阶段编排: 校验/调用/写入)
                 → MentorProvider (interface: respond(ProviderRequest) → ProviderResponse)
                   ├── DevMentorProvider (本地开发，固定回复)
                   └── SpringAiMentorProvider (ChatClient.prompt().system().user().call())
```

### SpringAiMentorProvider 现状

- 硬编码 `SYSTEM_PROMPT`（~100 字符，小禾老师人格 + 规则）
- **单轮无状态**：每次请求独立 `.system()` + `.user()` + `.call()`
- **无 tool calling**：ChatClient 未注册任何 tools
- **无 memory**：无 advisor、无 ChatMemory 实例
- `allowed-modes: [single_turn]` — 目前只支持单轮

### MentorProviderConfiguration 构建链

```java
OpenAiApi.builder().baseUrl(...).apiKey(...)  →  OpenAiChatModel.builder().defaultOptions(...)
→  ChatClient.create(chatModel)  →  new SpringAiMentorProvider(chatClient, properties)
```

**关键点**：ChatClient 通过 `ChatClient.create(chatModel)` 构建，未使用 builder 模式，因此无法附加 defaultTools/defaultAdvisors。S03 需要改为 `ChatClient.builder(chatModel).defaultTools(...).build()`。

### PalaceSearchService API

```java
public List<Document> search(String query, String wing, String room, int topK)
// filterExpression 使用 SQL-like 语法: wing == 'x' && room == 'y'
```

返回 `Document` 列表，每个 Document 含：

- `getText()` — 内容文本
- `getMetadata()` — JSONB: { wing, room, hall, age_range, source_book }

### 向量存储 Schema (vector_store)

| Column | Type | 说明 |
|--------|------|------|
| id | UUID | PK |
| content | TEXT | 原始文本 |
| metadata | JSONB | { wing, room, hall, age_range, source_book } |
| embedding | vector(1536) | text-embedding-3-small |

**无全文搜索基础设施** — 没有 tsvector 列，没有 GIN 索引。

### MemPalaceTaxonomy

- 5 个 Wing enum（language_development, cognitive, emotional, physical, parenting_skills）
- 18 个 Room enum
- 20+ 个 Hall enum
- 51 本书映射 + DEFAULT_MAPPING
- `MemPalaceTaxonomy.catalog()` 返回完整 map

### Spring AI 版本 & 依赖

- Spring AI 1.1.4, Spring Boot 3.4.4, Java 17
- 已有: `spring-ai-starter-model-openai`, `spring-ai-starter-vector-store-pgvector`
- 所有 auto-config 已排除 — 手动构建 beans

---

## 2. Spring AI Tool Calling 机制 (1.1.4)

### @Tool 注解方式

```java
public class PalaceTools {
    @Tool(description = "按宫殿坐标过滤的向量相似度检索")
    public String palaceVectorSearch(
        @ToolParam(description = "检索查询文本") String query,
        @ToolParam(description = "翼楼过滤，可选") String wing,
        @ToolParam(description = "房间过滤，可选") String room,
        @ToolParam(description = "返回数量") int topK) { ... }
}
```

### 注册方式

```java
// 方式 A：每次调用时传入 tool 实例
chatClient.prompt()
    .system(systemPrompt)
    .user(userMessage)
    .tools(palaceTools)  // <- 每次传入
    .call()
    .content();

// 方式 B：构建时注册为默认 tools
ChatClient.builder(chatModel)
    .defaultTools(palaceTools)
    .build();
```

### 执行流程

1. ChatClient 将 tool definitions（名称 + 描述 + 参数 schema）发送给 LLM
2. LLM 决定是否调用 tool，返回 `tool_calls` JSON
3. Spring AI 自动执行 tool 方法，获取结果
4. 结果作为 tool response 再次发给 LLM
5. LLM 根据 tool 结果生成最终回复
6. 可能多轮迭代（LLM 可以连续调用多个 tool）

### ChatMemory 集成

```java
ChatMemory chatMemory = MessageWindowChatMemory.builder().build();
ChatClient chatClient = ChatClient.builder(chatModel)
    .defaultAdvisors(MessageChatMemoryAdvisor.builder(chatMemory).build())
    .defaultTools(palaceTools)
    .build();
```

---

## 3. 设计方案

### 3.1 五个 @Tool 方法定义

| Tool | 描述 | 参数 | 返回 |
|------|------|------|------|
| `palace_vector_search` | 向量相似度检索 | query, wing?, room?, topK(default 5) | JSON: [{content, source_book, wing, room, hall, age_range}] |
| `palace_keyword_search` | PostgreSQL 全文检索 | keywords, wing?, room?, limit(default 5) | JSON: [{content, source_book, wing, room, hall}] |
| `palace_read_chunk` | 读取完整文档片段 | chunkId (UUID) | JSON: {content, metadata} |
| `palace_list_rooms` | 导航宫殿结构 | wing? | JSON: [{wing, room, description}] 或全部 wings |
| `kg_query_entity` | 知识图谱查询（先占位） | entity | JSON: {entity, related_concepts} |

### 3.2 Tool 实现类：`PalaceToolProvider`

```java
@Component
public class PalaceToolProvider {
    private final PalaceSearchService palaceSearchService;
    private final JdbcTemplate jdbcTemplate; // 用于 keyword search + read_chunk

    @Tool(description = "在知识宫殿中按语义相似度检索育儿知识片段。...")
    public String palaceVectorSearch(@ToolParam("查询文本") String query,
                                      @ToolParam("翼楼，可选") String wing,
                                      @ToolParam("房间，可选") String room,
                                      @ToolParam("返回数量，默认5") Integer topK) {
        var results = palaceSearchService.search(query, wing, room, topK != null ? topK : 5);
        return formatAsJson(results);
    }

    @Tool(description = "在知识宫殿中按关键词全文检索。...")
    public String palaceKeywordSearch(@ToolParam("关键词") String keywords,
                                       @ToolParam("翼楼过滤，可选") String wing,
                                       @ToolParam("房间过滤，可选") String room,
                                       @ToolParam("返回数量，默认5") Integer limit) {
        // 使用 PostgreSQL to_tsvector + plainto_tsquery
        return executeKeywordSearch(keywords, wing, room, limit != null ? limit : 5);
    }

    @Tool(description = "根据 chunk ID 读取完整文档片段内容。...")
    public String palaceReadChunk(@ToolParam("文档片段UUID") String chunkId) {
        // SELECT content, metadata FROM vector_store WHERE id = ?
        return readChunkById(UUID.fromString(chunkId));
    }

    @Tool(description = "列出知识宫殿结构。...")
    public String palaceListRooms(@ToolParam("翼楼名称，可选") String wing) {
        return listTaxonomyRooms(wing);
    }

    @Tool(description = "查询知识图谱中的实体关系。...")
    public String kgQueryEntity(@ToolParam("实体名称") String entity) {
        // Phase 1: 占位实现，返回 taxonomy 相关概念
        return buildEntityRelations(entity);
    }
}
```

### 3.3 四层 MemPalace Prompt (L0-L3)

```
┌─ L0 Identity (~100 tokens) ─────────────────────────────────────┐
│ 你是小禾老师... 规则... 人格设定（硬编码不变）                        │
├─ L1 Essential Story (~800 tokens) ──────────────────────────────┤
│ 按宝宝 age_range 自动预检索 top-15 核心知识条目                     │
│ （来自 vector_store where age_range matches baby age）             │
│ 每次请求前自动注入，无需 LLM 主动调用                                │
├─ L2 On-Demand Recall (tool calling) ───────────────────────────┤
│ LLM 通过 palace_vector_search / palace_keyword_search            │
│ 按需检索特定 wing/room/hall 的知识                                 │
├─ L3 Deep Search (tool calling) ─────────────────────────────────┤
│ LLM 用更宽泛的 query 做全库检索                                    │
│ 或读取特定 chunk (palace_read_chunk)                              │
│ 或导航宫殿结构 (palace_list_rooms)                                │
└─────────────────────────────────────────────────────────────────┘
```

**实现机制：**

- L0: 硬编码在 system prompt 字符串中
- L1: 在 provider 调用前，基于 context_summary 中的 baby age 执行预检索，将结果 append 到 system prompt
- L2/L3: 通过 @Tool 注册的 5 个方法，LLM 自主决策调用

### 3.4 Agentic / RAG 模式切换

**新增配置项：**

```yaml
app:
  mentor:
    search-mode: ${BABY_TALK_MENTOR_SEARCH_MODE:agentic}  # agentic | rag | none
```

| 模式 | 行为 |
|------|------|
| `agentic` | 注册 5 个 tools + L1 预注入，LLM 自主决策搜索策略 |
| `rag` | 仅 L1 预注入（纯 RAG，无 tool calling），类似 QuestionAnswerAdvisor |
| `none` | 既无 tools 也无 L1，纯 LLM 回复（现有行为 = 兼容退路） |

**实现位置**：`SpringAiMentorProvider.respond()` 方法内，根据配置决定是否附加 `.tools(palaceTools)` 和是否执行 L1 预检索。

### 3.5 ChatMemory 方案 (10 轮滑动窗口)

根据 D073，需要 10 轮滑动窗口对话记忆：

```java
ChatMemory chatMemory = MessageWindowChatMemory.builder()
    .maxMessages(20)  // 10 轮 = 20 条消息 (user + assistant)
    .build();
```

**conversationId 策略**：使用 `installationId` 作为 conversation ID（匿名用户）或 `accountId`（已认证用户）。

**注意**：`MessageWindowChatMemory` 默认使用内存存储。Phase 1 可接受。后续需要持久化时可切换到 JDBC/Redis 实现。

### 3.6 Flyway Migration — 全文搜索

需要 `V12__add_keyword_search_to_vector_store.sql`：

```sql
-- V12: 为 vector_store.content 添加 PostgreSQL 全文搜索支持
-- 使用 'simple' 配置（不做词干提取，适合中英混合文本）

-- 添加 tsvector 计算列（自动维护，insert/update 时自动生成）
ALTER TABLE vector_store
    ADD COLUMN content_tsv tsvector
    GENERATED ALWAYS AS (to_tsvector('simple', coalesce(content, ''))) STORED;

-- GIN 索引加速全文检索
CREATE INDEX idx_vector_store_content_tsv
    ON vector_store USING gin (content_tsv);
```

**全文检索 SQL 示例**：

```sql
SELECT id, content, metadata
FROM vector_store
WHERE content_tsv @@ plainto_tsquery('simple', :keywords)
  AND (metadata->>'wing' = :wing OR :wing IS NULL)
  AND (metadata->>'room' = :room OR :room IS NULL)
ORDER BY ts_rank(content_tsv, plainto_tsquery('simple', :keywords)) DESC
LIMIT :limit;
```

### 3.7 MentorProviderConfiguration 改造

需要将 ChatClient 构建改为 builder 模式并注入 tools + memory：

```java
private SpringAiMentorProvider buildSpringAiProvider(MentorProperties properties,
                                                      PalaceToolProvider palaceTools) {
    // ... OpenAiApi / OpenAiChatModel 构建不变 ...
    
    var chatClient = ChatClient.builder(chatModel)
        .defaultTools(palaceTools)  // S03 新增
        .build();
    
    return new SpringAiMentorProvider(chatClient, properties, palaceTools, palaceSearchService);
}
```

或者更灵活：在 `SpringAiMentorProvider.respond()` 内根据 search-mode 动态决定是否传 `.tools()`。

---

## 4. 关键风险与注意事项

| 风险 | 影响 | 缓解 |
|------|------|------|
| Tool calling 增加 token 消耗 | 每个 tool definition ~200 tokens × 5 = ~1000 extra tokens | 监控 + 合理设置 max_tokens |
| LLM 可能无限循环调用 tools | 请求超时 | Spring AI 默认限制 tool calling 轮次；配合 provider-timeout |
| tsvector('simple') 对中文分词效果有限 | 关键词检索可能不精确 | Phase 1 可接受；后续引入 zhparser 或 pg_jieba |
| ChatMemory 内存存储不持久 | 重启丢失 | Phase 1 接受；对话记忆是"尽力而为"的增强 |
| PalaceToolProvider 依赖 JdbcTemplate | 需要在 Provider 调用阶段持有连接 | Tool 方法应快速返回；keyword search 有索引 |

## 5. 文件变动预估

**新建：**

- `palace/PalaceToolProvider.java` — 5 个 @Tool 方法
- `config/AgenticSearchProperties.java` — search-mode 配置
- `db/migration/V12__add_keyword_search_to_vector_store.sql`
- `service/AgenticMentorProvider.java` (或改造 SpringAiMentorProvider)

**修改：**

- `config/MentorProviderConfiguration.java` — 注入 PalaceToolProvider + 模式选择
- `config/MentorProperties.java` — 新增 searchMode 字段
- `service/SpringAiMentorProvider.java` — 重构为支持 agentic/rag/none 三模式
- `resources/application.yml` — 新增 search-mode 配置

**测试：**

- `palace/PalaceToolProviderTest.java` — 工具方法单测
- `service/AgenticMentorProviderTest.java` — 模式切换 + tool calling 集成测试

## 6. 与 S02 的集成点

- S02 `PalaceSearchService.search(query, wing, room, topK)` — S03 `palace_vector_search` 工具直接调用
- S02 metadata schema (wing/room/hall/age_range/source_book) — S03 keyword search SQL 过滤条件
- S02 `MemPalaceTaxonomy.catalog()` — S03 `palace_list_rooms` 工具返回结构信息

## 7. 推荐任务拆分

1. **T01**: Flyway V12 migration + keyword search SQL 方法（JdbcTemplate 封装）
2. **T02**: PalaceToolProvider — 5 个 @Tool 方法实现 + 单元测试
3. **T03**: 四层 Prompt 构建器 + search-mode 配置 + MentorProvider 改造
4. **T04**: ChatMemory 10 轮滑动窗口集成
5. **T05**: 端到端集成测试（agentic 模式 tool calling 链路验证）
