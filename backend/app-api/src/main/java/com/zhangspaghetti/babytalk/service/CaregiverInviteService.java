package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.CaregiverInviteProperties;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.net.URI;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.util.HtmlUtils;
import org.springframework.web.util.UriComponentsBuilder;

@Service
public class CaregiverInviteService {

    public static final String RESULT_HEADER = "X-Invite-Result";
    public static final String AUDIT_HEADER = "X-Invite-Audit";
    public static final String FAILURE_REASON_HEADER = "X-Invite-Failure-Reason";

    private static final DateTimeFormatter EXPIRY_TIME_FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm 'UTC'").withZone(ZoneOffset.UTC);
    private static final Pattern PUBLIC_TOKEN_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{12,64}$");
    private static final Set<String> ALLOWED_PLATFORMS = Set.of("android", "ios");
    private static final MediaPalette PALETTE = new MediaPalette(
            "#FFF8F0",
            "#FFFFFF",
            "#F5F0EB",
            "#FFF0E5",
            "#FF8C42",
            "#E67A30",
            "#2D2926",
            "#6B5E57",
            "#D94B3C",
            "#3B8577"
    );

    private final CaregiverInviteRepository repository;
    private final AuthConsentSyncRepository authConsentSyncRepository;
    private final HouseholdSharedContextProjector householdSharedContextProjector;
    private final CaregiverInviteProperties properties;
    private final SensitiveAuthDataProtector sensitiveAuthDataProtector;
    private final Clock clock = Clock.systemUTC();
    private final TransactionTemplate auditTransactionTemplate;

    public CaregiverInviteService(
            CaregiverInviteRepository repository,
            AuthConsentSyncRepository authConsentSyncRepository,
            HouseholdSharedContextProjector householdSharedContextProjector,
            CaregiverInviteProperties properties,
            SensitiveAuthDataProtector sensitiveAuthDataProtector,
            org.springframework.transaction.PlatformTransactionManager transactionManager
    ) {
        this.repository = repository;
        this.authConsentSyncRepository = authConsentSyncRepository;
        this.householdSharedContextProjector = householdSharedContextProjector;
        this.properties = properties;
        this.sensitiveAuthDataProtector = sensitiveAuthDataProtector;
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
            var tokenLookupRef = inviteTokenLookupRef(token);
            var expiresAt = now.plus(properties.defaultLinkTtl());
            repository.insertInvite(new CaregiverInviteRepository.InviteRow(
                    0,
                    tokenLookupRef,
                    membership.householdId(),
                    session.accountId(),
                    requestedRole,
                    source,
                    "pending",
                    dbTime(now),
                    dbTime(expiresAt),
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
        var tokenLookupRef = inviteTokenLookupRef(token);
        var source = normalizeSource(command.source());
        var now = Instant.now(clock);
        try {
            var invite = repository.findInviteByTokenLookupRef(tokenLookupRef)
                    .orElseThrow(() -> notFoundInvite(token, session.accountId(), source, now));
            ensureInviteAcceptable(invite, token, session.accountId(), source, now);

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

            repository.insertMember(new CaregiverInviteRepository.HouseholdMemberRow(
                    0,
                    invite.householdId(),
                    session.accountId(),
                    invite.targetRole(),
                    "active",
                    invite.inviterAccountId(),
                    dbTime(now),
                    dbTime(now)
            ));
            refreshSharedContextProjectionOrThrow(
                    invite.householdId(),
                    now,
                    "accept",
                    token,
                    session.accountId(),
                    source,
                    invite.targetRole()
            );
            repository.markInviteAccepted(tokenLookupRef, session.accountId(), dbTime(now));
            repository.insertEvent(eventRow(token, invite.householdId(), session.accountId(), "accept", source, invite.targetRole(),
                    "accept", null, now));
            var sharedContext = requireSharedContextResponse(session.accountId());
            return new AcceptInviteResponse(
                    invite.householdId(),
                    invite.targetRole(),
                    now,
                    sharedContext
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
        var tokenLookupRef = inviteTokenLookupRef(token);
        var now = Instant.now(clock);
        try {
            var invite = repository.findInviteByTokenLookupRef(tokenLookupRef)
                    .orElseThrow(() -> notFoundInvite(token, session.accountId(), null, now));
            var membership = requirePrimaryInviteManager(session, now, "revoke", invite.source(), invite.targetRole());
            if (!membership.householdId().equals(invite.householdId())) {
                recordEventSafely(eventRow(token, invite.householdId(), session.accountId(), "revoke", invite.source(), invite.targetRole(),
                        "role_not_allowed", "cross_household_revoke", now));
                throw new ContractException(HttpStatus.FORBIDDEN, "role_not_allowed", "当前账号不能管理其他 household 的 invite。");
            }
            if (isExpired(invite, now)) {
                persistInviteExpired(tokenLookupRef);
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
            repository.markInviteRevoked(tokenLookupRef, dbTime(now), "invite_revoked");
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
            refreshSharedContextProjectionOrThrow(
                    membership.householdId(),
                    now,
                    "shared_context",
                    null,
                    session.accountId(),
                    null,
                    membership.role()
            );
            return requireSharedContextResponse(session.accountId());
        } catch (ContractException exception) {
            throw exception;
        } catch (DataAccessException exception) {
            recordEventSafely(eventRow(null, null, session.accountId(), "shared_context", null, null,
                    "shared_context_unavailable", "invite_storage_unavailable", now));
            throw inviteStorageUnavailable("shared_context", exception);
        }
    }

    public PageResponse renderLanding(String rawToken, String userAgent) {
        var preferredPlatform = detectPlatform(userAgent);
        var resolution = resolveInvite(rawToken, "landing", preferredPlatform);
        if (resolution.mode() != InviteResolutionMode.ACTIVE) {
            return resolution.toPageResponse(renderLandingHtml(resolution, preferredPlatform, Map.of(), resolution.failureReason()));
        }

        var openAppTargets = availableOpenAppTargets();
        var result = openAppTargets.isEmpty() ? "unavailable" : "page_view";
        var failureReason = openAppTargets.isEmpty() ? "open_app_unconfigured" : null;
        var auditStatus = recordPublicAudit(resolution.snapshot(), "landing", preferredPlatform, result, failureReason);
        return new PageResponse(
                result.equals("page_view") ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE,
                result,
                failureReason,
                auditStatus,
                renderLandingHtml(resolution, preferredPlatform, openAppTargets, failureReason)
        );
    }

    public RedirectResponse resolveOpenApp(String rawToken, String rawPlatform, String userAgent) {
        var requestedPlatform = normalizePlatform(rawPlatform);
        if (requestedPlatform == null && trimToNull(rawPlatform) != null) {
            return invalidPublicRoute(rawToken, "open_app", null, "unknown_platform", "当前平台参数无效，无法继续打开 app。", directDownloadFallback(null));
        }

        var preferredPlatform = requestedPlatform != null ? requestedPlatform : detectPlatform(userAgent);
        var resolution = resolveInvite(rawToken, "open_app", preferredPlatform);
        if (resolution.mode() != InviteResolutionMode.ACTIVE) {
            return resolution.toRedirectError(renderRedirectErrorHtml(
                    resolution,
                    preferredPlatform,
                    "无法继续打开 app，请先返回邀请页确认链接状态。",
                    resolution.snapshot() == null ? directDownloadFallback(preferredPlatform) : invitePagePath(resolution.token())
            ));
        }

        var platform = requestedPlatform != null ? requestedPlatform : preferredPlatform;
        if (platform == null) {
            var auditStatus = recordPublicAudit(resolution.snapshot(), "open_app", null, "unavailable", "platform_unresolved");
            return RedirectResponse.error(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "unavailable",
                    "platform_unresolved",
                    auditStatus,
                    renderRedirectErrorHtml(
                            resolution,
                            null,
                            "暂时无法判断设备平台，请返回邀请页或直接进入下载页。",
                            downloadRoutePath(resolution.token(), null)
                    )
            );
        }

        var target = availableOpenAppTargets().get(platform);
        if (target == null || target.isBlank()) {
            var auditStatus = recordPublicAudit(resolution.snapshot(), "open_app", platform, "unavailable", "platform_target_missing");
            return RedirectResponse.error(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "unavailable",
                    "platform_target_missing",
                    auditStatus,
                    renderRedirectErrorHtml(
                            resolution,
                            platform,
                            "当前平台暂未配置安全的打开 app 入口，请先进入下载页。",
                            downloadRoutePath(resolution.token(), platform)
                    )
            );
        }

        var location = UriComponentsBuilder.fromUriString(target)
                .queryParam("token", resolution.token())
                .queryParam("source", resolution.snapshot().source())
                .queryParam("role", resolution.snapshot().targetRole())
                .build(true)
                .toUri();
        var auditStatus = recordPublicAudit(resolution.snapshot(), "open_app", platform, "open_app_redirect", null);
        return RedirectResponse.redirect("open_app_redirect", null, auditStatus, location);
    }

    public RedirectResponse resolveDownloadFallback(String rawToken, String rawPlatform, String userAgent) {
        var requestedPlatform = normalizePlatform(rawPlatform);
        if (requestedPlatform == null && trimToNull(rawPlatform) != null) {
            return invalidPublicRoute(rawToken, "download", null, "unknown_platform", "当前平台参数无效，无法继续前往下载页。", directDownloadFallback(null));
        }

        var preferredPlatform = requestedPlatform != null ? requestedPlatform : detectPlatform(userAgent);
        var resolution = resolveInvite(rawToken, "download", preferredPlatform);
        if (resolution.mode() != InviteResolutionMode.ACTIVE) {
            return resolution.toRedirectError(renderRedirectErrorHtml(
                    resolution,
                    preferredPlatform,
                    "当前邀请链接不可继续回流，请返回下载页获取最新 app。",
                    directDownloadFallback(preferredPlatform)
            ));
        }

        if (!hasSafeDownloadFallback()) {
            var auditStatus = recordPublicAudit(resolution.snapshot(), "download", preferredPlatform, "unavailable", "download_fallback_unconfigured");
            return RedirectResponse.error(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "unavailable",
                    "download_fallback_unconfigured",
                    auditStatus,
                    renderRedirectErrorHtml(
                            resolution,
                            preferredPlatform,
                            "下载回流入口暂不可用，请稍后再试。",
                            invitePagePath(resolution.token())
                    )
            );
        }

        var auditStatus = recordPublicAudit(resolution.snapshot(), "download", preferredPlatform, "download_fallback", null);
        return RedirectResponse.redirect(
                "download_fallback",
                null,
                auditStatus,
                URI.create(directDownloadFallback(preferredPlatform))
        );
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
        var membership = repository.ensurePrimaryHousehold(session.accountId(), dbTime(now));
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

    private void ensureInviteAcceptable(
            CaregiverInviteRepository.InviteRow invite,
            String rawToken,
            String actorAccountId,
            String source,
            Instant now
    ) {
        if (isExpired(invite, now)) {
            persistInviteExpired(invite.tokenLookupRef());
            recordEventSafely(eventRow(rawToken, invite.householdId(), actorAccountId, "accept", source, invite.targetRole(),
                    "expired", "token_expired", now));
            throw new ContractException(HttpStatus.GONE, "invite_expired", "invite 已过期，请让主照护者重新生成。", Map.of("retryable", true));
        }
        if ("accepted".equals(invite.status())) {
            recordEventSafely(eventRow(rawToken, invite.householdId(), actorAccountId, "accept", source, invite.targetRole(),
                    "already_used", "token_already_used", now));
            throw new ContractException(HttpStatus.CONFLICT, "invite_already_used", "invite 已被使用。", Map.of("retryable", false));
        }
        if ("revoked".equals(invite.status())) {
            recordEventSafely(eventRow(rawToken, invite.householdId(), actorAccountId, "accept", source, invite.targetRole(),
                    "revoked", "invite_revoked", now));
            throw new ContractException(HttpStatus.CONFLICT, "invite_revoked", "invite 已撤销。", Map.of("retryable", false));
        }
        if (!"pending".equals(invite.status())) {
            recordEventSafely(eventRow(rawToken, invite.householdId(), actorAccountId, "accept", source, invite.targetRole(),
                    "invalid", "invite_status_invalid", now));
            throw new ContractException(HttpStatus.CONFLICT, "invite_invalid", "invite 当前状态不可接受。", Map.of("retryable", false));
        }
    }

    private CaregiverInviteRepository.SharedContextRow refreshSharedContextProjectionOrThrow(
            String householdId,
            Instant now,
            String entrypoint,
            String token,
            String actorAccountId,
            String source,
            String requestedRole
    ) {
        try {
            return householdSharedContextProjector.refreshForHousehold(householdId, now);
        } catch (ContractException exception) {
            if ("shared_context_unavailable".equals(exception.code())) {
                recordEventSafely(eventRow(
                        token,
                        householdId,
                        actorAccountId,
                        entrypoint,
                        source,
                        requestedRole,
                        "shared_context_unavailable",
                        sharedContextFailureReason(exception),
                        now
                ));
            }
            throw exception;
        }
    }

    private ContractException notFoundInvite(String token, String actorAccountId, String source, Instant now) {
        recordEventSafely(eventRow(token, null, actorAccountId, "accept", source, null,
                "invalid", "token_not_found", now));
        return new ContractException(HttpStatus.NOT_FOUND, "invite_not_found", "invite 不存在。", Map.of("retryable", false));
    }

    private boolean isExpired(CaregiverInviteRepository.InviteRow invite, Instant now) {
        return "expired".equals(invite.status()) || invite.expiresAt().isBefore(dbTime(now));
    }

    private void persistInviteExpired(String tokenLookupRef) {
        try {
            auditTransactionTemplate.executeWithoutResult(status -> repository.markInviteExpired(tokenLookupRef, "token_expired"));
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

    private SharedContextResponse requireSharedContextResponse(String accountId) {
        var response = repository.findSharedContextByAccount(accountId)
                .orElseThrow(() -> new ContractException(
                        HttpStatus.SERVICE_UNAVAILABLE,
                        "shared_context_unavailable",
                        "共享上下文暂时不可用，请稍后重试。",
                        Map.of("retryable", true)
                ));
        return toSharedContextResponse(response);
    }

    private SharedContextResponse toSharedContextResponse(CaregiverInviteRepository.SharedContextViewRow response) {
        return new SharedContextResponse(
                response.householdId(),
                response.role(),
                apiTime(response.lastAcceptedAt()),
                new SharedContextSnapshot(
                        response.babyProfileSummary(),
                        response.continuitySummary(),
                        response.gardenSummary(),
                        new PracticeRouteArgs(response.spaceId(), response.activityId()),
                        apiTime(response.latestInteractionAt()),
                        apiTime(response.updatedAt()),
                        toLatestActor(response.latestActorRole(), response.latestActorSource(), response.latestActorResult()),
                        toNextStep(response.nextStepSpaceId(), response.nextStepActivityId(), response.nextStepReason())
                )
        );
    }

    private LatestActor toLatestActor(String role, String source, String result) {
        if (role == null && source == null && result == null) {
            return null;
        }
        return new LatestActor(role, source, result);
    }

    private NextStep toNextStep(String spaceId, String activityId, String reason) {
        if (spaceId == null || activityId == null) {
            return null;
        }
        return new NextStep(spaceId, activityId, reason);
    }

    private String sharedContextFailureReason(ContractException exception) {
        var reason = exception.details().get("reason");
        if (reason instanceof String value && !value.isBlank()) {
            return value;
        }
        var field = exception.details().get("field");
        if (field instanceof String value && !value.isBlank()) {
            return value + "_invalid";
        }
        return "projection_refresh_failed";
    }

    private PublicInviteResolution resolveInvite(String rawToken, String entrypoint, String platform) {
        var token = trimToNull(rawToken);
        if (token == null) {
            var auditStatus = recordPublicAudit(null, safeToken(rawToken), entrypoint, null, null, null, platform, "invalid", "token_blank");
            return PublicInviteResolution.invalid(safeToken(rawToken), "token_blank", auditStatus, HttpStatus.BAD_REQUEST);
        }
        if (!PUBLIC_TOKEN_PATTERN.matcher(token).matches()) {
            var auditStatus = recordPublicAudit(null, safeToken(token), entrypoint, null, null, null, platform, "invalid", "token_malformed");
            return PublicInviteResolution.invalid(safeToken(token), "token_malformed", auditStatus, HttpStatus.BAD_REQUEST);
        }

        var tokenLookupRef = inviteTokenLookupRef(token);
        final CaregiverInviteRepository.InviteRow snapshot;
        try {
            snapshot = repository.findInviteByTokenLookupRef(tokenLookupRef).orElse(null);
        } catch (DataAccessException exception) {
            return PublicInviteResolution.unavailable(token, "storage_unavailable", AuditStatus.FAILED, HttpStatus.SERVICE_UNAVAILABLE);
        }
        if (snapshot == null) {
            var auditStatus = recordPublicAudit(null, token, entrypoint, null, null, null, platform, "invalid", "token_not_found");
            return PublicInviteResolution.invalid(token, "token_not_found", auditStatus, HttpStatus.NOT_FOUND);
        }
        if (isExpired(snapshot, Instant.now(clock))) {
            persistInviteExpired(snapshot.tokenLookupRef());
            var auditStatus = recordPublicAudit(snapshot, entrypoint, platform, "expired", "token_expired");
            return PublicInviteResolution.expired(snapshot, token, "token_expired", auditStatus, HttpStatus.GONE);
        }
        if ("accepted".equals(snapshot.status())) {
            var auditStatus = recordPublicAudit(snapshot, entrypoint, platform, "already_used", "token_already_used");
            return PublicInviteResolution.alreadyUsed(snapshot, token, "token_already_used", auditStatus, HttpStatus.CONFLICT);
        }
        if ("revoked".equals(snapshot.status())) {
            var auditStatus = recordPublicAudit(snapshot, entrypoint, platform, "revoked", "invite_revoked");
            return PublicInviteResolution.revoked(snapshot, token, "invite_revoked", auditStatus, HttpStatus.CONFLICT);
        }
        if (!"pending".equals(snapshot.status())) {
            var auditStatus = recordPublicAudit(snapshot, entrypoint, platform, "invalid", "invite_status_invalid");
            return PublicInviteResolution.invalid(token, "invite_status_invalid", auditStatus, HttpStatus.CONFLICT);
        }
        return PublicInviteResolution.active(snapshot, token);
    }

    private AuditStatus recordPublicAudit(
            CaregiverInviteRepository.InviteRow snapshot,
            String entrypoint,
            String platform,
            String result,
            String failureReason
    ) {
        return recordPublicAuditByLookupRef(
                snapshot,
                snapshot == null ? null : snapshot.tokenLookupRef(),
                entrypoint,
                snapshot == null ? null : snapshot.householdId(),
                snapshot == null ? null : snapshot.source(),
                snapshot == null ? null : snapshot.targetRole(),
                platform,
                result,
                failureReason
        );
    }

    private AuditStatus recordPublicAudit(
            CaregiverInviteRepository.InviteRow snapshot,
            String token,
            String entrypoint,
            String householdId,
            String source,
            String requestedRole,
            String platform,
            String result,
            String failureReason
    ) {
        return recordPublicAuditByLookupRef(
                snapshot,
                inviteTokenLookupRefForAudit(token),
                entrypoint,
                householdId,
                source,
                requestedRole,
                platform,
                result,
                failureReason
        );
    }

    private AuditStatus recordPublicAuditByLookupRef(
            CaregiverInviteRepository.InviteRow snapshot,
            String tokenLookupRef,
            String entrypoint,
            String householdId,
            String source,
            String requestedRole,
            String platform,
            String result,
            String failureReason
    ) {
        return recordAudit(new CaregiverInviteRepository.EventRow(
                tokenLookupRef,
                householdId,
                null,
                entrypoint,
                source,
                requestedRole,
                sanitizePlatform(platform),
                result,
                sanitizeFailureReason(failureReason),
                dbTime(Instant.now(clock))
        ));
    }

    private RedirectResponse invalidPublicRoute(
            String rawToken,
            String entrypoint,
            String platform,
            String failureReason,
            String message,
            String fallbackHref
    ) {
        var auditStatus = recordPublicAudit(null, rawToken, entrypoint, null, null, null, platform, "invalid", failureReason);
        var resolution = PublicInviteResolution.invalid(safeToken(rawToken), failureReason, auditStatus, HttpStatus.BAD_REQUEST);
        return RedirectResponse.error(
                HttpStatus.BAD_REQUEST,
                "invalid",
                failureReason,
                auditStatus,
                renderRedirectErrorHtml(resolution, platform, message, fallbackHref)
        );
    }

    private AuditStatus recordAudit(CaregiverInviteRepository.EventRow row) {
        try {
            auditTransactionTemplate.executeWithoutResult(status -> repository.insertEvent(row));
            return AuditStatus.RECORDED;
        } catch (RuntimeException ignored) {
            return AuditStatus.FAILED;
        }
    }

    private String renderLandingHtml(
            PublicInviteResolution resolution,
            String preferredPlatform,
            Map<String, String> openAppTargets,
            String failureReason
    ) {
        var snapshot = resolution.snapshot();
        var title = switch (resolution.mode()) {
            case ACTIVE -> "加入 Baby Talk 协作照护";
            case INVALID -> "邀请链接不可用";
            case EXPIRED -> "这份照护邀请已过期";
            case ALREADY_USED -> "这份照护邀请已被使用";
            case REVOKED -> "这份照护邀请已撤销";
            case UNAVAILABLE -> "邀请暂时不可用";
        };
        var summary = switch (resolution.mode()) {
            case ACTIVE -> "主照护者邀请你以 %s 身份加入共享宝宝档案、最近 continuity 与花园上下文。".formatted(roleLabel(snapshot.targetRole()));
            case INVALID -> "这个邀请链接无效，可能已经被改写、复制不完整，或已经不是当前可接受的 invite。";
            case EXPIRED -> "这份邀请已经超过有效期，请让主照护者重新生成新的 invite link。";
            case ALREADY_USED -> "这份邀请已经完成接受。为了保护邀请链路，不会再次复用旧 token。";
            case REVOKED -> "这份邀请已被主照护者撤销，请让对方重新发起新的邀请。";
            case UNAVAILABLE -> "邀请页暂时不可访问，请稍后重试，或先进入下载页安装最新版本。";
        };
        var pageResult = switch (resolution.mode()) {
            case ACTIVE -> failureReason == null ? "page_view" : "unavailable";
            case INVALID -> "invalid";
            case EXPIRED -> "expired";
            case ALREADY_USED -> "already_used";
            case REVOKED -> "revoked";
            case UNAVAILABLE -> "unavailable";
        };
        var pageFailureReason = resolution.mode() == InviteResolutionMode.ACTIVE ? failureReason : resolution.failureReason();
        var tokenForUrl = resolution.token();
        var chips = buildChipMarkup(snapshot);
        var platformButtons = new StringBuilder();
        if (resolution.mode() == InviteResolutionMode.ACTIVE) {
            for (var entry : orderTargets(openAppTargets).entrySet()) {
                var platform = entry.getKey();
                var href = openAppRoutePath(resolution.token(), platform);
                platformButtons.append("""
                        <a class=\"cta-link\" href=\"%s\">打开 app · %s%s</a>
                        """.formatted(
                        HtmlUtils.htmlEscape(href),
                        HtmlUtils.htmlEscape(platformLabel(platform)),
                        platform.equals(preferredPlatform) ? " · 推荐" : ""
                ));
            }
        }
        var fallbackHref = resolution.mode() == InviteResolutionMode.ACTIVE
                ? downloadRoutePath(resolution.token(), preferredPlatform)
                : directDownloadFallback(preferredPlatform);
        return """
                <!doctype html>
                <html lang=\"zh-CN\">
                <head>
                  <meta charset=\"utf-8\" />
                  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
                  <link rel=\"icon\" href=\"data:,\" />
                  <meta name=\"invite-result\" content=\"%s\" />
                  <meta name=\"invite-failure-reason\" content=\"%s\" />
                  <meta property=\"og:locale\" content=\"zh_CN\" />
                  <meta property=\"og:type\" content=\"website\" />
                  <meta property=\"og:site_name\" content=\"Baby Talk\" />
                  <meta property=\"og:url\" content=\"%s\" />
                  <meta property=\"og:title\" content=\"%s\" />
                  <meta property=\"og:description\" content=\"%s\" />
                  <title>%s · Baby Talk</title>
                  <style>
                    :root {
                      color-scheme: light;
                      --bg-base: %s;
                      --bg-surface: %s;
                      --bg-sunken: %s;
                      --bg-accent-soft: %s;
                      --accent: %s;
                      --accent-dark: %s;
                      --text-primary: %s;
                      --text-secondary: %s;
                      --error: %s;
                      --ok: %s;
                    }
                    * { box-sizing: border-box; }
                    body {
                      margin: 0;
                      min-height: 100vh;
                      background: linear-gradient(180deg, var(--bg-base) 0%%, var(--bg-sunken) 100%%);
                      color: var(--text-primary);
                      font-family: \"PingFang SC\", \"Noto Sans SC\", \"Microsoft YaHei\", sans-serif;
                    }
                    main {
                      max-width: 430px;
                      margin: 0 auto;
                      padding: 24px 16px 48px;
                    }
                    .card {
                      background: var(--bg-surface);
                      border-radius: 24px;
                      padding: 24px 20px;
                      box-shadow: 0 8px 24px rgba(45,41,38,0.12);
                    }
                    .eyebrow {
                      display: inline-flex;
                      align-items: center;
                      gap: 8px;
                      padding: 6px 12px;
                      border-radius: 9999px;
                      background: var(--bg-accent-soft);
                      color: var(--accent-dark);
                      font-size: 11px;
                      font-weight: 700;
                      letter-spacing: 0.06em;
                      text-transform: uppercase;
                    }
                    h1 {
                      margin: 16px 0 12px;
                      font-size: 28px;
                      line-height: 1.3;
                    }
                    .summary {
                      margin: 0;
                      color: var(--text-secondary);
                      font-size: 15px;
                      line-height: 1.7;
                    }
                    .chips {
                      margin-top: 18px;
                      display: flex;
                      flex-wrap: wrap;
                      gap: 8px;
                    }
                    .chip {
                      border-radius: 9999px;
                      background: var(--bg-accent-soft);
                      color: var(--accent-dark);
                      padding: 6px 10px;
                      font-size: 12px;
                    }
                    .status {
                      margin-top: 18px;
                      padding: 14px 16px;
                      border-radius: 16px;
                      background: rgba(59,133,119,0.10);
                      color: var(--ok);
                      line-height: 1.6;
                      font-size: 14px;
                    }
                    .status.warning {
                      background: rgba(255,140,66,0.10);
                      color: var(--accent-dark);
                    }
                    .status.error {
                      background: rgba(217,75,60,0.10);
                      color: var(--error);
                    }
                    .meta {
                      margin-top: 18px;
                      color: var(--text-secondary);
                      font-size: 13px;
                      line-height: 1.6;
                    }
                    .actions {
                      margin-top: 20px;
                      display: grid;
                      gap: 12px;
                    }
                    .cta-link {
                      display: block;
                      width: 100%%;
                      border: 0;
                      border-radius: 16px;
                      padding: 14px 16px;
                      background: var(--accent);
                      color: white;
                      font-weight: 700;
                      text-align: center;
                      text-decoration: none;
                    }
                    .cta-link.secondary {
                      background: var(--bg-accent-soft);
                      color: var(--accent-dark);
                    }
                    .footnote {
                      margin-top: 18px;
                      color: var(--text-secondary);
                      font-size: 13px;
                      line-height: 1.6;
                    }
                  </style>
                </head>
                <body>
                  <main data-result=\"%s\" data-failure-reason=\"%s\">
                    <section class=\"card\">
                      <span class=\"eyebrow\">Baby Talk · caregiver invite</span>
                      <h1>%s</h1>
                      <p class=\"summary\">%s</p>
                      %s
                      <p class=\"meta\">%s</p>
                      <div class=\"status %s\">%s</div>
                      <div class=\"actions\">
                        %s
                        <a class=\"cta-link secondary\" href=\"%s\">去下载页继续</a>
                      </div>
                      <p class=\"footnote\">公开 invite 页只暴露 token / result / source / role / route-arg 级信息，不展示宝宝昵称、installationId、sessionId 或原始互动内容。</p>
                    </section>
                  </main>
                </body>
                </html>
                """.formatted(
                HtmlUtils.htmlEscape(pageResult),
                HtmlUtils.htmlEscape(nullToEmpty(pageFailureReason)),
                HtmlUtils.htmlEscape(publicInviteUrl(tokenForUrl)),
                HtmlUtils.htmlEscape(title),
                HtmlUtils.htmlEscape(summary),
                HtmlUtils.htmlEscape(title),
                PALETTE.bgBase(),
                PALETTE.bgSurface(),
                PALETTE.bgSunken(),
                PALETTE.bgAccentSoft(),
                PALETTE.accent(),
                PALETTE.accentDark(),
                PALETTE.textPrimary(),
                PALETTE.textSecondary(),
                PALETTE.error(),
                PALETTE.positive(),
                HtmlUtils.htmlEscape(pageResult),
                HtmlUtils.htmlEscape(nullToEmpty(pageFailureReason)),
                HtmlUtils.htmlEscape(title),
                HtmlUtils.htmlEscape(summary),
                chips,
                HtmlUtils.htmlEscape(metaLine(snapshot)),
                statusClass(resolution, failureReason),
                HtmlUtils.htmlEscape(statusMessage(resolution, preferredPlatform, failureReason)),
                platformButtons,
                HtmlUtils.htmlEscape(fallbackHref)
        );
    }

    private String renderRedirectErrorHtml(PublicInviteResolution resolution, String platform, String message, String fallbackHref) {
        var token = resolution.token();
        return """
                <!doctype html>
                <html lang=\"zh-CN\">
                <head>
                  <meta charset=\"utf-8\" />
                  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
                  <link rel=\"icon\" href=\"data:,\" />
                  <meta name=\"invite-result\" content=\"%s\" />
                  <meta name=\"invite-failure-reason\" content=\"%s\" />
                  <title>无法继续跳转 · Baby Talk</title>
                </head>
                <body style=\"margin:0;background:%s;color:%s;font-family:PingFang SC,Microsoft YaHei,sans-serif;\">
                  <main style=\"max-width:430px;margin:0 auto;padding:24px 16px 48px;\">
                    <section style=\"background:%s;border-radius:24px;padding:24px 20px;box-shadow:0 8px 24px rgba(45,41,38,0.12);\">
                      <h1 style=\"margin:0 0 12px;font-size:24px;line-height:1.3;\">无法继续跳转</h1>
                      <p style=\"margin:0;color:%s;line-height:1.7;\">%s</p>
                      <p style=\"margin-top:18px;display:grid;gap:12px;\">
                        <a href=\"%s\" style=\"display:block;text-align:center;padding:14px 16px;border-radius:16px;background:%s;color:white;text-decoration:none;font-weight:700;\">去下载页继续</a>
                        <a href=\"%s\" style=\"display:block;text-align:center;padding:14px 16px;border-radius:16px;background:%s;color:%s;text-decoration:none;font-weight:700;\">返回邀请页</a>
                      </p>
                      <p style=\"margin-top:18px;color:%s;font-size:13px;\">platform：%s · token：%s</p>
                    </section>
                  </main>
                </body>
                </html>
                """.formatted(
                HtmlUtils.htmlEscape(resultForResolution(resolution)),
                HtmlUtils.htmlEscape(nullToEmpty(resolution.failureReason())),
                PALETTE.bgBase(),
                PALETTE.textPrimary(),
                PALETTE.bgSurface(),
                PALETTE.textSecondary(),
                HtmlUtils.htmlEscape(message),
                HtmlUtils.htmlEscape(fallbackHref),
                PALETTE.accent(),
                HtmlUtils.htmlEscape(invitePagePath(token)),
                PALETTE.bgAccentSoft(),
                PALETTE.accentDark(),
                PALETTE.textSecondary(),
                HtmlUtils.htmlEscape(platform == null ? "unknown" : platformLabel(platform)),
                HtmlUtils.htmlEscape(truncate(token, 32))
        );
    }

    private String buildChipMarkup(CaregiverInviteRepository.InviteRow snapshot) {
        if (snapshot == null) {
            return "";
        }
        var chips = new ArrayList<String>();
        chips.add("邀请角色 · " + roleLabel(snapshot.targetRole()));
        chips.add("来源 · " + sourceLabel(snapshot.source()));
        chips.add("有效期 · " + EXPIRY_TIME_FORMATTER.format(snapshot.expiresAt()));
        var markup = new StringBuilder("<div class=\"chips\">");
        for (var chip : chips) {
            markup.append("<span class=\"chip\">%s</span>".formatted(HtmlUtils.htmlEscape(chip)));
        }
        markup.append("</div>");
        return markup.toString();
    }

    private String metaLine(CaregiverInviteRepository.InviteRow snapshot) {
        if (snapshot == null) {
            return "invite page 只保留 coarse-grained 状态与回流入口。";
        }
        return "邀请来源：%s；角色：%s；接受后将以 account-level household/member 关系共享宝宝档案摘要。".formatted(
                sourceLabel(snapshot.source()),
                roleLabel(snapshot.targetRole())
        );
    }

    private String statusClass(PublicInviteResolution resolution, String failureReason) {
        if (resolution.mode() == InviteResolutionMode.INVALID
                || resolution.mode() == InviteResolutionMode.EXPIRED
                || resolution.mode() == InviteResolutionMode.ALREADY_USED
                || resolution.mode() == InviteResolutionMode.REVOKED) {
            return "error";
        }
        if (failureReason != null || resolution.mode() == InviteResolutionMode.UNAVAILABLE) {
            return "warning";
        }
        return "";
    }

    private String statusMessage(PublicInviteResolution resolution, String preferredPlatform, String failureReason) {
        return switch (resolution.mode()) {
            case INVALID -> "这个邀请链接无效，请让主照护者重新发送新的 invite。";
            case EXPIRED -> "邀请已过期。为了保护隐私，旧 token 不会再次激活。";
            case ALREADY_USED -> "这个邀请已经完成接受。如需新增照护者，请主照护者重新创建。";
            case REVOKED -> "这个邀请已撤销，不能继续接受。";
            case UNAVAILABLE -> "邀请页暂不可用，请稍后重试，或先前往下载页安装最新版本。";
            case ACTIVE -> {
                if (failureReason == null) {
                    yield preferredPlatform == null
                            ? "你可以直接打开 app 完成受邀加入，也可以先进入下载页安装 Baby Talk。"
                            : "系统已按当前设备推荐按钮；若跳转失败，也可以改走下载页继续。";
                }
                if ("open_app_unconfigured".equals(failureReason)) {
                    yield "当前未配置安全的打开 app 入口，请先进入下载页。";
                }
                yield "当前公开入口暂不可用，请先进入下载页继续。";
            }
        };
    }

    private String resultForResolution(PublicInviteResolution resolution) {
        return switch (resolution.mode()) {
            case ACTIVE -> "page_view";
            case INVALID -> "invalid";
            case EXPIRED -> "expired";
            case ALREADY_USED -> "already_used";
            case REVOKED -> "revoked";
            case UNAVAILABLE -> "unavailable";
        };
    }

    private Map<String, String> availableOpenAppTargets() {
        var ordered = new LinkedHashMap<String, String>();
        orderTargets(properties.openAppTargets()).forEach((platform, target) -> {
            var normalizedPlatform = normalizePlatform(platform);
            var normalizedTarget = trimToNull(target);
            if (normalizedPlatform == null || normalizedTarget == null) {
                return;
            }
            if (!isAllowedOpenAppTarget(normalizedTarget)) {
                return;
            }
            ordered.put(normalizedPlatform, normalizedTarget);
        });
        return ordered;
    }

    private Map<String, String> orderTargets(Map<String, String> rawTargets) {
        var ordered = new LinkedHashMap<String, String>();
        if (rawTargets == null || rawTargets.isEmpty()) {
            return ordered;
        }
        if (rawTargets.containsKey("android")) {
            ordered.put("android", rawTargets.get("android"));
        }
        if (rawTargets.containsKey("ios")) {
            ordered.put("ios", rawTargets.get("ios"));
        }
        rawTargets.forEach((platform, target) -> {
            if (!ordered.containsKey(platform)) {
                ordered.put(platform, target);
            }
        });
        return ordered;
    }

    private boolean isAllowedOpenAppTarget(String target) {
        try {
            var uri = URI.create(target);
            return "babytalk".equalsIgnoreCase(uri.getScheme())
                    && "invite".equalsIgnoreCase(uri.getHost())
                    && "/open".equals(uri.getPath())
                    && uri.getQuery() == null;
        } catch (IllegalArgumentException exception) {
            return false;
        }
    }

    private boolean hasSafeDownloadFallback() {
        return "/download".equals(trimToNull(properties.downloadFallbackPath()))
                && "caregiver_invite".equals(trimToNull(properties.downloadFallbackSource()));
    }

    private String publicInviteUrl(String token) {
        var baseUrl = properties.publicBaseUrl().endsWith("/")
                ? properties.publicBaseUrl().substring(0, properties.publicBaseUrl().length() - 1)
                : properties.publicBaseUrl();
        return baseUrl + invitePagePath(token);
    }

    private String invitePagePath(String token) {
        return "/invite/" + safeToken(token);
    }

    private String openAppRoutePath(String token, String platform) {
        var builder = UriComponentsBuilder.fromPath("/invite/{token}/open-app")
                .buildAndExpand(safeToken(token))
                .toUriString();
        if (platform == null) {
            return builder;
        }
        return UriComponentsBuilder.fromPath(builder)
                .queryParam("platform", platform)
                .build()
                .toUriString();
    }

    private String downloadRoutePath(String token, String platform) {
        var builder = UriComponentsBuilder.fromPath("/invite/{token}/download")
                .buildAndExpand(safeToken(token))
                .toUriString();
        if (platform == null) {
            return builder;
        }
        return UriComponentsBuilder.fromPath(builder)
                .queryParam("platform", platform)
                .build()
                .toUriString();
    }

    private String directDownloadFallback(String platform) {
        var builder = UriComponentsBuilder.fromPath(
                hasSafeDownloadFallback() ? properties.downloadFallbackPath() : "/download"
        ).queryParam("source", hasSafeDownloadFallback() ? properties.downloadFallbackSource() : "caregiver_invite");
        if (platform != null) {
            builder.queryParam("platform", platform);
        }
        return builder.build().toUriString();
    }

    private String roleLabel(String role) {
        return switch (role) {
            case "primary_caregiver" -> "主照护者";
            case "caregiver" -> "协作照护者";
            default -> role == null ? "未知角色" : role;
        };
    }

    private String sourceLabel(String source) {
        return switch (source) {
            case "household_settings" -> "家庭设置";
            case "invite_banner" -> "邀请横幅";
            case "invite_link" -> "邀请链接";
            default -> source == null ? "未知来源" : source;
        };
    }

    private String platformLabel(String platform) {
        return switch (platform) {
            case "android" -> "Android";
            case "ios" -> "iPhone / iPad";
            default -> platform == null ? "unknown" : platform;
        };
    }

    private String detectPlatform(String userAgent) {
        if (userAgent == null || userAgent.isBlank()) {
            return null;
        }
        var normalized = userAgent.toLowerCase(Locale.ROOT);
        if (normalized.contains("android")) {
            return "android";
        }
        if (normalized.contains("iphone") || normalized.contains("ipad") || normalized.contains("ios")) {
            return "ios";
        }
        return null;
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

    private String inviteTokenLookupRef(String normalizedToken) {
        return sensitiveAuthDataProtector.inviteTokenLookupRef(normalizedToken);
    }

    private String inviteTokenLookupRefForAudit(String rawToken) {
        var normalized = trimToNull(rawToken);
        if (normalized == null || !PUBLIC_TOKEN_PATTERN.matcher(normalized).matches()) {
            return null;
        }
        return inviteTokenLookupRef(normalized);
    }

    private String buildInviteUrl(String token) {
        return publicInviteUrl(token);
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

    private void recordEventSafely(CaregiverInviteRepository.EventRow row) {
        recordAudit(row);
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
        return eventRow(token, householdId, actorAccountId, entrypoint, source, requestedRole, null, result, failureReason, createdAt);
    }

    private CaregiverInviteRepository.EventRow eventRow(
            String token,
            String householdId,
            String actorAccountId,
            String entrypoint,
            String source,
            String requestedRole,
            String platform,
            String result,
            String failureReason,
            Instant createdAt
    ) {
        return new CaregiverInviteRepository.EventRow(
                inviteTokenLookupRefForAudit(token),
                householdId,
                actorAccountId,
                entrypoint,
                source,
                requestedRole,
                sanitizePlatform(platform),
                result,
                sanitizeFailureReason(failureReason),
                dbTime(createdAt)
        );
    }

    private OffsetDateTime dbTime(Instant time) {
        return time == null ? null : time.atOffset(ZoneOffset.UTC);
    }

    private Instant apiTime(OffsetDateTime time) {
        return time == null ? null : time.toInstant();
    }

    private String sanitizePlatform(String platform) {
        var normalized = normalizePlatform(platform);
        return normalized == null ? null : normalized;
    }

    private String normalizePlatform(String rawPlatform) {
        var normalized = trimToNull(rawPlatform);
        if (normalized == null) {
            return null;
        }
        normalized = normalized.toLowerCase(Locale.ROOT).replace('-', '_');
        if (!ALLOWED_PLATFORMS.contains(normalized)) {
            return null;
        }
        return normalized;
    }

    private String trimToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }

    private String safeToken(String token) {
        var normalized = trimToNull(token);
        if (normalized == null) {
            return "unknown";
        }
        return truncate(normalized, 64);
    }

    private String nullToEmpty(String value) {
        return value == null ? "" : value;
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
            Instant updatedAt,
            LatestActor actor,
            NextStep nextStep
    ) {
    }

    public record LatestActor(
            String role,
            String source,
            String result
    ) {
    }

    public record NextStep(
            String spaceId,
            String activityId,
            String reason
    ) {
    }

    public record PracticeRouteArgs(String spaceId, String activityId) {
    }

    public record PageResponse(
            HttpStatus status,
            String result,
            String failureReason,
            AuditStatus auditStatus,
            String html
    ) {
    }

    public record RedirectResponse(
            HttpStatus status,
            String result,
            String failureReason,
            AuditStatus auditStatus,
            URI location,
            String html
    ) {
        public static RedirectResponse redirect(String result, String failureReason, AuditStatus auditStatus, URI location) {
            return new RedirectResponse(HttpStatus.FOUND, result, failureReason, auditStatus, location, "");
        }

        public static RedirectResponse error(
                HttpStatus status,
                String result,
                String failureReason,
                AuditStatus auditStatus,
                String html
        ) {
            return new RedirectResponse(status, result, failureReason, auditStatus, null, html);
        }
    }

    public enum AuditStatus {
        RECORDED,
        FAILED
    }

    private enum InviteResolutionMode {
        ACTIVE,
        INVALID,
        EXPIRED,
        ALREADY_USED,
        REVOKED,
        UNAVAILABLE
    }

    private record PublicInviteResolution(
            InviteResolutionMode mode,
            CaregiverInviteRepository.InviteRow snapshot,
            String token,
            String failureReason,
            AuditStatus auditStatus,
            HttpStatus status
    ) {
        static PublicInviteResolution active(CaregiverInviteRepository.InviteRow snapshot, String rawToken) {
            return new PublicInviteResolution(InviteResolutionMode.ACTIVE, snapshot, rawToken, null, AuditStatus.RECORDED, HttpStatus.OK);
        }

        static PublicInviteResolution invalid(String token, String failureReason, AuditStatus auditStatus, HttpStatus status) {
            return new PublicInviteResolution(InviteResolutionMode.INVALID, null, token, failureReason, auditStatus, status);
        }

        static PublicInviteResolution expired(CaregiverInviteRepository.InviteRow snapshot, String rawToken, String failureReason, AuditStatus auditStatus, HttpStatus status) {
            return new PublicInviteResolution(InviteResolutionMode.EXPIRED, snapshot, rawToken, failureReason, auditStatus, status);
        }

        static PublicInviteResolution alreadyUsed(CaregiverInviteRepository.InviteRow snapshot, String rawToken, String failureReason, AuditStatus auditStatus, HttpStatus status) {
            return new PublicInviteResolution(InviteResolutionMode.ALREADY_USED, snapshot, rawToken, failureReason, auditStatus, status);
        }

        static PublicInviteResolution revoked(CaregiverInviteRepository.InviteRow snapshot, String rawToken, String failureReason, AuditStatus auditStatus, HttpStatus status) {
            return new PublicInviteResolution(InviteResolutionMode.REVOKED, snapshot, rawToken, failureReason, auditStatus, status);
        }

        static PublicInviteResolution unavailable(String token, String failureReason, AuditStatus auditStatus, HttpStatus status) {
            return new PublicInviteResolution(InviteResolutionMode.UNAVAILABLE, null, token, failureReason, auditStatus, status);
        }

        PageResponse toPageResponse(String html) {
            return new PageResponse(status, resultForMode(), failureReason, auditStatus, html);
        }

        RedirectResponse toRedirectError(String html) {
            return RedirectResponse.error(status, resultForMode(), failureReason, auditStatus, html);
        }

        private String resultForMode() {
            return switch (mode) {
                case ACTIVE -> "page_view";
                case INVALID -> "invalid";
                case EXPIRED -> "expired";
                case ALREADY_USED -> "already_used";
                case REVOKED -> "revoked";
                case UNAVAILABLE -> "unavailable";
            };
        }
    }

    private record MediaPalette(
            String bgBase,
            String bgSurface,
            String bgSunken,
            String bgAccentSoft,
            String accent,
            String accentDark,
            String textPrimary,
            String textSecondary,
            String error,
            String positive
    ) {
    }
}
