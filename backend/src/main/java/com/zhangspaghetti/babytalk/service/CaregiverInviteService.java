package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.CaregiverInviteProperties;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class CaregiverInviteService {

    private static final DateTimeFormatter SUMMARY_TIME_FORMATTER =
            DateTimeFormatter.ofPattern("M月d日 HH:mm").withZone(ZoneOffset.UTC);

    private final CaregiverInviteRepository repository;
    private final AuthConsentSyncRepository authConsentSyncRepository;
    private final CaregiverInviteProperties properties;
    private final Clock clock = Clock.systemUTC();
    private final TransactionTemplate auditTransactionTemplate;

    public CaregiverInviteService(
            CaregiverInviteRepository repository,
            AuthConsentSyncRepository authConsentSyncRepository,
            CaregiverInviteProperties properties,
            org.springframework.transaction.PlatformTransactionManager transactionManager
    ) {
        this.repository = repository;
        this.authConsentSyncRepository = authConsentSyncRepository;
        this.properties = properties;
        this.auditTransactionTemplate = new TransactionTemplate(transactionManager);
        this.auditTransactionTemplate.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    @Transactional
    public CreateInviteResponse createInvite(String sessionId, CreateInviteCommand command) {
        var session = requireEligibleSession(sessionId);
        var requestedRole = normalizeRole(command.role());
        var source = normalizeSource(command.source());
        var now = Instant.now(clock);
        try {
            var membership = requirePrimaryInviteManager(session, now, "create", source, requestedRole);
            var token = generateToken();
            var expiresAt = now.plus(properties.defaultLinkTtl());
            repository.insertInvite(new CaregiverInviteRepository.InviteRow(
                    0,
                    token,
                    membership.householdId(),
                    session.accountId(),
                    requestedRole,
                    source,
                    "pending",
                    now,
                    expiresAt,
                    null,
                    null,
                    null,
                    null
            ));
            repository.insertEvent(eventRow(token, membership.householdId(), session.accountId(), "create", source, requestedRole,
                    "create", null, now));
            return new CreateInviteResponse(
                    membership.householdId(),
                    token,
                    buildInviteUrl(token),
                    requestedRole,
                    source,
                    expiresAt
            );
        } catch (ContractException exception) {
            throw exception;
        } catch (DataAccessException exception) {
            recordEventSafely(eventRow(null, null, session.accountId(), "create", source, requestedRole,
                    "invalid", "invite_storage_unavailable", now));
            throw inviteStorageUnavailable("create", exception);
        }
    }

    @Transactional
    public AcceptInviteResponse acceptInvite(String sessionId, AcceptInviteCommand command) {
        var session = requireEligibleSession(sessionId);
        var token = normalizeToken(command.token());
        var source = normalizeSource(command.source());
        var now = Instant.now(clock);
        try {
            var invite = repository.findInviteByToken(token)
                    .orElseThrow(() -> notFoundInvite(token, session.accountId(), source, now));
            ensureInviteAcceptable(invite, session.accountId(), source, now);

            var existingMembership = repository.findActiveMembershipByAccount(session.accountId()).orElse(null);
            if (existingMembership != null) {
                recordEventSafely(eventRow(token, invite.householdId(), session.accountId(), "accept", source, invite.targetRole(),
                        "role_not_allowed", "already_member", now));
                throw new ContractException(
                        HttpStatus.CONFLICT,
                        "already_member",
                        "当前账号已经加入照护家庭，不能重复接受 invite。",
                        Map.of("retryable", false)
                );
            }

            var snapshot = buildSharedContextProjection(
                    invite.householdId(),
                    now,
                    "accept",
                    token,
                    session.accountId(),
                    source,
                    invite.targetRole(),
                    1
            );
            repository.insertMember(new CaregiverInviteRepository.HouseholdMemberRow(
                    0,
                    invite.householdId(),
                    session.accountId(),
                    invite.targetRole(),
                    "active",
                    invite.inviterAccountId(),
                    now,
                    now
            ));
            repository.upsertSharedContext(snapshot);
            repository.markInviteAccepted(token, session.accountId(), now);
            repository.insertEvent(eventRow(token, invite.householdId(), session.accountId(), "accept", source, invite.targetRole(),
                    "accept", null, now));
            return new AcceptInviteResponse(
                    invite.householdId(),
                    invite.targetRole(),
                    now,
                    toSharedContextResponse(invite.targetRole(), now, snapshot)
            );
        } catch (ContractException exception) {
            throw exception;
        } catch (DataAccessException exception) {
            recordEventSafely(eventRow(token, null, session.accountId(), "accept", source, null,
                    "invalid", "invite_storage_unavailable", now));
            throw inviteStorageUnavailable("accept", exception);
        }
    }

    @Transactional
    public RevokeInviteResponse revokeInvite(String sessionId, String rawToken) {
        var session = requireEligibleSession(sessionId);
        var token = normalizeToken(rawToken);
        var now = Instant.now(clock);
        try {
            var invite = repository.findInviteByToken(token)
                    .orElseThrow(() -> notFoundInvite(token, session.accountId(), null, now));
            var membership = requirePrimaryInviteManager(session, now, "revoke", invite.source(), invite.targetRole());
            if (!membership.householdId().equals(invite.householdId())) {
                recordEventSafely(eventRow(token, invite.householdId(), session.accountId(), "revoke", invite.source(), invite.targetRole(),
                        "role_not_allowed", "cross_household_revoke", now));
                throw new ContractException(HttpStatus.FORBIDDEN, "role_not_allowed", "当前账号不能管理其他 household 的 invite。");
            }
            if (isExpired(invite, now)) {
                persistInviteExpired(token);
                recordEventSafely(eventRow(token, invite.householdId(), session.accountId(), "revoke", invite.source(), invite.targetRole(),
                        "expired", "token_expired", now));
                throw new ContractException(HttpStatus.GONE, "invite_expired", "invite 已过期，请重新创建。", Map.of("retryable", true));
            }
            if ("accepted".equals(invite.status())) {
                recordEventSafely(eventRow(token, invite.householdId(), session.accountId(), "revoke", invite.source(), invite.targetRole(),
                        "already_used", "token_already_used", now));
                throw new ContractException(HttpStatus.CONFLICT, "invite_already_used", "invite 已被使用。", Map.of("retryable", false));
            }
            if ("revoked".equals(invite.status())) {
                return new RevokeInviteResponse(false, "duplicate", token, now);
            }
            repository.markInviteRevoked(token, now, "invite_revoked");
            repository.insertEvent(eventRow(token, invite.householdId(), session.accountId(), "revoke", invite.source(), invite.targetRole(),
                    "revoked", "invite_revoked", now));
            return new RevokeInviteResponse(true, "revoked", token, now);
        } catch (ContractException exception) {
            throw exception;
        } catch (DataAccessException exception) {
            recordEventSafely(eventRow(token, null, session.accountId(), "revoke", null, null,
                    "invalid", "invite_storage_unavailable", now));
            throw inviteStorageUnavailable("revoke", exception);
        }
    }

    @Transactional
    public SharedContextResponse fetchSharedContext(String sessionId) {
        var session = requireEligibleSession(sessionId);
        var now = Instant.now(clock);
        try {
            var membership = repository.findActiveMembershipByAccount(session.accountId())
                    .orElseThrow(() -> {
                        recordEventSafely(eventRow(null, null, session.accountId(), "shared_context", null, null,
                                "role_not_allowed", "household_membership_missing", now));
                        return new ContractException(HttpStatus.FORBIDDEN, "role_not_allowed", "当前账号尚未加入共享家庭。");
                    });
            var snapshot = buildSharedContextProjection(
                    membership.householdId(),
                    now,
                    "shared_context",
                    null,
                    session.accountId(),
                    null,
                    membership.role(),
                    0
            );
            repository.upsertSharedContext(snapshot);
            var response = repository.findSharedContextByAccount(session.accountId())
                    .orElseThrow(() -> new ContractException(
                            HttpStatus.SERVICE_UNAVAILABLE,
                            "shared_context_unavailable",
                            "共享上下文暂时不可用，请稍后重试。",
                            Map.of("retryable", true)
                    ));
            return new SharedContextResponse(
                    response.householdId(),
                    response.role(),
                    response.lastAcceptedAt(),
                    new SharedContextSnapshot(
                            response.babyProfileSummary(),
                            response.continuitySummary(),
                            response.gardenSummary(),
                            new PracticeRouteArgs(response.spaceId(), response.activityId()),
                            response.latestInteractionAt(),
                            response.updatedAt()
                    )
            );
        } catch (ContractException exception) {
            throw exception;
        } catch (DataAccessException exception) {
            recordEventSafely(eventRow(null, null, session.accountId(), "shared_context", null, null,
                    "shared_context_unavailable", "invite_storage_unavailable", now));
            throw inviteStorageUnavailable("shared_context", exception);
        }
    }

    private AuthConsentSyncRepository.SessionContextRow requireEligibleSession(String sessionId) {
        var normalizedSessionId = normalizeSessionId(sessionId);
        var session = authConsentSyncRepository.findSessionAnyStatus(normalizedSessionId)
                .orElseThrow(() -> new ContractException(HttpStatus.UNAUTHORIZED, "invalid_session", "session 不存在或已失效。"));
        if ("deleted".equals(session.accountStatus()) || "deleted".equals(session.sessionStatus())) {
            throw new ContractException(HttpStatus.GONE, "account_deleted", "账号已删除；请重新注册。");
        }
        if ("revoked".equals(session.sessionStatus()) || "revoked".equals(session.latestConsentStatus())) {
            throw new ContractException(
                    HttpStatus.CONFLICT,
                    "consent_revoked",
                    "同意已撤回，请重新登录并再次同意后再继续。",
                    Map.of("retryable", true)
            );
        }
        if (!"accepted".equals(session.latestConsentStatus())) {
            throw new ContractException(
                    HttpStatus.CONFLICT,
                    "consent_required",
                    "当前账号尚未完成同意，不能继续邀请流程。",
                    Map.of("retryable", true)
            );
        }
        if (!"active".equals(session.sessionStatus())) {
            throw new ContractException(HttpStatus.UNAUTHORIZED, "invalid_session", "session 不存在或已失效。");
        }
        return session;
    }

    private CaregiverInviteRepository.HouseholdMemberRow requirePrimaryInviteManager(
            AuthConsentSyncRepository.SessionContextRow session,
            Instant now,
            String entrypoint,
            String source,
            String requestedRole
    ) {
        var membership = repository.findActiveMembershipByAccount(session.accountId())
                .orElseGet(() -> createPrimaryHousehold(session.accountId(), now));
        if (!"primary_caregiver".equals(membership.role())) {
            recordEventSafely(eventRow(null, membership.householdId(), session.accountId(), entrypoint, source, requestedRole,
                    "role_not_allowed", "current_role_" + membership.role(), now));
            throw new ContractException(
                    HttpStatus.FORBIDDEN,
                    "role_not_allowed",
                    "只有 primary_caregiver 可以管理 invite。",
                    Map.of("role", membership.role())
            );
        }
        return membership;
    }

    private CaregiverInviteRepository.HouseholdMemberRow createPrimaryHousehold(String accountId, Instant now) {
        var householdId = "household_" + UUID.randomUUID();
        repository.insertHousehold(new CaregiverInviteRepository.HouseholdRow(
                householdId,
                accountId,
                "active",
                now,
                null
        ));
        return repository.insertMember(new CaregiverInviteRepository.HouseholdMemberRow(
                0,
                householdId,
                accountId,
                "primary_caregiver",
                "active",
                null,
                now,
                null
        ));
    }

    private void ensureInviteAcceptable(
            CaregiverInviteRepository.InviteRow invite,
            String actorAccountId,
            String source,
            Instant now
    ) {
        if (isExpired(invite, now)) {
            persistInviteExpired(invite.token());
            recordEventSafely(eventRow(invite.token(), invite.householdId(), actorAccountId, "accept", source, invite.targetRole(),
                    "expired", "token_expired", now));
            throw new ContractException(HttpStatus.GONE, "invite_expired", "invite 已过期，请让主照护者重新生成。", Map.of("retryable", true));
        }
        if ("accepted".equals(invite.status())) {
            recordEventSafely(eventRow(invite.token(), invite.householdId(), actorAccountId, "accept", source, invite.targetRole(),
                    "already_used", "token_already_used", now));
            throw new ContractException(HttpStatus.CONFLICT, "invite_already_used", "invite 已被使用。", Map.of("retryable", false));
        }
        if ("revoked".equals(invite.status())) {
            recordEventSafely(eventRow(invite.token(), invite.householdId(), actorAccountId, "accept", source, invite.targetRole(),
                    "revoked", "invite_revoked", now));
            throw new ContractException(HttpStatus.CONFLICT, "invite_revoked", "invite 已撤销。", Map.of("retryable", false));
        }
        if (!"pending".equals(invite.status())) {
            recordEventSafely(eventRow(invite.token(), invite.householdId(), actorAccountId, "accept", source, invite.targetRole(),
                    "invalid", "invite_status_invalid", now));
            throw new ContractException(HttpStatus.CONFLICT, "invite_invalid", "invite 当前状态不可接受。", Map.of("retryable", false));
        }
    }

    private CaregiverInviteRepository.SharedContextRow buildSharedContextProjection(
            String householdId,
            Instant now,
            String entrypoint,
            String token,
            String actorAccountId,
            String source,
            String requestedRole,
            int additionalActiveMembers
    ) {
        var latest = repository.findLatestHouseholdInteraction(householdId).orElse(null);
        if (latest == null) {
            recordEventSafely(eventRow(token, householdId, actorAccountId, entrypoint, source, requestedRole,
                    "shared_context_unavailable", "no_household_activity", now));
            throw new ContractException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "shared_context_unavailable",
                    "共享上下文尚未准备好，请主照护者先完成一次同步后再重试。",
                    Map.of("retryable", true)
            );
        }
        var spaceId = normalizeRouteArg(latest.spaceId(), "spaceId");
        var activityId = normalizeRouteArg(latest.activityId(), "activityId");
        var totalEvents = repository.countHouseholdInteractions(householdId);
        var memberCount = repository.countActiveMembers(householdId) + additionalActiveMembers;
        var topActivity = repository.findTopActivity(householdId).orElse(new CaregiverInviteRepository.ActivitySummaryRow(
                spaceId,
                activityId,
                totalEvents,
                latest.clientTimestamp()
        ));
        var latestTime = SUMMARY_TIME_FORMATTER.format(latest.clientTimestamp());
        return new CaregiverInviteRepository.SharedContextRow(
                householdId,
                truncate("共享宝宝档案：家庭已同步 %d 条互动，当前由 %d 位照护者共看护。".formatted(totalEvents, memberCount), 240),
                truncate("最近 continuity：%s/%s 在 %s 记录到 %s 反馈。".formatted(
                        spaceId,
                        activityId,
                        latestTime,
                        latest.reactionType()
                ), 240),
                truncate("花园上下文：%s/%s 已累计 %d 条互动。".formatted(
                        topActivity.spaceId(),
                        topActivity.activityId(),
                        topActivity.eventCount()
                ), 240),
                spaceId,
                activityId,
                latest.clientTimestamp(),
                now
        );
    }

    private ContractException notFoundInvite(String token, String actorAccountId, String source, Instant now) {
        recordEventSafely(eventRow(token, null, actorAccountId, "accept", source, null,
                "invalid", "token_not_found", now));
        return new ContractException(HttpStatus.NOT_FOUND, "invite_not_found", "invite 不存在。", Map.of("retryable", false));
    }

    private boolean isExpired(CaregiverInviteRepository.InviteRow invite, Instant now) {
        return "expired".equals(invite.status()) || invite.expiresAt().isBefore(now);
    }

    private void persistInviteExpired(String token) {
        try {
            auditTransactionTemplate.executeWithoutResult(status -> repository.markInviteExpired(token, "token_expired"));
        } catch (RuntimeException ignored) {
            // 忽略状态补写失败，避免覆盖原始合同错误。
        }
    }

    private ContractException inviteStorageUnavailable(String phase, DataAccessException exception) {
        return new ContractException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "invite_storage_unavailable",
                "邀请服务暂时不可用，请稍后重试。",
                Map.of(
                        "retryable", true,
                        "phase", phase,
                        "reason", simplifyDataAccessMessage(exception)
                )
        );
    }

    private SharedContextResponse toSharedContextResponse(
            String role,
            Instant lastAcceptedAt,
            CaregiverInviteRepository.SharedContextRow snapshot
    ) {
        return new SharedContextResponse(
                snapshot.householdId(),
                role,
                lastAcceptedAt,
                new SharedContextSnapshot(
                        snapshot.babyProfileSummary(),
                        snapshot.continuitySummary(),
                        snapshot.gardenSummary(),
                        new PracticeRouteArgs(snapshot.spaceId(), snapshot.activityId()),
                        snapshot.latestInteractionAt(),
                        snapshot.updatedAt()
                )
        );
    }

    private CaregiverInviteRepository.EventRow eventRow(
            String token,
            String householdId,
            String actorAccountId,
            String entrypoint,
            String source,
            String requestedRole,
            String result,
            String failureReason,
            Instant createdAt
    ) {
        return new CaregiverInviteRepository.EventRow(
                token,
                householdId,
                actorAccountId,
                entrypoint,
                source,
                requestedRole,
                null,
                result,
                sanitizeFailureReason(failureReason),
                createdAt
        );
    }

    private void recordEventSafely(CaregiverInviteRepository.EventRow row) {
        try {
            auditTransactionTemplate.executeWithoutResult(status -> repository.insertEvent(row));
        } catch (RuntimeException ignored) {
            // 审计不能反向影响主合同。
        }
    }

    private String normalizeRole(String role) {
        var normalized = requireTrimmed(role, "role").toLowerCase(Locale.ROOT);
        if (!properties.allowedRoles().contains(normalized)) {
            throw new ContractException(
                    HttpStatus.FORBIDDEN,
                    "role_not_allowed",
                    "请求的照护角色当前不可邀请。",
                    Map.of("role", normalized)
            );
        }
        return normalized;
    }

    private String normalizeSource(String source) {
        var normalized = requireTrimmed(source, "source").toLowerCase(Locale.ROOT);
        if (!properties.allowedSources().contains(normalized)) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_invite_source",
                    "source 非法。",
                    Map.of("source", normalized)
            );
        }
        return normalized;
    }

    private String normalizeSessionId(String sessionId) {
        var normalized = requireTrimmed(sessionId, "sessionId");
        if (normalized.length() > 128) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_session_id", "sessionId 过长。", Map.of());
        }
        return normalized;
    }

    private String normalizeToken(String token) {
        var normalized = requireTrimmed(token, "token");
        if (!normalized.matches("[A-Za-z0-9_-]{12,64}")) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_invite_token",
                    "invite token 格式非法。",
                    Map.of("retryable", false)
            );
        }
        return normalized;
    }

    private String normalizeRouteArg(String value, String fieldName) {
        var normalized = requireTrimmed(value, fieldName);
        if (normalized.length() > 64) {
            recordEventSafely(eventRow(null, null, null, "shared_context", null, null,
                    "shared_context_unavailable", fieldName + "_too_long", Instant.now(clock)));
            throw new ContractException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "shared_context_unavailable",
                    "共享上下文缺少安全路由参数，已拒绝输出 deep link。",
                    Map.of("retryable", true, "field", fieldName)
            );
        }
        return normalized;
    }

    private String buildInviteUrl(String token) {
        var baseUrl = properties.publicBaseUrl().endsWith("/")
                ? properties.publicBaseUrl().substring(0, properties.publicBaseUrl().length() - 1)
                : properties.publicBaseUrl();
        return baseUrl + "/invite/" + token;
    }

    private String generateToken() {
        return "invite_" + UUID.randomUUID().toString().replace("-", "").substring(0, 24);
    }

    private String requireTrimmed(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "missing_" + fieldName, fieldName + " 不能为空。", Map.of());
        }
        return value.trim();
    }

    private String sanitizeFailureReason(String failureReason) {
        if (failureReason == null || failureReason.isBlank()) {
            return null;
        }
        return truncate(failureReason.trim(), 128);
    }

    private String simplifyDataAccessMessage(DataAccessException exception) {
        var message = exception.getMostSpecificCause() == null
                ? exception.getMessage()
                : exception.getMostSpecificCause().getMessage();
        if (message == null || message.isBlank()) {
            return "database_write_failed";
        }
        return truncate(message, 180);
    }

    private String truncate(String value, int maxLength) {
        if (value == null || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }

    public record CreateInviteCommand(String role, String source) {
    }

    public record AcceptInviteCommand(String token, String source) {
    }

    public record CreateInviteResponse(
            String householdId,
            String token,
            String inviteUrl,
            String role,
            String source,
            Instant expiresAt
    ) {
    }

    public record AcceptInviteResponse(
            String householdId,
            String role,
            Instant acceptedAt,
            SharedContextResponse sharedContext
    ) {
    }

    public record RevokeInviteResponse(
            boolean applied,
            String result,
            String token,
            Instant updatedAt
    ) {
    }

    public record SharedContextResponse(
            String householdId,
            String role,
            Instant lastAcceptedAt,
            SharedContextSnapshot snapshot
    ) {
    }

    public record SharedContextSnapshot(
            String babyProfileSummary,
            String continuitySummary,
            String gardenSummary,
            PracticeRouteArgs practice,
            Instant latestInteractionAt,
            Instant updatedAt
    ) {
    }

    public record PracticeRouteArgs(String spaceId, String activityId) {
    }
}
