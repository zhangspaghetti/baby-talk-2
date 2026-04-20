package com.zhangspaghetti.babytalk.kg;

import java.time.Instant;
import java.util.UUID;

/**
 * 知识图谱实体 — 对应 kg_entities 表。
 *
 * <p>实体类型：concept（概念）、recommendation（建议）、milestone（里程碑）、fact（事实）
 */
public record KgEntity(
        UUID id,
        String name,
        String entityType,
        String sourceBook,
        String wing,
        String room,
        String description,
        Integer validFromMonths,
        Integer validToMonths,
        Instant createdAt,
        Instant updatedAt
) {

    public static final String TYPE_CONCEPT = "concept";
    public static final String TYPE_RECOMMENDATION = "recommendation";
    public static final String TYPE_MILESTONE = "milestone";
    public static final String TYPE_FACT = "fact";

    /** 创建新实体（自动生成 ID 和时间戳） */
    public static KgEntity create(String name, String entityType, String sourceBook,
                                   String wing, String room, String description,
                                   Integer validFromMonths, Integer validToMonths) {
        Instant now = Instant.now();
        return new KgEntity(UUID.randomUUID(), name, entityType, sourceBook,
                wing, room, description, validFromMonths, validToMonths, now, now);
    }
}
