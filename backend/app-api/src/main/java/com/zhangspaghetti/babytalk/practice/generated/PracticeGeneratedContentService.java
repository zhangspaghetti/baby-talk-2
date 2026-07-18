package com.zhangspaghetti.babytalk.practice.generated;

import cn.hutool.core.util.StrUtil;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator.InvalidGeneratedContentException;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator.RejectedGeneratedContentException;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGenerationService;
import com.zhangspaghetti.babytalk.practice.discovery.PolicyTextMatcher;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryMode;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryCustomSceneProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyProperties;
import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoverySurface;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextSecurityPolicy;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PracticeGeneratedContentService {

    private static final String STATUS_DRAFT = "draft";
    private static final String STATUS_ACTIVE = "active";
    private static final String STATUS_PROMOTED = "promoted";
    private static final String OWNER_INSTALLATION = "installation";
    private static final String OWNER_ACCOUNT = "account";
    private static final String OWNER_PROFILE = "profile";
    private static final String ERROR_GENERATION_IN_PROGRESS = "generation_in_progress";
    private static final String ERROR_GENERATION_UNAVAILABLE = "generation_unavailable";
    private static final String ERROR_GENERATION_TIMEOUT = "generation_timeout";
    private static final String ERROR_GENERATED_CONTENT_REJECTED = "generated_content_rejected";
    private static final String ERROR_GENERATION_INVALID_OUTPUT = "generation_invalid_output";
    private static final String ERROR_INVALID_CUSTOM_SCENE_TEXT = "invalid_custom_scene_text";
    private static final String ERROR_UNSAFE_CUSTOM_SCENE_TEXT = "unsafe_custom_scene_text";
    private static final String ERROR_UNSUPPORTED_CUSTOM_SCENE_TEXT = "unsupported_custom_scene_text";
    private static final String ERROR_CUSTOM_SCENE_RATE_LIMITED = "custom_scene_rate_limited";
    private static final int MIN_CUSTOM_SCENE_CHARS = 4;
    private static final int MAX_CUSTOM_SCENE_CHARS = 80;
    private static final int MAX_NORMALIZED_SCENE_TEXT_CODE_POINTS = 160;
    private static final int MAX_DRAFT_RESERVATION_ATTEMPTS = 5;
    private static final Duration DRAFT_TTL = Duration.ofMinutes(5);
    private static final Duration INSTALLATION_ACTIVE_RETENTION = Duration.ofDays(30);
    private static final Duration INSTALLATION_TERMINAL_RETENTION = Duration.ofDays(7);
    private static final int MIN_CLEANUP_LIMIT = 1;
    private static final int MAX_CLEANUP_LIMIT = 100;
    private final PracticeGeneratedContentMapper mapper;
    private final CustomSceneGenerationService generationService;
    private final CustomSceneGeneratedContentValidator generatedContentValidator;
    private final PracticeDiscoveryCustomSceneProperties customSceneProperties;
    private final PracticeDiscoveryPolicyProperties policyProperties;
    private final PracticeGeneratedContentOwnerProperties ownerProperties;
    private final PracticeGeneratedContentKeyFactory keyFactory;
    private final SceneTextCanonicalizer sceneTextCanonicalizer;
    private final SceneTextSecurityPolicy sceneTextSecurityPolicy;
    private final PolicyTextMatcher policyTextMatcher;
    private final Clock clock;
    private final PracticeGeneratedContentWriteService writeService;

    @Autowired
    public PracticeGeneratedContentService(
            PracticeGeneratedContentMapper mapper,
            PracticeGeneratedContentWriteService writeService,
            CustomSceneGenerationService generationService,
            CustomSceneGeneratedContentValidator generatedContentValidator,
            PracticeDiscoveryCustomSceneProperties customSceneProperties,
            PracticeDiscoveryPolicyProperties policyProperties,
            PracticeGeneratedContentOwnerProperties ownerProperties,
            PracticeGeneratedContentKeyFactory keyFactory,
            SceneTextCanonicalizer sceneTextCanonicalizer,
            SceneTextSecurityPolicy sceneTextSecurityPolicy,
            PolicyTextMatcher policyTextMatcher
    ) {
        this(mapper, writeService, generationService, generatedContentValidator, customSceneProperties,
                policyProperties, Clock.systemUTC(), ownerProperties, keyFactory,
                sceneTextCanonicalizer, sceneTextSecurityPolicy, policyTextMatcher);
    }

    PracticeGeneratedContentService(
            PracticeGeneratedContentMapper mapper,
            PracticeGeneratedContentWriteService writeService,
            CustomSceneGenerationService generationService,
            CustomSceneGeneratedContentValidator generatedContentValidator,
            PracticeDiscoveryCustomSceneProperties customSceneProperties,
            PracticeDiscoveryPolicyProperties policyProperties,
            Clock clock,
            PracticeGeneratedContentOwnerProperties ownerProperties
    ) {
        this(mapper, writeService, generationService, generatedContentValidator, customSceneProperties,
                policyProperties, clock, ownerProperties, new PracticeGeneratedContentKeyFactory(ownerProperties),
                new SceneTextCanonicalizer(),
                new SceneTextSecurityPolicy(policyProperties, new PolicyTextMatcher(new SceneTextCanonicalizer())),
                new PolicyTextMatcher(new SceneTextCanonicalizer()));
    }

    private PracticeGeneratedContentService(
            PracticeGeneratedContentMapper mapper,
            PracticeGeneratedContentWriteService writeService,
            CustomSceneGenerationService generationService,
            CustomSceneGeneratedContentValidator generatedContentValidator,
            PracticeDiscoveryCustomSceneProperties customSceneProperties,
            PracticeDiscoveryPolicyProperties policyProperties,
            Clock clock,
            PracticeGeneratedContentOwnerProperties ownerProperties,
            PracticeGeneratedContentKeyFactory keyFactory,
            SceneTextCanonicalizer sceneTextCanonicalizer,
            SceneTextSecurityPolicy sceneTextSecurityPolicy,
            PolicyTextMatcher policyTextMatcher
    ) {
        this.mapper = mapper;
        this.writeService = java.util.Objects.requireNonNull(writeService, "practice generated content write service is required");
        this.generationService = generationService;
        this.generatedContentValidator = generatedContentValidator;
        this.customSceneProperties = customSceneProperties;
        if (policyProperties == null || ownerProperties == null) {
            throw new IllegalArgumentException("practice generated content typed properties are required");
        }
        this.policyProperties = policyProperties;
        this.ownerProperties = ownerProperties;
        this.keyFactory = java.util.Objects.requireNonNull(keyFactory, "practice generated content key factory is required");
        this.sceneTextCanonicalizer = java.util.Objects.requireNonNull(
                sceneTextCanonicalizer, "scene text canonicalizer is required");
        this.sceneTextSecurityPolicy = java.util.Objects.requireNonNull(
                sceneTextSecurityPolicy, "scene text security policy is required");
        this.policyTextMatcher = java.util.Objects.requireNonNull(
                policyTextMatcher, "policy text matcher is required");
        this.clock = clock;
        var normalizedSecret = ownerProperties.keySecret();
        if (customSceneProperties.enabled()
                && !customSceneProperties.providerDisabled()
                && (normalizedSecret == null || normalizedSecret.getBytes(StandardCharsets.UTF_8).length < 32)) {
            throw new IllegalArgumentException("owner key secret must be explicitly configured with at least 32 bytes");
        }
    }

    public DraftReservation reserveDraft(PracticeGeneratedContentEntity entity) {
        return writeService.reserveDraft(entity, reservationPolicy(entity.ownerScope()));
    }

    public Optional<PracticeGeneratedContentEntity> activateDraft(PracticeGeneratedContentEntity entity) {
        return writeService.activateDraft(entity);
    }

    public void rejectDraft(String generatedContentId, String generationErrorCode, OffsetDateTime updatedAt) {
        writeService.rejectDraft(
                generatedContentId,
                generationErrorCode,
                updatedAt,
                updatedAt.plus(INSTALLATION_TERMINAL_RETENTION));
    }

    public void expireDraft(String generatedContentId, String generationErrorCode, OffsetDateTime updatedAt) {
        writeService.expireDraft(
                generatedContentId,
                generationErrorCode,
                updatedAt,
                updatedAt.plus(INSTALLATION_TERMINAL_RETENTION));
    }

    public Optional<PracticeGeneratedContentEntity> findActiveOrPromotedByGeneratedContentId(String generatedContentId) {
        return Optional.ofNullable(mapper.findActiveOrPromotedByGeneratedContentId(
                generatedContentId, ownerKeyVersion(), nowUtc()));
    }

    public Optional<PracticeGeneratedContentEntity> findActiveOrPromotedByFingerprint(
            String ownerKey,
            String surface,
            String mode,
            String requestFingerprint,
            String promptVersion,
            String strategyVersion
    ) {
        return Optional.ofNullable(mapper.findActiveOrPromotedByFingerprint(
                ownerKey,
                ownerKeyVersion(),
                surface,
                mode,
                requestFingerprint,
                promptVersion,
                strategyVersion,
                policyVersion(),
                nowUtc()));
    }

    public int countRecentGenerationAttempts(String ownerKey, String surface, String mode, OffsetDateTime createdAtFrom) {
        return mapper.countRecentGenerationAttempts(
                ownerKey, ownerKeyVersion(), surface, mode, createdAtFrom);
    }

    public List<PracticeGeneratedContentEntity> findInstallationCleanupCandidates(
            String installationRefHash,
            OffsetDateTime retentionExpiresAtOrBefore,
            int limit
    ) {
        return mapper.findInstallationCleanupCandidates(
                ownerKeyVersion(), installationRefHash, retentionExpiresAtOrBefore, boundCleanupLimit(limit));
    }

    @Transactional
    public int deleteExpiredInstallationRows(OffsetDateTime retentionExpiresAtOrBefore, int limit) {
        return mapper.deleteExpiredInstallationRows(
                retentionExpiresAtOrBefore, boundCleanupLimit(limit));
    }

    @Transactional
    public int expireStaleDrafts(OffsetDateTime generationExpiresAtOrBefore, int limit) {
        var now = generationExpiresAtOrBefore.withOffsetSameInstant(ZoneOffset.UTC);
        return mapper.expireStaleDrafts(
                now,
                now.plus(INSTALLATION_TERMINAL_RETENTION),
                now,
                boundCleanupLimit(limit));
    }

    @Transactional
    public int deleteAccountOwned(String accountId) {
        return mapper.deleteAccountOwned(accountId);
    }

    public void requireCustomSceneGenerationAvailable() {
        if (!customSceneProperties.enabled() || customSceneProperties.providerDisabled()) {
            throw generationUnavailable("provider_disabled");
        }
        if (customSceneProperties.agenticProvider()) {
            throw generationUnavailable("agentic_not_implemented");
        }
    }

    public PracticeGeneratedContentEntity generateCustomScene(
            CustomSceneDiscoveryRequest request
    ) {
        requireCustomSceneGenerationAvailable();
        var forms = sceneTextCanonicalizer.derive(request.customSceneText());
        sceneTextSecurityPolicy.requireSafe(forms);
        var normalizedSceneText = validateDisplayLength(forms.displayText());
        var owner = resolveOwner(request);
        var requestFingerprint = fingerprint(request, owner, forms.securityText());
        var existing = mapper.findLiveByFingerprint(
                owner.ownerKey(),
                ownerKeyVersion(),
                request.surface(),
                request.mode(),
                requestFingerprint,
                promptVersion(),
                strategyVersion(),
                policyVersion());
        if (existing != null) {
            if (isActiveOrPromoted(existing)) {
                if (isReusableActiveOrPromoted(existing)) {
                    return existing;
                }
            } else if (!isExpiredDraft(existing)) {
                throw generationInProgress(existing.generatedContentId());
            }
        }
        for (var reservationAttempt = 0; reservationAttempt < MAX_DRAFT_RESERVATION_ATTEMPTS; reservationAttempt++) {
            var draft = draftRow(request, owner, requestFingerprint, normalizedSceneText, reservationAttempt);
            DraftReservation reservation;
            try {
                reservation = reserveDraft(draft);
            } catch (GeneratedContentIdConflictException exception) {
                continue;
            } catch (PracticeGeneratedContentWriteService.RateLimitExceededException exception) {
                var window = "burst".equals(exception.windowName())
                        ? customSceneProperties.burstWindow()
                        : customSceneProperties.dailyWindow();
                throw rateLimited(
                        owner.ownerScope(), exception.limit(), exception.windowName(), window);
            }

            var reserved = reservation.row();
            if (isActiveOrPromoted(reserved)) {
                return reserved;
            }
            if (!STATUS_DRAFT.equals(reserved.status())) {
                throw generationInProgress(reserved.generatedContentId());
            }
            if (!reservation.inserted()) {
                if (isExpiredDraft(reserved)) {
                    expireDraft(reserved.generatedContentId(), "draft_expired");
                    continue;
                }
                throw generationInProgress(reserved.generatedContentId());
            }
            return generateAndActivate(request, owner, requestFingerprint, normalizedSceneText, reserved);
        }

        throw generationInProgress(generatedContentId(owner, requestFingerprint, 0));
    }

    private PracticeGeneratedContentWriteService.ReservationPolicy reservationPolicy(String ownerScope) {
        var now = nowUtc();
        var caps = rateLimitCaps(ownerScope);
        return new PracticeGeneratedContentWriteService.ReservationPolicy(
                now,
                now.minus(customSceneProperties.burstWindow()),
                caps.burstLimit(),
                now.minus(customSceneProperties.dailyWindow()),
                caps.dailyLimit(),
                now.plus(INSTALLATION_TERMINAL_RETENTION));
    }

    private PracticeGeneratedContentEntity generateAndActivate(
            CustomSceneDiscoveryRequest request,
            OwnerContext owner,
            String requestFingerprint,
            String normalizedSceneText,
            PracticeGeneratedContentEntity reserved
    ) {

        CustomSceneGenerationService.GeneratedPracticeContentCandidate candidate;
        try {
            candidate = generationService.generateCustomSceneStarter(new CustomSceneGenerationService.CustomSceneGenerationRequest(
                    reserved.generatedContentId(),
                    normalizedSceneText,
                    PracticeDiscoverySurface.fromWireValue(request.surface()),
                    PracticeDiscoveryMode.fromWireValue(request.mode()),
                    request.ageRange(),
                    request.parentGoal(),
                    request.locale(),
                    "gen_trace_" + reserved.generatedContentId().substring(4),
                    customSceneProperties.timeout(),
                    contentConstraints(),
                    promptVersion(),
                    strategyVersion()
            ));
        } catch (CustomSceneGenerationService.GenerationUnavailableException exception) {
            if (exception.retryable()) {
                bestEffortExpireDraft(reserved.generatedContentId(), exception.reason(), exception);
            } else {
                bestEffortRejectDraft(reserved.generatedContentId(), exception.reason(), exception);
            }
            throw generationUnavailable(exception.reason(), exception.retryable(), exception);
        } catch (CustomSceneGenerationService.GenerationTimeoutException exception) {
            bestEffortExpireDraft(reserved.generatedContentId(), ERROR_GENERATION_TIMEOUT, exception);
            throw generationTimeout(exception);
        } catch (RuntimeException exception) {
            bestEffortExpireDraft(reserved.generatedContentId(), "provider_failure", exception);
            throw generationUnavailable("provider_failure", true, exception);
        }

        var validated = validateGeneratedOutput(reserved.generatedContentId(), candidate, normalizedSceneText);
        try {
            var activated = activateDraft(activeRow(reserved, validated, requestFingerprint))
                    .or(() -> findActiveOrPromotedByFingerprint(
                            owner.ownerKey(),
                            request.surface(),
                            request.mode(),
                            requestFingerprint,
                            promptVersion(),
                            strategyVersion()))
                    .orElseThrow(() -> generationInProgress(reserved.generatedContentId()));
            if (!isActiveOrPromoted(activated)) {
                throw generationInProgress(activated.generatedContentId());
            }
            return activated;
        } catch (ContractException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            bestEffortExpireDraft(reserved.generatedContentId(), "activation_failure", exception);
            throw generationUnavailable("activation_failure", true, exception);
        }
    }

    private CustomSceneGenerationService.GeneratedPracticeContentCandidate validateGeneratedOutput(
            String generatedContentId,
            CustomSceneGenerationService.GeneratedPracticeContentCandidate candidate,
            String normalizedSceneText
    ) {
        try {
            return generatedContentValidator.normalizeAndValidate(
                    candidate,
                    contentConstraints(),
                    new CustomSceneGeneratedContentValidator.GeneratedOutputValidationContext(normalizedSceneText)
            );
        } catch (RejectedGeneratedContentException exception) {
            bestEffortRejectDraft(generatedContentId, ERROR_GENERATED_CONTENT_REJECTED, exception);
            var contract = new ContractException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    ERROR_GENERATED_CONTENT_REJECTED,
                    "生成内容不适合展示。",
                    Map.of("reason", exception.reason())
            );
            contract.initCause(exception);
            throw contract;
        } catch (InvalidGeneratedContentException exception) {
            bestEffortRejectDraft(generatedContentId, ERROR_GENERATION_INVALID_OUTPUT, exception);
            var contract = new ContractException(
                    HttpStatus.BAD_GATEWAY,
                    ERROR_GENERATION_INVALID_OUTPUT,
                    "生成内容结构不合法。",
                    Map.of("field", exception.fieldName(), "retryable", true)
            );
            contract.initCause(exception);
            throw contract;
        } catch (RuntimeException exception) {
            bestEffortExpireDraft(generatedContentId, "validation_failure", exception);
            throw generationUnavailable("validation_failure", true, exception);
        }
    }

    private CustomSceneGenerationService.ContentConstraints contentConstraints() {
        return customSceneProperties.fakeProvider()
                ? CustomSceneGenerationService.ContentConstraints.fakeProviderDefaults()
                : CustomSceneGenerationService.ContentConstraints.defaults();
    }

    private PracticeGeneratedContentEntity draftRow(
            CustomSceneDiscoveryRequest request,
            OwnerContext owner,
            String requestFingerprint,
            String normalizedSceneText,
            int reservationAttempt
    ) {
        var now = nowUtc();
        var row = new PracticeGeneratedContentEntity(
                generatedContentId(owner, requestFingerprint, reservationAttempt),
                owner.ownerScope(),
                owner.ownerKey(),
                owner.accountId(),
                owner.installationRefHash(),
                owner.profileId(),
                request.surface(),
                request.mode(),
                requestFingerprint,
                normalizedSceneText,
                request.ageRange(),
                request.parentGoal(),
                request.locale(),
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                STATUS_DRAFT,
                null,
                null,
                null,
                promptVersion(),
                strategyVersion(),
                1,
                null,
                now,
                now.plus(DRAFT_TTL),
                now,
                now
        );
        row.setOwnerKeyVersion(ownerKeyVersion());
        row.setPolicyVersion(policyVersion());
        row.setRetentionExpiresAt(OWNER_INSTALLATION.equals(owner.ownerScope())
                ? now.plus(INSTALLATION_ACTIVE_RETENTION)
                : null);
        return row;
    }

    private PracticeGeneratedContentEntity activeRow(
            PracticeGeneratedContentEntity draft,
            CustomSceneGenerationService.GeneratedPracticeContentCandidate candidate,
            String requestFingerprint
    ) {
        var slugHash = keyFactory.stableDigest(
                draft.ownerKey() + "|" + requestFingerprint + "|" + promptVersion() + "|" + strategyVersion());
        var now = nowUtc();
        var row = new PracticeGeneratedContentEntity(
                draft.generatedContentId(),
                draft.ownerScope(),
                draft.ownerKey(),
                draft.accountId(),
                draft.installationRefHash(),
                draft.profileId(),
                draft.surface(),
                draft.mode(),
                draft.requestFingerprint(),
                null,
                draft.ageRange(),
                draft.parentGoal(),
                draft.locale(),
                "gen_scene_" + slugHash.substring(0, 20),
                "gen_activity_" + slugHash.substring(20, 40),
                "gen_phrase_" + slugHash.substring(40, 60),
                candidate.spaceTitleZh(),
                candidate.activityTitleZh(),
                candidate.sceneTagEn(),
                candidate.coachTipZh(),
                candidate.englishText(),
                candidate.chineseText(),
                candidate.pronunciationHint(),
                candidate.difficulty(),
                candidate.generationSource(),
                STATUS_ACTIVE,
                candidate.providerTraceId(),
                candidate.retrievalTraceId(),
                candidate.modelName(),
                draft.promptVersion(),
                draft.strategyVersion(),
                draft.contentVersion(),
                null,
                draft.generationStartedAt(),
                null,
                draft.createdAt(),
                now
        );
        row.setOwnerKeyVersion(draft.ownerKeyVersion());
        row.setPolicyVersion(draft.policyVersion());
        row.setRetentionExpiresAt(OWNER_INSTALLATION.equals(draft.ownerScope())
                ? now.plus(INSTALLATION_ACTIVE_RETENTION)
                : null);
        return row;
    }

    private OwnerContext resolveOwner(CustomSceneDiscoveryRequest request) {
        if (trimToNull(request.profileId()) != null) {
            var accountId = trimToNull(request.accountId());
            if (accountId == null) {
                throw new ContractException(
                        HttpStatus.BAD_REQUEST,
                        "invalid_generated_content_owner",
                        "profile owner 缺少 accountId。"
                );
            }
            return new OwnerContext(
                    OWNER_PROFILE,
                    keyFactory.ownerKey(OWNER_PROFILE, accountId + ":" + request.profileId()),
                    accountId,
                    null,
                    request.profileId()
            );
        }

        var accountId = trimToNull(request.accountId());
        if (accountId != null) {
            return new OwnerContext(
                    OWNER_ACCOUNT,
                    keyFactory.ownerKey(OWNER_ACCOUNT, accountId),
                    accountId,
                    null,
                    null
            );
        }

        var installationId = trimToNull(request.installationId());
        if (installationId == null) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_installation_id",
                    "installationId 不合法。",
                    Map.of("field", "installationId")
            );
        }
        return new OwnerContext(
                OWNER_INSTALLATION,
                keyFactory.ownerKey(OWNER_INSTALLATION, installationId),
                null,
                keyFactory.installationRefHash(installationId),
                null
        );
    }

    private String fingerprint(CustomSceneDiscoveryRequest request, OwnerContext owner, String securitySceneText) {
        return keyFactory.requestFingerprint(
                owner.ownerKey(),
                new PracticeGeneratedContentKeyFactory.RequestFingerprintMaterial(
                        request.surface(),
                        request.mode(),
                        securitySceneText,
                        request.ageRange(),
                        request.parentGoal(),
                        request.locale(),
                        promptVersion(),
                        strategyVersion(),
                        policyVersion(),
                        1));
    }

    private String generatedContentId(OwnerContext owner, String requestFingerprint, int reservationAttempt) {
        var base = "pgc_" + keyFactory.stableDigest(owner.ownerKey()
                + "|" + requestFingerprint
                + "|" + promptVersion()
                + "|" + strategyVersion()).substring(0, 32);
        if (reservationAttempt == 0) {
            return base;
        }
        return base + "_" + keyFactory.stableDigest(
                base + "|retry=" + reservationAttempt + "|" + UUID.randomUUID()).substring(0, 8);
    }

    private String promptVersion() {
        return customSceneProperties.promptVersion();
    }

    private String strategyVersion() {
        return customSceneProperties.strategyVersion();
    }

    private String policyVersion() {
        return policyProperties.policyVersion();
    }

    private String ownerKeyVersion() {
        return ownerProperties.keyVersion();
    }

    private String validateDisplayLength(String displayText) {
        if (displayText == null) {
            throw invalidCustomSceneText();
        }
        var length = sceneTextCanonicalizer.graphemeLength(displayText);
        if (length < MIN_CUSTOM_SCENE_CHARS || length > MAX_CUSTOM_SCENE_CHARS) {
            throw invalidCustomSceneText();
        }
        if (sceneTextCanonicalizer.codePointLength(displayText) > MAX_NORMALIZED_SCENE_TEXT_CODE_POINTS) {
            throw invalidCustomSceneText();
        }
        if (policyTextMatcher.containsAny(displayText, policyProperties.unsupportedIntents())) {
            throw unsupportedCustomSceneText("unsupported_intent");
        }
        return displayText;
    }

    private ContractException invalidCustomSceneText() {
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                ERROR_INVALID_CUSTOM_SCENE_TEXT,
                "customSceneText 长度不合法。",
                Map.of("min", MIN_CUSTOM_SCENE_CHARS, "max", MAX_CUSTOM_SCENE_CHARS)
        );
    }

    private ContractException unsupportedCustomSceneText(String reason) {
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                ERROR_UNSUPPORTED_CUSTOM_SCENE_TEXT,
                "customSceneText 需要是照护场景。",
                Map.of("reason", reason)
        );
    }

    private void rejectDraft(String generatedContentId, String generationErrorCode) {
        rejectDraft(generatedContentId, generationErrorCode, nowUtc());
    }

    private void expireDraft(String generatedContentId, String generationErrorCode) {
        expireDraft(generatedContentId, generationErrorCode, nowUtc());
    }

    private ContractException generationInProgress(String generatedContentId) {
        return new ContractException(
                HttpStatus.CONFLICT,
                ERROR_GENERATION_IN_PROGRESS,
                "该自定义场景正在生成。",
                Map.of("generatedContentId", generatedContentId, "retryable", true)
        );
    }

    private ContractException generationUnavailable(String reason) {
        return generationUnavailable(reason, false, null);
    }

    private ContractException generationUnavailable(String reason, boolean retryable, RuntimeException cause) {
        var contract = new ContractException(
                HttpStatus.SERVICE_UNAVAILABLE,
                ERROR_GENERATION_UNAVAILABLE,
                "自定义场景生成暂不可用。",
                Map.of(
                        "retryable", retryable,
                        "suggestCatalogFallback", true,
                        "reason", reason
                )
        );
        if (cause != null) {
            contract.initCause(cause);
        }
        return contract;
    }

    private void bestEffortExpireDraft(String generatedContentId, String errorCode, RuntimeException originalFailure) {
        try {
            expireDraft(generatedContentId, errorCode);
        } catch (RuntimeException cleanupFailure) {
            originalFailure.addSuppressed(cleanupFailure);
        }
    }

    private void bestEffortRejectDraft(String generatedContentId, String errorCode, RuntimeException originalFailure) {
        try {
            rejectDraft(generatedContentId, errorCode);
        } catch (RuntimeException cleanupFailure) {
            originalFailure.addSuppressed(cleanupFailure);
        }
    }

    private ContractException generationTimeout(RuntimeException cause) {
        var contract = new ContractException(
                HttpStatus.GATEWAY_TIMEOUT,
                ERROR_GENERATION_TIMEOUT,
                "自定义场景生成超时。",
                Map.of("retryable", true, "suggestCatalogFallback", true)
        );
        contract.initCause(cause);
        return contract;
    }

    private ContractException rateLimited(String ownerScope, int limit, String windowName, Duration window) {
        var windowSeconds = window.toSeconds();
        return new ContractException(
                HttpStatus.TOO_MANY_REQUESTS,
                ERROR_CUSTOM_SCENE_RATE_LIMITED,
                "自定义场景生成次数过多，请稍后再试。",
                Map.of(
                        "scope", ownerScope,
                        "limit", limit,
                        "window", windowName,
                        "windowSeconds", windowSeconds,
                        "retryAfterSeconds", windowSeconds
                )
        );
    }

    private RateLimitCaps rateLimitCaps(String ownerScope) {
        if (OWNER_INSTALLATION.equals(ownerScope)) {
            return new RateLimitCaps(
                    customSceneProperties.installationBurstLimit(),
                    customSceneProperties.installationDailyLimit());
        }
        return new RateLimitCaps(
                customSceneProperties.accountBurstLimit(),
                customSceneProperties.accountDailyLimit());
    }

    private int boundCleanupLimit(int limit) {
        return Math.max(MIN_CLEANUP_LIMIT, Math.min(MAX_CLEANUP_LIMIT, limit));
    }

    private boolean isActiveOrPromoted(PracticeGeneratedContentEntity row) {
        return STATUS_ACTIVE.equals(row.status()) || STATUS_PROMOTED.equals(row.status());
    }

    private boolean isReusableActiveOrPromoted(PracticeGeneratedContentEntity row) {
        return isActiveOrPromoted(row)
                && (!"installation".equals(row.ownerScope())
                || (row.retentionExpiresAt() != null && row.retentionExpiresAt().isAfter(nowUtc())));
    }

    private boolean isExpiredDraft(PracticeGeneratedContentEntity row) {
        return STATUS_DRAFT.equals(row.status())
                && row.generationExpiresAt() != null
                && !row.generationExpiresAt().isAfter(nowUtc());
    }

    private String trimToNull(String value) {
        return StrUtil.trimToNull(value);
    }

    private OffsetDateTime nowUtc() {
        return OffsetDateTime.now(clock).withOffsetSameInstant(ZoneOffset.UTC);
    }

    public record CustomSceneDiscoveryRequest(
            String surface,
            String mode,
            String installationId,
            String accountId,
            String profileId,
            String ageRange,
            String parentGoal,
            String locale,
            String customSceneText
    ) {
    }

    private record OwnerContext(
            String ownerScope,
            String ownerKey,
            String accountId,
            String installationRefHash,
            String profileId
    ) {
    }

    private record RateLimitCaps(
            int burstLimit,
            int dailyLimit
    ) {
    }

    public record DraftReservation(
            PracticeGeneratedContentEntity row,
            boolean inserted
    ) {
    }

    public static class GeneratedContentIdConflictException extends RuntimeException {

        private final String generatedContentId;

        public GeneratedContentIdConflictException(String generatedContentId, Throwable cause) {
            super("practice generated content id already exists: " + generatedContentId, cause);
            this.generatedContentId = generatedContentId;
        }

        public String generatedContentId() {
            return generatedContentId;
        }
    }
}
