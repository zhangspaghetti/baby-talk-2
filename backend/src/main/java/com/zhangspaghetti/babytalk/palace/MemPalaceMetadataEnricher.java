package com.zhangspaghetti.babytalk.palace;

import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.Document;
import org.springframework.ai.document.DocumentTransformer;

/**
 * 知识宫殿元数据标注器 — 给每个 Document chunk 注入宫殿坐标。
 *
 * <p>读取每个 Document metadata 中的 {@code source_book} 字段，
 * 通过 {@link MemPalaceTaxonomy#resolve(String)} 查找 BookMapping，
 * 然后向 metadata map 添加以下 snake_case 键：
 * <ul>
 *   <li>{@code wing} — 翼楼</li>
 *   <li>{@code room} — 房间</li>
 *   <li>{@code hall} — 大厅</li>
 *   <li>{@code age_range} — 适龄范围</li>
 * </ul>
 *
 * <p>如果 source_book 缺失或为空，使用默认分类。
 *
 * <p>实现 {@link DocumentTransformer} 接口，可直接接入 Spring AI ETL 管道。
 */
public class MemPalaceMetadataEnricher implements DocumentTransformer {

    private static final Logger log = LoggerFactory.getLogger(MemPalaceMetadataEnricher.class);

    public static final String META_SOURCE_BOOK = "source_book";
    public static final String META_WING = "wing";
    public static final String META_ROOM = "room";
    public static final String META_HALL = "hall";
    public static final String META_AGE_RANGE = "age_range";

    @Override
    public List<Document> apply(List<Document> documents) {
        if (documents == null || documents.isEmpty()) {
            return documents;
        }

        for (Document doc : documents) {
            var metadata = doc.getMetadata();
            String sourceBook = metadata.getOrDefault(META_SOURCE_BOOK, "").toString();

            MemPalaceTaxonomy.BookMapping mapping = MemPalaceTaxonomy.resolve(sourceBook);

            metadata.put(META_WING, mapping.wing().name().toLowerCase());
            metadata.put(META_ROOM, mapping.room().name().toLowerCase());
            metadata.put(META_HALL, mapping.hall().name().toLowerCase());
            metadata.put(META_AGE_RANGE, mapping.ageRange());

            if (!MemPalaceTaxonomy.hasExplicitMapping(sourceBook)) {
                log.debug("书名 '{}' 使用默认宫殿分类", sourceBook);
            }
        }

        log.info("MemPalaceMetadataEnricher 处理了 {} 个 document chunks", documents.size());
        return documents;
    }
}
