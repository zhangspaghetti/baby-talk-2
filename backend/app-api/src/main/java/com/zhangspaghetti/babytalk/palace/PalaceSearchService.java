package com.zhangspaghetti.babytalk.palace;

import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.Document;
import org.springframework.ai.vectorstore.SearchRequest;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.stereotype.Service;

/**
 * 知识宫殿向量检索服务 — 封装 PgVectorStore.similaritySearch + filterExpression。
 *
 * <p>支持按 wing（翼楼）、room（房间）过滤检索，构建 filterExpression 字符串
 * 传递给 Spring AI 的 SearchRequest.builder().filterExpression()。
 */
@Service
public class PalaceSearchService {

    private static final Logger log = LoggerFactory.getLogger(PalaceSearchService.class);

    private final VectorStore vectorStore;

    public PalaceSearchService(VectorStore vectorStore) {
        this.vectorStore = vectorStore;
    }

    /**
     * 按宫殿坐标过滤的向量相似度检索。
     *
     * @param query 查询文本
     * @param wing  翼楼过滤（可选，null 或空表示不过滤）
     * @param room  房间过滤（可选，null 或空表示不过滤）
     * @param topK  返回结果数量上限
     * @return 相似文档列表
     */
    public List<Document> search(String query, String wing, String room, int topK) {
        SearchRequest.Builder builder = SearchRequest.builder()
                .query(query)
                .topK(topK);

        String filterExpression = buildFilterExpression(wing, room);
        if (filterExpression != null) {
            builder.filterExpression(filterExpression);
            log.info("向量检索: query='{}', topK={}, filter='{}'", query, topK, filterExpression);
        } else {
            log.info("向量检索: query='{}', topK={}, 无过滤条件", query, topK);
        }

        List<Document> results = vectorStore.similaritySearch(builder.build());
        log.info("检索完成: 返回 {} 条结果", results.size());
        return results;
    }

    /**
     * 构建 filterExpression 字符串。
     *
     * <p>Spring AI PgVectorStore 支持 SQL-like 过滤语法：
     * {@code wing == 'language_development' && room == 'early_communication'}
     *
     * @return filterExpression 字符串，无条件时返回 null
     */
    String buildFilterExpression(String wing, String room) {
        StringBuilder sb = new StringBuilder();

        if (wing != null && !wing.isBlank()) {
            sb.append("wing == '").append(wing.trim().toLowerCase()).append("'");
        }

        if (room != null && !room.isBlank()) {
            if (sb.length() > 0) {
                sb.append(" && ");
            }
            sb.append("room == '").append(room.trim().toLowerCase()).append("'");
        }

        return sb.length() > 0 ? sb.toString() : null;
    }
}
