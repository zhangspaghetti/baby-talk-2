package com.zhangspaghetti.babytalk.palace;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
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

    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    public PalaceKeywordRepository(JdbcTemplate jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
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
            log.debug("关键词检索: keywords 为空，返回空列表");
            return Collections.emptyList();
        }

        int safeLimit = (limit <= 0 || limit > MAX_LIMIT) ? DEFAULT_LIMIT : limit;

        // 动态构建 SQL WHERE 子句
        StringBuilder sql = new StringBuilder("""
                SELECT id, content, metadata,
                       ts_rank(content_tsv, plainto_tsquery('simple', ?)) AS rank
                FROM vector_store
                WHERE content_tsv @@ plainto_tsquery('simple', ?)
                """);
        List<Object> params = new ArrayList<>();
        params.add(keywords.trim());
        params.add(keywords.trim());

        if (wing != null && !wing.isBlank()) {
            sql.append("  AND metadata->>'wing' = ?\n");
            params.add(wing.trim().toLowerCase());
        }

        if (room != null && !room.isBlank()) {
            sql.append("  AND metadata->>'room' = ?\n");
            params.add(room.trim().toLowerCase());
        }

        sql.append("ORDER BY rank DESC\nLIMIT ?");
        params.add(safeLimit);

        log.info("关键词检索: keywords='{}', wing='{}', room='{}', limit={}",
                keywords, wing, room, safeLimit);

        List<ChunkResult> results = jdbc.query(
                sql.toString(),
                chunkResultRowMapper(),
                params.toArray()
        );

        log.info("关键词检索完成: 返回 {} 条结果", results.size());
        return results;
    }

    /**
     * 按 UUID 读取单个 chunk 的 content 和 metadata。
     *
     * @param id chunk UUID（null 返回 empty）
     * @return Optional 包装的 ChunkResult
     */
    public Optional<ChunkResult> readChunkById(UUID id) {
        if (id == null) {
            log.debug("readChunkById: id 为 null，返回 empty");
            return Optional.empty();
        }

        List<ChunkResult> results = jdbc.query(
                "SELECT id, content, metadata FROM vector_store WHERE id = ?",
                chunkResultRowMapper(),
                id
        );

        if (results.isEmpty()) {
            log.debug("readChunkById: 未找到 id={}", id);
        }
        return results.stream().findFirst();
    }

    private RowMapper<ChunkResult> chunkResultRowMapper() {
        return (rs, rowNum) -> mapChunkResult(rs);
    }

    private ChunkResult mapChunkResult(ResultSet rs) throws SQLException {
        UUID id = UUID.fromString(rs.getString("id"));
        String content = rs.getString("content");
        String metadataJson = rs.getString("metadata");

        Map<String, Object> metadata = parseMetadata(metadataJson);
        return new ChunkResult(id, content, metadata);
    }

    private Map<String, Object> parseMetadata(String json) {
        if (json == null || json.isBlank()) {
            return Collections.emptyMap();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<>() {});
        } catch (Exception e) {
            log.warn("metadata JSON 解析失败: {}", e.getMessage());
            return Collections.emptyMap();
        }
    }

    /**
     * Chunk 检索结果。
     *
     * @param id       chunk UUID
     * @param content  原始文本内容
     * @param metadata 结构化元数据（wing, room, source_book 等）
     */
    public record ChunkResult(UUID id, String content, Map<String, Object> metadata) {}
}
