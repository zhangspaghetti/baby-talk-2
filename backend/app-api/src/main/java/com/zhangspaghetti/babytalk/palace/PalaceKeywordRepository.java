package com.zhangspaghetti.babytalk.palace;

import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.palace.PalaceKeywordMapper.ChunkRow;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Repository;

/**
 * 知识宫殿关键词检索仓库 — 基于 PostgreSQL 全文搜索（tsvector + plainto_tsquery）。
 *
 * <p>提供两个核心方法：
 * <ul>
 *   <li>{@link #searchByKeywords} — 全文检索 + metadata JSONB 过滤 + ts_rank 排序</li>
 *   <li>{@link #readChunkById} — 按 UUID 读取单个 chunk 的 content 和 metadata</li>
 * </ul>
 *
 * <p>这是 PalaceToolProvider 中 palace_keyword_search 和 palace_read_chunk 两个 tool 的数据层依赖。
 */
@Repository
public class PalaceKeywordRepository {

    private static final Logger log = LoggerFactory.getLogger(PalaceKeywordRepository.class);

    private static final int DEFAULT_LIMIT = 5;
    private static final int MAX_LIMIT = 50;

    private final PalaceKeywordMapper palaceKeywordMapper;
    private final ObjectMapper objectMapper;

    public PalaceKeywordRepository(PalaceKeywordMapper palaceKeywordMapper, ObjectMapper objectMapper) {
        this.palaceKeywordMapper = palaceKeywordMapper;
        this.objectMapper = objectMapper;
    }

    /**
     * 全文关键词检索 — 使用 plainto_tsquery('simple', ?) 匹配 content_tsv 计算列。
     *
     * @param keywords 搜索关键词（空格分隔，plainto_tsquery 自动处理）
     * @param wing     翼楼过滤（可选，null 或空表示不过滤）
     * @param room     房间过滤（可选，null 或空表示不过滤）
     * @param limit    返回结果数量上限（≤0 或 &gt;50 时使用默认值 5）
     * @return 按 ts_rank 降序排列的 ChunkResult 列表；keywords 为空时返回空列表
     */
    public List<ChunkResult> searchByKeywords(String keywords, String wing, String room, int limit) {
        if (keywords == null || keywords.isBlank()) {
            log.debug("event=palace_keyword_search_skipped reason=empty_keywords");
            return Collections.emptyList();
        }

        int safeLimit = (limit <= 0 || limit > MAX_LIMIT) ? DEFAULT_LIMIT : limit;
        String normalizedWing = wing == null || wing.isBlank() ? null : wing.trim().toLowerCase();
        String normalizedRoom = room == null || room.isBlank() ? null : room.trim().toLowerCase();
        String trimmedKeywords = keywords.trim();

        int keywordsLength = safeTextLength(trimmedKeywords);
        log.info(
                "event=palace_keyword_search_started keywordsLength={} hasWingFilter={} hasRoomFilter={} limit={}",
                keywordsLength,
                normalizedWing != null,
                normalizedRoom != null,
                safeLimit);
        try {
            List<ChunkResult> results = palaceKeywordMapper.searchByKeywords(
                            trimmedKeywords,
                            normalizedWing,
                            normalizedRoom,
                            safeLimit
                    )
                    .stream()
                    .map(this::mapChunkResult)
                    .toList();

            log.info(
                    "event=palace_keyword_search_complete keywordsLength={} resultCount={}",
                    keywordsLength,
                    results.size());
            return results;
        } catch (RuntimeException exception) {
            log.error(
                    "event=palace_keyword_search_failed keywordsLength={} exceptionType={}",
                    keywordsLength,
                    exception.getClass().getSimpleName());
            throw exception;
        }
    }

    /**
     * 按 UUID 读取单个 chunk 的 content 和 metadata。
     *
     * @param id chunk UUID（null 返回 empty）
     * @return Optional 包装的 ChunkResult
     */
    public Optional<ChunkResult> readChunkById(UUID id) {
        if (id == null) {
            log.debug("event=palace_chunk_read_skipped reason=missing_id");
            return Optional.empty();
        }

        ChunkRow row = palaceKeywordMapper.readChunkById(id);
        if (row == null) {
            log.debug("event=palace_chunk_read_complete found=false");
            return Optional.empty();
        }
        log.debug("event=palace_chunk_read_complete found=true");
        return Optional.of(mapChunkResult(row));
    }

    private ChunkResult mapChunkResult(ChunkRow row) {
        Map<String, Object> metadata = parseMetadata(row.metadataJson());
        return new ChunkResult(row.id(), row.content(), metadata, row.keywordScore());
    }

    private Map<String, Object> parseMetadata(String json) {
        if (json == null || json.isBlank()) {
            return Collections.emptyMap();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<>() {});
        } catch (Exception e) {
            log.warn(
                    "event=palace_keyword_metadata_parse_failed exceptionType={}",
                    e.getClass().getSimpleName());
            return Collections.emptyMap();
        }
    }

    private int safeTextLength(String value) {
        return value == null ? 0 : value.codePointCount(0, value.length());
    }

    /**
     * Chunk 检索结果。
     *
     * @param id           chunk UUID
     * @param content      原始文本内容
     * @param metadata     结构化元数据（wing, room, source_book 等）
     * @param keywordScore PostgreSQL ts_rank 得分（readChunkById 时可为 null）
     */
    public record ChunkResult(UUID id, String content, Map<String, Object> metadata, Double keywordScore) {}
}
