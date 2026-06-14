---
phase: "02"
plan: "01"
---

# T01: feat: 搭建 S02 ingestion 基础设施 — EmbeddingModel/PgVectorStore bean、Flyway V11 ingestion_jobs 表、MinIO bucket 初始化、@Async 线程池、Tika 依赖

**feat: 搭建 S02 ingestion 基础设施 — EmbeddingModel/PgVectorStore bean、Flyway V11 ingestion_jobs 表、MinIO bucket 初始化、@Async 线程池、Tika 依赖**

## What Happened

按任务计划逐步完成 9 项变更：

1. **pom.xml** — 添加 `spring-ai-tika-document-reader` 依赖，由 BOM 管理版本。
2. **EmbeddingProperties** — 创建 `app.embedding` 前缀的 record 配置类（baseUrl, apiKey, model, dimensions），参考 MentorProperties 模式，默认 dimensions=1536。
3. **EmbeddingConfiguration** — 手动构建 OpenAiApi → OpenAiEmbeddingModel（MetadataMode.EMBED + 自定义 options）→ PgVectorStore（builder 模式，initializeSchema=false 因 V10 已建表）。初次编译发现 `OpenAiEmbeddingModel` 构造函数需要显式 `MetadataMode` 参数，修正后通过。
4. **application.yml** — 在 `app:` 节点下添加 `embedding:` 配置块，4 个属性均带 `BABY_TALK_EMBEDDING_*` 环境变量占位符。
5. **V11__create_ingestion_tables.sql** — 创建 `ingestion_jobs` 表（UUID PK、original_filename、minio_object_key、status CHECK 约束、total_chunks、error_message、created_at/updated_at），附加状态索引和创建时间索引。
6. **MinioBucketInitializer** — 实现 `ApplicationRunner`，启动时检查 bucket 是否存在，不存在则调用 `makeBucket()` 创建。bucket 名称从 `MinioProperties.bucketName()` 获取。
7. **AsyncConfiguration** — `@EnableAsync` + 命名 bean `ingestionExecutor`（core=2, max=4, queue=50, prefix="ingestion-"），支持优雅关闭（waitForTasksToCompleteOnShutdown + awaitTerminationSeconds）。
8. **application-test.yml** — 添加 `app.embedding` 测试配置（占位符值），集成测试中可 mock EmbeddingModel 覆盖。
9. **docker-compose.yml** — backend 环境变量添加 4 个 `BABY_TALK_EMBEDDING_*` 变量，带默认值。

关键决策：OpenAiEmbeddingModel 使用 3 参数构造（OpenAiApi, MetadataMode.EMBED, OpenAiEmbeddingOptions），而非 Spring AI 文档中较简单的单参数形式，以支持完整的模型/维度自定义。

## Verification

运行任务计划中的验证命令，6 项检查全部通过。额外验证 8 项关键约束（initializeSchema=false、app.embedding 前缀、表结构字段、线程前缀、bucketName 来源等）全部通过。`mvn compile -q` 编译成功无错误。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `grep + test 组合验证命令（任务计划 Verification）` | 0 | ✅ pass | 200ms |
| 2 | `8 项关键约束 grep 验证` | 0 | ✅ pass | 150ms |
| 3 | `mvn compile -q` | 0 | ✅ pass | 11100ms |

## Deviations

初次编译发现 OpenAiEmbeddingModel 构造函数签名与文档示例不同，需要显式 MetadataMode 参数。已修正为 3 参数构造函数。

## Known Issues

None.

## Files Created/Modified

- `backend/pom.xml`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/EmbeddingProperties.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/EmbeddingConfiguration.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/MinioBucketInitializer.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/AsyncConfiguration.java`
- `backend/src/main/resources/application.yml`
- `backend/src/main/resources/db/migration/V11__create_ingestion_tables.sql`
- `backend/src/test/resources/application-test.yml`
- `docker-compose.yml`
