package com.zhangspaghetti.babytalk.kg;

import java.time.Instant;
import java.util.UUID;

/**
 * 知识图谱矛盾记录 — 对应 kg_contradictions 表。
 *
 * <p>状态机：detected → reviewing → escalated → resolved / dismissed
 */
public record KgContradiction(
        UUID id,
        String entityTopic,
        UUID relationshipAId,
        UUID relationshipBId,
        String sourceABook,
        String sourceBBook,
        String description,
        String status,
        String agentReviewResult,
        String adminNotes,
        Instant detectedAt,
        Instant reviewedAt,
        Instant resolvedAt
) {

    public static final String STATUS_DETECTED = "detected";
    public static final String STATUS_REVIEWING = "reviewing";
    public static final String STATUS_ESCALATED = "escalated";
    public static final String STATUS_RESOLVED = "resolved";
    public static final String STATUS_DISMISSED = "dismissed";

    /** 创建新矛盾记录（detected 状态） */
    public static KgContradiction detected(String entityTopic,
                                            UUID relationshipAId, UUID relationshipBId,
                                            String sourceABook, String sourceBBook,
                                            String description) {
        return new KgContradiction(UUID.randomUUID(), entityTopic,
                relationshipAId, relationshipBId,
                sourceABook, sourceBBook, description,
                STATUS_DETECTED, null, null, Instant.now(), null, null);
    }
}
