package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.ApiContractProperties;
import com.zhangspaghetti.babytalk.config.ConsumerAuthProperties;
import com.zhangspaghetti.babytalk.security.JwtTokenService;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthConsentSyncService {

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(AuthConsentSyncService.class);

    private static final Set<String> ALLOWED_REACTION_TYPES =
            Set.of("cooperating", "hesitant", "resisting", "no_response", "other");

    private final AuthConsentSyncRepository repository;
    private final SmsVerificationProvider smsVerificationProvider;
    private final HouseholdSharedContextProjector householdSharedContextProjector;
    private final ApiContractProperties contractProperties;
    private final ConsumerAuthProperties consumerAuthProperties;
    private final JwtTokenService jwtTokenService;
    private final Clock clock = Clock.systemUTC();

    public AuthConsentSyncService(
            AuthConsentSyncRepository repository,
            SmsVerificationProvider smsVerificationProvider,
            HouseholdSharedContextProjector householdSharedContextProjector,
            ApiContractProperties contractProperties,
            ConsumerAuthProperties consumerAuthProperties,
            JwtTokenService jwtTokenService
    ) {
        this.repository = repository;
        this.smsVerificationProvider = smsVerificationProvider;
        this.householdSharedContextProjector = householdSharedContextProjector;
        this.contractProperties = contractProperties;
        this.consumerAuthProperties = consumerAuthProperties;
        this.jwtTokenService = jwtTokenService;
    }

    @Transactional
    public ChallengeResponse createChallenge(String phoneNumber) {
        var normalizedPhone = normalizePhone(phoneNumber);
        var now = Instant.now(clock);
        SmsVerificationProvider.SmsChallenge issued;
        try {
            issued = smsVerificationProvider.issueChallenge(normalizedPhone, now);
        } catch (SmsVerificationProvider.ProviderMisconfiguredException exception) {
            throw new ContractException(HttpStatus.SERVICE_UNAVAILABLE, "sms_provider_unconfigured", exception.getMessage());
        } catch (SmsVerificationProvider.RetryableChallengeException exception) {
            throw new ContractException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "sms_provider_retryable",
                    exception.getMessage(),
                    Map.of("retryable", true)
            );
        }

        var challengeId = "challenge_" + UUID.randomUUID();
        repository.insertChallenge(
                new AuthConsentSyncRepository.ChallengeRow(
                        challengeId,
                        normalizedPhone,
                        issued.verificationCode(),
                        "pending",
                        now,
                        issued.expiresAt(),
                        null,
                        null
                )
        );
        log.info("[AUTH] 验证码已创建: challengeId={}, phone={}, codeLen={}", challengeId, issued.maskedPhoneNumber(), issued.codeLength());
        return new ChallengeResponse(challengeId, issued.maskedPhoneNumber(), issued.codeLength(), issued.expiresAt());
    }

    @Transactional(noRollbackFor = ContractException.class)
    public SessionResponse verifyChallenge(String challengeId, String verificationCode, String installationId) {
        if (challengeId == null || challengeId.isBlank()) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "challenge_id_required", "challengeId 不能为空。");
        }
        if (verificationCode == null || !verificationCode.matches("\\d{4,8}")) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_verification_code", "验证码必须是 4-8 位数字。");
        }
        var normalizedInstallationId = normalizeInstallationId(installationId);

        log.info("[AUTH] 验证请求: challengeId={}, codeLen={}", challengeId, verificationCode.length());
        var challenge = repository.findChallenge(challengeId)
                .orElseThrow(() -> new ContractException(HttpStatus.BAD_REQUEST, "challenge_not_found", "challenge 不存在。"));
        var now = Instant.now(clock);
        if (challenge.expiresAt().isBefore(now)) {
            log.warn("[AUTH] 验证码已过期: challengeId={}", challengeId);
            repository.markChallengeExpired(challengeId, "expired_before_verify");
            throw new ContractException(HttpStatus.BAD_REQUEST, "challenge_expired", "验证码已过期，请重新获取。", Map.of("retryable", true));
        }
        if (!challenge.verificationCode().equals(verificationCode)) {
            log.warn("[AUTH] 验证码不匹配: challengeId={}, expected={}, got={}", challengeId, challenge.verificationCode(), verificationCode);
            throw new ContractException(HttpStatus.BAD_REQUEST, "verification_code_invalid", "验证码错误。", Map.of("retryable", true));
        }

        log.info("[AUTH] 验证成功: challengeId={}", challengeId);
        int affectedRows = repository.markChallengeVerified(challengeId, now);
        if (affectedRows == 0) {
            throw new ContractException(HttpStatus.CONFLICT, "challenge_already_verified", "challenge 已被其他请求验证。");
        }
        var account = repository.findActiveAccountByPhone(challenge.phoneNumber())
                .orElseGet(() -> repository.insertAccount(
                        new AuthConsentSyncRepository.AccountRow(
                                "acct_" + UUID.randomUUID(),
                                challenge.phoneNumber(),
                                "active",
                                "signed_out",
                                now,
                                null
                        )
                ));

        var sessionId = "sess_" + UUID.randomUUID();
        var session = new AuthConsentSyncRepository.SessionContextRow(
                sessionId,
                account.accountId(),
                normalizedInstallationId,
                "active",
                now,
                null,
                account.phoneNumber(),
                account.status(),
                account.latestConsentStatus(),
                account.createdAt(),
                account.deletedAt()
        );
        repository.insertSession(session);
        var refreshTokenId = newRefreshTokenId();
        insertActiveRefreshToken(account.accountId(), session.sessionId(), refreshTokenId, now);
        return buildSessionResponse(account, session, refreshTokenId);
    }

    @Transactional(noRollbackFor = ContractException.class)
    public SessionResponse refresh(String rawRefreshToken) {
        var decodedRefreshToken = decodeRefreshToken(rawRefreshToken);
        var refreshToken = repository.lockRefreshToken(decodedRefreshToken.tokenId())
                .orElseThrow(() -> invalidRefreshToken("not_found"));
        if (!refreshClaimsMatchRow(decodedRefreshToken, refreshToken)) {
            log.warn("consumer-auth refresh rejected. reason=claim_mismatch");
            throw invalidRefreshToken("claim_mismatch");
        }

        var now = Instant.now(clock);
        var status = resolveRefreshTokenStatus(refreshToken, now);
        if (status != RefreshTokenStatus.ACTIVE) {
            log.warn("consumer-auth refresh rejected. accountId={} reason={}", refreshToken.accountId(), status.name().toLowerCase(Locale.ROOT));
            throw refreshTokenException(status);
        }

        var session = repository.findSessionAnyStatus(refreshToken.sessionId())
                .orElseThrow(() -> invalidRefreshToken("session_not_found"));
        if (!refreshToken.accountId().equals(session.accountId())) {
            log.warn("consumer-auth refresh rejected. accountId={} reason=session_mismatch", refreshToken.accountId());
            throw invalidRefreshToken("session_mismatch");
        }
        if (!"active".equals(session.sessionStatus())) {
            log.warn("consumer-auth refresh rejected. accountId={} reason=session_invalid", refreshToken.accountId());
            throw invalidRefreshToken("session_invalid");
        }
        var account = repository.findAccountById(refreshToken.accountId())
                .filter(candidate -> "active".equals(candidate.status()))
                .orElseThrow(() -> invalidRefreshToken("account_missing"));

        var replacementTokenId = newRefreshTokenId();
        repository.rotateRefreshToken(refreshToken.refreshTokenId(), replacementTokenId, now);
        insertActiveRefreshToken(account.accountId(), session.sessionId(), replacementTokenId, now);
        log.info("consumer-auth refresh success. accountId={}", account.accountId());
        return buildSessionResponse(account, session, replacementTokenId);
    }

    @Transactional(noRollbackFor = ContractException.class)
    public LogoutResponse logout(String rawRefreshToken) {
        var decodedRefreshToken = decodeRefreshToken(rawRefreshToken);
        var refreshToken = repository.lockRefreshToken(decodedRefreshToken.tokenId())
                .orElseThrow(() -> invalidRefreshToken("not_found"));
        if (!refreshClaimsMatchRow(decodedRefreshToken, refreshToken)) {
            log.warn("consumer-auth logout rejected. reason=claim_mismatch");
            throw invalidRefreshToken("claim_mismatch");
        }

        var loggedOutAt = Instant.now(clock);
        var status = resolveRefreshTokenStatus(refreshToken, loggedOutAt);
        if (status != RefreshTokenStatus.ACTIVE) {
            log.warn("consumer-auth logout rejected. accountId={} reason={}", refreshToken.accountId(), status.name().toLowerCase(Locale.ROOT));
            throw refreshTokenException(status);
        }

        repository.revokeRefreshToken(refreshToken.refreshTokenId(), loggedOutAt);
        repository.revokeSession(refreshToken.sessionId(), loggedOutAt);
        log.info("consumer-auth logout success. accountId={}", refreshToken.accountId());
        return new LogoutResponse(true, loggedOutAt);
    }

    @Transactional
    public ConsentResponse acceptConsent(String sessionId, String consentVersion) {
        var session = requireExistingActiveSession(sessionId);
        var now = Instant.now(clock);
        if ("accepted".equals(session.latestConsentStatus())) {
            repository.insertConsentAudit(audit(session, "accept", "duplicate", sanitizeReason(consentVersion), now));
            return new ConsentResponse(false, "duplicate", "accepted", session.accountId(), session.sessionId(), now);
        }
        repository.updateAccountConsent(session.accountId(), "accepted");
        repository.insertConsentAudit(audit(session, "accept", "applied", sanitizeReason(consentVersion), now));
        return new ConsentResponse(true, "applied", "accepted", session.accountId(), session.sessionId(), now);
    }

    @Transactional
    public ConsentResponse revokeConsent(String sessionId, String reason) {
        var session = requireExistingSessionAnyStatus(sessionId);
        if ("deleted".equals(session.accountStatus())) {
            throw new ContractException(HttpStatus.GONE, "account_deleted", "账号已删除。请重新注册。");
        }
        var now = Instant.now(clock);
        if ("revoked".equals(session.latestConsentStatus())) {
            repository.insertConsentAudit(audit(session, "revoke", "duplicate", sanitizeReason(reason), now));
            return new ConsentResponse(false, "duplicate", "revoked", session.accountId(), session.sessionId(), now);
        }
        repository.updateAccountConsent(session.accountId(), "revoked");
        repository.updateSessionsStatus(session.accountId(), "revoked", now);
        repository.insertConsentAudit(audit(session, "revoke", "applied", sanitizeReason(reason), now));
        return new ConsentResponse(true, "applied", "revoked", session.accountId(), session.sessionId(), now);
    }

    @Transactional
    public DeleteResponse deleteAccount(String sessionId, String reason) {
        var session = requireExistingSessionAnyStatus(sessionId);
        var now = Instant.now(clock);
        if ("deleted".equals(session.accountStatus())) {
            repository.insertConsentAudit(audit(session, "delete", "duplicate", sanitizeReason(reason), now));
            return new DeleteResponse(false, "duplicate", session.accountId(), session.sessionId(), 0, now);
        }

        var deletedEvents = repository.deleteInteractionEvents(session.accountId());
        repository.updateSessionsStatus(session.accountId(), "deleted", now);
        repository.tombstoneAccount(session.accountId(), "deleted:" + session.accountId(), now);
        repository.insertConsentAudit(audit(session, "delete", "applied", sanitizeReason(reason), now));
        return new DeleteResponse(true, "applied", session.accountId(), session.sessionId(), deletedEvents, now);
    }

    @Transactional
    public SyncBatchResponse ingestEvents(String sessionId, String installationId, List<SyncEventRequest> events) {
        var session = requireSessionForSync(sessionId);
        var normalizedInstallationId = normalizeInstallationId(installationId);
        if (!normalizedInstallationId.equals(session.installationId())) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "installation_mismatch", "请求 installationId 与当前 session 不一致。");
        }
        if (events == null || events.isEmpty()) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "empty_batch", "同步 batch 不能为空。");
        }
        if (events.size() > contractProperties.syncMaxBatchSize()) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "batch_too_large",
                    "同步 batch 超过上限。",
                    Map.of("maxBatchSize", contractProperties.syncMaxBatchSize())
            );
        }

        var seenEventKeys = new LinkedHashSet<String>();
        var acceptedEventKeys = new ArrayList<String>();
        var duplicateEventKeys = new ArrayList<String>();
        var now = Instant.now(clock);

        for (var event : events) {
            var validated = validateSyncEvent(normalizedInstallationId, event, seenEventKeys);
            try {
                if (repository.insertInteractionEvent(session.accountId(), session.sessionId(), validated, now)) {
                    acceptedEventKeys.add(validated.eventKey());
                } else {
                    duplicateEventKeys.add(validated.eventKey());
                }
            } catch (DataAccessException exception) {
                throw new ContractException(
                        HttpStatus.BAD_REQUEST,
                        "sync_batch_rejected",
                        "同步 batch 被拒绝，整批已回滚。",
                        Map.of(
                                "failedEventKey", validated.eventKey(),
                                "reason", simplifyDataAccessMessage(exception)
                        )
                );
            }
        }

        if (!acceptedEventKeys.isEmpty()) {
            try {
                householdSharedContextProjector.refreshForAccount(session.accountId(), now);
            } catch (ContractException | DataAccessException exception) {
                // projection runs in REQUIRES_NEW — its failure does NOT roll back the committed event inserts.
                // log and continue: events are committed, projection will refresh on the next sync.
                log.warn("sync: household projection refresh failed; events committed, projection deferred. accountId={}", session.accountId(), exception);
            }
        }

        return new SyncBatchResponse(
                session.accountId(),
                session.sessionId(),
                normalizedInstallationId,
                events.size(),
                acceptedEventKeys.size(),
                duplicateEventKeys.size(),
                acceptedEventKeys,
                duplicateEventKeys,
                now
        );
    }

    @Transactional(readOnly = true)
    public BootstrapResponse bootstrap(String sessionId, String installationId) {
        var session = requireSessionForSync(sessionId);
        var normalizedInstallationId = normalizeInstallationId(installationId);
        if (!normalizedInstallationId.equals(session.installationId())) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "installation_mismatch", "请求 installationId 与当前 session 不一致。");
        }
        var events = repository.listInteractionEvents(session.accountId(), normalizedInstallationId, contractProperties.bootstrapMaxEvents())
                .stream()
                .map(row -> new BootstrapEvent(
                        row.eventKey(),
                        row.localEventId(),
                        row.installationId(),
                        row.spaceId(),
                        row.activityId(),
                        row.phraseId(),
                        row.reactionType(),
                        row.clientTimestamp(),
                        row.receivedAt()
                ))
                .toList();
        return new BootstrapResponse(
                session.accountId(),
                session.sessionId(),
                normalizedInstallationId,
                session.latestConsentStatus(),
                events.size(),
                events,
                Instant.now(clock)
        );
    }

    @Transactional
    public AccessValidationResult validateAccessToken(String accountId, String sessionId, String refreshTokenId) {
        if (accountId == null || accountId.isBlank() || accountId.length() > 64) {
            return AccessValidationResult.INVALID;
        }
        if (sessionId == null || sessionId.isBlank() || sessionId.length() > 128) {
            return AccessValidationResult.INVALID;
        }
        if (refreshTokenId == null || refreshTokenId.isBlank() || refreshTokenId.length() > 64) {
            return AccessValidationResult.INVALID;
        }
        var refreshToken = repository.findRefreshToken(refreshTokenId).orElse(null);
        if (refreshToken == null
                || !accountId.equals(refreshToken.accountId())
                || !sessionId.equals(refreshToken.sessionId())) {
            return AccessValidationResult.INVALID;
        }
        var status = resolveRefreshTokenStatus(refreshToken, Instant.now(clock));
        if (status != RefreshTokenStatus.ACTIVE) {
            return switch (status) {
                case ROTATED -> AccessValidationResult.ROTATED;
                case REVOKED -> AccessValidationResult.REVOKED;
                case EXPIRED -> AccessValidationResult.EXPIRED;
                default -> AccessValidationResult.INVALID;
            };
        }
        var session = repository.findSessionAnyStatus(sessionId).orElse(null);
        if (session == null || !accountId.equals(session.accountId())) {
            return AccessValidationResult.SESSION_INVALID;
        }
        if ("deleted".equals(session.accountStatus())) {
            return AccessValidationResult.ACCOUNT_DELETED;
        }
        if (!"active".equals(session.sessionStatus())) {
            return AccessValidationResult.SESSION_INVALID;
        }
        return AccessValidationResult.ACTIVE;
    }

    @Transactional(readOnly = true)
    public int countInteractionEvents(String accountId, String installationId) {
        return repository.countInteractionEvents(accountId, installationId);
    }

    @Transactional(readOnly = true)
    public int countAllInteractionEvents() {
        return repository.countAllInteractionEvents();
    }

    @Transactional(readOnly = true)
    public String resolveAccountIdForGrowthSummary(String sessionId) {
        return requireSessionForSync(sessionId).accountId();
    }

    @Transactional(readOnly = true)
    public List<AuditEntry> listAuditEntries(String accountId) {
        return repository.listAuditEntries(accountId)
                .stream()
                .map(row -> new AuditEntry(
                        row.accountId(),
                        row.sessionId(),
                        row.installationId(),
                        row.action(),
                        row.result(),
                        row.reason(),
                        row.createdAt()
                ))
                .toList();
    }

    private AuthConsentSyncRepository.SessionContextRow requireExistingActiveSession(String sessionId) {
        var normalizedSessionId = normalizeSessionId(sessionId);
        var session = repository.findActiveSession(normalizedSessionId)
                .orElseThrow(() -> new ContractException(HttpStatus.UNAUTHORIZED, "invalid_session", "session 不存在或已失效。"));
        if ("deleted".equals(session.accountStatus())) {
            throw new ContractException(HttpStatus.GONE, "account_deleted", "账号已删除。请重新注册。");
        }
        return session;
    }

    private AuthConsentSyncRepository.SessionContextRow requireExistingSessionAnyStatus(String sessionId) {
        var normalizedSessionId = normalizeSessionId(sessionId);
        return repository.findSessionAnyStatus(normalizedSessionId)
                .orElseThrow(() -> new ContractException(HttpStatus.UNAUTHORIZED, "invalid_session", "session 不存在。"));
    }

    private AuthConsentSyncRepository.SessionContextRow requireSessionForSync(String sessionId) {
        var session = requireExistingSessionAnyStatus(sessionId);
        if ("deleted".equals(session.accountStatus()) || "deleted".equals(session.sessionStatus())) {
            throw new ContractException(HttpStatus.GONE, "account_deleted", "账号已删除，bootstrap/sync 不再可用。请重新注册。");
        }
        if ("revoked".equals(session.sessionStatus()) || "revoked".equals(session.latestConsentStatus())) {
            throw new ContractException(HttpStatus.CONFLICT, "consent_revoked", "同意已撤回，请重新登录并再次同意后再同步。", Map.of("retryable", true));
        }
        if (!"accepted".equals(session.latestConsentStatus())) {
            throw new ContractException(HttpStatus.CONFLICT, "consent_required", "当前账号尚未完成同意，不能执行 bootstrap/sync。", Map.of("retryable", true));
        }
        if (!"active".equals(session.sessionStatus())) {
            throw new ContractException(HttpStatus.UNAUTHORIZED, "invalid_session", "session 不存在或已失效。");
        }
        return session;
    }

    private AuthConsentSyncRepository.SyncEventRecord validateSyncEvent(
            String requestInstallationId,
            SyncEventRequest event,
            Set<String> seenEventKeys
    ) {
        if (event == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_event", "batch 中存在空事件。");
        }
        var localEventId = requireTrimmed(event.localEventId(), "localEventId");
        var installationId = normalizeInstallationId(event.installationId());
        if (!requestInstallationId.equals(installationId)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "installation_mismatch", "事件 installationId 与 batch 不一致。");
        }
        var expectedEventKey = installationId + ":" + localEventId;
        var eventKey = requireTrimmed(event.eventKey(), "eventKey");
        if (!expectedEventKey.equals(eventKey)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "unknown_event_key", "eventKey 与 installationId/localEventId 不一致。", Map.of("eventKey", eventKey));
        }
        if (!seenEventKeys.add(eventKey)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "duplicate_event_key_in_batch", "同一 batch 内不允许重复 eventKey。", Map.of("eventKey", eventKey));
        }
        var reactionType = requireTrimmed(event.reactionType(), "reactionType").toLowerCase(Locale.ROOT);
        if (!ALLOWED_REACTION_TYPES.contains(reactionType)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_reaction_type", "reactionType 非法。");
        }
        return new AuthConsentSyncRepository.SyncEventRecord(
                eventKey,
                localEventId,
                installationId,
                requireTrimmed(event.spaceId(), "spaceId"),
                requireTrimmed(event.activityId(), "activityId"),
                requireTrimmed(event.phraseId(), "phraseId"),
                reactionType,
                requireClientTimestamp(event.clientTimestamp())
        );
    }

    private AuthConsentSyncRepository.AuditRow audit(
            AuthConsentSyncRepository.SessionContextRow session,
            String action,
            String result,
            String reason,
            Instant createdAt
    ) {
        return new AuthConsentSyncRepository.AuditRow(
                session.accountId(),
                session.sessionId(),
                session.installationId(),
                action,
                result,
                reason,
                createdAt
        );
    }

    private ContractException syncBatchRejectedForProjection(Exception exception) {
        var reason = exception instanceof ContractException contractException
                ? simplifyProjectionFailureReason(contractException)
                : simplifyDataAccessMessage((DataAccessException) exception);
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                "sync_batch_rejected",
                "同步 batch 被拒绝，整批已回滚。",
                Map.of(
                        "retryable", true,
                        "reason", reason,
                        "phase", "household_shared_context_projection"
                )
        );
    }

    private String simplifyProjectionFailureReason(ContractException exception) {
        var reason = exception.details().get("reason");
        if (reason instanceof String value && !value.isBlank()) {
            return value;
        }
        var field = exception.details().get("field");
        if (field instanceof String value && !value.isBlank()) {
            return value + "_invalid";
        }
        return exception.code();
    }

    private String simplifyDataAccessMessage(DataAccessException exception) {
        var message = exception.getMostSpecificCause() == null
                ? exception.getMessage()
                : exception.getMostSpecificCause().getMessage();
        if (message == null || message.isBlank()) {
            return "database_write_failed";
        }
        return message.length() > 240 ? message.substring(0, 240) : message;
    }

    private JwtTokenService.DecodedToken decodeRefreshToken(String rawRefreshToken) {
        try {
            var decoded = jwtTokenService.decode(requireToken(rawRefreshToken));
            if (decoded.tokenType() != JwtTokenService.TokenType.REFRESH) {
                throw invalidRefreshToken("wrong_type");
            }
            if (decoded.subject() == null || decoded.subject().isBlank()) {
                throw invalidRefreshToken("missing_sub");
            }
            if (decoded.sessionId() == null || decoded.sessionId().isBlank()) {
                throw invalidRefreshToken("missing_sid");
            }
            if (decoded.refreshTokenId() == null || decoded.refreshTokenId().isBlank()) {
                throw invalidRefreshToken("missing_rtid");
            }
            if (decoded.tokenId() == null || decoded.tokenId().isBlank()) {
                throw invalidRefreshToken("missing_jti");
            }
            if (!decoded.tokenId().equals(decoded.refreshTokenId())) {
                throw invalidRefreshToken("rtid_mismatch");
            }
            if (decoded.sessionId().length() > 128) {
                throw invalidRefreshToken("invalid_sid");
            }
            if (decoded.refreshTokenId().length() > 64) {
                throw invalidRefreshToken("invalid_rtid");
            }
            return decoded;
        } catch (ContractException exception) {
            throw exception;
        } catch (JwtException | IllegalArgumentException exception) {
            throw invalidRefreshToken("decode_failed");
        }
    }

    private boolean refreshClaimsMatchRow(
            JwtTokenService.DecodedToken decodedRefreshToken,
            AuthConsentSyncRepository.RefreshTokenRow refreshToken
    ) {
        return decodedRefreshToken.subject().equals(refreshToken.accountId())
                && decodedRefreshToken.sessionId().equals(refreshToken.sessionId())
                && decodedRefreshToken.refreshTokenId().equals(refreshToken.refreshTokenId());
    }

    private RefreshTokenStatus resolveRefreshTokenStatus(AuthConsentSyncRepository.RefreshTokenRow refreshToken, Instant now) {
        if (refreshToken.expiresAt().isBefore(now) && "active".equals(refreshToken.status())) {
            repository.expireRefreshToken(refreshToken.refreshTokenId(), now);
            return RefreshTokenStatus.EXPIRED;
        }
        return switch (refreshToken.status()) {
            case "active" -> RefreshTokenStatus.ACTIVE;
            case "revoked" -> RefreshTokenStatus.REVOKED;
            case "rotated" -> RefreshTokenStatus.ROTATED;
            case "expired" -> RefreshTokenStatus.EXPIRED;
            default -> RefreshTokenStatus.INVALID;
        };
    }

    private void insertActiveRefreshToken(String accountId, String sessionId, String refreshTokenId, Instant issuedAt) {
        repository.insertRefreshToken(new AuthConsentSyncRepository.RefreshTokenRow(
                refreshTokenId,
                accountId,
                sessionId,
                "active",
                issuedAt,
                issuedAt.plus(consumerAuthProperties.refreshTokenTtl()),
                issuedAt,
                null,
                null,
                null
        ));
    }

    private SessionResponse buildSessionResponse(
            AuthConsentSyncRepository.AccountRow account,
            AuthConsentSyncRepository.SessionContextRow session,
            String refreshTokenId
    ) {
        var accessToken = jwtTokenService.issueConsumerAccessToken(
                consumerAuthProperties.issuer(),
                account.accountId(),
                session.sessionId(),
                refreshTokenId,
                consumerAuthProperties.accessTokenTtl()
        );
        var refreshToken = jwtTokenService.issueConsumerRefreshToken(
                consumerAuthProperties.issuer(),
                account.accountId(),
                session.sessionId(),
                refreshTokenId,
                consumerAuthProperties.refreshTokenTtl()
        );
        return new SessionResponse(
                account.accountId(),
                session.sessionId(),
                maskPhone(account.phoneNumber()),
                session.createdAt(),
                session.latestConsentStatus(),
                accessToken.tokenValue(),
                refreshToken.tokenValue(),
                "Bearer",
                accessToken.expiresAt(),
                refreshToken.expiresAt()
        );
    }

    private String normalizePhone(String phoneNumber) {
        if (phoneNumber == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_phone_number", "手机号不能为空。");
        }
        var digits = phoneNumber.replaceAll("[^0-9]", "");
        if (!digits.matches("1\\d{10}")) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_phone_number", "手机号必须是 11 位大陆手机号。");
        }
        return digits;
    }

    private String normalizeInstallationId(String installationId) {
        var normalized = requireTrimmed(installationId, "installationId");
        if (normalized.length() > 128) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_installation_id", "installationId 过长。");
        }
        return normalized;
    }

    private String normalizeSessionId(String sessionId) {
        var normalized = requireTrimmed(sessionId, "sessionId");
        if (normalized.length() > 128) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_session_id", "sessionId 过长。");
        }
        return normalized;
    }

    private String requireTrimmed(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "missing_" + fieldName, fieldName + " 不能为空。");
        }
        return value.trim();
    }

    private String requireToken(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            throw invalidRefreshToken("missing");
        }
        return rawToken.trim();
    }

    private Instant requireClientTimestamp(Instant clientTimestamp) {
        if (clientTimestamp == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "missing_client_timestamp", "clientTimestamp 不能为空。");
        }
        return clientTimestamp;
    }

    private ContractException invalidRefreshToken(String reason) {
        return new ContractException(HttpStatus.UNAUTHORIZED, "invalid_refresh_token", "refresh token 无效。", Map.of("reason", reason));
    }

    private ContractException refreshTokenException(RefreshTokenStatus status) {
        return switch (status) {
            case REVOKED -> new ContractException(HttpStatus.UNAUTHORIZED, "refresh_token_revoked", "refresh token 已失效，请重新登录。", Map.of());
            case ROTATED -> new ContractException(HttpStatus.UNAUTHORIZED, "refresh_token_rotated", "refresh token 已被轮换，请使用新的 token。", Map.of());
            case EXPIRED -> new ContractException(HttpStatus.UNAUTHORIZED, "refresh_token_expired", "refresh token 已过期，请重新登录。", Map.of());
            default -> invalidRefreshToken(status.name().toLowerCase(Locale.ROOT));
        };
    }

    private String newRefreshTokenId() {
        return "crt_" + UUID.randomUUID();
    }

    private String maskPhone(String phoneNumber) {
        return phoneNumber.substring(0, 3) + "****" + phoneNumber.substring(phoneNumber.length() - 4);
    }

    private String sanitizeReason(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        var trimmed = value.trim();
        return trimmed.length() > 240 ? trimmed.substring(0, 240) : trimmed;
    }

    public enum AccessValidationResult {
        ACTIVE,
        INVALID,
        ROTATED,
        REVOKED,
        EXPIRED,
        SESSION_INVALID,
        ACCOUNT_DELETED
    }

    private enum RefreshTokenStatus {
        ACTIVE,
        REVOKED,
        ROTATED,
        EXPIRED,
        INVALID
    }

    public record ChallengeResponse(
            String challengeId,
            String maskedPhoneNumber,
            int codeLength,
            Instant expiresAt
    ) {
    }

    public record SessionResponse(
            String accountId,
            String sessionId,
            String maskedPhoneNumber,
            Instant createdAt,
            String consentStatus,
            String accessToken,
            String refreshToken,
            String tokenType,
            Instant accessTokenExpiresAt,
            Instant refreshTokenExpiresAt
    ) {
    }

    public record LogoutResponse(boolean loggedOut, Instant loggedOutAt) {
    }

    public record ConsentResponse(
            boolean applied,
            String result,
            String consentStatus,
            String accountId,
            String sessionId,
            Instant updatedAt
    ) {
    }

    public record DeleteResponse(
            boolean applied,
            String result,
            String accountId,
            String sessionId,
            int deletedEventCount,
            Instant updatedAt
    ) {
    }

    public record SyncEventRequest(
            String eventKey,
            String localEventId,
            String installationId,
            String spaceId,
            String activityId,
            String phraseId,
            String reactionType,
            Instant clientTimestamp
    ) {
    }

    public record SyncBatchResponse(
            String accountId,
            String sessionId,
            String installationId,
            int receivedCount,
            int acceptedCount,
            int duplicateCount,
            List<String> acceptedEventKeys,
            List<String> duplicateEventKeys,
            Instant syncedAt
    ) {
    }

    public record BootstrapEvent(
            String eventKey,
            String localEventId,
            String installationId,
            String spaceId,
            String activityId,
            String phraseId,
            String reactionType,
            Instant clientTimestamp,
            Instant receivedAt
    ) {
    }

    public record BootstrapResponse(
            String accountId,
            String sessionId,
            String installationId,
            String consentStatus,
            int eventCount,
            List<BootstrapEvent> events,
            Instant bootstrapAt
    ) {
    }

    public record AuditEntry(
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
