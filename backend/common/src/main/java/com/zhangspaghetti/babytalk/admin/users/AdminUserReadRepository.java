package com.zhangspaghetti.babytalk.admin.users;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public class AdminUserReadRepository {

    private final AdminUserReadMapper adminUserReadMapper;

    public AdminUserReadRepository(AdminUserReadMapper adminUserReadMapper) {
        this.adminUserReadMapper = adminUserReadMapper;
    }

    public UserPage listUsers(UserListQuery query) {
        var total = adminUserReadMapper.countUsers(query.status(), query.query());
        var items = adminUserReadMapper.listUsers(query.status(), query.query(), query.limit(), query.offset());
        return new UserPage(items, total == null ? 0 : total);
    }

    public Optional<UserDetailRow> findUserDetail(String accountId, int sessionLimit, int auditLimit) {
        return findAccount(accountId)
                .map(account -> new UserDetailRow(
                        account,
                        listRecentSessions(accountId, sessionLimit),
                        listRecentConsentAudit(accountId, auditLimit)
                ));
    }

    public Optional<AdminUserRow> findAccount(String accountId) {
        return Optional.ofNullable(adminUserReadMapper.findAccount(accountId));
    }

    public Optional<AdminUserRow> lockAccount(String accountId) {
        return Optional.ofNullable(adminUserReadMapper.lockAccount(accountId));
    }

    public Optional<AuditContextRow> findLatestAuditContext(String accountId) {
        return Optional.ofNullable(adminUserReadMapper.findLatestAuditContext(accountId));
    }

    public List<UserSessionRow> listRecentSessions(String accountId, int limit) {
        return adminUserReadMapper.listRecentSessions(accountId, limit);
    }

    public List<UserConsentAuditRow> listRecentConsentAudit(String accountId, int limit) {
        return adminUserReadMapper.listRecentConsentAudit(accountId, limit);
    }

    public int deleteInteractionEvents(String accountId) {
        return adminUserReadMapper.deleteInteractionEvents(accountId);
    }

    public int updateSessionsStatus(String accountId, String newStatus, Instant changedAt) {
        return adminUserReadMapper.updateSessionsStatus(accountId, newStatus, changedAt);
    }

    public int tombstoneAccount(String accountId, String tombstonePhone, Instant deletedAt) {
        return adminUserReadMapper.tombstoneAccount(accountId, tombstonePhone, deletedAt);
    }

    public void insertConsentAudit(AuditWriteRow auditRow) {
        adminUserReadMapper.insertConsentAudit(auditRow);
    }

    public record UserListQuery(
            String status,
            String query,
            int limit,
            int offset
    ) {
    }

    public record UserPage(List<AdminUserRow> items, int total) {
    }

    public record UserDetailRow(
            AdminUserRow account,
            List<UserSessionRow> recentSessions,
            List<UserConsentAuditRow> recentConsentAudit
    ) {
    }

    public record AdminUserRow(
            String accountId,
            String phoneNumber,
            String status,
            String latestConsentStatus,
            Instant createdAt,
            Instant deletedAt
    ) {
    }

    public record UserSessionRow(
            String sessionId,
            String installationId,
            String status,
            Instant createdAt,
            Instant revokedAt
    ) {
    }

    public record UserConsentAuditRow(
            long auditId,
            String sessionId,
            String installationId,
            String action,
            String result,
            String reason,
            Instant createdAt
    ) {
    }

    public record AuditContextRow(String sessionId, String installationId) {
    }

    public record AuditWriteRow(
            String accountId,
            String sessionId,
            String installationId,
            String action,
            String result,
            String reason,
            Instant createdAt
    ) {
    }
}
