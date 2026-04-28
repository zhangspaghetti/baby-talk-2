package com.zhangspaghetti.babytalk.kg;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface KgContradictionMapper {

    void insert(@Param("contradiction") KgContradiction contradiction);

    KgContradiction findById(@Param("id") UUID id);

    List<KgContradiction> findAll();

    List<KgContradiction> findByStatus(@Param("status") String status);

    int updateStatus(
            @Param("id") UUID id,
            @Param("status") String status,
            @Param("agentReviewResult") String agentReviewResult,
            @Param("reviewedAt") Instant reviewedAt
    );

    int updateResolved(
            @Param("id") UUID id,
            @Param("status") String status,
            @Param("adminNotes") String adminNotes,
            @Param("resolvedAt") Instant resolvedAt
    );

    List<KgContradiction> findPendingReview(
            @Param("status") String status,
            @Param("batchSize") int batchSize
    );
}
