package com.zhangspaghetti.babytalk.admin.mentor;

import java.time.Instant;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface AdminMentorAuditReadMapper {

    @Update("set local statement_timeout = '2000ms'")
    void applyStatementTimeout();

    List<AdminMentorAuditReadRepository.QueueIncidentRow> listFlaggedIncidents(
            @Param("installationId") String installationId,
            @Param("flagCode") String flagCode,
            @Param("limit") int limit
    );

    AdminMentorAuditReadRepository.IncidentSnapshotRow findIncidentSnapshot(@Param("correlationId") String correlationId);

    List<AdminMentorAuditReadRepository.TimelineRow> listTimeline(@Param("correlationId") String correlationId);

    AdminMentorAuditReadRepository.DeliveredTurnRow findDeliveredTurn(@Param("correlationId") String correlationId);

    int countCurrentWindowRequests(
            @Param("installationId") String installationId,
            @Param("windowStart") Instant windowStart
    );

    AdminMentorAuditReadRepository.OverviewSummaryRow fetchOverviewSummary();
}
