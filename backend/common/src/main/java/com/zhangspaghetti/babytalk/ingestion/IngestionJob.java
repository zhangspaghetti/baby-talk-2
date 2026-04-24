package com.zhangspaghetti.babytalk.ingestion;

import java.time.Instant;
import java.util.UUID;

/**
 * Ingestion 任务数据模型 — 对应 ingestion_jobs 表。
 *
 * <p>状态机：PENDING → PROCESSING → COMPLETED / FAILED
 */
public record IngestionJob(
        UUID id,
        String originalFilename,
        String minioObjectKey,
        String status,
        int totalChunks,
        String errorMessage,
        Instant createdAt,
        Instant updatedAt
) {

    public static final String STATUS_PENDING = "PENDING";
    public static final String STATUS_PROCESSING = "PROCESSING";
    public static final String STATUS_COMPLETED = "COMPLETED";
    public static final String STATUS_FAILED = "FAILED";

    public static IngestionJob pending(String originalFilename, String minioObjectKey) {
        Instant now = Instant.now();
        return new IngestionJob(
                UUID.randomUUID(),
                originalFilename,
                minioObjectKey,
                STATUS_PENDING,
                0,
                null,
                now,
                now
        );
    }
}
