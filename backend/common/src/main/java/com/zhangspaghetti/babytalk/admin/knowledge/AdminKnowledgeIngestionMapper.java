package com.zhangspaghetti.babytalk.admin.knowledge;

import java.util.List;
import java.util.UUID;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface AdminKnowledgeIngestionMapper {

    @Update("set local statement_timeout = '2000ms'")
    void applyStatementTimeout();

    List<AdminKnowledgeIngestionRepository.IngestionJobRow> listJobs(
            @Param("status") String status,
            @Param("limit") int limit
    );

    AdminKnowledgeIngestionRepository.IngestionJobRow findJob(@Param("jobId") UUID jobId);

    AdminKnowledgeIngestionRepository.QueueSummaryRow fetchQueueSummary();
}
