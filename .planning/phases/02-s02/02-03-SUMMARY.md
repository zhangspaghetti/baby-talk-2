---
phase: "02"
plan: "03"
---

# T03: feat: 实现 IngestionController REST API（上传/状态/重试）、PalaceSearchService 按宫殿坐标过滤向量检索、3 个集成测试类 + 测试资源文件

**feat: 实现 IngestionController REST API（上传/状态/重试）、PalaceSearchService 按宫殿坐标过滤向量检索、3 个集成测试类 + 测试资源文件**

## What Happened

实现了 T03 计划中的全部 6 个产出文件：

**IngestionController** — REST API 入口层：

- `POST /api/v1/ingestion/upload`：接收 multipart/form-data（file + bookTitle），调用 IngestionService.uploadAndIngest()，返回 202 + {jobId}
- `GET /api/v1/ingestion/jobs/{id}`：查询单个 job 状态 JSON（id, originalFilename, status, totalChunks, errorMessage, createdAt, updatedAt）
- `POST /api/v1/ingestion/jobs/{id}/retry`：仅允许重试 FAILED 状态的 job，先 updateStatusPending 重置再异步触发 processFile

为支持重试功能，给 IngestionRepository 添加了 `updateStatusPending(UUID)` 方法。

**PalaceSearchService** — 封装 PgVectorStore.similaritySearch + filterExpression：

- `search(query, wing, room, topK)` 方法构建 SearchRequest，按 wing/room 组合构建 SQL-like filter expression（如 `wing == 'language_development' && room == 'early_communication'`）
- 使用 Spring AI 1.1.4 的 `SearchRequest.builder().query().topK().filterExpression().build()` API

**集成测试（3 个类）**：

- `IngestionControllerTest` — MockMvc 测试 6 个场景：上传→202、空文件→400、查状态→200、不存在→404、重试FAILED→202、重试非FAILED→409
- `PalaceSearchServiceTest` — 直接 JdbcTemplate INSERT vector_store 带不同 wing 的记录，验证 wing 过滤、wing+room 组合过滤、无过滤、topK 限制、buildFilterExpression 边界情况（共 7 个测试）
- `IngestionServiceIntegrationTest` — 验证 uploadAndIngest 创建 job 记录、minioObjectKey 格式、测试资源文件存在（共 3 个测试）

所有集成测试使用 @MockitoBean 替代 EmbeddingModel（避免真实 API key）和 MinioClient（避免真实 MinIO 连接）。PalaceSearchServiceTest 使用固定归一化 1536 维向量作为存储和查询向量，确保余弦相似度 ≈ 1.0。

## Verification

1. 文件存在性验证 — 所有 6 个预期输出文件 + 5 个 T02 输入文件均存在
2. `mvn compile` — 主代码编译成功（exit 0）
3. `mvn test-compile` — 测试代码编译成功（23 个源文件，exit 0，BUILD SUCCESS）
4. T03 验证命令完整通过：IngestionController.java, PalaceSearchService.java, IngestionControllerTest.java, PalaceSearchServiceTest.java, IngestionServiceIntegrationTest.java 全部存在
5. 此前失败的 T02 验证检查（MemPalaceTaxonomy.java, MemPalaceMetadataEnricher.java, IngestionService.java, MemPalaceTaxonomyTest.java, MemPalaceMetadataEnricherTest.java）全部通过

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `test -f backend/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionController.java && test -f backend/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceSearchService.java && test -f backend/src/test/java/com/zhangspaghetti/babytalk/ingestion/IngestionControllerTest.java && test -f backend/src/test/java/com/zhangspaghetti/babytalk/palace/PalaceSearchServiceTest.java && test -f backend/src/test/java/com/zhangspaghetti/babytalk/ingestion/IngestionServiceIntegrationTest.java` | 0 | ✅ pass | 200ms |
| 2 | `mvn compile -q` | 0 | ✅ pass | 11000ms |
| 3 | `mvn test-compile` | 0 | ✅ pass | 11300ms |
| 4 | `test -f backend/src/main/java/com/zhangspaghetti/babytalk/palace/MemPalaceTaxonomy.java && test -f backend/src/main/java/com/zhangspaghetti/babytalk/palace/MemPalaceMetadataEnricher.java && test -f backend/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionService.java && test -f backend/src/test/java/com/zhangspaghetti/babytalk/palace/MemPalaceTaxonomyTest.java && test -f backend/src/test/java/com/zhangspaghetti/babytalk/palace/MemPalaceMetadataEnricherTest.java` | 0 | ✅ pass | 150ms |

## Deviations

为支持 retry 功能，给 IngestionRepository 新增了 updateStatusPending 方法（T02 未包含此方法）。这是 T03 retry 端点的必要补充。

## Known Issues

集成测试尚未执行（需要 Docker 运行 Testcontainers PostgreSQL），仅验证了编译通过。运行时测试留待 CI 或手动执行。

## Files Created/Modified

- `backend/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionController.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceSearchService.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/ingestion/IngestionControllerTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/palace/PalaceSearchServiceTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/ingestion/IngestionServiceIntegrationTest.java`
- `backend/src/test/resources/test-document.txt`
- `backend/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionRepository.java`
