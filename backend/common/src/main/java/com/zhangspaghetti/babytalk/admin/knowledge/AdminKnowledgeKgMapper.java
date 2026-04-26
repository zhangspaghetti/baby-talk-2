package com.zhangspaghetti.babytalk.admin.knowledge;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface AdminKnowledgeKgMapper {

    @Update("set local statement_timeout = '2000ms'")
    void applyStatementTimeout();

    List<AdminKnowledgeKgRepository.ContradictionRow> listContradictions(
            @Param("status") String status,
            @Param("limit") int limit
    );

    AdminKnowledgeKgRepository.ContradictionRow findContradiction(@Param("contradictionId") UUID contradictionId);

    AdminKnowledgeKgRepository.ContradictionRow findContradictionForUpdate(@Param("contradictionId") UUID contradictionId);

    void resolveContradiction(
            @Param("contradictionId") UUID contradictionId,
            @Param("adminNotes") String adminNotes,
            @Param("resolvedAt") Instant resolvedAt
    );

    List<AdminKnowledgeKgRepository.NotificationRow> listNotifications(
            @Param("contradictionId") UUID contradictionId,
            @Param("limit") int limit
    );

    AdminKnowledgeKgRepository.NotificationRow findNotification(@Param("notificationId") UUID notificationId);

    AdminKnowledgeKgRepository.NotificationRow findNotificationForUpdate(@Param("notificationId") UUID notificationId);

    void markNotificationRead(@Param("notificationId") UUID notificationId);

    AdminKnowledgeKgRepository.QueueSummaryRow fetchQueueSummary();
}
