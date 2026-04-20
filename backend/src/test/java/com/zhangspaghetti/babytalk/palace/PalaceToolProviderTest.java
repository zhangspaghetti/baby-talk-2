package com.zhangspaghetti.babytalk.palace;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.kg.KgQueryTool;
import com.zhangspaghetti.babytalk.palace.PalaceKeywordRepository.ChunkResult;
import java.lang.reflect.Method;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.ai.document.Document;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.beans.factory.ObjectProvider;

/**
 * PalaceToolProvider 单元测试 — 使用 Mockito mock 底层服务。
 *
 * <p>覆盖场景：
 * <ul>
 *   <li>5 个 @Tool 方法的正常路径和边界情况</li>
 *   <li>null/blank 参数防御（无 NPE）</li>
 *   <li>JSON 输出格式验证（包含 source_book 等来源信息）</li>
 *   <li>@Tool 注解存在性反射检查</li>
 *   <li>负向测试：无效 UUID、不存在的 wing、topK=0 等</li>
 * </ul>
 */
@ExtendWith(MockitoExtension.class)
class PalaceToolProviderTest {

    @Mock
    private PalaceSearchService searchService;

    @Mock
    private PalaceKeywordRepository keywordRepository;

    @Mock
    private ObjectProvider<KgQueryTool> kgQueryToolProvider;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private PalaceToolProvider provider;

    @BeforeEach
    void setUp() {
        provider = new PalaceToolProvider(searchService, keywordRepository, objectMapper, kgQueryToolProvider);
    }

    // ─── 辅助方法 ─────────────────────────────────────────────

    private Document makeDocument(String id, String text, Map<String, Object> metadata) {
        Document doc = new Document(id, text, metadata);
        return doc;
    }

    private ChunkResult makeChunk(UUID id, String content, Map<String, Object> metadata) {
        return new ChunkResult(id, content, metadata);
    }

    private Map<String, Object> sampleMetadata() {
        Map<String, Object> meta = new HashMap<>();
        meta.put("source_book", "Baby Talk");
        meta.put("wing", "language_development");
        meta.put("room", "early_communication");
        meta.put("hall", "babbling_hall");
        meta.put("age_range", "0-2");
        return meta;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> parseJson(String json) throws Exception {
        return objectMapper.readValue(json, new TypeReference<Map<String, Object>>() {});
    }

    // ========================================================================
    // palace_vector_search
    // ========================================================================

    @Nested
    class VectorSearchTests {

        @Test
        void normalQuery_returnsJsonWithResults() throws Exception {
            UUID docId = UUID.randomUUID();
            Document doc = makeDocument(docId.toString(), "宝宝语言发展的关键阶段", sampleMetadata());
            when(searchService.search(eq("宝宝语言发展"), isNull(), isNull(), eq(5)))
                    .thenReturn(List.of(doc));

            String result = provider.palaceVectorSearch("宝宝语言发展", null, null, null);
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsKey("results");
            assertThat(json).containsEntry("count", 1);

            @SuppressWarnings("unchecked")
            List<Map<String, Object>> results = (List<Map<String, Object>>) json.get("results");
            assertThat(results).hasSize(1);
            assertThat(results.get(0)).containsEntry("source_book", "Baby Talk");
            assertThat(results.get(0)).containsEntry("wing", "language_development");
            assertThat(results.get(0)).containsEntry("room", "early_communication");
            assertThat(results.get(0)).containsEntry("hall", "babbling_hall");
            assertThat(results.get(0)).containsEntry("age_range", "0-2");
            assertThat(results.get(0)).containsKey("id");
            assertThat(results.get(0)).containsKey("content");
        }

        @Test
        void emptyResults_returnsEmptyJson() throws Exception {
            when(searchService.search(anyString(), isNull(), isNull(), eq(5)))
                    .thenReturn(Collections.emptyList());

            String result = provider.palaceVectorSearch("不存在的主题", null, null, null);
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("count", 0);
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> results = (List<Map<String, Object>>) json.get("results");
            assertThat(results).isEmpty();
        }

        @Test
        void withWingAndRoomFilter_passesToService() throws Exception {
            when(searchService.search(eq("宝宝"), eq("language_development"), eq("early_communication"), eq(3)))
                    .thenReturn(Collections.emptyList());

            provider.palaceVectorSearch("宝宝", "language_development", "early_communication", 3);

            verify(searchService).search("宝宝", "language_development", "early_communication", 3);
        }

        @Test
        void nullQuery_returnsEmptyWithoutCallingService() throws Exception {
            String result = provider.palaceVectorSearch(null, null, null, null);
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("count", 0);
            verify(searchService, never()).search(anyString(), anyString(), anyString(), anyInt());
        }

        @Test
        void blankQuery_returnsEmptyWithoutCallingService() throws Exception {
            String result = provider.palaceVectorSearch("   ", null, null, null);
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("count", 0);
            verify(searchService, never()).search(anyString(), anyString(), anyString(), anyInt());
        }

        @Test
        void topKZero_defaultsToFive() {
            when(searchService.search(anyString(), isNull(), isNull(), eq(5)))
                    .thenReturn(Collections.emptyList());

            provider.palaceVectorSearch("宝宝", null, null, 0);

            verify(searchService).search("宝宝", null, null, 5);
        }

        @Test
        void topKNegative_defaultsToFive() {
            when(searchService.search(anyString(), isNull(), isNull(), eq(5)))
                    .thenReturn(Collections.emptyList());

            provider.palaceVectorSearch("宝宝", null, null, -1);

            verify(searchService).search("宝宝", null, null, 5);
        }
    }

    // ========================================================================
    // palace_keyword_search
    // ========================================================================

    @Nested
    class KeywordSearchTests {

        @Test
        void normalSearch_returnsJsonWithSourceInfo() throws Exception {
            UUID chunkId = UUID.randomUUID();
            ChunkResult chunk = makeChunk(chunkId, "早期沟通方法", sampleMetadata());
            when(keywordRepository.searchByKeywords(eq("早期沟通"), isNull(), isNull(), eq(5)))
                    .thenReturn(List.of(chunk));

            String result = provider.palaceKeywordSearch("早期沟通", null, null, null);
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("count", 1);
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> results = (List<Map<String, Object>>) json.get("results");
            assertThat(results).hasSize(1);
            assertThat(results.get(0)).containsEntry("source_book", "Baby Talk");
            assertThat(results.get(0)).containsEntry("id", chunkId.toString());
            assertThat(results.get(0)).containsEntry("content", "早期沟通方法");
        }

        @Test
        void nullKeywords_returnsEmptyWithoutCallingRepo() throws Exception {
            String result = provider.palaceKeywordSearch(null, null, null, null);
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("count", 0);
            verify(keywordRepository, never()).searchByKeywords(anyString(), anyString(), anyString(), anyInt());
        }

        @Test
        void blankKeywords_returnsEmptyWithoutCallingRepo() throws Exception {
            String result = provider.palaceKeywordSearch("  ", null, null, null);
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("count", 0);
            verify(keywordRepository, never()).searchByKeywords(anyString(), anyString(), anyString(), anyInt());
        }

        @Test
        void limitZero_defaultsToFive() {
            when(keywordRepository.searchByKeywords(anyString(), isNull(), isNull(), eq(5)))
                    .thenReturn(Collections.emptyList());

            provider.palaceKeywordSearch("宝宝", null, null, 0);

            verify(keywordRepository).searchByKeywords("宝宝", null, null, 5);
        }
    }

    // ========================================================================
    // palace_read_chunk
    // ========================================================================

    @Nested
    class ReadChunkTests {

        @Test
        void validId_returnsChunkJson() throws Exception {
            UUID chunkId = UUID.randomUUID();
            ChunkResult chunk = makeChunk(chunkId, "这是一段育儿知识内容", sampleMetadata());
            when(keywordRepository.readChunkById(eq(chunkId)))
                    .thenReturn(Optional.of(chunk));

            String result = provider.palaceReadChunk(chunkId.toString());
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("found", true);
            assertThat(json).containsEntry("content", "这是一段育儿知识内容");
            assertThat(json).containsEntry("source_book", "Baby Talk");
            assertThat(json).containsEntry("wing", "language_development");
            assertThat(json).containsEntry("id", chunkId.toString());
        }

        @Test
        void notFoundId_returnsNotFoundJson() throws Exception {
            UUID chunkId = UUID.randomUUID();
            when(keywordRepository.readChunkById(eq(chunkId)))
                    .thenReturn(Optional.empty());

            String result = provider.palaceReadChunk(chunkId.toString());
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("found", false);
            assertThat(json).containsKey("error");
        }

        @Test
        void nullChunkId_returnsErrorJson() throws Exception {
            String result = provider.palaceReadChunk(null);
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("found", false);
            assertThat(json).containsKey("error");
            verify(keywordRepository, never()).readChunkById(any());
        }

        @Test
        void blankChunkId_returnsErrorJson() throws Exception {
            String result = provider.palaceReadChunk("   ");
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("found", false);
            verify(keywordRepository, never()).readChunkById(any());
        }

        @Test
        void invalidUuidFormat_returnsErrorJson() throws Exception {
            String result = provider.palaceReadChunk("not-a-valid-uuid");
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("found", false);
            assertThat((String) json.get("error")).contains("无效的 UUID 格式");
            verify(keywordRepository, never()).readChunkById(any());
        }

        private <T> T any() {
            return org.mockito.ArgumentMatchers.any();
        }
    }

    // ========================================================================
    // palace_list_rooms
    // ========================================================================

    @Nested
    class ListRoomsTests {

        @Test
        void noFilter_returnsAllWings() throws Exception {
            String result = provider.palaceListRooms(null);
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsKey("wings");
            assertThat(json).containsKey("wing_count");
            int wingCount = (int) json.get("wing_count");
            // 5 个翼楼
            assertThat(wingCount).isEqualTo(5);

            @SuppressWarnings("unchecked")
            Map<String, Object> wings = (Map<String, Object>) json.get("wings");
            assertThat(wings).containsKey("language_development");
            assertThat(wings).containsKey("cognitive");
            assertThat(wings).containsKey("emotional");
            assertThat(wings).containsKey("physical");
            assertThat(wings).containsKey("parenting_skills");
        }

        @Test
        void filterByWing_returnsOnlyMatchingWing() throws Exception {
            String result = provider.palaceListRooms("LANGUAGE_DEVELOPMENT");
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("wing_count", 1);
            @SuppressWarnings("unchecked")
            Map<String, Object> wings = (Map<String, Object>) json.get("wings");
            assertThat(wings).containsKey("language_development");
            assertThat(wings).hasSize(1);
        }

        @Test
        void nonexistentWing_returnsEmptyWings() throws Exception {
            String result = provider.palaceListRooms("nonexistent_wing");
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("wing_count", 0);
            @SuppressWarnings("unchecked")
            Map<String, Object> wings = (Map<String, Object>) json.get("wings");
            assertThat(wings).isEmpty();
        }

        @Test
        void blankWing_returnsAllWings() throws Exception {
            String result = provider.palaceListRooms("  ");
            Map<String, Object> json = parseJson(result);

            int wingCount = (int) json.get("wing_count");
            assertThat(wingCount).isEqualTo(5);
        }

        @Test
        void booksContainRequiredFields() throws Exception {
            String result = provider.palaceListRooms("COGNITIVE");
            Map<String, Object> json = parseJson(result);

            @SuppressWarnings("unchecked")
            Map<String, List<Map<String, String>>> wings =
                    (Map<String, List<Map<String, String>>>) json.get("wings");
            List<Map<String, String>> cognitiveBooks = wings.get("cognitive");
            assertThat(cognitiveBooks).isNotEmpty();

            Map<String, String> firstBook = cognitiveBooks.get(0);
            assertThat(firstBook).containsKey("book");
            assertThat(firstBook).containsKey("room");
            assertThat(firstBook).containsKey("hall");
            assertThat(firstBook).containsKey("age_range");
        }
    }

    // ========================================================================
    // kg_query_entity
    // ========================================================================

    @Nested
    class KgQueryEntityTests {

        @Test
        void validEntity_returnsPlaceholderJson() throws Exception {
            String result = provider.kgQueryEntity("Baby Talk");
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("entity", "Baby Talk");
            assertThat(json).containsKey("relationships");
            assertThat(json).containsKey("note");
            assertThat((String) json.get("note")).contains("Phase 1");

            @SuppressWarnings("unchecked")
            List<Map<String, String>> relationships = (List<Map<String, String>>) json.get("relationships");
            // "Baby Talk" 在书目目录中存在
            assertThat(relationships).isNotEmpty();
            assertThat(relationships.get(0)).containsEntry("relation", "mentioned_in");
            assertThat(relationships.get(0)).containsKey("book");
            assertThat(relationships.get(0)).containsKey("wing");
            assertThat(relationships.get(0)).containsKey("room");
        }

        @Test
        void nullEntity_returnsEmptyRelationships() throws Exception {
            String result = provider.kgQueryEntity(null);
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("entity", "");
            @SuppressWarnings("unchecked")
            List<Object> relationships = (List<Object>) json.get("relationships");
            assertThat(relationships).isEmpty();
            assertThat((String) json.get("note")).contains("Phase 1");
        }

        @Test
        void blankEntity_returnsEmptyRelationships() throws Exception {
            String result = provider.kgQueryEntity("  ");
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("entity", "");
            @SuppressWarnings("unchecked")
            List<Object> relationships = (List<Object>) json.get("relationships");
            assertThat(relationships).isEmpty();
        }

        @Test
        void noMatchEntity_returnsEmptyRelationships() throws Exception {
            String result = provider.kgQueryEntity("完全不存在的实体名称XYZ");
            Map<String, Object> json = parseJson(result);

            assertThat(json).containsEntry("entity", "完全不存在的实体名称XYZ");
            @SuppressWarnings("unchecked")
            List<Object> relationships = (List<Object>) json.get("relationships");
            assertThat(relationships).isEmpty();
        }
    }

    // ========================================================================
    // @Tool 注解反射检查
    // ========================================================================

    @Nested
    class AnnotationTests {

        @Test
        void allToolMethodsHaveToolAnnotation() throws Exception {
            String[] expectedToolNames = {
                    "palace_vector_search",
                    "palace_keyword_search",
                    "palace_read_chunk",
                    "palace_list_rooms",
                    "kg_query_entity"
            };

            for (String toolName : expectedToolNames) {
                boolean found = false;
                for (Method method : PalaceToolProvider.class.getDeclaredMethods()) {
                    Tool toolAnnotation = method.getAnnotation(Tool.class);
                    if (toolAnnotation != null && toolAnnotation.name().equals(toolName)) {
                        found = true;
                        // 验证 description 非空
                        assertThat(toolAnnotation.description())
                                .as("Tool %s should have a non-empty description", toolName)
                                .isNotBlank();
                        break;
                    }
                }
                assertThat(found)
                        .as("Expected @Tool(name=\"%s\") annotation to be present", toolName)
                        .isTrue();
            }
        }

        @Test
        void toolMethodsReturnString() {
            for (Method method : PalaceToolProvider.class.getDeclaredMethods()) {
                Tool toolAnnotation = method.getAnnotation(Tool.class);
                if (toolAnnotation != null) {
                    assertThat(method.getReturnType())
                            .as("Tool %s should return String", toolAnnotation.name())
                            .isEqualTo(String.class);
                }
            }
        }
    }

    // ========================================================================
    // JSON 格式化辅助方法测试
    // ========================================================================

    @Nested
    class FormatHelperTests {

        @Test
        void formatDocumentsAsList_preservesSourceInfo() {
            UUID id = UUID.randomUUID();
            Document doc = makeDocument(id.toString(), "内容文本", sampleMetadata());

            List<Map<String, Object>> result = provider.formatDocumentsAsList(List.of(doc));

            assertThat(result).hasSize(1);
            assertThat(result.get(0)).containsEntry("source_book", "Baby Talk");
            assertThat(result.get(0)).containsEntry("content", "内容文本");
        }

        @Test
        void formatDocumentsAsList_emptyList_returnsEmpty() {
            List<Map<String, Object>> result = provider.formatDocumentsAsList(Collections.emptyList());
            assertThat(result).isEmpty();
        }

        @Test
        void formatChunksAsList_preservesSourceInfo() {
            UUID id = UUID.randomUUID();
            ChunkResult chunk = makeChunk(id, "chunk 内容", sampleMetadata());

            List<Map<String, Object>> result = provider.formatChunksAsList(List.of(chunk));

            assertThat(result).hasSize(1);
            assertThat(result.get(0)).containsEntry("source_book", "Baby Talk");
            assertThat(result.get(0)).containsEntry("id", id.toString());
        }

        @Test
        void formatChunkAsMap_missingMetadataKeys_defaultsToEmptyString() {
            UUID id = UUID.randomUUID();
            ChunkResult chunk = makeChunk(id, "内容", Collections.emptyMap());

            Map<String, Object> result = provider.formatChunkAsMap(chunk);

            assertThat(result).containsEntry("source_book", "");
            assertThat(result).containsEntry("wing", "");
            assertThat(result).containsEntry("room", "");
            assertThat(result).containsEntry("hall", "");
            assertThat(result).containsEntry("age_range", "");
        }

        @Test
        void toJson_validObject_producesValidJson() {
            String json = provider.toJson(Map.of("key", "value"));
            assertThat(json).isEqualTo("{\"key\":\"value\"}");
        }
    }
}
