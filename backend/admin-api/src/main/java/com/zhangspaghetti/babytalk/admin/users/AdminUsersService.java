package com.zhangspaghetti.babytalk.admin.users;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminUsersService {

    private static final Logger log = LoggerFactory.getLogger(AdminUsersService.class);
    private static final String STATUS_ALL = "all";
    private static final String STATUS_ACTIVE = "active";
    private static final String STATUS_DELETED = "deleted";
    private static final String CONSENT_SIGNED_OUT = "signed_out";
    private static final String CONSENT_ACCEPTED = "accepted";
    private static final String CONSENT_REVOKED = "revoked";
    private static final String CONSENT_DELETED = "deleted";
    private static final String AUDIT_ACTION_DELETE = "delete";
    private static final String AUDIT_RESULT_APPLIED = "applied";
    private static final String AUDIT_RESULT_DUPLICATE = "duplicate";
    private static final String FALLBACK_INSTALLATION_ID = "admin-workbench";
    private static final int DEFAULT_HISTORY_LIMIT = 10;
    private static final Set<String> ALLOWED_LIST_STATUSES = Set.of(STATUS_ALL, STATUS_ACTIVE, STATUS_DELETED);
    private static final Set<String> ALLOWED_ACCOUNT_STATUSES = Set.of(STATUS_ACTIVE, STATUS_DELETED);
    private static final Set<String> ALLOWED_CONSENT_STATUSES = Set.of(
            CONSENT_SIGNED_OUT,
            CONSENT_ACCEPTED,
            CONSENT_REVOKED,
            CONSENT_DELETED
    );
    private static final Set<String> ALLOWED_SESSION_STATUSES = Set.of(STATUS_ACTIVE, "revoked", STATUS_DELETED);
    private static final Set<String> ALLOWED_AUDIT_ACTIONS = Set.of("accept", "revoke", AUDIT_ACTION_DELETE);
    private static final Set<String> ALLOWED_AUDIT_RESULTS = Set.of(AUDIT_RESULT_APPLIED, AUDIT_RESULT_DUPLICATE);

    private final AdminUserReadRepository adminUserReadRepository;
    private final Clock clock;

    public AdminUsersService(AdminUserReadRepository adminUserReadRepository, Clock clock) {
        this.adminUserReadRepository = adminUserReadRepository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public UserListView listUsers(int page, int pageSize, String status, String query) {
        var normalizedStatus = normalizeStatus(status);
        var normalizedQuery = normalizeQuery(query);
        try {
            var result = adminUserReadRepository.listUsers(new AdminUserReadRepository.UserListQuery(
                    STATUS_ALL.equals(normalizedStatus) ? null : normalizedStatus,
                    normalizedQuery,
                    pageSize,
                    (page - 1) * pageSize
            ));
            return new UserListView(
                    result.items().stream().map(this::toUserSummary).toList(),
                    page,
                    pageSize,
                    result.total(),
                    calculateTotalPages(result.total(), pageSize),
                    new UserFiltersView(normalizedStatus, normalizedQuery)
            );
        } catch (DataAccessException exception) {
            throw storageFailure("list_users", exception);
        } catch (IllegalStateException exception) {
            throw contractFailure("list_users", Map.of("reason", exception.getMessage()));
        }
    }

    @Transactional(readOnly = true)
    public UserDetailView getUser(String accountId) {
        var normalizedAccountId = normalizeAccountId(accountId);
        try {
            var detail = adminUserReadRepository.findUserDetail(normalizedAccountId, DEFAULT_HISTORY_LIMIT, DEFAULT_HISTORY_LIMIT)
                    .orElseThrow(() -> accountNotFound(normalizedAccountId));
            return new UserDetailView(
                    toUserSummary(detail.account()),
                    detail.recentSessions().stream().map(this::toSessionView).toList(),
                    detail.recentConsentAudit().stream().map(this::toConsentAuditView).toList()
            );
        } catch (DataAccessException exception) {
            throw storageFailure("get_user", exception);
        } catch (IllegalStateException exception) {
            throw contractFailure("get_user", Map.of(
                    "accountId", normalizedAccountId,
                    "reason", exception.getMessage()
            ));
        }
    }

    @Transactional
    public DisableUserView disableUser(String accountId, String reason) {
        var normalizedAccountId = normalizeAccountId(accountId);
        var normalizedReason = normalizeReason(reason);
        var now = Instant.now(clock);

        try {
            var account = adminUserReadRepository.lockAccount(normalizedAccountId)
                    .orElseThrow(() -> accountNotFound(normalizedAccountId));
            var auditContext = adminUserReadRepository.findLatestAuditContext(normalizedAccountId)
                    .orElse(new AdminUserReadRepository.AuditContextRow(normalizedAccountId, FALLBACK_INSTALLATION_ID));

            if (STATUS_DELETED.equals(requireAllowed(account.status(), ALLOWED_ACCOUNT_STATUSES, "account.status"))) {
                adminUserReadRepository.insertConsentAudit(new AdminUserReadRepository.AuditWriteRow(
                        normalizedAccountId,
                        auditContext.sessionId(),
                        auditContext.installationId(),
                        AUDIT_ACTION_DELETE,
                        AUDIT_RESULT_DUPLICATE,
                        normalizedReason,
                        now
                ));
                log.info("admin-users disable duplicate. accountId={}", normalizedAccountId);
                return new DisableUserView(
                        normalizedAccountId,
                        STATUS_DELETED,
                        false,
                        AUDIT_RESULT_DUPLICATE,
                        now,
                        0,
                        0
                );
            }

            var deletedEventCount = adminUserReadRepository.deleteInteractionEvents(normalizedAccountId);
            var revokedSessionCount = adminUserReadRepository.updateSessionsStatus(normalizedAccountId, STATUS_DELETED, now);
            adminUserReadRepository.tombstoneAccount(normalizedAccountId, now);
            adminUserReadRepository.insertConsentAudit(new AdminUserReadRepository.AuditWriteRow(
                    normalizedAccountId,
                    auditContext.sessionId(),
                    auditContext.installationId(),
                    AUDIT_ACTION_DELETE,
                    AUDIT_RESULT_APPLIED,
                    normalizedReason,
                    now
            ));
            log.info(
                    "admin-users disable applied. accountId={} revokedSessions={} deletedEvents={}",
                    normalizedAccountId,
                    revokedSessionCount,
                    deletedEventCount
            );
            return new DisableUserView(
                    normalizedAccountId,
                    STATUS_DELETED,
                    true,
                    AUDIT_RESULT_APPLIED,
                    now,
                    revokedSessionCount,
                    deletedEventCount
            );
        } catch (DataAccessException exception) {
            throw storageFailure("disable_user", exception);
        }
    }

    private UserSummaryView toUserSummary(AdminUserReadRepository.AdminUserRow row) {
        return new UserSummaryView(
                row.accountId(),
                row.phoneMask(),
                requireAllowed(row.status(), ALLOWED_ACCOUNT_STATUSES, "account.status"),
                requireAllowed(row.latestConsentStatus(), ALLOWED_CONSENT_STATUSES, "account.latestConsentStatus"),
                row.createdAt(),
                row.deletedAt()
        );
    }

    private UserSessionView toSessionView(AdminUserReadRepository.UserSessionRow row) {
        return new UserSessionView(
                row.sessionId(),
                row.installationId(),
                requireAllowed(row.status(), ALLOWED_SESSION_STATUSES, "session.status"),
                row.createdAt(),
                row.revokedAt()
        );
    }

    private UserConsentAuditView toConsentAuditView(AdminUserReadRepository.UserConsentAuditRow row) {
        return new UserConsentAuditView(
                row.auditId(),
                row.sessionId(),
                row.installationId(),
                requireAllowed(row.action(), ALLOWED_AUDIT_ACTIONS, "consentAudit.action"),
                requireAllowed(row.result(), ALLOWED_AUDIT_RESULTS, "consentAudit.result"),
                row.reason(),
                row.createdAt()
        );
    }

    private int calculateTotalPages(int total, int pageSize) {
        if (total == 0) {
            return 0;
        }
        return (int) Math.ceil((double) total / pageSize);
    }

    private String normalizeStatus(String status) {
        if (status == null || status.isBlank()) {
            return STATUS_ALL;
        }
        var normalized = status.trim().toLowerCase(Locale.ROOT);
        if (!ALLOWED_LIST_STATUSES.contains(normalized)) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_user_status",
                    "status 仅支持 all / active / deleted。",
                    Map.of("allowed", ALLOWED_LIST_STATUSES));
        }
        return normalized;
    }

    private String normalizeQuery(String query) {
        if (query == null || query.isBlank()) {
            return null;
        }
        var normalized = query.trim();
        if (normalized.length() > 64) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_user_query",
                    "query 过长。",
                    Map.of("maxLength", 64));
        }
        return normalized;
    }

    private String normalizeAccountId(String accountId) {
        if (accountId == null || accountId.isBlank()) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_user_account_id",
                    "accountId 不能为空。",
                    Map.of());
        }
        var normalized = accountId.trim();
        if (normalized.length() > 64) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_user_account_id",
                    "accountId 过长。",
                    Map.of("maxLength", 64));
        }
        return normalized;
    }

    private String normalizeReason(String reason) {
        if (reason == null || reason.isBlank()) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_user_disable_reason",
                    "reason 不能为空。",
                    Map.of());
        }
        var normalized = reason.trim();
        if (normalized.length() > 240) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_user_disable_reason",
                    "reason 过长。",
                    Map.of("maxLength", 240));
        }
        return normalized;
    }

    private String requireAllowed(String value, Set<String> allowedValues, String fieldName) {
        if (!allowedValues.contains(value)) {
            throw new IllegalStateException(fieldName + " unexpected: " + value);
        }
        return value;
    }

    private AdminApiContractException accountNotFound(String accountId) {
        return new AdminApiContractException(
                HttpStatus.NOT_FOUND,
                "user_account_not_found",
                "用户账号不存在。",
                Map.of("accountId", accountId));
    }

    private AdminApiContractException storageFailure(String phase, DataAccessException exception) {
        log.warn("admin-users storage failure. phase={}", phase, exception);
        return new AdminApiContractException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "users_storage_unavailable",
                "用户账号共享存储暂不可用。",
                Map.of(
                        "phase", phase,
                        "retryable", true
                ));
    }

    private AdminApiContractException contractFailure(String phase, Map<String, Object> details) {
        return new AdminApiContractException(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "users_contract_failure",
                "用户账号合同构造失败。",
                Map.of("phase", phase, "details", details));
    }

    public record UserListView(
            List<UserSummaryView> items,
            int page,
            int pageSize,
            int total,
            int totalPages,
            UserFiltersView filters
    ) {
    }

    public record UserFiltersView(String status, String query) {
    }

    public record UserSummaryView(
            String accountId,
            String phoneNumber,
            String status,
            String latestConsentStatus,
            Instant createdAt,
            Instant deletedAt
    ) {
    }

    public record UserDetailView(
            UserSummaryView account,
            List<UserSessionView> recentSessions,
            List<UserConsentAuditView> recentConsentAudit
    ) {
    }

    public record UserSessionView(
            String sessionId,
            String installationId,
            String status,
            Instant createdAt,
            Instant revokedAt
    ) {
    }

    public record UserConsentAuditView(
            long auditId,
            String sessionId,
            String installationId,
            String action,
            String result,
            String reason,
            Instant createdAt
    ) {
    }

    public record DisableUserView(
            String accountId,
            String status,
            boolean applied,
            String result,
            Instant updatedAt,
            int revokedSessionCount,
            int deletedEventCount
    ) {
    }
}
