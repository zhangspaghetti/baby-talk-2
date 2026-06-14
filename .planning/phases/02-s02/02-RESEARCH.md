# S02 Research: 知识宫殿 Ingestion 管道 + taxonomy 设计

**Date:** 2026-04-20

## Requirements Advanced

- R041 — 本 slice 将定义 MemPalace Wing/Room/Hall taxonomy 数据模型，创建元数据标注逻辑，并实现按宫殿坐标过滤的向量检索
- R045 — 本 slice 将实现完整 ingestion 管道：REST API 上传 → MinIO 存储 → 异步多格式解析 → 智能分块 → 元数据标注 → embedding → PgVector，以及批量导入脚本

## Requirements Validated

- R046 — docker-compose up -d 全栈健康，/actuator/health 返回 db(PostgreSQL)+minio 均 UP，Flyway V10 创建 pgvector 扩展 + vector_store 表 + HNSW 索引（S01 已完成）

## Requirements Invalidated or Re-scoped

None.

## Summary

S02 是 M005 的核心数据层 slice，在 S01 已建立的 PostgreSQL(pgvector) + MinIO 基础设施上构建完整的文献 ingestion 管道和 MemPalace 知识分类体系。

**关键发现：**

1. **Spring AI 1.1.4 已有完整的 ETL 管道**：`TikaDocumentReader`（Apache Tika，支持 PDF/ePub/DOCX/TXT 等 1000+ 格式）→ `TokenTextSplitter`（基于 jtokkit CL100K_BASE 分词，按 token 数智能分块）→ `PgVectorStore`（写入 vector_store 表，自动调用 EmbeddingModel 生成向量）。无需自行实现解析和分块逻辑。

2. **Embedding 配置需独立于 Mentor Chat**：当前 `MentorProviderConfiguration` 手动构建 `OpenAiApi` + `OpenAiChatModel`（已 exclude 了所有 OpenAI 自动配置）。Embedding 也需要独立手动构建 `OpenAiEmbeddingModel`，使用自己的 base_url / api_key（D072 决策：通过胜算云等第三方 proxy）。不能复用 `spring.ai.openai.*` 自动配置。

3. **PgVectorStore 的 metadata 过滤机制**：Spring AI 的 `SearchRequest` 支持 `filterExpression("wing == 'language_development' && room == 'bilingual'")`，直接在 SQL 层对 JSONB metadata 字段做过滤。MemPalace 的 wing/room/hall 坐标只需作为 metadata key 存入 Document，无需额外的关系表。

4. **MinIO bucket 需要 S02 创建**：S01 的 MinioHealthIndicator 只检测连通性，不创建 bucket。S02 必须在应用启动或首次上传时确保 bucket 存在。

5. **现有 vector_store 表结构完全兼容**：V10 迁移已创建 `vector_store(id UUID, content TEXT, metadata JSONB, embedding vector(1536))`，这正是 PgVectorStore 的默认表结构。

## Recommendation

**采用 Spring AI 原生 ETL 管道 + 自定义 MemPalace MetadataEnricher**：

1. 用 `TikaDocumentReader` 做多格式解析（PDF/ePub/TXT 一个类搞定）
2. 用 `TokenTextSplitter` 做智能分块（~800 tokens/chunk，保持语义完整性）
3. 自定义 `MemPalaceMetadataEnricher` 实现 `DocumentTransformer`，在 chunk 的 metadata 中注入 wing/room/hall/source_book/age_range
4. 用 `PgVectorStore.add(documents)` 写入，它会自动调用 EmbeddingModel 生成向量

**taxonomy 设计不需要额外的关系表**：wing/room/hall 作为 Document metadata 存储在 vector_store 的 JSONB 字段中，通过 PgVectorStore 的 filterExpression 过滤检索。一个独立的 `palace_taxonomy` 配置表/enum 定义合法的 wing→room→hall 映射关系即可。

**异步处理**：用 Spring 的 `@Async` + `CompletableFuture` 处理上传后的 ingestion 流程，避免 REST API 阻塞。ingestion 状态通过 `ingestion_jobs` 表跟踪。

## Implementation Landscape

### Key Files

- `backend/pom.xml` — 需添加 `spring-ai-tika-document-reader` 依赖（Tika 多格式解析）
- `backend/src/main/resources/application.yml` — 添加 `app.embedding.*` 配置块（独立于 app.mentor 的 base-url/api-key/model），添加 `app.ingestion.*` 配置
- `backend/src/main/resources/db/migration/V11__create_ingestion_tables.sql` — 创建 `ingestion_jobs`（跟踪异步处理状态）、`palace_taxonomy`（wing/room/hall 合法映射，可选用 enum 替代）表
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/EmbeddingProperties.java` — Embedding 配置属性（base-url/api-key/model/dimensions），独立于 MentorProperties
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/EmbeddingConfiguration.java` — 手动构建 OpenAiEmbeddingModel + PgVectorStore Bean（排除自动配置，手动 wiring）
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/AsyncConfiguration.java` — @EnableAsync + 自定义 TaskExecutor（ingestion 线程池）
- `backend/src/main/java/com/zhangspaghetti/babytalk/palace/MemPalaceTaxonomy.java` — Wing/Room/Hall 枚举或配置类，定义知识宫殿分类体系
- `backend/src/main/java/com/zhangspaghetti/babytalk/palace/MemPalaceMetadataEnricher.java` — DocumentTransformer 实现，根据书名/内容注入 wing/room/hall/source_book/age_range metadata
- `backend/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionService.java` — 核心 ingestion 编排：MinIO 上传 → 异步解析 → 分块 → 元数据标注 → embedding → PgVector
- `backend/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionRepository.java` — ingestion_jobs 表 CRUD
- `backend/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionController.java` — REST API：POST /api/v1/ingestion/upload（单文件）、POST /api/v1/ingestion/batch（触发批量）、GET /api/v1/ingestion/jobs/{id}（状态查询）、POST /api/v1/ingestion/jobs/{id}/retry（重试）
- `backend/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceSearchService.java` — 封装 PgVectorStore.similaritySearch + SearchRequest.filterExpression，提供按宫殿坐标过滤的检索接口
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/MinioBucketInitializer.java` — ApplicationRunner，启动时确保 MinIO bucket 存在
- `scripts/batch-ingest.sh` (或 `.cmd`) — 批量导入脚本，调用 REST API 逐文件上传 51 本文献

### Build Order

1. **Embedding + PgVectorStore Bean 配置** — 先让 embedding 和向量存储可用，这是其他一切的前提。需要独立的 `EmbeddingProperties`，手动构建 `OpenAiEmbeddingModel` 和 `PgVectorStore`。验证：Spring context 启动成功 + PgVectorStore bean 可注入。

2. **Flyway V11 迁移 + MinIO bucket 初始化** — 创建 ingestion_jobs 表 + palace_taxonomy 结构；ApplicationRunner 确保 MinIO bucket 存在。验证：docker-compose up 后 actuator/health UP + bucket 存在。

3. **MemPalace taxonomy + MetadataEnricher** — 定义 Wing/Room/Hall 分类体系和 51 本文献的元数据映射。这是 ingestion 管道的关键数据质量环节。验证：给定书名 → 正确输出 wing/room/hall/source_book/age_range metadata。

4. **Ingestion 管道核心** — TikaDocumentReader → TokenTextSplitter → MetadataEnricher → PgVectorStore.add()。先做同步版本验证端到端正确性。验证：上传一个 TXT 文件 → vector_store 表有带正确 metadata 的记录。

5. **REST API + 异步化** — 上传接口 + ingestion 状态跟踪 + @Async 异步执行 + 重试 API。验证：POST 上传 → 202 Accepted → GET 状态 → completed。

6. **按宫殿坐标过滤检索** — PalaceSearchService 封装 SearchRequest.filterExpression。验证：插入不同 wing 的文档 → 按 wing 过滤返回正确子集。

7. **批量导入脚本** — shell/cmd 脚本调用 REST API 逐文件导入。验证：脚本能正确调用 API。

### Verification Approach

1. **集成测试**（继承 AbstractIntegrationTest）：
   - `IngestionServiceTest`: 上传 TXT → 验证 vector_store 有记录 + metadata 正确
   - `PalaceSearchServiceTest`: 插入文档 → 按 wing/room/hall 过滤 → 返回正确结果
   - `IngestionControllerTest`: MockMvc POST /api/v1/ingestion/upload → 202 + job 状态
   - 注意：集成测试中 embedding 调用需 mock（不依赖真实 OpenAI API key）

2. **端到端验证**（docker-compose）：
   - `docker-compose up -d` → 全部 healthy
   - `curl POST /api/v1/ingestion/upload` 上传测试文件 → 202
   - `curl GET /api/v1/ingestion/jobs/{id}` → completed
   - `SELECT count(*) FROM vector_store WHERE metadata->>'wing' = 'xxx'` → 有记录

3. **单元测试**：
   - `MemPalaceTaxonomy`: 书名到 wing/room/hall 映射正确性
   - `MemPalaceMetadataEnricher`: 输入 Document → 输出包含正确 metadata

## Don't Hand-Roll

| Problem | Existing Solution | Why Use It |
|---------|------------------|------------|
| 多格式文档解析（PDF/ePub/TXT） | Spring AI `TikaDocumentReader`（Apache Tika） | 支持 1000+ 格式，生产级稳定，无需自行处理各种编码/格式边界情况 |
| 智能文本分块 | Spring AI `TokenTextSplitter`（jtokkit CL100K_BASE） | 按 token 数分块，在句子边界切割，保留原始 metadata，专为 LLM token limit 设计 |
| 向量存储 + JSONB 过滤检索 | Spring AI `PgVectorStore` + `SearchRequest.filterExpression` | 已有 vector_store 表（V10），自动调用 EmbeddingModel 生成向量，支持 metadata JSONB 过滤 |
| OpenAI 兼容 Embedding | Spring AI `OpenAiEmbeddingModel` | 支持自定义 base_url（第三方 proxy），与项目已有的 OpenAI chat 模型配置模式一致 |

## Constraints

- **OpenAI 自动配置已全部 exclude**：`application.yml` 排除了 `OpenAiChatAutoConfiguration`、`OpenAiEmbeddingAutoConfiguration`、`PgVectorStoreAutoConfiguration` 等。所有 Spring AI bean 必须手动构建，不能依赖自动配置。
- **Embedding API 通过第三方 proxy（胜算云）调用**（D072）：配置必须独立于 Mentor chat 的 base_url/api_key。集成测试不能依赖真实 API key，需要 mock EmbeddingModel。
- **Spring AI 版本 1.1.4**：`spring-ai-bom` 版本锁定在 1.1.4。TikaDocumentReader 通过 `spring-ai-tika-document-reader` 引入。
- **vector_store 表已由 V10 创建**：embedding 维度 1536，HNSW 索引已建。PgVectorStore 必须设置 `initializeSchema(false)` 避免重复建表。
- **Testcontainers 在 Windows Docker Desktop 存在 npipe 兼容性问题**（S01 已知限制）：集成测试通过 docker-compose 端到端验证补充。
- **MinIO bucket 尚未创建**：S01 的 MinioHealthIndicator 只检测连通性。S02 必须在启动时或首次使用时创建 bucket。

## Common Pitfalls

- **PgVectorStore initializeSchema 冲突** — V10 已手动创建 vector_store 表和索引。如果 PgVectorStore 设置 `initializeSchema(true)`，会尝试重复创建表/扩展，可能因 Flyway 版本管理冲突而失败。务必设置 `initializeSchema(false)`。
- **Embedding mock 在集成测试中必须**：真实 EmbeddingModel 需要 API key 和网络。集成测试应使用固定维度的 mock embedding（返回 1536 维零向量或随机向量），否则 CI 和本地都无法运行。
- **TikaDocumentReader 传入 InputStream 而非 classpath Resource** — 从 MinIO 下载的文件是 InputStream/byte[]，需要包装为 `InputStreamResource` 传给 TikaDocumentReader。注意 InputStreamResource 不可重复读。
- **TokenTextSplitter 默认 chunk size 可能过大** — 默认值可能产生超过 token limit 的 chunk。应显式设置 `withChunkSize(800)` 保持每个 chunk ≈800 tokens，适合 text-embedding-3-small。
- **MemPalace metadata 映射需要 51 本书的精确配置** — 自动推断书名到 wing/room/hall 的映射不可靠，需要一份硬编码的映射配置（JSON/YAML/enum），51 本书逐一标注。这是人力密集型任务但对检索质量至关重要。
- **JSONB metadata 字段名大小写敏感** — PgVectorStore 的 filterExpression 在 PostgreSQL JSONB 操作中区分大小写。确保所有 metadata key 统一使用 snake_case（`wing`、`room`、`hall`、`source_book`、`age_range`）。

## Open Risks

- **51 本文献的 MemPalace 元数据标注质量**：每本书需要人工确认 wing/room/hall/age_range 分配。如果标注错误，downstream 的 agentic search（S03）检索质量会受影响。建议先定义完整 taxonomy 并让用户审核。
- **文献文件格式多样性**：51 本书可能包含扫描版 PDF（无文字层）、繁体中文 ePub 等边界情况。TikaDocumentReader 对扫描 PDF 只能提取空文本。需要在 ingestion 日志中记录解析结果大小，0 字符的标记为解析失败。
- **Embedding API 成本和速率限制**：51 本书按每本 200 chunk 估算 ≈ 10,000 chunks × embedding 调用。通过第三方 proxy 调用需确认速率限制和费用。建议批量导入时加入 rate limiting（如每秒 50 请求）。
- **集成测试中 mock EmbeddingModel 的维度匹配**：vector_store 表 embedding 列是 `vector(1536)`，mock 必须返回精确 1536 维的向量，否则 INSERT 会失败。

## Skills Discovered

| Technology | Skill | Status |
|------------|-------|--------|
| Spring AI | spring-ai (installed) | installed |
| Spring Boot | spring-boot-engineer (installed) | installed |
| MinIO | vm0-ai/vm0-skills@minio | available (120 installs, not installed — generic, not needed) |

## Sources

- Spring AI PgVectorStore 文档：metadata JSONB 过滤通过 `SearchRequest.filterExpression` 支持，语法 `key == 'value' && key2 == 'value2'` (source: [Spring AI PgVector docs](https://docs.spring.io/spring-ai/reference/api/vectordbs/pgvector.html))
- Spring AI ETL Pipeline：`TikaDocumentReader` → `TokenTextSplitter` → `VectorStore` 标准管道 (source: [Spring AI ETL Pipeline](https://docs.spring.io/spring-ai/reference/api/etl-pipeline.html))
- Spring AI OpenAI Embedding：`OpenAiEmbeddingModel` 支持自定义 base_url 和 api_key (source: [Spring AI OpenAI Embedding](https://docs.spring.io/spring-ai/reference/api/embeddings/openai-embeddings.html))
