package com.zhangspaghetti.babytalk.ingestion;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface IngestionMapper {

    void insert(@Param("job") IngestionJob job);

    int updateStatusProcessing(
            @Param("jobId") UUID jobId,
            @Param("updatedAt") Instant updatedAt
    );

    int updateCompleted(
            @Param("jobId") UUID jobId,
            @Param("totalChunks") int totalChunks,
            @Param("updatedAt") Instant updatedAt
    );

    int updateFailed(
            @Param("jobId") UUID jobId,
            @Param("errorMessage") String errorMessage,
            @Param("updatedAt") Instant updatedAt
    );

    IngestionJob findById(@Param("jobId") UUID jobId);

    List<IngestionJob> findAll();

    int updateStatusPending(
            @Param("jobId") UUID jobId,
            @Param("updatedAt") Instant updatedAt
    );

    List<IngestionJob> findByStatus(@Param("status") String status);
}
