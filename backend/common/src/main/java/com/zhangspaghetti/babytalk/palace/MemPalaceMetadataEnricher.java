package com.zhangspaghetti.babytalk.palace;

import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.Document;
import org.springframework.ai.document.DocumentTransformer;

/**
 * 知识宫殿元数据标注器 — 给每个 Document chunk 注入宫殿坐标。
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

        for (Document document : documents) {
            var metadata = document.getMetadata();
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
