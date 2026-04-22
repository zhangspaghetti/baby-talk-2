package com.zhangspaghetti.babytalk.kg;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * 知识图谱关系 — 对应 kg_relationships 表。
 *
 * <p>关系类型包括 supports、contradicts、precedes、follows、part_of、related_to、causes、prevents。
 */
public record KgRelationship(
        UUID id,
        UUID sourceEntityId,
        UUID targetEntityId,
        String relationType,
        String sourceBook,
        BigDecimal confidence,
        String contextNote,
        Instant createdAt,
        Instant updatedAt
) {

    public static final String REL_SUPPORTS = "supports";
    public static final String REL_CONTRADICTS = "contradicts";
    public static final String REL_PRECEDES = "precedes";
    public static final String REL_FOLLOWS = "follows";
    public static final String REL_PART_OF = "part_of";
    public static final String REL_RELATED_TO = "related_to";
    public static final String REL_CAUSES = "causes";
    public static final String REL_PREVENTS = "prevents";

    /** 创建新关系（自动生成 ID 和时间戳） */
    public static KgRelationship create(UUID sourceEntityId, UUID targetEntityId,
                                         String relationType, String sourceBook,
                                         BigDecimal confidence, String contextNote) {
        Instant now = Instant.now();
        return new KgRelationship(UUID.randomUUID(), sourceEntityId, targetEntityId,
                relationType, sourceBook, confidence, contextNote, now, now);
    }
}
