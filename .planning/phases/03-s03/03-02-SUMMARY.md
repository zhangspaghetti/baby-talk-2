---
phase: "03"
plan: "02"
---

# T02: 实现 PalaceToolProvider 五个 @Tool 方法并创建 32 个单元测试覆盖全部正向/负向场景

**实现 PalaceToolProvider 五个 @Tool 方法并创建 32 个单元测试覆盖全部正向/负向场景**

## What Happened

PalaceToolProvider.java 已由先前会话完整实现，包含 5 个 @Tool 注解方法：palace_vector_search（语义向量检索）、palace_keyword_search（关键词全文检索）、palace_read_chunk（按 UUID 读取 chunk）、palace_list_rooms（列出知识宫殿结构）、kg_query_entity（Phase 1 知识图谱占位）。所有方法返回 JSON 字符串，包含 source_book/wing/room/hall/age_range 等来源引用信息。每个方法对 null/blank 参数做防御处理，不会抛出 NPE。

本任务主要工作是创建 PalaceToolProviderTest.java 单元测试，使用 @MockitoExtension 纯单元测试模式（mock PalaceSearchService + PalaceKeywordRepository），共 32 个测试分 7 个 @Nested 类组织：

1. **VectorSearchTests (7个)**：正常查询返回 JSON、空结果、wing/room 过滤传递验证、null/blank query 防御、topK=0 和负数默认值回退
2. **KeywordSearchTests (4个)**：正常搜索含来源信息、null/blank keywords 防御、limit=0 默认值
3. **ReadChunkTests (5个)**：正常读取、不存在 UUID、null/blank chunkId、无效 UUID 格式错误提示
4. **ListRoomsTests (5个)**：全部翼楼列出、按 wing 过滤、不存在 wing 空结果、blank wing 返回全部、书目包含必要字段
5. **KgQueryEntityTests (4个)**：正常实体返回 placeholder、null/blank 实体、无匹配实体
6. **AnnotationTests (2个)**：反射验证 5 个 @Tool 注解存在且 description 非空、所有 tool 方法返回 String
7. **FormatHelperTests (5个)**：formatDocumentsAsList/formatChunksAsList 来源信息保留、空列表、缺失 metadata key 默认空字符串、toJson 序列化

Slice 级观测性验证：SLF4J 结构化日志在测试输出中清晰可见——PalaceToolProvider 记录每次 tool 调用的参数（query/keywords/wing/room/topK/limit）和结果数量。

## Verification

编译和测试全部通过：

- `mvn compile test-compile -q` — exit code 0，无编译错误
- `mvn test -pl . -Dtest=PalaceToolProviderTest -q` — exit code 0，32 个测试全部通过（7 VectorSearch + 4 KeywordSearch + 5 ReadChunk + 5 ListRooms + 4 KgQueryEntity + 2 Annotation + 5 FormatHelper）
- SLF4J 结构化日志验证：tool 调用参数和结果数量在测试输出中正确记录
- @Tool 注解反射检查：5 个 tool 名称 + 非空 description + 返回类型 String 全部验证通过

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd backend && mvn compile test-compile -q` | 0 | ✅ pass | 5600ms |
| 2 | `cd backend && mvn test -pl . -Dtest=PalaceToolProviderTest -q` | 0 | ✅ pass | 6900ms |

## Deviations

PalaceToolProvider.java 已由先前会话完整实现，本任务仅需创建单元测试文件。实现代码无需修改。

## Known Issues

None.

## Files Created/Modified

- `backend/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceToolProvider.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/palace/PalaceToolProviderTest.java`
