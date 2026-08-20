package com.zhangspaghetti.babytalk.admin.users;

import java.time.Instant;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface AdminUserReadMapper {

    Integer countUsers(
            @Param("status") String status,
            @Param("query") String query
    );

    List<AdminUserReadRepository.AdminUserRow> listUsers(
            @Param("status") String status,
            @Param("query") String query,
            @Param("limit") int limit,
            @Param("offset") int offset
    );

    AdminUserReadRepository.AdminUserRow findAccount(@Param("accountId") String accountId);

    AdminUserReadRepository.AdminUserRow lockAccount(@Param("accountId") String accountId);

    AdminUserReadRepository.AuditContextRow findLatestAuditContext(@Param("accountId") String accountId);

    List<AdminUserReadRepository.UserSessionRow> listRecentSessions(
            @Param("accountId") String accountId,
            @Param("limit") int limit
    );

    List<AdminUserReadRepository.UserConsentAuditRow> listRecentConsentAudit(
            @Param("accountId") String accountId,
            @Param("limit") int limit
    );

    int deleteInteractionEvents(@Param("accountId") String accountId);

    int updateSessionsStatus(
            @Param("accountId") String accountId,
            @Param("newStatus") String newStatus,
            @Param("changedAt") Instant changedAt
    );

    int tombstoneAccount(
            @Param("accountId") String accountId,
            @Param("deletedAt") Instant deletedAt
    );

    void insertConsentAudit(@Param("auditRow") AdminUserReadRepository.AuditWriteRow auditRow);
}
