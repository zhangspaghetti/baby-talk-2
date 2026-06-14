---
phase: "03"
plan: "01"
---

# T01: 添加 Flyway V12 全文搜索 migration（tsvector 计算列 + GIN 索引）并封装 PalaceKeywordRepository 关键词检索/chunk 读取方法

**添加 Flyway V12 全文搜索 migration（tsvector 计算列 + GIN 索引）并封装 PalaceKeywordRepository 关键词检索/chunk 读取方法**

## What Happened

为 vector_store 表添加 PostgreSQL 全文搜索基础设施和数据访问层：

1. **V12 Flyway migration**：创建 `V12__add_keyword_search_to_vector_store.sql`，为 vector_store 表添加 `content_tsv` tsvector 计算列（GENERATED ALWAYS AS + 'simple' 配置，适合中英混合文本不做词干提取），以及 GIN 索引加速全文匹配。

2. **PalaceKeywordRepository**：封装两个核心方法——`searchByKeywords` 使用 plainto_tsquery 全文检索 + metadata JSONB 过滤（wing/room）+ ts_rank 排序，`readChunkById` 按 UUID 读取单个 chunk。包含完整防御逻辑：null/空 keywords 返回空列表、limit ≤0 或 >50 回退默认值 5、null UUID 返回 Optional.empty()、metadata JSON 解析失败降级为空 map。使用 ObjectMapper 解析 JSONB metadata 为 Map。自定义 record `ChunkResult(UUID, String, Map)` 作为返回类型。

3. **PalaceKeywordRepositoryTest**：11 个单元测试覆盖正向和负向场景——纯关键词/+wing/+wing+room 的 SQL 构建与参数传递验证、null/空 keywords 防御、limit=0 和负数的默认值回退、null UUID 和不存在 UUID 的 readChunkById 处理、ChunkResult record 数据完整性。使用 @MockitoExtension + @Mock JdbcTemplate 纯单元测试。

关键设计决策：

- 使用 'simple' tsconfig 而非 'english'，因为知识宫殿内容为中英混合，simple 不做词干提取更适合
- metadata 过滤使用 JSONB `->>` 操作符直接在 SQL 层完成，避免应用层二次过滤
- 与现有 PalaceSearchService 向量检索并列，关键词检索作为 agentic search 中 tool calling 的独立检索路径

## Verification

编译和测试全部通过：

- `mvn compile test-compile -q` — exit code 0，无编译错误
- `mvn test -pl . -Dtest=PalaceKeywordRepositoryTest -q` — exit code 0，11 个测试全部通过
- SLF4J 结构化日志输出验证：关键词检索参数（keywords, wing, room, limit）和结果数量正确记录

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd backend && mvn compile test-compile -q` | 0 | ✅ pass | 14500ms |
| 2 | `cd backend && mvn test -pl . -Dtest=PalaceKeywordRepositoryTest -q` | 0 | ✅ pass | 8600ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `backend/src/main/resources/db/migration/V12__add_keyword_search_to_vector_store.sql`
- `backend/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceKeywordRepository.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/palace/PalaceKeywordRepositoryTest.java`
