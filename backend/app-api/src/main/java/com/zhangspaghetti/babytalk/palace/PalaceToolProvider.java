package com.zhangspaghetti.babytalk.palace;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.kg.KgQueryTool;
import com.zhangspaghetti.babytalk.palace.MemPalaceTaxonomy.BookMapping;
import com.zhangspaghetti.babytalk.palace.PalaceKeywordRepository.ChunkResult;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.Document;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/**
 * 知识宫殿 Tool Provider — 供 Spring AI ChatClient tool calling 使用的 5 个 @Tool 方法。
 *
 * <p>LLM 通过这些 tool 自主决策搜索知识宫殿的策略：
 * <ul>
 *   <li>{@code palace_vector_search} — 按语义相似度检索</li>
 *   <li>{@code palace_keyword_search} — 按关键词全文检索</li>
 *   <li>{@code palace_read_chunk} — 按 chunk ID 读取完整内容</li>
 *   <li>{@code palace_list_rooms} — 列出知识宫殿结构</li>
 *   <li>{@code kg_query_entity} — 知识图谱实体查询（委托 KgQueryTool）</li>
 * </ul>
 *
 * <p>所有方法返回 JSON 字符串，包含 source_book 等来源信息以支持知识来源引用。
 */
@Component
public class PalaceToolProvider {

    private static final Logger log = LoggerFactory.getLogger(PalaceToolProvider.class);
    private static final int DEFAULT_TOP_K = 5;

    private final PalaceSearchService searchService;
    private final PalaceKeywordRepository keywordRepository;
    private final ObjectMapper objectMapper;
    private final KgQueryTool kgQueryTool;

    public PalaceToolProvider(PalaceSearchService searchService,
                              PalaceKeywordRepository keywordRepository,
                              ObjectMapper objectMapper,
                              ObjectProvider<KgQueryTool> kgQueryToolProvider) {
        this.searchService = searchService;
        this.keywordRepository = keywordRepository;
        this.objectMapper = objectMapper;
        this.kgQueryTool = kgQueryToolProvider.getIfAvailable();
    }

    /**
     * 按语义相似度检索知识宫殿中的育儿知识片段。
     */
    @Tool(name = "palace_vector_search",
          description = "在知识宫殿中按语义相似度检索育儿知识片段。当需要根据用户问题语义查找相关知识时使用。")
    public String palaceVectorSearch(
            @ToolParam(description = "搜索查询文本") String query,
            @ToolParam(description = "翼楼过滤（可选，如 language_development）", required = false) String wing,
            @ToolParam(description = "房间过滤（可选，如 early_communication）", required = false) String room,
            @ToolParam(description = "返回结果数量上限（默认5）", required = false) Integer topK) {

        if (query == null || query.isBlank()) {
            log.info("palace_vector_search: query 为空，返回空结果");
            return toJson(Map.of("results", List.of(), "count", 0));
        }

        int safeTopK = (topK == null || topK <= 0) ? DEFAULT_TOP_K : topK;
        log.info("palace_vector_search: query='{}', wing='{}', room='{}', topK={}",
                query, wing, room, safeTopK);

        List<Document> docs = searchService.search(query, wing, room, safeTopK);
        List<Map<String, Object>> formatted = formatDocumentsAsList(docs);

        log.info("palace_vector_search: 返回 {} 条结果", formatted.size());
        return toJson(Map.of("results", formatted, "count", formatted.size()));
    }

    /**
     * 按关键词全文检索知识宫殿。
     */
    @Tool(name = "palace_keyword_search",
          description = "在知识宫殿中按关键词全文检索。当需要精确匹配特定术语或书名时使用。")
    public String palaceKeywordSearch(
            @ToolParam(description = "搜索关键词（空格分隔）") String keywords,
            @ToolParam(description = "翼楼过滤（可选）", required = false) String wing,
            @ToolParam(description = "房间过滤（可选）", required = false) String room,
            @ToolParam(description = "返回结果数量上限（默认5）", required = false) Integer limit) {

        if (keywords == null || keywords.isBlank()) {
            log.info("palace_keyword_search: keywords 为空，返回空结果");
            return toJson(Map.of("results", List.of(), "count", 0));
        }

        int safeLimit = (limit == null || limit <= 0) ? DEFAULT_TOP_K : limit;
        log.info("palace_keyword_search: keywords='{}', wing='{}', room='{}', limit={}",
                keywords, wing, room, safeLimit);

        List<ChunkResult> chunks = keywordRepository.searchByKeywords(keywords, wing, room, safeLimit);
        List<Map<String, Object>> formatted = formatChunksAsList(chunks);

        log.info("palace_keyword_search: 返回 {} 条结果", formatted.size());
        return toJson(Map.of("results", formatted, "count", formatted.size()));
    }

    /**
     * 按 chunk ID 读取完整文档片段内容。
     */
    @Tool(name = "palace_read_chunk",
          description = "根据 chunk ID 读取完整文档片段内容。当需要阅读检索结果的完整上下文时使用。")
    public String palaceReadChunk(
            @ToolParam(description = "chunk 的 UUID 字符串") String chunkId) {

        if (chunkId == null || chunkId.isBlank()) {
            log.info("palace_read_chunk: chunkId 为空");
            return toJson(Map.of("error", "chunkId 不能为空", "found", false));
        }

        UUID id;
        try {
            id = UUID.fromString(chunkId.trim());
        } catch (IllegalArgumentException e) {
            log.warn("palace_read_chunk: 无效的 UUID 格式: {}", chunkId);
            return toJson(Map.of("error", "无效的 UUID 格式: " + chunkId, "found", false));
        }

        log.info("palace_read_chunk: 读取 chunkId={}", id);
        Optional<ChunkResult> result = keywordRepository.readChunkById(id);

        if (result.isEmpty()) {
            log.info("palace_read_chunk: 未找到 chunkId={}", id);
            return toJson(Map.of("error", "未找到指定的 chunk", "found", false));
        }

        ChunkResult chunk = result.get();
        Map<String, Object> formatted = formatChunkAsMap(chunk);
        formatted.put("found", true);

        log.info("palace_read_chunk: 成功读取 chunkId={}", id);
        return toJson(formatted);
    }

    /**
     * 列出知识宫殿的结构——翼楼和房间。
     */
    @Tool(name = "palace_list_rooms",
          description = "列出知识宫殿的结构——翼楼和房间。帮助了解知识组织方式，决定在哪个区域搜索。")
    public String palaceListRooms(
            @ToolParam(description = "按翼楼过滤（可选，如 LANGUAGE_DEVELOPMENT）", required = false) String wing) {

        log.info("palace_list_rooms: wing 过滤='{}'", wing);

        Map<String, BookMapping> catalog = MemPalaceTaxonomy.catalog();

        // 按 wing 分组 book 映射
        String wingFilterLower = (wing != null && !wing.isBlank()) ? wing.trim().toLowerCase() : null;

        Map<String, List<Map<String, String>>> wingRoomMap = new LinkedHashMap<>();

        for (Map.Entry<String, BookMapping> entry : catalog.entrySet()) {
            BookMapping mapping = entry.getValue();
            String wingName = mapping.wing().name().toLowerCase();

            if (wingFilterLower != null && !wingName.equals(wingFilterLower)) {
                continue;
            }

            wingRoomMap.computeIfAbsent(wingName, k -> new ArrayList<>())
                    .add(Map.of(
                            "book", entry.getKey(),
                            "room", mapping.room().name().toLowerCase(),
                            "hall", mapping.hall().name().toLowerCase(),
                            "age_range", mapping.ageRange()
                    ));
        }

        log.info("palace_list_rooms: 返回 {} 个翼楼", wingRoomMap.size());
        return toJson(Map.of("wings", wingRoomMap, "wing_count", wingRoomMap.size()));
    }

    /**
     * 查询知识图谱中的实体关系。
     */
    @Tool(name = "kg_query_entity",
          description = "查询知识图谱中的实体关系。搜索实体名称并返回关联关系、来源书籍等信息。")
    public String kgQueryEntity(
            @ToolParam(description = "要查询的实体名称") String entity) {

        // 如果 KgQueryTool 可用，委托给真实 KG 查询
        if (kgQueryTool != null) {
            log.info("kg_query_entity: entity='{}' — 委托 KgQueryTool", entity);
            return kgQueryTool.queryEntity(entity);
        }

        // 回退：Phase 1 占位实现（KgQueryTool 不可用时）
        log.info("kg_query_entity: entity='{}' (Phase 1 占位，KgQueryTool 不可用)", entity);

        if (entity == null || entity.isBlank()) {
            return toJson(Map.of(
                    "entity", "",
                    "relationships", List.of(),
                    "note", "KgQueryTool 不可用，请使用 palace_vector_search 或 palace_keyword_search"
            ));
        }

        // Phase 1 占位：返回 taxonomy 相关概念
        Map<String, BookMapping> catalog = MemPalaceTaxonomy.catalog();
        List<Map<String, String>> relatedConcepts = catalog.entrySet().stream()
                .filter(e -> e.getKey().toLowerCase().contains(entity.trim().toLowerCase()))
                .limit(5)
                .map(e -> Map.of(
                        "book", e.getKey(),
                        "wing", e.getValue().wing().name().toLowerCase(),
                        "room", e.getValue().room().name().toLowerCase(),
                        "relation", "mentioned_in"
                ))
                .collect(Collectors.toList());

        return toJson(Map.of(
                "entity", entity.trim(),
                "relationships", relatedConcepts,
                "note", "Phase 1: 基于 taxonomy 书名匹配的占位实现"
        ));
    }

    // ─── 格式化辅助方法 ───────────────────────────────────────

    /**
     * 将 Document 列表转为 Map 列表（含来源信息）。
     */
    List<Map<String, Object>> formatDocumentsAsList(List<Document> docs) {
        return docs.stream().map(this::formatDocumentAsMap).collect(Collectors.toList());
    }

    private Map<String, Object> formatDocumentAsMap(Document doc) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", doc.getId());
        map.put("content", doc.getText());

        Map<String, Object> metadata = doc.getMetadata();
        map.put("source_book", metadata.getOrDefault("source_book", ""));
        map.put("wing", metadata.getOrDefault("wing", ""));
        map.put("room", metadata.getOrDefault("room", ""));
        map.put("hall", metadata.getOrDefault("hall", ""));
        map.put("age_range", metadata.getOrDefault("age_range", ""));
        return map;
    }

    /**
     * 将 ChunkResult 列表转为 Map 列表。
     */
    List<Map<String, Object>> formatChunksAsList(List<ChunkResult> chunks) {
        return chunks.stream().map(this::formatChunkAsMap).collect(Collectors.toList());
    }

    Map<String, Object> formatChunkAsMap(ChunkResult chunk) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", chunk.id().toString());
        map.put("content", chunk.content());

        Map<String, Object> metadata = chunk.metadata();
        map.put("source_book", metadata.getOrDefault("source_book", ""));
        map.put("wing", metadata.getOrDefault("wing", ""));
        map.put("room", metadata.getOrDefault("room", ""));
        map.put("hall", metadata.getOrDefault("hall", ""));
        map.put("age_range", metadata.getOrDefault("age_range", ""));
        return map;
    }

    /**
     * 将对象序列化为 JSON 字符串。
     */
    String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (JacksonException e) {
            log.error("JSON 序列化失败", e);
            return "{\"error\":\"JSON 序列化失败\"}";
        }
    }
}
